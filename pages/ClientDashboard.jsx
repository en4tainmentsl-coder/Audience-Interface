
import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { 
  Calendar, Clock, Heart, CreditCard, 
  Star, Settings, LogOut, ChevronRight,
  Shield, Music, MapPin
} from 'lucide-react';
import { Button } from '../components/Button';
import { supabase } from '../services/supabase';

export const ClientDashboard = () => {
  const [client, setClient] = useState(null);
  const [bookings, setBookings] = useState([]);
  const [quotes, setQuotes] = useState([]);
  const [favorites, setFavorites] = useState([]);
  const [loading, setLoading] = useState(true);
  const navigate = useNavigate();

  useEffect(() => {
    const checkAuth = async () => {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) {
        navigate('/venue-portal'); // Using venue-portal as a general auth entry for now
        return;
      }

      // Fetch Client Profile
      const { data: profile, error } = await supabase
        .from('profiles_clients')
        .select('*')
        .eq('user_id', user.id)
        .single();

      if (error || !profile) {
        console.error('Client profile not found:', error);
        navigate('/');
        return;
      }

      setClient(profile);
      fetchData(user.id);
    };
    checkAuth();
  }, [navigate]);

  const fetchData = async (userId) => {
    setLoading(true);
    try {
      // Fetch Bookings
      const { data: bookingsData } = await supabase
        .from('bookings')
        .select(`
          *,
          profiles_talent (stage_name, profile_photo_url),
          profiles_venues (name_of_venue, name_of_location)
        `)
        .eq('client_user_id', userId)
        .order('event_date', { ascending: false });
      
      setBookings(bookingsData || []);

      // Fetch Quotes
      const { data: quotesData } = await supabase
        .from('quote_requests')
        .select(`
          *,
          profiles_talent (stage_name, profile_photo_url)
        `)
        .eq('client_user_id', userId)
        .order('created_at', { ascending: false });
      
      setQuotes(quotesData || []);

      // Fetch Favorites
      const { data: favoritesData } = await supabase
        .from('reviews_heart')
        .select(`
          *,
          profiles_talent (id, stage_name, profile_photo_url, rating)
        `)
        .eq('ReviewerUserUUID', userId);
      
      setFavorites(favoritesData || []);
    } catch (error) {
      console.error('Error fetching client data:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleLogout = async () => {
    await supabase.auth.signOut();
    navigate('/');
  };

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-brand-dark">
        <div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-brand-purple"></div>
      </div>
    );
  }

  return (
    <div className="min-h-screen pt-24 pb-12 px-4 bg-brand-dark">
      <div className="max-w-7xl mx-auto">
        <div className="flex flex-col md:flex-row justify-between items-start md:items-center mb-8 gap-4">
          <div>
            <h1 className="text-3xl font-bold text-white">Client Dashboard</h1>
            <p className="text-gray-400">Welcome back, {client?.full_name}</p>
          </div>
          <div className="flex gap-3">
            <Button variant="outline" onClick={handleLogout} className="flex items-center gap-2">
              <LogOut className="w-4 h-4" /> Logout
            </Button>
            <Button className="flex items-center gap-2">
              <Settings className="w-4 h-4" /> Account Settings
            </Button>
          </div>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
          {/* Left Column: Favorites & Account */}
          <div className="space-y-6">
            <section className="bg-brand-surface rounded-2xl border border-white/10 p-6">
              <h3 className="text-lg font-bold mb-4 flex items-center gap-2">
                <Heart className="w-5 h-5 text-brand-pink" /> Saved Favorites
              </h3>
              {favorites.length === 0 ? (
                <div className="text-center py-8 border border-dashed border-white/10 rounded-xl">
                  <p className="text-gray-500 text-sm">No favorites saved yet.</p>
                  <Button variant="ghost" size="sm" className="mt-2" onClick={() => navigate('/artists')}>
                    Explore Artists
                  </Button>
                </div>
              ) : (
                <div className="space-y-4">
                  {favorites.map((fav) => (
                    <div key={fav.id} className="flex items-center gap-4 group cursor-pointer" onClick={() => navigate(`/artists/${fav.profiles_talent?.id}`)}>
                      <img 
                        src={fav.profiles_talent?.profile_photo_url || 'https://picsum.photos/seed/artist/100/100'} 
                        alt={fav.profiles_talent?.stage_name}
                        className="w-12 h-12 rounded-lg object-cover border border-white/10"
                      />
                      <div className="flex-grow">
                        <h4 className="font-semibold group-hover:text-brand-purple transition-colors">{fav.profiles_talent?.stage_name}</h4>
                        <div className="flex items-center gap-1 text-brand-lime text-xs">
                          <Star className="w-3 h-3 fill-current" />
                          <span>{fav.profiles_talent?.rating || 'N/A'}</span>
                        </div>
                      </div>
                      <ChevronRight className="w-4 h-4 text-gray-600 group-hover:text-white transition-colors" />
                    </div>
                  ))}
                </div>
              )}
            </section>

            <section className="bg-brand-surface rounded-2xl border border-white/10 p-6">
              <h3 className="text-lg font-bold mb-4 flex items-center gap-2">
                <CreditCard className="w-5 h-5 text-brand-purple" /> Payment Methods
              </h3>
              <div className="space-y-3">
                <div className="bg-brand-dark/50 p-4 rounded-xl border border-white/5 flex items-center justify-between">
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-6 bg-brand-purple/20 rounded flex items-center justify-center text-brand-purple font-bold text-[10px]">VISA</div>
                    <span className="text-sm text-gray-300">•••• 4242</span>
                  </div>
                  <span className="text-[10px] text-gray-500 font-bold uppercase">Default</span>
                </div>
                <Button variant="outline" className="w-full text-sm">Add Payment Method</Button>
              </div>
            </section>

            <section className="bg-gradient-to-br from-brand-purple/20 to-brand-pink/20 rounded-2xl border border-white/10 p-6">
              <div className="flex items-center gap-2 mb-2">
                <Shield className="w-5 h-5 text-brand-purple" />
                <h3 className="font-bold">Authorization Codes</h3>
              </div>
              <p className="text-xs text-gray-400 mb-4">Verification codes for upcoming event check-ins.</p>
              <div className="bg-brand-dark/50 p-3 rounded-lg border border-white/5 text-center font-mono text-lg tracking-widest text-brand-lime">
                EN4-8829-X
              </div>
            </section>
          </div>

          {/* Center Column: Bookings & Quotes */}
          <div className="lg:col-span-2 space-y-6">
            <section className="bg-brand-surface rounded-2xl border border-white/10 p-6">
              <div className="flex items-center justify-between mb-6">
                <h2 className="text-xl font-bold flex items-center gap-2">
                  <Calendar className="w-5 h-5 text-brand-purple" /> My Bookings
                </h2>
              </div>

              {bookings.length === 0 ? (
                <div className="text-center py-12 border border-dashed border-white/10 rounded-xl">
                  <p className="text-gray-500">No bookings found.</p>
                  <Button className="mt-4" onClick={() => navigate('/artists')}>Book an Artist</Button>
                </div>
              ) : (
                <div className="space-y-4">
                  {bookings.map((booking) => (
                    <div
                      key={booking.id}
                      className="bg-brand-dark/50 border border-white/5 rounded-xl p-4 flex flex-col md:flex-row justify-between gap-4"
                    >
                      <div className="flex items-center gap-4">
                        <img 
                          src={booking.profiles_talent?.profile_photo_url || 'https://picsum.photos/seed/artist/100/100'} 
                          alt={booking.profiles_talent?.stage_name}
                          className="w-12 h-12 rounded-lg object-cover"
                        />
                        <div className="space-y-1">
                          <h3 className="font-bold text-lg">{booking.profiles_talent?.stage_name || 'TBA'}</h3>
                          <div className="flex flex-wrap gap-4 text-sm text-gray-400">
                            <span className="flex items-center gap-1">
                              <Calendar className="w-4 h-4" /> {new Date(booking.event_date).toLocaleDateString()}
                            </span>
                            <span className="flex items-center gap-1">
                              <MapPin className="w-4 h-4" /> {booking.profiles_venues?.name_of_venue || booking.location}
                            </span>
                          </div>
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
                  <Clock className="w-5 h-5 text-brand-pink" /> Open Quote Requests
                </h2>
              </div>

              {quotes.length === 0 ? (
                <div className="text-center py-12 border border-dashed border-white/10 rounded-xl">
                  <p className="text-gray-500">No open quote requests.</p>
                </div>
              ) : (
                <div className="space-y-4">
                  {quotes.map((quote) => (
                    <div
                      key={quote.id}
                      className="bg-brand-dark/50 border border-white/5 rounded-xl p-4 flex flex-col md:flex-row justify-between gap-4"
                    >
                      <div className="flex items-center gap-4">
                        <div className="w-12 h-12 bg-white/5 rounded-lg flex items-center justify-center text-brand-purple">
                          <Music className="w-6 h-6" />
                        </div>
                        <div className="space-y-1">
                          <h3 className="font-bold text-lg">{quote.profiles_talent?.stage_name || 'General Request'}</h3>
                          <p className="text-sm text-gray-400">{quote.event_type} — {new Date(quote.event_date).toLocaleDateString()}</p>
                        </div>
                      </div>
                      <div className="flex items-center gap-3">
                        <span className={`px-3 py-1 rounded-full text-[10px] font-black uppercase tracking-wider ${
                          quote.status === 'quoted' ? 'bg-brand-purple/20 text-brand-purple' : 'bg-white/10 text-gray-400'
                        }`}>
                          {quote.status}
                        </span>
                        <Button variant="outline" size="sm">View</Button>
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
