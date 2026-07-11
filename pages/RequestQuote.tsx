import React, { useState, useEffect } from 'react';
import { useSearchParams, Link } from 'react-router-dom';
import { ARTISTS } from '../constants';
import { Button } from '../components/Button';
import { supabase } from '../services/supabase';
import { CheckCircle, Music, MapPin, Calendar, Clock, AlertCircle } from 'lucide-react';
import { Artist } from '../types';

interface QuoteFormData {
  name: string;
  email: string;
  phone: string;
  date: string;
  time: string;
  location: string;
  artistId: string;
  notes: string;
}

export const RequestQuote: React.FC = () => {
  const [searchParams] = useSearchParams();
  const preSelectedArtistId: string | null = searchParams.get('artistId');

  const [formData, setFormData] = useState<QuoteFormData>({
    name: '',
    email: '',
    phone: '',
    date: '',
    time: '',
    location: '',
    artistId: preSelectedArtistId || '',
    notes: ''
  });

  const [isSubmitted, setIsSubmitted] = useState<boolean>(false);
  const [loading, setLoading] = useState<boolean>(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  useEffect(() => {
    if (preSelectedArtistId) {
      setFormData(prev => ({ ...prev, artistId: preSelectedArtistId }));
    }
  }, [preSelectedArtistId]);

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement>): void => {
    const { name, value } = e.target;
    setFormData(prev => ({ ...prev, [name]: value }));
  };

  const handleSubmit = async (e: React.FormEvent): Promise<void> => {
    e.preventDefault();
    setLoading(true);
    setErrorMessage(null);
    
    try {
      const { data: { user } } = await supabase.auth.getUser();
      
      const { error } = await supabase.from('quote_requests').insert({
        client_user_id: user?.id || null,
        preferred_talent_id: formData.artistId || null,
        event_type: 'general',   // verify against the actual enum values first — see below
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
            Your quotation request has been sent to our talent team. We'll get back to you within 24 hours with a custom proposal.
          </p>
          <Link to="/">
            <Button variant="primary" size="lg" className="w-full">Back to Home</Button>
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
              Tell us your vision, and we'll match it with the perfect talent from our curated roster.
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
            <p className="text-gray-400">Fill out the details below to receive a personalized booking summary.</p>
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
              <label className="text-xs font-black text-brand-lime uppercase tracking-widest">Select Talent</label>
              <select
                name="artistId"
                value={formData.artistId}
                onChange={handleChange}
                className="w-full bg-brand-dark/50 border border-white/10 rounded-xl px-4 py-3 text-white focus:ring-2 focus:ring-brand-purple focus:border-transparent outline-none transition-all appearance-none cursor-pointer"
              >
                <option value="">I'm not sure yet...</option>
                {ARTISTS.map((artist: Artist) => (
                  <option key={artist.id} value={artist.id}>{artist.name} — {artist.category}</option>
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
                disabled={loading}
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
