import React, { useState } from 'react';
import { Button } from '../components/Button';
import { Mail, CheckCircle, AlertCircle } from 'lucide-react';
import { supabase } from '../services/supabase';

// The previous version of this page was a lie: handleSubmit set a success flag
// and discarded the message, and every input was uncontrolled, so there was
// nothing to send even in principle. Everything below exists to make the
// success panel true.

const MAX_MESSAGE = 5000;

export const Contact: React.FC = () => {
  const [submitted, setSubmitted] = useState<boolean>(false);
  const [sending, setSending]     = useState<boolean>(false);
  const [error, setError]         = useState<string | null>(null);

  const [form, setForm] = useState({
    first_name: '',
    last_name: '',
    email: '',
    message: '',
    website: '', // honeypot — see the hidden field below
  });

  const set = (field: keyof typeof form) =>
    (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) =>
      setForm(f => ({ ...f, [field]: e.target.value }));

  const handleSubmit = async (e: React.FormEvent): Promise<void> => {
    e.preventDefault();
    if (sending) return;

    setSending(true);
    setError(null);

    try {
      const { data, error: fnError } = await supabase.functions.invoke('contact', {
        body: form,
      });

      // A non-2xx from the function arrives as FunctionsHttpError, whose message
      // is a generic "non-2xx status code" — the useful text is in the response
      // body, which has to be read off the error's context.
      if (fnError) {
        let message = 'Something went wrong. Please try again, or email us directly at info@en4tainment.com.';
        const res = (fnError as { context?: Response }).context;
        if (res && typeof res.json === 'function') {
          const body = await res.json().catch(() => null);
          if (body?.error && (res.status === 400 || res.status === 429)) {
            message = body.error;
          }
        }
        setError(message);
        return;
      }

      if (!data?.success) {
        setError('Something went wrong. Please try again, or email us directly at info@en4tainment.com.');
        return;
      }

      setSubmitted(true);
      setForm({ first_name: '', last_name: '', email: '', message: '', website: '' });

    } catch {
      // Network failure, offline, DNS. The message never left the browser.
      setError('We could not reach our servers. Please check your connection and try again.');
    } finally {
      setSending(false);
    }
  };

  const inputClass = "w-full bg-brand-dark border border-white/10 rounded-lg px-4 py-3 text-white focus:ring-2 focus:ring-brand-purple focus:border-transparent outline-none disabled:opacity-60";

  return (
    <div className="pt-24 pb-20 min-h-screen bg-brand-dark" id="contact-page">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">

        <div className="text-center mb-16">
          <h1 className="text-4xl font-bold text-white mb-4">Get in Touch</h1>
          <p className="text-gray-400">Have general questions? We'd love to hear from you.</p>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-12 text-left">

          {/* Info Side */}
          <div className="space-y-8">
            <div className="bg-brand-surface p-8 rounded-2xl border border-white/5">
              <h3 className="text-2xl font-bold text-white mb-6">Contact Information</h3>
              <div className="space-y-6">
                <div className="flex items-start gap-4">
                  <div className="bg-brand-lime/20 p-3 rounded-lg text-brand-lime">
                    <Mail size={24} />
                  </div>
                  <div>
                    <h4 className="text-white font-semibold">Email</h4>
                    <p className="text-gray-400">info@en4tainment.com</p>
                  </div>
                </div>
              </div>
            </div>
          </div>

          {/* Form Side */}
          <div className="bg-brand-surface p-8 rounded-2xl border border-white/5 shadow-2xl">
            <h3 className="text-2xl font-bold text-white mb-6">Send us a Message</h3>

            {submitted ? (
              <div className="bg-brand-lime/10 border border-brand-lime/20 text-brand-lime p-8 rounded-2xl text-center flex flex-col items-center justify-center space-y-4 animate-in fade-in" id="contact-success">
                <CheckCircle size={48} />
                <h4 className="text-xl font-bold">Message Sent Successfully!</h4>
                <p className="text-gray-300 text-sm">Thank you for reaching out. Our team will get back to you shortly.</p>
              </div>
            ) : (
              <form className="space-y-6" onSubmit={handleSubmit} noValidate={false}>

                {error && (
                  <div className="bg-red-500/10 border border-red-500/30 text-red-300 rounded-lg p-4 flex items-start gap-3" role="alert" id="contact-error">
                    <AlertCircle size={20} className="shrink-0 mt-0.5" />
                    <p className="text-sm">{error}</p>
                  </div>
                )}

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-6">
                  <div>
                    <label htmlFor="contact-first" className="block text-sm font-medium text-gray-400 mb-2">First Name</label>
                    <input id="contact-first" name="first_name" required type="text" maxLength={100}
                      autoComplete="given-name" value={form.first_name} onChange={set('first_name')}
                      disabled={sending} className={inputClass} />
                  </div>
                  <div>
                    <label htmlFor="contact-last" className="block text-sm font-medium text-gray-400 mb-2">Last Name</label>
                    <input id="contact-last" name="last_name" required type="text" maxLength={100}
                      autoComplete="family-name" value={form.last_name} onChange={set('last_name')}
                      disabled={sending} className={inputClass} />
                  </div>
                </div>

                <div>
                  <label htmlFor="contact-email" className="block text-sm font-medium text-gray-400 mb-2">Email</label>
                  <input id="contact-email" name="email" required type="email" maxLength={320}
                    autoComplete="email" value={form.email} onChange={set('email')}
                    disabled={sending} className={inputClass} />
                </div>

                <div>
                  <label htmlFor="contact-message" className="block text-sm font-medium text-gray-400 mb-2">Message</label>
                  <textarea id="contact-message" name="message" required rows={5} maxLength={MAX_MESSAGE}
                    value={form.message} onChange={set('message')}
                    disabled={sending}
                    className={`${inputClass} resize-none`} />
                  <p className="text-xs text-gray-500 mt-2">{form.message.length} / {MAX_MESSAGE}</p>
                </div>

                {/* Honeypot. Hidden from sighted users and from screen readers, so
                    only a form-filling bot reaches it. The function discards any
                    submission where this is non-empty, and reports success anyway. */}
                <div aria-hidden="true" style={{ position: 'absolute', left: '-9999px', width: 1, height: 1, overflow: 'hidden' }}>
                  <label htmlFor="contact-website">Website</label>
                  <input id="contact-website" name="website" type="text" tabIndex={-1}
                    autoComplete="off" value={form.website} onChange={set('website')} />
                </div>

                <Button type="submit" className="w-full" disabled={sending}>
                  {sending ? 'Sending…' : 'Send Message'}
                </Button>
              </form>
            )}
          </div>

        </div>
      </div>
    </div>
  );
};