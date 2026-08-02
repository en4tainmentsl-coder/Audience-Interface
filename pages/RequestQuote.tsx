import React, { useState, useEffect } from 'react';
import { useSearchParams, Link } from 'react-router';
import { Button } from '../components/Button';
import { supabase } from '../services/supabase';
import { CheckCircle, Music, MapPin, Calendar, Clock, AlertCircle } from 'lucide-react';

interface TalentOption {
  id: string;
  stage_name: string;
}

// Mirrors the live `events_type` Postgres enum. Keep in sync manually if
// the enum is ever altered — there is no runtime introspection of it here.
const EVENT_TYPES: { value: string; label: string }[] = [
  { value: 'wedding', label: 'Wedding' },
  { value: 'corporate', label: 'Corporate' },
  { value: 'birthday', label: 'Birthday' },
  { value: 'concert', label: 'Concert' },
  { value: 'private', label: 'Private Event' },
  { value: 'dinner_service', label: 'Dinner Service' },
  { value: 'lunch_service', label: 'Lunch Service' },
  { value: 'other', label: 'Other' },
];

interface QuoteFormData {
  name: string;
  email: string;
  phone: string;
  date: string;
  time: string;
  location: string;
  talentId: string;
  eventType: string;
  notes: string;
}

export const RequestQuote: React.FC = () => {
  const [searchParams] = useSearchParams();
  const preSelectedTalentId: string | null = searchParams.get('artistId');

  const [formData, setFormData] = useState<QuoteFormData>({
    name: '',
    email: '',
    phone: '',
    date: '',
    time: '',
    location: '',
    talentId: preSelectedTalentId || '',
    eventType: '',
    notes: ''
  });

  const [talentOptions, setTalentOptions] = useState<TalentOption[]>([]);
  const [talentLoading, setTalentLoading] = useState<boolean>(true);

  const [authChecked, setAuthChecked] = useState<boolean>(false);
  const [isLoggedIn, setIsLoggedIn] = useState<boolean>(false);

  const [isSubmitted, setIsSubmitted] = useState<boolean>(false);
  const [loading, setLoading] = useState<boolean>(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  // Auth gate — login is required to submit a quote request.
  useEffect(() => {
    supabase.auth.getUser().then(({ data: { user } }) => {
      setIsLoggedIn(!!user);
      setAuthChecked(true);
    });
  }, []);

  // Live talent list — replaces the static ARTISTS constants array.
  // Only is_public = true rows are visible under RLS to a non-owner reader.
  useEffect(() => {
    async function loadTalent() {
      setTalentLoading(true);
      const { data, error } = await supabase
        .from('profiles_talent')
        .select('id, stage_name')
        .eq('is_public', true)
        .order('stage_name');

      if (!error && data) {
        setTalentOptions(data);
        // Default-select the first talent if none was pre-selected via query param
        setFormData(prev => ({
          ...prev,
          talentId: prev.talentId || data[0]?.id || ''
        }));
      }
      setTalentLoading(false);
    }
    loadTalent();
  }, []);

  useEffect(() => {
    if (preSelectedTalentId) {
      setFormData(prev => ({ ...prev, talentId: preSelectedTalentId }));
    }
  }, [preSelectedTalentId]);

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement>): void => {
    const { name, value } = e.target;
    setFormData(prev => ({ ...prev, [name]: value }));
  };

  const handleSubmit = async (e: React.FormEvent): Promise<void> => {
    e.preventDefault();

    if (!formData.talentId) {
      setErrorMessage("Please select a talent before submitting.");
      return;
    }

    if (!formData.eventType) {
      setErrorMessage("Please select an event type before submitting.");
      return;
    }

    setLoading(true);
    setErrorMessage(null);

    try {
      const { data: { user } } = await supabase.auth.getUser();

      if (!user) {
        setLoading(false);
        setErrorMessage("Your session has expired. Please sign in again to submit a quote request.");
        setIsLoggedIn(false);
        return;
      }

      const { error } = await supabase.from('quote_requests').insert({
        client_user_id: user.id,
        talent_id: formData.talentId,
        event_type: formData.eventType,
        event_date: formData.date,
        start_time: formData.time,
        duration_hours: 2,
        location: formData.location,
        special_requirements: formData.notes,
        status: 'open'
      });

      if (error) throw error;

      setLoading(false);
      setIsSubmitted(true);
    } catch (error: any) {
      console.error('Quote Request Error:', error);
      setLoading(false);
      setErrorMessage("Something went wrong. Please try again or check your parameters.");
    }
  };

  if (isSubmitted) {
    return (
      <div className="pt-32 pb-20 min-h-screen bg-brand-dark flex items-center justify-center px-4" id="quote-success-screen">
        <div className="max-w-md w-full text-center bg-brand-surface p-12 rounded-3xl border border-brand-lime/30 shadow-2xl animate-in zoom-in-95 duration-500">
          <div className="w-24 h-24 bg-brand-lime/20 rounded-full flex items-center justify-center mx-auto mb-8 text-brand-lime">
            <CheckCircle size={48} />
          </div>
          <h1 className="text-4xl font-black text-white mb-4 uppercase italic">Success!</h1>
          <p className="text-gray-400 text-lg mb-10">
            Your quotation request has been sent directly to the talent you selected. You'll be notified as soon as they respond.
          </p>
          <Link to="/">
            <Button variant="primary" size="lg" className="w-full">Back to Home</Button>
          </Link>
        </div>
      </div>
    );
  }

  // Auth gate: don't render the form (or let anyone fill it out) until we
  // know there's a valid session. Avoids a confusing failure at submit time.
  if (authChecked && !isLoggedIn) {
    return (
      <div className="pt-32 pb-20 min-h-screen bg-brand-dark flex items-center justify-center px-4" id="request-quote-auth-gate">
        <div className="max-w-md w-full text-center bg-brand-surface p-12 rounded-3xl border border-white/10 shadow-2xl">
          <h1 className="text-3xl font-black text-white mb-4 uppercase italic">Sign In Required</h1>
          <p className="text-gray-400 text-lg mb-10">
            Please sign in to request a quote from our talent.
          </p>
          <Link to="/login">
            <Button variant="primary" size="lg" className="w-full">Sign In</Button>
          </Link>
        </div>
      </div>
    );
  }

  return (
    <div className="pt-32 pb-20 min-h-screen bg-brand-dark flex items-center justify-center px-4" id="request-quote-page">
      <div className="max-w-5xl w-full bg-brand-surface border border-white/10 rounded-3xl shadow-2xl overflow-hidden flex flex-col lg:flex-row">
        
        <div className="lg:w-2/5 bg-gradient-to-br from-brand-purple via-brand-pink to-brand-indigo p-12 text-white flex flex-col justify-between relative overflow-hidden text-left animate-fade-in">
          <div className="relative z-10">
            <Music className="w-16 h-16 mb-10 text-brand-lime animate-pulse" />
            <h2 className="text-5xl font-black mb-6 uppercase tracking-tighter italic">Book the Future.</h2>
            <p className="text-white/80 text-lg leading-relaxed mb-8">
              Tell us your vision, and send your request directly to the talent you want.
            </p>
            <ul className="space-y-6">
              <li className="flex items-center gap-4 text-white/90 font-bold uppercase tracking-widest text-sm">
                <div className="bg-white/20 p-2 rounded-lg"><MapPin size={18} /></div>
                Global Venues
              </li>
              <li className="flex items-center gap-4 text-white/90 font-bold uppercase tracking-widest text-sm">
                <div className="bg-white/20 p-2 rounded-lg"><Calendar size={18} /></div>
                Custom Availability
              </li>
              <li className="flex items-center gap-4 text-white/90 font-bold uppercase tracking-widest text-sm">
                <div className="bg-white/20 p-2 rounded-lg"><Clock size={18} /></div>
                Tailored Sessions
              </li>
            </ul>
          </div>
          
          <div className="absolute -bottom-20 -right-20 opacity-20 transform rotate-12">
            <svg width="400" height="400" viewBox="0 0 100 100">
               <path d="M10,90 L50,10 L90,90 Z" fill="none" stroke="currentColor" strokeWidth="2" />
               <circle cx="50" cy="50" r="30" fill="none" stroke="currentColor" strokeWidth="2" />
            </svg>
          </div>
        </div>

        <div className="lg:w-3/5 p-10 md:p-14 bg-brand-surface text-left">
          <div className="mb-10">
            <h1 className="text-3xl font-black text-white mb-2 uppercase italic">Get a Quote</h1>
            <p className="text-gray-400">Fill out the details below to send a request directly to your chosen talent.</p>
          </div>

          {errorMessage && (
            <div className="mb-6 p-4 bg-red-500/10 border border-red-500/20 rounded-xl flex items-center gap-3 text-red-500 animate-in fade-in" id="quote-error-banner">
              <AlertCircle size={20} />
              <p className="text-sm">{errorMessage}</p>
            </div>
          )}
          
          <form onSubmit={handleSubmit} className="space-y-6">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div className="space-y-2">
                <label className="text-xs font-black text-brand-lime uppercase tracking-widest">Full Name</label>
                <input
                  type="text"
                  name="name"
                  required
                  value={formData.name}
                  onChange={handleChange}
                  placeholder="Saman Perera"
                  className="w-full bg-brand-dark/50 border border-white/10 rounded-xl px-4 py-3 text-white focus:ring-2 focus:ring-brand-purple focus:border-transparent outline-none transition-all placeholder:text-gray-600"
                />
              </div>
              <div className="space-y-2">
                <label className="text-xs font-black text-brand-lime uppercase tracking-widest">Email Address</label>
                <input
                  type="email"
                  name="email"
                  required
                  value={formData.email}
                  onChange={handleChange}
                  placeholder="saman@en4tainment.com"
                  className="w-full bg-brand-dark/50 border border-white/10 rounded-xl px-4 py-3 text-white focus:ring-2 focus:ring-brand-purple focus:border-transparent outline-none transition-all placeholder:text-gray-600"
                />
              </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div className="space-y-2">
                <label className="text-xs font-black text-brand-lime uppercase tracking-widest">Phone Number</label>
                <input
                  type="tel"
                  name="phone"
                  required
                  value={formData.phone}
                  onChange={handleChange}
                  placeholder="+94 (77) 718-6162"
                  className="w-full bg-brand-dark/50 border border-white/10 rounded-xl px-4 py-3 text-white focus:ring-2 focus:ring-brand-purple focus:border-transparent outline-none transition-all placeholder:text-gray-600"
                />
              </div>
              <div className="space-y-2">
                <label className="text-xs font-black text-brand-lime uppercase tracking-widest">Venue / Location</label>
                <input
                  type="text"
                  name="location"
                  required
                  value={formData.location}
                  onChange={handleChange}
                  placeholder="Downtown Arena"
                  className="w-full bg-brand-dark/50 border border-white/10 rounded-xl px-4 py-3 text-white focus:ring-2 focus:ring-brand-purple focus:border-transparent outline-none transition-all placeholder:text-gray-600"
                />
              </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div className="space-y-2">
                <label className="text-xs font-black text-brand-lime uppercase tracking-widest">Event Date</label>
                <input
                  type="date"
                  name="date"
                  required
                  value={formData.date}
                  onChange={handleChange}
                  className="w-full bg-brand-dark/50 border border-white/10 rounded-xl px-4 py-3 text-white focus:ring-2 focus:ring-brand-purple focus:border-transparent outline-none transition-all"
                />
              </div>
              <div className="space-y-2">
                <label className="text-xs font-black text-brand-lime uppercase tracking-widest">Start Time</label>
                <input
                  type="time"
                  name="time"
                  required
                  value={formData.time}
                  onChange={handleChange}
                  className="w-full bg-brand-dark/50 border border-white/10 rounded-xl px-4 py-3 text-white focus:ring-2 focus:ring-brand-purple focus:border-transparent outline-none transition-all"
                />
              </div>
            </div>

            <div className="space-y-2">
              <label className="text-xs font-black text-brand-lime uppercase tracking-widest">Event Type</label>
              <select
                name="eventType"
                required
                value={formData.eventType}
                onChange={handleChange}
                className="w-full bg-brand-dark/50 border border-white/10 rounded-xl px-4 py-3 text-white focus:ring-2 focus:ring-brand-purple focus:border-transparent outline-none transition-all appearance-none cursor-pointer"
              >
                <option value="">Select an event type...</option>
                {EVENT_TYPES.map((et) => (
                  <option key={et.value} value={et.value}>{et.label}</option>
                ))}
              </select>
            </div>

            <div className="space-y-2">
              <label className="text-xs font-black text-brand-lime uppercase tracking-widest">Select Talent</label>
              <select
                name="talentId"
                required
                value={formData.talentId}
                onChange={handleChange}
                disabled={talentLoading || talentOptions.length === 0}
                className="w-full bg-brand-dark/50 border border-white/10 rounded-xl px-4 py-3 text-white focus:ring-2 focus:ring-brand-purple focus:border-transparent outline-none transition-all appearance-none cursor-pointer disabled:opacity-50"
              >
                {talentLoading && <option value="">Loading talent...</option>}
                {!talentLoading && talentOptions.length === 0 && (
                  <option value="">No talent currently available</option>
                )}
                {talentOptions.map((talent) => (
                  <option key={talent.id} value={talent.id}>{talent.stage_name}</option>
                ))}
              </select>
            </div>

            <div className="space-y-2">
              <label className="text-xs font-black text-brand-lime uppercase tracking-widest">Extra Vibes / Notes</label>
              <textarea
                name="notes"
                rows={3}
                value={formData.notes}
                onChange={handleChange}
                placeholder="Tell us about the event atmosphere..."
                className="w-full bg-brand-dark/50 border border-white/10 rounded-xl px-4 py-3 text-white focus:ring-2 focus:ring-brand-purple focus:border-transparent outline-none resize-none transition-all placeholder:text-gray-600"
              ></textarea>
            </div>

            <div className="pt-6">
              <Button 
                type="submit" 
                variant="primary" 
                className="w-full py-5 text-lg"
                disabled={loading || talentLoading || !formData.talentId || !formData.eventType}
              >
                {loading ? 'Processing...' : 'Submit Quote Request'}
              </Button>
            </div>
          </form>
        </div>
      </div>
    </div>
  );
};
