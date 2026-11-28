import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router';
import { 
  Calendar, Clock, Heart, 
  Settings, LogOut, ChevronRight,
  Music, MapPin
} from 'lucide-react';
import { Button } from '../components/Button';
import { supabase } from '../services/supabase';
import { formatMoney } from '../utils/money';
import { TalentRating } from '../components/TalentRating';
import type { RawTalentStats } from '../types';
import { cldImage } from '../utils/cloudinary';

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
  profiles_talent?: {
    stage_name: string;
    profile_photo_url?: string;
  };
  profiles_venues?: {
    name_of_venue: string;
    name_of_location: string;
  };
    // Read through to the request rather than stored on the booking: `bookings`
  // has no address column of any kind, only venue_id, which is NULL for a
  // private address. Both hops are many-to-one FKs, so PostgREST returns
  // objects, not arrays - bookings.quote_id -> quotes.id -> quote_requests.id.
  // event_address is frozen by enforce_quote_request_writes once the request
  // leaves 'open', so reading it live cannot drift from what was booked.
  quotes?: {
    quote_requests?: {
      location: string | null;
      event_address: string | null;
    } | null;
  } | null;
}

// What the client is shown of a quote. Deliberately NOT commission_amount or
// talent_payout_amount — those are En4's margin and the performer's payout,
// and quotes_client_read grants row access, not column access, so keeping
// them out is a discipline of the select string below.
interface ClientDashboardQuoteOffer {
  id: string;
  quoted_amount: string;
  travel_fee: string | null;
  meals_fee: string | null;
  accommodation_fee: string | null;
  sscl_amount: string | null;
  vat_amount: string | null;
  gateway_fee_amount: string | null;
  total_client_price: string | null;
  quote_status: string;
  expires_at: string;
  notes_to_client: string | null;
  performer_count: number | null;
}

// Everything the client pays for the engagement itself: the talent's fee, En4's
// client-side commission, and travel, meals and accommodation where they apply.
//
// Derived by SUBTRACTING the separately itemised lines from the total rather
// than summed from the parts. Two reasons. The breakdown can then never
// disagree with the total - it previously showed lines summing to 10% less than
// the total, because the client commission leg had no line and was never meant
// to have one. And commission_client_amount still never has to be fetched, so
// En4's margin stays out of the browser entirely.
//
// SSCL, VAT and the gateway fee keep their own lines deliberately: a tax
// invoice must state the tax charged separately from the value of the supply,
// so bundling them would not survive VAT registration.
const engagementAmount = (q: ClientDashboardQuoteOffer): string =>
  String(
    Number(q.total_client_price ?? 0) -
      Number(q.sscl_amount ?? 0) -
      Number(q.vat_amount ?? 0) -
      Number(q.gateway_fee_amount ?? 0),
  );

interface ClientDashboardQuote {
  id: string;
  event_type: string;
  starts_at: string;
  status: string;
  decline_reason: string | null;
  decline_note: string | null;
  profiles_talent?: {
    stage_name: string;
    profile_photo_url?: string;
  };
  quotes?: ClientDashboardQuoteOffer | null;
}

// The artist picks an enum; the client reads a sentence. Never show the label.
// Must cover every value of public.quote_decline_reason.
const DECLINE_SENTENCES: Record<string, string> = {
  schedule_conflict: 'The artist is not available at that time.',
  outside_service_area: 'The event is outside the area the artist travels to.',
  event_type_mismatch: 'The artist does not take this kind of event.',
  other: 'The artist is unable to take this booking.',
};

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
  const [showClosed, setShowClosed] = useState<boolean>(false);
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
          profiles_venues (name_of_venue, name_of_location),
          quotes ( quote_requests ( location, event_address ) )
        `)
        .eq('client_user_id', userId)
        .order('starts_at', { ascending: false });
      
      setBookings(((bookingsData as unknown) as ClientDashboardBooking[]) || []);

      // Fetch Quotes
      const { data: quotesData, error: quotesError } = await supabase
        .from('quote_requests')
        .select(`
          id,
          event_type,
          starts_at,
          status,
          decline_reason,
          decline_note,
          profiles_talent (stage_name, profile_photo_url),
          quotes (
            id,
            quoted_amount,
            travel_fee,
            meals_fee,
            accommodation_fee,
            sscl_amount,
            vat_amount,
            gateway_fee_amount,
            total_client_price,
            quote_status,
            expires_at,
            notes_to_client,
            performer_count
          )
        `)
        .eq('client_user_id', userId)
        .order('created_at', { ascending: false });
      
      if (quotesError) setActionMessage('Could not load your quote requests. Please refresh.');
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

      const body = await res.json();

      if (!res.ok) {
        setActionMessage(body?.error ?? 'Could not accept the quote.');
        return;
      }

      // Not "confirmed". booking_status is 'pending' here and stays there until
      // payment is arranged, which is manual until PayHere ships. Telling a client
      // their booking is confirmed contradicts the PENDING badge on the same screen,
      // and sets an expectation nothing in the system has met yet.
      setActionMessage('Quote accepted. Your booking is pending until payment is arranged — we will be in touch.');
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

  // A request is live while it still needs the client: waiting on the artist,
  // or carrying a quote to accept. Everything else is history the client may
  // want to look back at - a decline and its reason, an expiry, a request that
  // became a booking - so it is kept, but folded away by default rather than
  // burying the one row that needs attention.
  const LIVE_STATUSES = ['open', 'matched'];
  const liveQuotes = quotes.filter((q) => LIVE_STATUSES.includes(q.status));
  const closedQuotes = quotes.filter((q) => !LIVE_STATUSES.includes(q.status));
  const visibleQuotes = showClosed ? [...liveQuotes, ...closedQuotes] : liveQuotes;

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
                        src={cldImage(fav.profiles_talent?.profile_photo_url, 'avatar') || '/avatar-placeholder.svg'} 
                        alt={fav.profiles_talent?.stage_name}
                        className="w-12 h-12 rounded-lg object-cover border border-white/10 animate-fade-in"
                      />
                      <div className="grow">
                        <h4 className="font-semibold group-hover:text-brand-purple transition-colors">{fav.profiles_talent?.stage_name}</h4>
                        <TalentRating stats={fav.profiles_talent?.talent_stats} size={12} className="text-brand-lime text-xs" />
                      </div>
                      <ChevronRight className="w-4 h-4 text-gray-600 group-hover:text-white transition-colors" />
                    </div>
                  ))}
                </div>
              )}
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
                          src={cldImage(booking.profiles_talent?.profile_photo_url, 'avatar') || '/avatar-placeholder.svg'} 
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
                              <MapPin className="w-4 h-4" /> {booking.profiles_venues?.name_of_venue || booking.quotes?.quote_requests?.location || booking.quotes?.quote_requests?.event_address || 'TBA'}
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
                  <Clock className="w-5 h-5 text-brand-pink" /> Quote Requests
                </h2>
              </div>

              {actionMessage && (
                <div className="mb-4 rounded-xl border border-white/10 bg-white/5 px-4 py-3 text-sm text-gray-200">
                  {actionMessage}
                </div>
              )}
              
              {visibleQuotes.length === 0 ? (
                <div className="text-center py-12 border border-dashed border-white/10 rounded-xl" id="no-open-quotes-dashboard">
                  <p className="text-gray-500">
                    {closedQuotes.length === 0
                      ? 'No quote requests yet.'
                      : 'Nothing needs you right now.'}
                  </p>
                </div>
              ) : (
                <div className="space-y-4" id="quotes-list">
                  {visibleQuotes.map((quote: ClientDashboardQuote) => (
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

                      {/* A declined request is closed for good: it names one artist
                          and cannot be passed to another. Say why, and what to do. */}
                      {quote.status === 'declined' && (
                        <div className="border-t border-white/5 pt-4 space-y-1 text-sm text-gray-400">
                          <p>
                            {DECLINE_SENTENCES[quote.decline_reason ?? ''] ?? DECLINE_SENTENCES.other}
                          </p>
                          {quote.decline_note && (
                            <p className="italic">&ldquo;{quote.decline_note}&rdquo;</p>
                          )}
                          <p className="text-xs text-gray-500">
                            This request is now closed. You can send a new request to another artist.
                          </p>
                        </div>
                      )}

                      {/* The offer itself. quotes_one_per_request is UNIQUE on quote_request_id, so
                          PostgREST returns an object here, or null, never an array. */}
                      {quote.quotes && quote.quotes.quote_status === 'pending' && (
                        <div className="border-t border-white/5 pt-4 space-y-3">
                          <div className="space-y-1 text-sm">
                            <div className="flex justify-between text-gray-400">
                              <span>Performance fee*</span><span>{formatMoney(engagementAmount(quote.quotes))}</span>
                            </div>
                            {Number(quote.quotes.sscl_amount ?? 0) > 0 && (
                              <div className="flex justify-between text-gray-400">
                                <span>SSCL</span><span>{formatMoney(quote.quotes.sscl_amount)}</span>
                              </div>
                            )}
                            {Number(quote.quotes.vat_amount ?? 0) > 0 && (
                              <div className="flex justify-between text-gray-400">
                                <span>VAT</span><span>{formatMoney(quote.quotes.vat_amount)}</span>
                              </div>
                            )}
                            {Number(quote.quotes.gateway_fee_amount ?? 0) > 0 && (
                              <div className="flex justify-between text-gray-400">
                                <span>Payment processing</span><span>{formatMoney(quote.quotes.gateway_fee_amount)}</span>
                              </div>
                            )}
                            <div className="flex justify-between font-bold text-white pt-2 border-t border-white/5">
                              <span>Total</span><span>{formatMoney(quote.quotes.total_client_price)}</span>
                            </div>
                            <p className="pt-2 text-xs text-gray-500">
                              * Covers the performers, their instruments and equipment,
                              travel, meals and accommodation.
                              {Number(quote.quotes.travel_fee ?? 0) > 0 &&
                                ` Includes ${formatMoney(quote.quotes.travel_fee)} for travel.`}
                            </p>
                          </div>

                          {quote.quotes.notes_to_client && (
                            <p className="text-sm text-gray-400 italic">{quote.quotes.notes_to_client}</p>
                          )}

                          <p className="text-xs text-gray-500">
                            Valid until {lkDate(quote.quotes.expires_at)}. Accepting confirms the booking.
                          </p>

                          <Button
                            onClick={() => handleAcceptQuote(quote.quotes!.id)}
                            disabled={accepting === quote.quotes.id}
                            size="sm"
                          >
                            {accepting === quote.quotes.id ? 'Accepting…' : 'Accept quote'}
                          </Button>
                        </div>
                      )}
                    </div>
                  ))}
                </div>
              )}

              {closedQuotes.length > 0 && (
                <button
                  type="button"
                  onClick={() => setShowClosed((v) => !v)}
                  className="mt-4 text-sm text-gray-400 hover:text-white transition-colors"
                  id="toggle-closed-quotes"
                >
                  {showClosed
                    ? 'Hide closed requests'
                    : `Show ${closedQuotes.length} closed request${closedQuotes.length === 1 ? '' : 's'}`}
                </button>
              )}
            </section>
          </div>
        </div>
      </div>
    </div>
  );
};
