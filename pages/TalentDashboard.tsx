import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router';
import { 
  Calendar, Clock, Image as ImageIcon, 
  Star, Settings, LogOut
} from 'lucide-react';
import { Button } from '../components/Button';
import { supabase } from '../services/supabase';

interface TalentProfile {
  id: string;
  stage_name: string;
  rating?: number;
  profile_photo_url?: string;
  bio?: string;
}

interface TalentDashboardBooking {
  id: string;
  event_date: string;
  start_time?: string;
  booking_status: string;
  profiles_venues?: {
    name_of_venue: string;
    name_of_location: string;
  };
}

interface TalentDashboardQuote {
  id: string;
  event_type: string;
  starts_at: string;
  ends_at: string;
  location: string | null;
  status: string | null;
}

export const TalentDashboard: React.FC = () => {
  const [talent, setTalent] = useState<TalentProfile | null>(null);
  const [bookings, setBookings] = useState<TalentDashboardBooking[]>([]);
  const [quotes, setQuotes] = useState<TalentDashboardQuote[]>([]);
  const [loading, setLoading] = useState<boolean>(true);
  const navigate = useNavigate();

  const fetchData = async (talentId: string): Promise<void> => {
    setLoading(true);
    try {
      // Fetch Bookings
      const { data: bookingsData } = await supabase
        .from('bookings')
        .select(`
          id,
          event_date,
          start_time,
          booking_status,
          profiles_venues (name_of_venue, name_of_location)
        `)
        .eq('talent_id', talentId)
        .order('event_date', { ascending: false });
      
      setBookings(((bookingsData as unknown) as TalentDashboardBooking[]) || []);

      // Fetch Quotes
      const { data: quotesData } = await supabase
        .from('quote_requests')
        .select(`
          id,
          event_type,
          starts_at,
          ends_at,
          location,
          status
        `)
        .eq('talent_id', talentId)
        .order('created_at', { ascending: false });
      
      setQuotes(((quotesData as unknown) as TalentDashboardQuote[]) || []);
    } catch (error) {
      console.error('Error fetching talent data:', error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    const checkAuth = async (): Promise<void> => {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) {
        navigate('/venue-portal'); // Using venue-portal as a general auth entry for now
        return;
      }

      // Fetch Talent Profile
      const { data: profile, error } = await supabase
        .from('profiles_talent')
        .select('*')
        .eq('user_id', user.id)
        .single();

      if (error || !profile) {
        console.error('Talent profile not found:', error);
        navigate('/');
        return;
      }

      setTalent((profile as unknown) as TalentProfile);
      fetchData(profile.id);
    };
    checkAuth();
  }, [navigate]);

  const handleLogout = async (): Promise<void> => {
    await supabase.auth.signOut();
    navigate('/');
  };

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-brand-dark" id="talent-dashboard-loading">
        <div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-brand-purple"></div>
      </div>
    );
  }

  return (
    <div className="min-h-screen pt-24 pb-12 px-4 bg-brand-dark" id="talent-dashboard">
      <div className="max-w-7xl mx-auto">
        <div className="flex flex-col md:flex-row justify-between items-start md:items-center mb-8 gap-4 text-left">
          <div>
            <h1 className="text-3xl font-bold text-white">Talent Dashboard</h1>
            <p className="text-gray-400">Welcome back, {talent?.stage_name}</p>
          </div>
          <div className="flex gap-3">
            <Button variant="outline" onClick={handleLogout} className="flex items-center gap-2" id="talent-logout-btn">
              <LogOut className="w-4 h-4" /> Logout
            </Button>
            <Button className="flex items-center gap-2" id="talent-edit-profile-btn">
              <Settings className="w-4 h-4" /> Edit Profile
            </Button>
          </div>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
          {/* Left Column: Stats & Profile */}
          <div className="space-y-6 text-left">
            <section className="bg-brand-surface rounded-2xl border border-white/10 p-6">
              <div className="flex items-center gap-4 mb-6">
                <img 
                  src={talent?.profile_photo_url || 'https://picsum.photos/seed/talent/200/200'} 
                  alt={talent?.stage_name}
                  className="w-20 h-20 rounded-xl object-cover border border-white/10"
                />
                <div>
                  <h2 className="text-xl font-bold">{talent?.stage_name}</h2>
                  <div className="flex items-center gap-1 text-brand-lime">
                    <Star className="w-4 h-4 fill-current" />
                    <span className="text-sm font-bold">{talent?.rating || 'N/A'}</span>
                  </div>
                </div>
              </div>
              
              <div className="space-y-4">
                <div className="bg-brand-dark/50 p-4 rounded-xl border border-white/5">
                  <div className="flex justify-between text-sm mb-2">
                    <span className="text-gray-400">Profile Completeness</span>
                    <span className="text-brand-purple font-bold">85%</span>
                  </div>
                  <div className="w-full bg-white/5 h-2 rounded-full overflow-hidden">
                    <div className="bg-brand-purple h-full w-[85%]" />
                  </div>
                </div>
                
                <div className="grid grid-cols-2 gap-4">
                  <div className="bg-brand-dark/50 p-4 rounded-xl border border-white/5">
                    <p className="text-xs text-gray-400 mb-1">Total Earnings</p>
                    <p className="text-xl font-bold text-white">$4,250</p>
                  </div>
                  <div className="bg-brand-dark/50 p-4 rounded-xl border border-white/5">
                    <p className="text-xs text-gray-400 mb-1">Total Bookings</p>
                    <p className="text-xl font-bold text-white">{bookings.length}</p>
                  </div>
                </div>
              </div>
            </section>

            <section className="bg-brand-surface rounded-2xl border border-white/10 p-6">
              <h3 className="text-lg font-bold mb-4 flex items-center gap-2">
                <ImageIcon className="w-5 h-5 text-brand-pink" /> Media Gallery
              </h3>
              <div className="grid grid-cols-3 gap-2">
                {[1, 2, 3, 4, 5, 6].map((i: number) => (
                  <div key={i} className="aspect-square bg-brand-dark rounded-lg border border-white/5 overflow-hidden group cursor-pointer">
                    <img 
                      src={`https://picsum.photos/seed/media${i}/200/200`} 
                      alt="Media" 
                      className="w-full h-full object-cover group-hover:scale-110 transition-transform"
                    />
                  </div>
                ))}
              </div>
              <Button variant="ghost" className="w-full mt-4 text-sm">Manage Media</Button>
            </section>
          </div>

          {/* Center Column: Bookings & Quotes */}
          <div className="lg:col-span-2 space-y-6 text-left">
            <section className="bg-brand-surface rounded-2xl border border-white/10 p-6">
              <div className="flex items-center justify-between mb-6">
                <h2 className="text-xl font-bold flex items-center gap-2">
                  <Calendar className="w-5 h-5 text-brand-purple" /> Upcoming Bookings
                </h2>
              </div>

              {bookings.length === 0 ? (
                <div className="text-center py-12 border border-dashed border-white/10 rounded-xl" id="no-bookings-found-talent">
                  <p className="text-gray-500">No upcoming bookings found.</p>
                </div>
              ) : (
                <div className="space-y-4" id="talent-bookings-list">
                  {bookings.map((booking: TalentDashboardBooking) => (
                    <div
                      key={booking.id}
                      className="bg-brand-dark/50 border border-white/5 rounded-xl p-4 flex flex-col md:flex-row justify-between gap-4"
                    >
                      <div className="space-y-1">
                        <h3 className="font-bold text-lg">{booking.profiles_venues?.name_of_venue || 'Private Event'}</h3>
                        <div className="flex flex-wrap gap-4 text-sm text-gray-400">
                          <span className="flex items-center gap-1">
                            <Calendar className="w-4 h-4" /> {new Date(booking.event_date).toLocaleDateString()}
                          </span>
                          <span className="flex items-center gap-1">
                            <Clock className="w-4 h-4" /> {booking.start_time || 'TBA'}
                          </span>
                        </div>
                      </div>
                      <div className="flex items-center gap-3">
                        <span className={`px-3 py-1 rounded-full text-xs font-bold uppercase tracking-wider ${
                          booking.booking_status === 'confirmed' ? 'bg-brand-lime/20 text-brand-lime' : 'bg-yellow-500/20 text-yellow-500'
                        }`}>
                          {booking.booking_status}
                        </span>
                        <Button variant="outline" size="sm">Details</Button>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </section>

            <section className="bg-brand-surface rounded-2xl border border-white/10 p-6">
              <div className="flex items-center justify-between mb-6">
                <h2 className="text-xl font-bold flex items-center gap-2">
                  <Clock className="w-5 h-5 text-brand-pink" /> Pending Quote Requests
                </h2>
              </div>

              {quotes.length === 0 ? (
                <div className="text-center py-12 border border-dashed border-white/10 rounded-xl" id="no-quotes-found-talent">
                  <p className="text-gray-500">No pending quote requests.</p>
                </div>
              ) : (
                <div className="space-y-4 animate-fade-in" id="talent-quotes-list">
                  {quotes.map((quote: TalentDashboardQuote) => (
                    <div
                      key={quote.id}
                      className="bg-brand-dark/50 border border-white/5 rounded-xl p-4 flex flex-col md:flex-row justify-between gap-4"
                    >
                      <div className="space-y-1">
                                                <h3 className="font-bold text-lg">{quote.location || 'Location not specified'}</h3>
                        <p className="text-sm text-gray-400">
                          {quote.event_type} — {new Date(quote.starts_at).toLocaleDateString('en-GB', { timeZone: 'Asia/Colombo' })}
                        </p>
                      </div>
                      <div className="flex items-center gap-3">
                        <Button variant="outline" size="sm">View Request</Button>
                        <Button size="sm">Send Quote</Button>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </section>
          </div>
        </div>
      </div>
    </div>
  );
};
