import React, { useState } from 'react';
import { supabase } from '../services/supabase';

interface SignInModalProps {
  open: boolean;
  onClose: () => void;
  reason?: string;
}

export const SignInModal: React.FC<SignInModalProps> = ({ open, onClose, reason }) => {
  const [showOther, setShowOther] = useState(false);
  const [email, setEmail] = useState('');
  const [sent, setSent] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  if (!open) return null;

  const signInWithGoogle = async (): Promise<void> => {
    setBusy(true);
    setError(null);
    const { error: err } = await supabase.auth.signInWithOAuth({
      provider: 'google',
      options: { redirectTo: window.location.href },
    });
    if (err) {
      setError(err.message);
      setBusy(false);
    }
  };

  const sendMagicLink = async (e: React.FormEvent): Promise<void> => {
    e.preventDefault();
    setBusy(true);
    setError(null);
    const { error: err } = await supabase.auth.signInWithOtp({
      email,
      options: { emailRedirectTo: window.location.href },
    });
    if (err) setError(err.message);
    else setSent(true);
    setBusy(false);
  };

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4"
      onClick={onClose}
      id="signin-modal-backdrop"
    >
      <div
        className="w-full max-w-sm rounded-2xl bg-brand-surface border border-white/10 p-6 shadow-2xl"
        onClick={(e) => e.stopPropagation()}
      >
        <h3 className="text-lg font-black text-white mb-1">Sign in to continue</h3>
        {reason && <p className="text-sm text-white/60 mb-5">{reason}</p>}

        <button
          onClick={signInWithGoogle}
          disabled={busy}
          className="w-full rounded-xl bg-white text-black font-bold py-3 disabled:opacity-50"
          id="signin-google"
        >
          Continue with Google
        </button>

        {!showOther && (
          <button
            onClick={() => setShowOther(true)}
            className="mt-4 w-full text-xs text-white/40 hover:text-white/70 underline"
            id="signin-other"
          >
            Sign in another way
          </button>
        )}

        {showOther && !sent && (
          <form onSubmit={sendMagicLink} className="mt-5">
            <input
              type="email"
              required
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="you@company.com"
              className="w-full rounded-xl bg-black/30 border border-white/10 px-4 py-3 text-white text-sm"
              id="signin-email"
            />
            <button
              type="submit"
              disabled={busy}
              className="mt-3 w-full rounded-xl border border-white/20 text-white font-bold py-3 disabled:opacity-50"
            >
              Email me a sign-in link
            </button>
          </form>
        )}

        {sent && (
          <p className="mt-5 text-sm text-brand-lime">
            Check your inbox for a sign-in link.
          </p>
        )}

        {error && <p className="mt-4 text-sm text-red-400">{error}</p>}

        <button
          onClick={onClose}
          className="mt-5 w-full text-xs text-white/40 hover:text-white/70"
        >
          Cancel
        </button>
      </div>
    </div>
  );
};
