-- Harden writes on messages.
--
-- Found 2026-09-02 during the full RLS audit. messages_participant_access is
-- FOR ALL, and its two clauses do not agree:
--
--   USING      -> caller is ANY participant in the booking
--   WITH CHECK -> auth.uid() = sender_id
--
-- USING selects which rows you may touch; WITH CHECK validates the row you
-- leave behind. Because USING is "any participant" and WITH CHECK only
-- requires the RESULTING row to name you as sender, a participant could
-- UPDATE another party's message and reattribute it to themselves. A client
-- could rewrite what the talent said and have it attributed to the client.
--
-- Being FOR ALL, it also permitted DELETE of any participant's message.
--
-- This matters because cancellations are human-reviewed, and message history
-- is the natural evidence in a "they agreed to X" dispute. Either party could
-- edit or delete the other's messages before review, undetectably.
--
-- Decision settled 2026-09-02: content is IMMUTABLE once sent. This table is
-- evidence; an editable message with no revision history is worse than none.
-- An edit feature would need an edited_at column and a revision table.
--
-- Note the shape differs from the fix originally proposed. Restricting UPDATE
-- to auth.uid() = sender_id would have broken read receipts, since marking a
-- message read is an update performed by the RECIPIENT. The policy therefore
-- stays open to participants and the trigger controls the columns.

CREATE OR REPLACE FUNCTION public.enforce_message_writes()
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
    NEW.sender_id  := auth.uid();
    NEW.created_at := now();
    NEW.is_read    := false;
    NEW.read_at    := NULL;
    RETURN NEW;
  END IF;

  -- Everything except the read receipt is frozen. sender_id restored from
  -- OLD is what closes the reattribution attack.
  NEW.id              := OLD.id;
  NEW.booking_id      := OLD.booking_id;
  NEW.sender_id       := OLD.sender_id;
  NEW.content         := OLD.content;
  NEW.attachment_url  := OLD.attachment_url;
  NEW.attachment_type := OLD.attachment_type;
  NEW.created_at      := OLD.created_at;

  IF NEW.is_read IS DISTINCT FROM OLD.is_read THEN
    -- A sender marking their own message read would read, in a dispute, as
    -- "you saw this and did not object".
    IF auth.uid() = OLD.sender_id THEN
      RAISE EXCEPTION 'A sender cannot mark their own message as read.'
        USING ERRCODE = '42501';
    END IF;

    IF OLD.is_read AND NOT NEW.is_read THEN
      -- Un-reading is silently reverted rather than raised: it is a
      -- meaningless action, not an attack worth an error.
      NEW.is_read := OLD.is_read;
      NEW.read_at := OLD.read_at;
    ELSE
      NEW.read_at := now();
    END IF;
  ELSE
    NEW.read_at := OLD.read_at;
  END IF;

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS enforce_message_writes ON public.messages;
CREATE TRIGGER enforce_message_writes
  BEFORE INSERT OR UPDATE ON public.messages
  FOR EACH ROW EXECUTE FUNCTION public.enforce_message_writes();

-- Split FOR ALL. No DELETE policy is created, so DELETE is denied by
-- absence - messages are a record, not a participant-managed object.
DROP POLICY IF EXISTS messages_participant_access ON public.messages;

CREATE POLICY messages_participant_select ON public.messages
  FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.bookings b
     WHERE b.id = messages.booking_id
       AND (b.client_user_id = auth.uid()
            OR EXISTS (SELECT 1 FROM public.profiles_talent pt
                        WHERE pt.id = b.talent_id AND pt.user_id = auth.uid())
            OR EXISTS (SELECT 1 FROM public.profiles_venues pv
                        WHERE pv.id = b.venue_id AND pv.user_id = auth.uid()))
  ));

CREATE POLICY messages_participant_insert ON public.messages
  FOR INSERT TO authenticated
  WITH CHECK (
    auth.uid() = sender_id
    AND EXISTS (
      SELECT 1 FROM public.bookings b
       WHERE b.id = messages.booking_id
         AND (b.client_user_id = auth.uid()
              OR EXISTS (SELECT 1 FROM public.profiles_talent pt
                          WHERE pt.id = b.talent_id AND pt.user_id = auth.uid())
              OR EXISTS (SELECT 1 FROM public.profiles_venues pv
                          WHERE pv.id = b.venue_id AND pv.user_id = auth.uid()))
    )
  );

-- Stays open to participants rather than senders: the recipient is the one
-- who marks a message read. The trigger pins every other column.
CREATE POLICY messages_participant_update ON public.messages
  FOR UPDATE TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.bookings b
     WHERE b.id = messages.booking_id
       AND (b.client_user_id = auth.uid()
            OR EXISTS (SELECT 1 FROM public.profiles_talent pt
                        WHERE pt.id = b.talent_id AND pt.user_id = auth.uid())
            OR EXISTS (SELECT 1 FROM public.profiles_venues pv
                        WHERE pv.id = b.venue_id AND pv.user_id = auth.uid()))
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.bookings b
     WHERE b.id = messages.booking_id
       AND (b.client_user_id = auth.uid()
            OR EXISTS (SELECT 1 FROM public.profiles_talent pt
                        WHERE pt.id = b.talent_id AND pt.user_id = auth.uid())
            OR EXISTS (SELECT 1 FROM public.profiles_venues pv
                        WHERE pv.id = b.venue_id AND pv.user_id = auth.uid()))
  ));

COMMENT ON FUNCTION public.enforce_message_writes() IS
  'Freezes every column on messages except the read receipt. content is '
  'immutable once sent - this table is dispute evidence. Only a non-sender '
  'may set is_read, and read_at is stamped by the trigger. service_role and '
  'admin bypass.';
