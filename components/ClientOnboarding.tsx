import React, { useState } from 'react';
import { supabase } from '../services/supabase';
import { toE164 } from '../utils/phone';

interface ClientOnboardingProps {
  userId: string;
  email: string | null;
  suggestedName: string;
  onComplete: () => void;
}

export const ClientOnboarding: React.FC<ClientOnboardingProps> = ({
  userId,
  email,
  suggestedName,
  onComplete,
}) => {
  const [fullName, setFullName] = useState(suggestedName);
  const [dob, setDob] = useState('');
  const [phone, setPhone] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleSubmit = async (e: React.FormEvent): Promise<void> => {
    e.preventDefault();
    setError(null);

    if (!fullName.trim()) {
      setError('Please tell us your name.');
      return;
    }

    const eighteenthBirthday = new Date(dob);
    eighteenthBirthday.setFullYear(eighteenthBirthday.getFullYear() + 18);
    if (eighteenthBirthday > new Date()) {
      setError('You must be 18 or older to book through En4tainment.');
      return;
    }

    setBusy(true);

    const { error: userError } = await supabase.from('profiles_users').insert({
      id: userId,
      email: email ?? undefined,
      phone: toE164(phone),
      role: 'client',
      status: 'active',
      date_of_birth: dob,
    });

    if (userError) {
      setBusy(false);
      setError(
        userError.code === '23514'
          ? 'You must be 18 or older to book through En4tainment.'
          : 'Could not save your details. Please try again.'
      );
      return;
    }

    const { error: clientError } = await supabase.from('profiles_clients').insert({
      user_id: userId,
      full_name: fullName.trim(),
    });

    if (clientError) {
      setBusy(false);
      setError('Your account was created but your profile was not. Please refresh and try again.');
      return;
    }

    setBusy(false);
    onComplete();
  };

  return (
    <div className="pt-32 pb-20 min-h-screen bg-brand-dark flex items-center justify-center px-4" id="client-onboarding">
      <div className="max-w-md w-full bg-brand-surface p-10 rounded-3xl border border-white/10 shadow-2xl">
        <h1 className="text-3xl font-black text-white mb-3 uppercase italic">Just a few details</h1>
        <p className="text-gray-400 mb-8">
          We ask for your date of birth because bookings on En4tainment are for over-18s only,
          and your number so the artist can reach you about your event.
        </p>

        <form onSubmit={handleSubmit} className="space-y-5">
          <div className="space-y-2">
            <label className="text-xs font-black text-brand-lime uppercase tracking-widest">Full Name</label>
            <input
              type="text"
              required
              value={fullName}
              onChange={(e) => setFullName(e.target.value)}
              className="w-full bg-brand-dark/50 border border-white/10 rounded-xl px-4 py-3 text-white outline-none focus:ring-2 focus:ring-brand-purple"
              id="onboarding-name"
            />
          </div>

          <div className="space-y-2">
            <label className="text-xs font-black text-brand-lime uppercase tracking-widest">Date of Birth</label>
            <input
              type="date"
              required
              value={dob}
              onChange={(e) => setDob(e.target.value)}
              max={new Date().toISOString().split('T')[0]}
              className="w-full bg-brand-dark/50 border border-white/10 rounded-xl px-4 py-3 text-white outline-none focus:ring-2 focus:ring-brand-purple"
              id="onboarding-dob"
            />
          </div>

          <div className="space-y-2">
            <label className="text-xs font-black text-brand-lime uppercase tracking-widest">Mobile Number</label>
            <input
              type="tel"
              required
              value={phone}
              onChange={(e) => setPhone(e.target.value)}
              placeholder="077 123 4567"
              className="w-full bg-brand-dark/50 border border-white/10 rounded-xl px-4 py-3 text-white outline-none focus:ring-2 focus:ring-brand-purple"
              id="onboarding-phone"
            />
          </div>

          {error && <p className="text-sm text-red-400" role="alert">{error}</p>}

          <button
            type="submit"
            disabled={busy}
            className="w-full py-3 rounded-xl bg-brand-purple text-white font-bold disabled:opacity-50"
            id="onboarding-submit"
          >
            {busy ? 'Saving…' : 'Continue'}
          </button>
        </form>
      </div>
    </div>
  );
};