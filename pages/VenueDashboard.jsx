import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { motion } from 'framer-motion';
import { Plus, Calendar, Clock, Star, Heart, LogOut, Clock as ClockIcon, AlertCircle } from 'lucide-react';
import { Button } from '../components/Button';
import { supabase } from '../services/supabase';
import { ARTISTS } from '../constants';

export const VenueDashboard = () => {
  const [venue, setVenue] = useState(null);
  const [bookings, setBookings] = useState([]);
  const [artists, setArtists] = useState([]);
  const [showBookingForm, setShowBookingForm] = useState(false);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const navigate = useNavigate();

  const [newBooking, setNewBooking] = useState({
    areaName: '',
    venueSize: 0,
    timeSlot: '',
    performanceDays: '',
    mealsProvided: false,
    occasionType: '',
    primaryLanguage: '',
  });

  useEffect(() => {
    const checkAuth = async () => {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) {
        navigate('/venue-portal');
        return;
      }

      // Fetch Venue Profile
      const { data: venueProfile, error: venueError } = await supabase
        .from('profiles_venues')
        .select('*')
        .eq('user_id', user.id)
        .single();

      if (venueError || !venueProfile) {
        console.error('Venue profile not found:', venueError);
        navigate('/venue-portal');
        return;
      }

      setVenue(venueProfile);
      fetchData(venueProfile.id);
    };
    checkAuth();
  }, [navigate]);

  const fetchData = async (venueId) => {
    setLoading(true);
    try {
      // Fetch Bookings from 'bookings' table
      const { data: bookingsData, error: bookingsError } = await supabase
        .from('bookings')
        .select(`
          *,
          profiles_talent (stage_name, profile_photo_url)
        `)
        .eq('venue_id', venueId)
        .order('event_date', { ascending: false });
      
      if (bookingsError) throw bookingsError;
      setBookings(bookingsData || []);

      // Fetch Recommended Artists
      const { data: artistsData } = await supabase
        .from('profiles_talent')
        .select(`
          id,
          stage_name,
          rating,
          profile_photo_url,
          talent_genres (genres (genre_name))
        `)
        .eq('is_public', true)
        .limit(5);
      
      if (artistsData) {
        const mappedArtists = artistsData.map(a => ({
          id: a.id,
          name: a.stage_name,
          imageUrl: a.profile_photo_url,
          category: a.talent_genres?.[0]?.genres?.genre_name || 'Artist'
        }));
        setArtists(mappedArtists);
      } else {
        setArtists(ARTISTS.slice(0, 5));
      }
    } catch (error) {
      console.error('Error fetching data:', error);
      setError('Failed to load dashboard data.');
    } finally {
      setLoading(false);
    }
  };

  const handleCreateBooking = async (e) => {
    e.preventDefault();
    if (!venue) return;

    try {
      const { data: { user } } = await supabase.auth.getUser();
      
      // Insert into quote_requests as per user instruction for "New Booking" form
      const { error } = await supabase.from('quote_requests').insert({
        client_user_id: user.id,
        venue_id: venue.id,
        event_type: newBooking.occasionType,
        event_date: new Date().toISOString().split('T')[0], // Placeholder date
        start_time: newBooking.timeSlot,
        duration_hours: 2,
        location: venue.name_of_location,
        special_requirements: `Area: ${newBooking.areaName}, Size: ${newBooking.venueSize}, Days: ${newBooking.performanceDays}, Meals: ${newBooking.mealsProvided ? 'Yes' : 'No'}, Language: ${newBooking.primaryLanguage}`,
        status: 'open'
      });

      if (error) throw error;

      setShowBookingForm(false);
      fetchData(venue.id);
      setNewBooking({
        areaName: '',
        venueSize: 0,
        timeSlot: '',
        performanceDays: '',
        mealsProvided: false,
        occasionType: '',
        primaryLanguage: '',
      });
    } catch (error) {
      console.error('Error creating booking request:', error);
      setError('Failed to submit booking request.');
    }
  };

  const handleLogout = async () => {
    await supabase.auth.signOut();
    navigate('/venue-portal');
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
            <h1 className="text-3xl font-bold text-white">Venue Dashboard</h1>
            <p className="text-gray-400">Welcome back, {venue?.name}</p>
          </div>
          <div className="flex gap-3">
            <Button variant="outline" onClick={handleLogout} className="flex items-center gap-2">
              <LogOut className="w-4 h-4" /> Logout
            </Button>
            <Button onClick={() => setShowBookingForm(true)} className="flex items-center gap-2">
              <Plus className="w-4 h-4" /> New Booking
            </Button>
          </div>
        </div>

        {error && (
          <div className="mb-6 flex items-center gap-2 text-red-500 bg-red-500/10 p-4 rounded-xl border border-red-500/20">
            <AlertCircle className="w-5 h-5" />
            {error}
          </div>
        )}

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
          {/* Left Column: Booking Management */}
          <div className="lg:col-span-2 space-y-6">
            <section className="bg-brand-surface rounded-2xl border border-white/10 p-6">
              <div className="flex items-center justify-between mb-6">
                <h2 className="text-xl font-bold flex items-center gap-2">
                  <Calendar className="w-5 h-5 text-brand-purple" /> Active Bookings
                </h2>
              </div>

              {bookings.length === 0 ? (
                <div className="text-center py-12 border border-dashed border-white/10 rounded-xl">
                  <ClockIcon className="w-12 h-12 text-gray-600 mx-auto mb-4" />
                  <p className="text-gray-500">No active bookings found.</p>
                  <Button variant="ghost" onClick={() => setShowBookingForm(true)} className="mt-4">
                    Create your first booking
                  </Button>
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
                              <Clock className="w-4 h-4" /> {booking.start_time}
                            </span>
                          </div>
                        </div>
                      </div>
                      <div className="flex items-center gap-3">
                        <span className={`px-3 py-1 rounded-full text-xs font-bold uppercase tracking-wider ${
                          booking.booking_status === 'confirmed' ? 'bg-brand-lime/20 text-brand-lime' :
                          booking.booking_status === 'completed' ? 'bg-blue-500/20 text-blue-500' :
                          'bg-yellow-500/20 text-yellow-500'
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
          </div>

          {/* Right Column: Quick Stats & Artists */}
          <div className="space-y-6">
            <section className="bg-brand-surface rounded-2xl border border-white/10 p-6">
              <h2 className="text-xl font-bold mb-4 flex items-center gap-2">
                <Star className="w-5 h-5 text-brand-pink" /> Recommended Artists
              </h2>
              <div className="space-y-4">
                {artists.map((artist) => (
                  <div key={artist.id} className="flex items-center gap-4 group cursor-pointer">
                    <img
                      src={artist.imageUrl}
                      alt={artist.name}
                      className="w-12 h-12 rounded-full object-cover border border-white/10"
                    />
                    <div className="flex-grow">
                      <h4 className="font-semibold group-hover:text-brand-purple transition-colors">{artist.name}</h4>
                      <p className="text-xs text-gray-500">{artist.category}</p>
                    </div>
                    <button className="text-gray-500 hover:text-brand-pink transition-colors">
                      <Heart className="w-5 h-5" />
                    </button>
                  </div>
                ))}
                <Button variant="ghost" className="w-full text-sm" onClick={() => navigate('/artists')}>
                  View All Artists
                </Button>
              </div>
            </section>

            <section className="bg-gradient-to-br from-brand-purple/20 to-brand-pink/20 rounded-2xl border border-white/10 p-6">
              <h3 className="font-bold mb-2">Need Help?</h3>
              <p className="text-sm text-gray-400 mb-4">Our dedicated account managers are here to help you find the perfect artist for your venue.</p>
              <Button variant="outline" className="w-full text-sm">Contact Support</Button>
            </section>
          </div>
        </div>
      </div>

      {/* Booking Modal */}
      {showBookingForm && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-sm">
          <motion.div
            initial={{ opacity: 0, scale: 0.9 }}
            animate={{ opacity: 1, scale: 1 }}
            className="bg-brand-surface rounded-2xl border border-white/10 w-full max-w-2xl overflow-hidden"
          >
            <div className="p-6 border-b border-white/10 flex justify-between items-center">
              <h2 className="text-xl font-bold">Request Recurring Booking</h2>
              <button onClick={() => setShowBookingForm(false)} className="text-gray-400 hover:text-white">
                <Plus className="w-6 h-6 rotate-45" />
              </button>
            </div>
            <form onSubmit={handleCreateBooking} className="p-6 space-y-4">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-400 mb-1">Name of Area</label>
                  <input
                    type="text"
                    required
                    placeholder="e.g. Main Lobby, Rooftop Bar"
                    className="w-full bg-brand-dark border border-white/10 rounded-lg py-2 px-4 focus:outline-none focus:border-brand-purple"
                    value={newBooking.areaName}
                    onChange={(e) => setNewBooking({ ...newBooking, areaName: e.target.value })}
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-400 mb-1">Venue Size (Max Pax)</label>
                  <input
                    type="number"
                    required
                    className="w-full bg-brand-dark border border-white/10 rounded-lg py-2 px-4 focus:outline-none focus:border-brand-purple"
                    value={newBooking.venueSize}
                    onChange={(e) => setNewBooking({ ...newBooking, venueSize: parseInt(e.target.value) })}
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-400 mb-1">Required Time Slot</label>
                  <input
                    type="text"
                    required
                    placeholder="e.g. 7:00 PM - 10:00 PM"
                    className="w-full bg-brand-dark border border-white/10 rounded-lg py-2 px-4 focus:outline-none focus:border-brand-purple"
                    value={newBooking.timeSlot}
                    onChange={(e) => setNewBooking({ ...newBooking, timeSlot: e.target.value })}
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-400 mb-1">Performance Days</label>
                  <input
                    type="text"
                    required
                    placeholder="e.g. Mon, Wed, Fri"
                    className="w-full bg-brand-dark border border-white/10 rounded-lg py-2 px-4 focus:outline-none focus:border-brand-purple"
                    value={newBooking.performanceDays}
                    onChange={(e) => setNewBooking({ ...newBooking, performanceDays: e.target.value })}
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-400 mb-1">Type of Occasion</label>
                  <input
                    type="text"
                    required
                    placeholder="e.g. Fine Dining, Cocktail Night"
                    className="w-full bg-brand-dark border border-white/10 rounded-lg py-2 px-4 focus:outline-none focus:border-brand-purple"
                    value={newBooking.occasionType}
                    onChange={(e) => setNewBooking({ ...newBooking, occasionType: e.target.value })}
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-400 mb-1">Primary Language</label>
                  <input
                    type="text"
                    required
                    placeholder="e.g. English, Sinhala, Multi"
                    className="w-full bg-brand-dark border border-white/10 rounded-lg py-2 px-4 focus:outline-none focus:border-brand-purple"
                    value={newBooking.primaryLanguage}
                    onChange={(e) => setNewBooking({ ...newBooking, primaryLanguage: e.target.value })}
                  />
                </div>
              </div>

              <div className="flex items-center gap-3 py-2">
                <button
                  type="button"
                  onClick={() => setNewBooking({ ...newBooking, mealsProvided: !newBooking.mealsProvided })}
                  className={`w-12 h-6 rounded-full transition-colors relative ${newBooking.mealsProvided ? 'bg-brand-lime' : 'bg-gray-600'}`}
                >
                  <div className={`absolute top-1 w-4 h-4 bg-white rounded-full transition-all ${newBooking.mealsProvided ? 'left-7' : 'left-1'}`} />
                </button>
                <span className="text-sm font-medium text-gray-300">Provision of meals for Artists</span>
              </div>

              <div className="pt-4 flex gap-3">
                <Button variant="outline" type="button" className="flex-1" onClick={() => setShowBookingForm(false)}>
                  Cancel
                </Button>
                <Button type="submit" className="flex-1">
                  Submit Request
                </Button>
              </div>
            </form>
          </motion.div>
        </div>
      )}
    </div>
  );
};
