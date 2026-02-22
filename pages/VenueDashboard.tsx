import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { motion } from 'framer-motion';
import { Plus, Calendar, Clock, Users, Utensils, Languages, Star, Heart, LayoutDashboard, LogOut, CheckCircle, Clock as ClockIcon } from 'lucide-react';
import { Button } from '../components/Button';
import { supabase } from '../services/supabase';
import { Venue, RecurringBooking, Artist } from '../types';

export const VenueDashboard: React.FC = () => {
  const [venue, setVenue] = useState<Venue | null>(null);
  const [bookings, setBookings] = useState<RecurringBooking[]>([]);
  const [artists, setArtists] = useState<Artist[]>([]);
  const [showBookingForm, setShowBookingForm] = useState(false);
  const [loading, setLoading] = useState(true);
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
    const storedVenue = localStorage.getItem('venue_user');
    if (!storedVenue) {
      navigate('/venue-portal');
      return;
    }
    const parsedVenue = JSON.parse(storedVenue);
    setVenue(parsedVenue);
    fetchData(parsedVenue.id);
  }, [navigate]);

  const fetchData = async (venueId: string) => {
    setLoading(true);
    try {
      // Fetch Bookings
      const { data: bookingsData } = await supabase
        .from('recurring_bookings')
        .select('*')
        .eq('venue_id', venueId)
        .order('created_at', { ascending: false });
      
      if (bookingsData) {
        const mappedBookings = (bookingsData as any[]).map(b => ({
          id: b.id,
          venueId: b.venue_id,
          areaName: b.area_name,
          venueSize: b.venue_size,
          timeSlot: b.time_slot,
          performanceDays: b.performance_days,
          mealsProvided: b.meals_provided,
          occasionType: b.occasion_type,
          primaryLanguage: b.primary_language,
          status: b.status,
          createdAt: b.created_at
        }));
        setBookings(mappedBookings);
      }

      // Fetch Active Artists for reference
      const { data: artistsData } = await supabase
        .from('artists')
        .select('*')
        .limit(5);
      
      if (artistsData) setArtists(artistsData);
    } catch (error) {
      console.error('Error fetching data:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleCreateBooking = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!venue) return;

    try {
      const { error } = await supabase.from('recurring_bookings').insert({
        venue_id: venue.id,
        area_name: newBooking.areaName,
        venue_size: newBooking.venueSize,
        time_slot: newBooking.timeSlot,
        performance_days: newBooking.performanceDays,
        meals_provided: newBooking.mealsProvided,
        occasion_type: newBooking.occasionType,
        primary_language: newBooking.primaryLanguage,
        status: 'pending',
      } as any);

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
      console.error('Error creating booking:', error);
    }
  };

  const handleLogout = () => {
    localStorage.removeItem('venue_user');
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
                      <div className="space-y-1">
                        <h3 className="font-bold text-lg">{booking.areaName}</h3>
                        <div className="flex flex-wrap gap-4 text-sm text-gray-400">
                          <span className="flex items-center gap-1">
                            <Users className="w-4 h-4" /> {booking.venueSize} Pax
                          </span>
                          <span className="flex items-center gap-1">
                            <Clock className="w-4 h-4" /> {booking.timeSlot}
                          </span>
                          <span className="flex items-center gap-1">
                            <Calendar className="w-4 h-4" /> {booking.performanceDays}
                          </span>
                        </div>
                      </div>
                      <div className="flex items-center gap-3">
                        <span className={`px-3 py-1 rounded-full text-xs font-bold uppercase tracking-wider ${
                          booking.status === 'confirmed' ? 'bg-brand-lime/20 text-brand-lime' :
                          booking.status === 'quoted' ? 'bg-brand-purple/20 text-brand-purple' :
                          'bg-yellow-500/20 text-yellow-500'
                        }`}>
                          {booking.status}
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
