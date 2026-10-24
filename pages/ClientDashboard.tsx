import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router';
import { 
  Calendar, Clock, Heart, CreditCard, 
  Settings, LogOut, ChevronRight,
  Shield, Music, MapPin
} from 'lucide-react';
import { Button } from '../components/Button';
import { supabase } from '../services/supabase';
import { TalentRating } from '../components/TalentRating';
import type { RawTalentStats } from '../types';

// bookings.starts_at and quote_requests.starts_at are timestamptz. Without an
// explicit timeZone these render in the *viewer's* zone, so an 8pm–1am wedding
// shows the wrong date for a client browsing from abroad. Mirrors the helpers
// already in VenueDashboard.tsx.
const LK_TZ = 'Asia/Colombo';

const lkDate = (iso: string, opts: Intl.DateTimeFormatOptions = { day: 'numeric', month: 'short', year: 'numeric' }): string =>
  new Date(iso).toLocaleDateString('en-GB', { timeZone: LK_TZ, ...opts });

interface ClientProfile {
  id: string;
  user_id: string;
  full_name: string;
  email?: string;
}

interface ClientDashboardBooking {
  id: string;
  starts_at: string;
  booking_status: string;
  location?: string;
  profiles_talent?: {
    stage_name: string;
    profile_photo_url?: string;
  };
  profiles_venues?: {
    name_of_venue: string;
    name_of_location: string;
  };
}

// What the client is shown of a quote. Deliberately NOT commission_amount or
// talent_payout_amount — those are En4's margin and the performer's payout,
// and quotes_client_read grants row access, not column access, so keeping
// them out is a discipline of the select string below.
interface ClientDashboardQuoteOffer {
  id: string;
  quoted_amount: string;
  travel_fee: string | null;
  equipment_fee: string | null;
  sscl_amount: string | null;
  vat_amount: string | null;
  gateway_fee_amount: string | null;
  total_client_price: string | null;
  quote_status: string;
  expires_at: string;
  notes_to_client: string | null;
  equipment_provided_by: string;
  performer_count: number | null;
}

interface ClientDashboardQuote {
  id: string;
  event_type: string;
  starts_at: string;
  status: string;
  profiles_talent?: {
    stage_name: string;
    profile_photo_url?: string;
  };
  quotes?: ClientDashboardQuoteOffer[];
}

interface ClientDashboardFavorite {
  id: string;
  profiles_talent?: {
    id: string;
    stage_name: string;
    profile_photo_url?: string;
    talent_stats?: RawTalentStats;
  };
}

export const ClientDashboard: React.FC = () => {
  const [client, setClient] = useState<ClientProfile | null>(null);
  const [bookings, setBookings] = useState<ClientDashboardBooking[]>([]);
  const [quotes, setQuotes] = useState<ClientDashboardQuote[]>([]);
  const [accepting, setAccepting] = useState<string | null>(null);
  const [actionMessage, setActionMessage] = useState<string | null>(null);
  const [favorites, setFavorites] = useState<ClientDashboardFavorite[]>([]);
  const [loading, setLoading] = useState<boolean>(true);
  const navigate = useNavigate();

  const fetchData = async (userId: string): Promise<void> => {
    setLoading(true);
    try {
      // Fetch Bookings
      const { data: bookingsData } = await supabase
        .from('bookings')
        .select(`
          id,
          starts_at,
          booking_status,
          profiles_talent (stage_name, profile_photo_url),
          profiles_venues (name_of_venue, name_of_location)
        `)
        .eq('client_user_id', userId)
        .order('starts_at', { ascending: false });
      
      setBookings(((bookingsData as unknown) as ClientDashboardBooking[]) || []);

      // Fetch Quotes
      const { data: quotesData } = await supabase
        .from('quote_requests')
        .select(`
          id,
          event_type,
          starts_at,
          status,
          profiles_talent (stage_name, profile_photo_url),
          quotes (
            id,
            quoted_amount,
            travel_fee,
            equipment_fee,
            sscl_amount,
            vat_amount,
            gateway_fee_amount,
            total_client_price,
            quote_status,
            expires_at,
            notes_to_client,
            equipment_provided_by,
            performer_count
          )
        `)
        .eq('client_user_id', userId)
        .order('created_at', { ascending: false });
      
      setQuotes(((quotesData as unknown) as ClientDashboardQuote[]) || []);

      // Fetch Favorites
      const { data: favoritesData } = await supabase
        .from('talent_favourites')
        .select(`
          id,
          profiles_talent (id, stage_name, profile_photo_url, talent_stats(rating_average, rating_count))
          `)
          .eq('user_id', userId);
      
      setFavorites(((favoritesData as unknown) as ClientDashboardFavorite[]) || []);
    } catch (error) {
      console.error('Error fetching client data:', error);
    } finally {
      setLoading(false);
    }
  };

  // Accepting a quote is NOT a client-side update. There is no client UPDATE
  // policy on quotes, and the three writes (quote -> accepted, booking INSERT,
  // request -> converted) must share one transaction — accept-quote calls a
  // Postgres function that does all three. Raw fetch, not functions.invoke():
  // invoke does not reliably surface 4xx JSON bodies, and the RPC's error
  // messages are written to be read by the client.
  const handleAcceptQuote = async (quoteId: string): Promise<void> => {
    setAccepting(quoteId);
    setActionMessage(null);
    try {
      const { data: { session } } = await supabase.auth.getSession();
      if (!session) {
        setActionMessage('Please sign in again.');
        return;
      }

      const res = await fetch(
        `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/accept-quote`,
        {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${session.access_token}`,
            apikey: import.meta.env.VITE_SUPABASE_ANON_KEY,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ quote_id: quoteId }),
        },
      );

  // PostgREST serialises numeric as a STRING ("57360.62"), so every money
  // value must go through Number() before formatting. This is the same trap
  // that made FlexArtistCard crash on .toFixed(1).
  const money = (v: string | null): string =>
    v == null ? '—' : `LKR ${Number(v).toLocaleString('en-LK', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;

      const body = await res.json();

      if (!res.ok) {
        setActionMessage(body?.error ?? 'Could not accept the quote.');
        return;
      }

      setActionMessage('Quote accepted — your booking is confirmed.');
      fetchData(session.user.id);
    } catch {
      setActionMessage('Could not accept the quote. Please try again.');
    } finally {
      setAccepting(null);
    }
  };
  // PostgREST serialises numeric as a STRING ("57360.62"), so every money
  // value must go through Number() before formatting. This is the same trap
  // that made FlexArtistCard crash on .toFixed(1).
  const money = (v: string | null): string =>
    v == null ? '—' : `LKR ${Number(v).toLocaleString('en-LK', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;

  useEffect(() => {
    const checkAuth = async (): Promise<void> => {
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

      setClient((profile as unknown) as ClientProfile);
      fetchData(user.id);
    };
    checkAuth();
  }, [navigate]);

  const handleLogout = async (): Promise<void> => {
    await supabase.auth.signOut();
    navigate('/');
  };

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-brand-dark" id="client-dashboard-loading">
        <div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-brand-purple"></div>
      </div>
    );
  }

  return (
    <div className="min-h-screen pt-24 pb-12 px-4 bg-brand-dark" id="client-dashboard">
      <div className="max-w-7xl mx-auto">
        <div className="flex flex-col md:flex-row justify-between items-start md:items-center mb-8 gap-4 text-left">
          <div>
            <h1 className="text-3xl font-bold text-white">Client Dashboard</h1>
            <p className="text-gray-400">Welcome back, {client?.full_name}</p>
          </div>
          <div className="flex gap-3">
            <Button variant="outline" onClick={handleLogout} className="flex items-center gap-2" id="client-logout-btn">
              <LogOut className="w-4 h-4" /> Logout
            </Button>
            <Button className="flex items-center gap-2" id="client-settings-btn">
              <Settings className="w-4 h-4" /> Account Settings
            </Button>
          </div>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
          {/* Left Column: Favorites & Account */}
          <div className="space-y-6 text-left">
            <section className="bg-brand-surface rounded-2xl border border-white/10 p-6">
              <h3 className="text-lg font-bold mb-4 flex items-center gap-2">
                <Heart className="w-5 h-5 text-brand-pink" /> Saved Favorites
              </h3>
              {favorites.length === 0 ? (
                <div className="text-center py-8 border border-dashed border-white/10 rounded-xl" id="no-favorites-saved">
                  <p className="text-gray-500 text-sm">No favorites saved yet.</p>
                  <Button variant="ghost" size="sm" className="mt-2" onClick={() => navigate('/artists')}>
                    Explore Artists
                  </Button>
                </div>
              ) : (
                <div className="space-y-4" id="favorites-list">
                  {favorites.map((fav: ClientDashboardFavorite) => (
                    <div key={fav.id} className="flex items-center gap-4 group cursor-pointer" onClick={() => fav.profiles_talent?.id && navigate(`/artists/${fav.profiles_talent.id}`)}>
                      <img 
                        src={fav.profiles_talent?.profile_photo_url || 'https://picsum.photos/seed/artist/100/100'} 
                        alt={fav.profiles_talent?.stage_name}
                        className="w-12 h-12 rounded-lg object-cover border border-white/10 animate-fade-in"
                      />
                      <div className="flex-grow">
                        <h4 className="font-semibold group-hover:text-brand-purple transition-colors">{fav.profiles_talent?.stage_name}</h4>
                        <TalentRating stats={fav.profiles_talent?.talent_stats} size={12} className="text-brand-lime text-xs" />
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
          <div className="lg:col-span-2 space-y-6 text-left">
            <section className="bg-brand-surface rounded-2xl border border-white/10 p-6">
              <div className="flex items-center justify-between mb-6">
                <h2 className="text-xl font-bold flex items-center gap-2">
                  <Calendar className="w-5 h-5 text-brand-purple" /> My Bookings
                </h2>
              </div>

              {bookings.length === 0 ? (
                <div className="text-center py-12 border border-dashed border-white/10 rounded-xl" id="no-bookings-found-dashboard">
                  <p className="text-gray-500">No bookings found.</p>
                  <Button className="mt-4" onClick={() => navigate('/artists')}>Book an Artist</Button>
                </div>
              ) : (
                <div className="space-y-4" id="bookings-list">
                  {bookings.map((booking: ClientDashboardBooking) => (
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
                              <Calendar className="w-4 h-4" /> {lkDate(booking.starts_at)}
                            </span>
                            <span className="flex items-center gap-1">
                              <MapPin className="w-4 h-4" /> {booking.profiles_venues?.name_of_venue || booking.location || 'TBA'}
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

              {actionMessage && (
                <div className="mb-4 rounded-xl border border-white/10 bg-white/5 px-4 py-3 text-sm text-gray-200">
                  {actionMessage}
                </div>
              )}
              
              {quotes.length === 0 ? (
                <div className="text-center py-12 border border-dashed border-white/10 rounded-xl" id="no-open-quotes-dashboard">
                  <p className="text-gray-500">No open quote requests.</p>
                </div>
              ) : (
                <div className="space-y-4" id="quotes-list">
                  {quotes.map((quote: ClientDashboardQuote) => (
                    <div
                      key={quote.id}
                      className="bg-brand-dark/50 border border-white/5 rounded-xl p-4 space-y-4"
                    >
                      <div className="flex flex-col md:flex-row justify-between gap-4">
                        <div className="flex items-center gap-4">
                          <div className="w-12 h-12 bg-white/5 rounded-lg flex items-center justify-center text-brand-purple">
                            <Music className="w-6 h-6" />
                          </div>
                          <div className="space-y-1">
                            <h3 className="font-bold text-lg">{quote.profiles_talent?.stage_name || 'General Request'}</h3>
                            <p className="text-sm text-gray-400">{quote.event_type} — {lkDate(quote.starts_at)}</p>
                          </div>
                        </div>
                        <div className="flex items-center gap-3">
                          <span className={`px-3 py-1 rounded-full text-[10px] font-black uppercase tracking-wider ${
                            quote.status === 'quoted' ? 'bg-brand-purple/20 text-brand-purple' : 'bg-white/10 text-gray-400'
                          }`}>
                            {quote.status}
                          </span>
                        </div>
                      </div>

                      {/* The offer itself. quotes_one_per_request means there is at
                          most one, but PostgREST returns an array for the embed. */}
                      {quote.quotes?.[0] && quote.quotes[0].quote_status === 'pending' && (
                        <div className="border-t border-white/5 pt-4 space-y-3">
                          <div className="space-y-1 text-sm">
                            <div className="flex justify-between text-gray-400">
                              <span>Performance fee</span><span>{money(quote.quotes[0].quoted_amount)}</span>
                            </div>
                            {Number(quote.quotes[0].travel_fee ?? 0) > 0 && (
                              <div className="flex justify-between text-gray-400">
                                <span>Travel</span><span>{money(quote.quotes[0].travel_fee)}</span>
                              </div>
                            )}
                            {Number(quote.quotes[0].equipment_fee ?? 0) > 0 && (
                              <div className="flex justify-between text-gray-400">
                                <span>Equipment</span><span>{money(quote.quotes[0].equipment_fee)}</span>
                              </div>
                            )}
                            {Number(quote.quotes[0].sscl_amount ?? 0) > 0 && (
                              <div className="flex justify-between text-gray-400">
                                <span>SSCL</span><span>{money(quote.quotes[0].sscl_amount)}</span>
                              </div>
                            )}
                            {Number(quote.quotes[0].vat_amount ?? 0) > 0 && (
                              <div className="flex justify-between text-gray-400">
                                <span>VAT</span><span>{money(quote.quotes[0].vat_amount)}</span>
                              </div>
                            )}
                            {Number(quote.quotes[0].gateway_fee_amount ?? 0) > 0 && (
                              <div className="flex justify-between text-gray-400">
                                <span>Payment processing</span><span>{money(quote.quotes[0].gateway_fee_amount)}</span>
                              </div>
                            )}
                            <div className="flex justify-between font-bold text-white pt-2 border-t border-white/5">
                              <span>Total</span><span>{money(quote.quotes[0].total_client_price)}</span>
                            </div>
                          </div>

                          {quote.quotes[0].notes_to_client && (
                            <p className="text-sm text-gray-400 italic">{quote.quotes[0].notes_to_client}</p>
                          )}

                          <p className="text-xs text-gray-500">
                            Valid until {lkDate(quote.quotes[0].expires_at)}. Accepting confirms the booking.
                          </p>

                          <Button
                            onClick={() => handleAcceptQuote(quote.quotes![0].id)}
                            disabled={accepting === quote.quotes[0].id}
                            size="sm"
                          >
                            {accepting === quote.quotes[0].id ? 'Accepting…' : 'Accept quote'}
                          </Button>
                        </div>
                      )}
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
