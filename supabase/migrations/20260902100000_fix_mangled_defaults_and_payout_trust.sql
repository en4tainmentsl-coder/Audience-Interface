-- Fix nine mangled column defaults, and pin trust fields on
-- talent_payout_accounts.
--
-- PART 1 - MANGLED DEFAULTS
--
-- Nine text columns across four tables carry defaults that were double- or
-- triple-quoted through some export/reimport cycle. The SQL fragment ::text
-- is being stored AS DATA. What actually lands:
--
--   talent_payout_accounts.bank_country  -> ''LK''::text
--   talent_payout_accounts.currency      -> ''LKR''::text
--   profiles_admin.permissions           -> ' { } '
--   profiles_clients.preferred_*         -> '' { } ''::text'::text
--   profiles_venues (5 columns)          -> ''' { } '''::text
--
-- This is not hypothetical. The one existing profiles_clients row already
-- holds the corrupt value in both columns. A payout record would carry a
-- currency of ''LKR''::text, which no bulk transfer generator will parse.
--
-- Broader than the previously filed scope, which covered only
-- profiles_clients and profiles_venues.
--
-- All ten affected columns are plain nullable text. Intent is clearly an
-- empty-array-shaped string for the list-like columns, and the ISO codes for
-- the payout columns.

ALTER TABLE public.talent_payout_accounts
  ALTER COLUMN bank_country SET DEFAULT 'LK',
  ALTER COLUMN currency     SET DEFAULT 'LKR';

ALTER TABLE public.profiles_admin
  ALTER COLUMN permissions SET DEFAULT '{}';

ALTER TABLE public.profiles_clients
  ALTER COLUMN preferred_genre    SET DEFAULT '{}',
  ALTER COLUMN preferred_language SET DEFAULT '{}';

ALTER TABLE public.profiles_venues
  ALTER COLUMN audience_nationality   SET DEFAULT '{}',
  ALTER COLUMN language_preference    SET DEFAULT '{}',
  ALTER COLUMN music_genre_preference SET DEFAULT '{}',
  ALTER COLUMN performance_days       SET DEFAULT '{}',
  ALTER COLUMN type_of_occasion       SET DEFAULT '{}';

-- Repair rows already written with the corrupt value. Matched on the ::text
-- marker rather than the exact string, since the mangling differs per table.
-- Deliberately narrow: only rows whose value is corrupt are touched, so any
-- genuine user data is left alone.
UPDATE public.profiles_clients
   SET preferred_genre = '{}'
 WHERE preferred_genre LIKE '%::text%';
UPDATE public.profiles_clients
   SET preferred_language = '{}'
 WHERE preferred_language LIKE '%::text%';

UPDATE public.profiles_venues SET audience_nationality   = '{}' WHERE audience_nationality   LIKE '%::text%';
UPDATE public.profiles_venues SET language_preference    = '{}' WHERE language_preference    LIKE '%::text%';
UPDATE public.profiles_venues SET music_genre_preference = '{}' WHERE music_genre_preference LIKE '%::text%';
UPDATE public.profiles_venues SET performance_days       = '{}' WHERE performance_days       LIKE '%::text%';
UPDATE public.profiles_venues SET type_of_occasion       = '{}' WHERE type_of_occasion       LIKE '%::text%';

UPDATE public.profiles_admin SET permissions = '{}' WHERE permissions LIKE '%{ }%';

UPDATE public.talent_payout_accounts SET bank_country = 'LK'  WHERE bank_country LIKE '%::text%';
UPDATE public.talent_payout_accounts SET currency     = 'LKR' WHERE currency     LIKE '%::text%';

-- PART 2 - PAYOUT TRUST FIELDS
--
-- talent_payout_accounts holds no bank account number: only
-- bank_account_last_4, bank_name, and payable_account_id, a token reference.
-- Talent_Interface/src/components/ProfileEditor.tsx documents the design -
-- bank data is tokenised via Payable.lk and there is deliberately no
-- full-account-number column.
--
-- WHO may write this table is DEFERRED to the payout build. The current
-- tpa_manage_own ALL policy is left untouched.
--
-- These pins are correct under EITHER outcome, which is why they ship now:
-- a talent must never self-verify, never self-complete onboarding, and never
-- set their own payout token. If writes later become service-role-only, the
-- talent branch becomes unreachable but stays correct.

CREATE OR REPLACE FUNCTION public.enforce_payout_account_trust_fields()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF auth.uid() IS NULL OR get_my_role() = 'admin' THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'INSERT' THEN
    NEW.is_verified                 := false;
    NEW.payable_onboarding_complete := false;
    NEW.payable_account_id          := '';
    NEW.created_at                  := now();
    NEW.updated_at                  := now();
    RETURN NEW;
  END IF;

  NEW.id                          := OLD.id;
  NEW.talent_id                   := OLD.talent_id;
  NEW.created_at                  := OLD.created_at;

  -- Verification state and the payout token are set by the tokenisation
  -- callback, never by the account holder.
  NEW.is_verified                 := OLD.is_verified;
  NEW.payable_onboarding_complete := OLD.payable_onboarding_complete;
  NEW.payable_account_id          := OLD.payable_account_id;

  NEW.updated_at := now();
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS enforce_payout_account_trust_fields ON public.talent_payout_accounts;
CREATE TRIGGER enforce_payout_account_trust_fields
  BEFORE INSERT OR UPDATE ON public.talent_payout_accounts
  FOR EACH ROW EXECUTE FUNCTION public.enforce_payout_account_trust_fields();

COMMENT ON FUNCTION public.enforce_payout_account_trust_fields() IS
  'Pins is_verified, payable_onboarding_complete, payable_account_id, '
  'talent_id and created_at against non-admin writes. Correct under either '
  'outcome of the deferred question of who may write this table.';
