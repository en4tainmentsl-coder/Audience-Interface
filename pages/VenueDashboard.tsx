import React, { useState, useEffect, useRef, useCallback } from 'react';
import { useNavigate } from 'react-router';
import { 
  Calendar, MessageSquare, Bell, LogOut, ChevronDown, ChevronUp, 
  CheckCircle, Clock, AlertCircle, FileText, 
  CreditCard, X, Send, Users, TrendingUp, Zap 
} from 'lucide-react';
import { supabase } from '../services/supabase';
import { Button } from '../components/Button';
import type { Database } from '../database.types';
import { TalentRating } from '../components/TalentRating';
import type { RawTalentStats } from '../types';

// bookings.starts_at / ends_at and quote_requests.starts_at are timestamptz.
// Without an explicit timeZone these render in the *viewer's* zone, so an
// 8pm–1am wedding shows the wrong date for a client browsing from abroad.
const LK_TZ = 'Asia/Colombo';

const lkDate = (iso: string, opts: Intl.DateTimeFormatOptions = { day: 'numeric', month: 'short' }): string =>
  new Date(iso).toLocaleDateString('en-GB', { timeZone: LK_TZ, ...opts });

const lkTime = (iso: string): string =>
  new Date(iso).toLocaleTimeString('en-GB', { timeZone: LK_TZ, hour: '2-digit', minute: '2-digit' });

type BookingRow = Database['public']['Tables']['bookings']['Row'];
type QuoteRequestRow = Database['public']['Tables']['quote_requests']['Row'];

// --- Types & Interfaces ---

interface StatusBadgeProps {
  status: string;
}

interface StatCardProps {
  title: string;
  value: string | number;
  icon: React.ComponentType<any>;
  accentColor: 'purple' | 'pink' | 'lime' | 'indigo';
}

interface VenueProfile {
  id: string;
  user_id: string;
  name_of_venue: string;
  is_verified?: boolean;
  name_of_location?: string;
  size_of_space?: string;
  address_row_1?: string;
  address_city?: string;
  address_country?: string;
  contact_person?: string;
  contact_email?: string;
  contact_phone?: string;
  url_venue_photo?: string;
  required_time_slot?: string;
  performance_days?: string[];
  type_of_occasion?: string;
  music_genre_preference?: string[];
  language_preference?: string;
  meals_for_talent?: boolean;
  audience_age_range?: string;
  [key: string]: any;
}

interface BookingQuote {
  id: string;
  talent_id: string;
  quoted_amount: number;
  total_client_price: number;
  quote_status: string;
  notes_to_client?: string;
  travel_fee?: number;
  equipment_fee?: number;
  profiles_talent?: {
    stage_name: string;
    profile_photo_url?: string;
    talent_stats?: RawTalentStats;
    type_of_performer?: string;
  };
}

interface QuoteRequest extends QuoteRequestRow {
  quotes?: BookingQuote[];
}

interface BookingPayment {
  id: string;
  payment_type: string;
  payment_status: string;
  gross_amount?: number;
  paid_at?: string;
  currency?: string;
}

interface UpcomingBooking extends BookingRow {
  profiles_talent?: {
    user_id?: string;
    stage_name: string;
    profile_photo_url?: string;
    talent_stats?: RawTalentStats;
    type_of_performer?: string;
    is_verified?: boolean;
    mobile?: string;
    email?: string;
  };
  contracts?: {
    id?: string;
    status: string;
    signed_by_talent_at?: string;
    signed_by_venue_at?: string;
  };
  payments?: BookingPayment[];
}

interface PastBooking extends BookingRow {
  profiles_talent?: {
    stage_name: string;
    profile_photo_url?: string;
    talent_stats?: RawTalentStats;
  };
}

// Derived from the live schema rather than hand-listed: the column is sent_at,
// not send_at, and both message_preview and sent_at are nullable.
type NotificationItem = Database['public']['Tables']['notifications']['Row'];

interface MessageItem {
  id?: string;
  booking_id: string;
  sender_id: string;
  content: string;
  is_read: boolean;
  created_at?: string;
  read_at?: string;
}

// --- Sub-components ---

const StatusBadge: React.FC<StatusBadgeProps> = ({ status }) => {
  const getStyles = (): string => {
    switch (status) {
      case 'open': return 'bg-brand-lime text-brand-dark';
      case 'confirmed': return 'bg-brand-lime text-brand-dark';
      case 'pending': return 'bg-amber-500 text-white';
      case 'completed': return 'bg-gray-600 text-white';
      case 'cancelled': return 'bg-brand-pink text-white';
      case 'accepted': return 'bg-brand-lime text-brand-dark';
      case 'rejected': return 'bg-red-500 text-white';
      case 'matched': return 'bg-brand-purple text-white';
      case 'converted': return 'bg-brand-lime text-brand-dark';
      case 'countered': return 'bg-brand-purple text-white';
      case 'declined': return 'bg-brand-pink text-white';
      case 'expired': return 'bg-gray-700 text-gray-400';
      default: return 'bg-gray-700 text-gray-300';
    }
  };

  return (
    <span className={`text-[10px] font-black uppercase tracking-widest px-2 py-1 rounded-full ${getStyles()}`}>
      {status?.replace('_', ' ')}
    </span>
  );
};

const StatCard: React.FC<StatCardProps> = ({ title, value, icon: Icon, accentColor }) => {
  const accentStyles = {
    purple: 'border-l-brand-purple',
    pink: 'border-l-brand-pink',
    lime: 'border-l-brand-lime',
    indigo: 'border-l-brand-indigo',
  };

  return (
    <div className={`bg-brand-surface p-6 rounded-xl border border-white/5 border-l-4 ${accentStyles[accentColor]} hover:-translate-y-1 hover:shadow-xl transition-all duration-300`}>
      <div className="flex justify-between items-start text-left">
        <div>
          <p className="text-xs font-black uppercase tracking-widest text-gray-400 mb-1">{title}</p>
          <h3 className="text-2xl font-black text-white">{value}</h3>
        </div>
        <div className={`p-2 rounded-lg bg-white/5 text-brand-${accentColor}`}>
          <Icon size={20} />
        </div>
      </div>
    </div>
  );
};

export const VenueDashboard: React.FC = () => {
  const navigate = useNavigate();
  const [loading, setLoading] = useState<boolean>(true);
  const [error, setError] = useState<string | null>(null);
  const [toast, setToast] = useState<string | null>(null);

  // Data State
  const [venue, setVenue] = useState<VenueProfile | null>(null);
  const [quoteRequests, setQuoteRequests] = useState<QuoteRequest[]>([]);
  const [upcomingBookings, setUpcomingBookings] = useState<UpcomingBooking[]>([]);
  const [pastBookings, setPastBookings] = useState<PastBooking[]>([]);
  const [notifications, setNotifications] = useState<NotificationItem[]>([]);
  const [unreadMessages, setUnreadMessages] = useState<MessageItem[]>([]);
  const [unreadNotificationCount, setUnreadNotificationCount] = useState<number>(0);

  // UI State
  const [showNotifications, setShowNotifications] = useState<boolean>(false);
  const [activeMessageBooking, setActiveMessageBooking] = useState<UpcomingBooking | null>(null);
  const [messageContent, setMessageContent] = useState<string>('');
  const [messages, setMessages] = useState<MessageItem[]>([]);
  const [showBookingForm, setShowBookingForm] = useState<boolean>(false);
  const [expandedBooking, setExpandedBooking] = useState<string | null>(null);
  const [expandedQuoteRequest, setExpandedQuoteRequest] = useState<string | null>(null);
  const [historyPage, setHistoryPage] = useState<number>(1);

  const messageEndRef = useRef<HTMLDivElement | null>(null);

  // --- Data Loading ---

  const showToast = (message: string): void => {
    setToast(message);
    setTimeout(() => setToast(null), 5000);
  };

  const loadDashboardData = useCallback(async (): Promise<void> => {
    try {
      let authUser: any = null;
try {
  const { data } = await supabase.auth.getUser();
  authUser = data.user;
} catch (e) {
  console.error("Auth check failed", e);
}

if (!authUser) {
  navigate('/venue-portal');
  return;
}

      // 1. Fetch Venue Profile
      let venueProfile: VenueProfile | null = null;
const { data, error: venueError } = await supabase
  .from('profiles_venues')
  .select('*')
  .eq('user_id', authUser.id)
  .single();
if (data) venueProfile = data as unknown as VenueProfile;
      if (!venueProfile) {
        setError("Venue profile not found. Please contact support.");
        setLoading(false);
        return;
      }
      setVenue(venueProfile);
      
      // Parallel Queries (Real Data)
      const [
        quoteRequestsRes,
        upcomingBookingsRes,
        pastBookingsRes,
        notificationsRes,
        messagesRes
      ] = await Promise.all([
        // 2. Quote Requests
        supabase.from('quote_requests')
          .select('*, quotes(id, talent_id, quoted_amount, total_client_price, quote_status, expires_at, notes_to_client, profiles_talent(stage_name, profile_photo_url, talent_stats(rating_average, rating_count), type_of_performer))')
          .eq('venue_id', venueProfile.id)
          .order('created_at', { ascending: false }),

        // 3. Upcoming Bookings
        supabase.from('bookings')
          .select('*, profiles_talent(stage_name, profile_photo_url, talent_stats(rating_average, rating_count), type_of_performer, mobile, email, is_verified), contracts(id, status, signed_by_talent_at, signed_by_venue_at), payments(id, payment_type, payment_status, gross_amount, paid_at, currency)')
          .eq('venue_id', venueProfile.id)
          .in('booking_status', ['confirmed', 'pending'])
          .order('starts_at', { ascending: true }),

        // 4. Past Bookings
        supabase.from('bookings')
          .select('*, profiles_talent(stage_name, profile_photo_url, talent_stats(rating_average, rating_count))')
          .eq('venue_id', venueProfile.id)
          .eq('booking_status', 'completed')
          .order('starts_at', { ascending: false })
          .limit(10),

        // 5. Notifications
        supabase.from('notifications')
          .select('*')
          .eq('user_id', authUser.id)
          .eq('is_read', false)
          .order('sent_at', { ascending: false })
          .limit(20),

        // 6. Unread Messages
        supabase.from('messages')
          .select('*, bookings!inner(venue_id)')
          .eq('bookings.venue_id', venueProfile.id)
          .eq('is_read', false)
          .neq('sender_id', authUser.id)
      ]);

      setQuoteRequests((quoteRequestsRes.data as unknown as QuoteRequest[]) || []);
      setUpcomingBookings((upcomingBookingsRes.data as unknown as UpcomingBooking[]) || []);
      setPastBookings((pastBookingsRes.data as unknown as PastBooking[]) || []);
      setNotifications((notificationsRes.data as unknown as NotificationItem[]) || []);
      setUnreadNotificationCount(notificationsRes.data?.length || 0);
      setUnreadMessages((messagesRes.data as unknown as MessageItem[]) || []);

      setLoading(false);
    } catch (err) {
      console.error('Dashboard Load Error:', err);
      showToast("Failed to load dashboard data.");
      setLoading(false);
    }
  }, [navigate]);

  useEffect(() => {
    loadDashboardData();
  }, [loadDashboardData]);

  // --- Real-time Subscriptions ---

  useEffect(() => {
    if (!venue) return;

    const messageChannel = supabase.channel('venue-messages')
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'messages' }, (payload) => {
        setUnreadMessages(prev => [...prev, payload.new as MessageItem]);
        if (activeMessageBooking?.id === payload.new.booking_id) {
          setMessages(prev => [...prev, payload.new as MessageItem]);
        }
      })
      .subscribe();

    const bookingChannel = supabase.channel('venue-bookings')
      .on('postgres_changes', { 
        event: 'UPDATE', 
        schema: 'public', 
        table: 'bookings', 
        filter: `venue_id=eq.${venue.id}` 
      }, (payload) => {
        setUpcomingBookings(prev => prev.map(b => b.id === payload.new.id ? { ...b, ...payload.new } : b));
        setPastBookings(prev => prev.map(b => b.id === payload.new.id ? { ...b, ...payload.new } : b));
      })
      .subscribe();

    return () => {
      supabase.removeChannel(messageChannel);
      supabase.removeChannel(bookingChannel);
    };
  }, [venue, activeMessageBooking]);

  // --- Actions ---

  const handleLogout = async (): Promise<void> => {
    try {
      await supabase.auth.signOut();
    } catch (e) {
      console.warn("Sign out failed", e);
    }
    navigate('/venue-portal');
  };

  const handleAcceptQuote = async (quoteId: string, requestId: string): Promise<void> => {
    try {
      const { error: quoteError } = await supabase.from('quotes').update({ quote_status: 'accepted' }).eq('id', quoteId);
      if (quoteError) throw quoteError;

      const { error: requestError } = await supabase.from('quote_requests').update({ status: 'converted' }).eq('id', requestId);
      if (requestError) throw requestError;

      showToast("Quote accepted successfully!");
      loadDashboardData();
    } catch {
      showToast("Failed to accept quote.");
    }
  };

  const handleDeclineQuote = async (quoteId: string): Promise<void> => {
    try {
      const { error } = await supabase.from('quotes').update({ quote_status: 'rejected' }).eq('id', quoteId);
      if (error) throw error;
      showToast("Quote declined.");
      loadDashboardData();
    } catch {
      showToast("Failed to decline quote.");
    }
  };

  // Cancellation moved server-side on 2026-08-31 (Todoist 6hPqRpRPcFP5HQCX).
  // bookings has no UPDATE policy for authenticated any more, and PostgREST
  // returns success on zero RLS matches — so the old client-side update
  // reported "Booking cancelled." while changing nothing at all.
  // Disabled until the cancel-booking Edge Function exists.
  const handleCancelBooking = async (): Promise<void> => {
    showToast("To cancel a booking, please contact support. Self-service cancellation is coming soon.");
  };

  const openMessages = async (booking: UpcomingBooking): Promise<void> => {
    setActiveMessageBooking(booking);
    try {
      const { data: msgData } = await supabase.from('messages')
        .select('*')
        .eq('booking_id', booking.id)
        .order('created_at', { ascending: true });
      
      setMessages((msgData as unknown as MessageItem[]) || []);

      // Mark as read
      const { data: { user } } = await supabase.auth.getUser();
      if (user) {
        await supabase.from('messages')
          .update({ is_read: true, read_at: new Date().toISOString() })
          .eq('booking_id', booking.id)
          .neq('sender_id', user.id);
        
        setUnreadMessages(prev => prev.filter(m => m.booking_id !== booking.id));
      }
    } catch {
      showToast("Failed to load messages.");
    }
  };

  const sendMessage = async (e: React.FormEvent): Promise<void> => {
    e.preventDefault();
    if (!messageContent.trim() || !activeMessageBooking) return;

    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;

      const { data, error } = await supabase.from('messages').insert({
        booking_id: activeMessageBooking.id,
        sender_id: user.id,
        content: messageContent,
        is_read: false
      }).select().single();

      if (error) throw error;
      setMessages(prev => [...prev, data as unknown as MessageItem]);
      setMessageContent('');
      setTimeout(() => messageEndRef.current?.scrollIntoView({ behavior: 'smooth' }), 100);
    } catch {
      showToast("Failed to send message.");
    }
  };

  const markNotificationRead = async (id: string): Promise<void> => {
    try {
      await supabase.from('notifications').update({ is_read: true }).eq('id', id);
      setNotifications(prev => prev.filter(n => n.id !== id));
      setUnreadNotificationCount(prev => Math.max(0, prev - 1));
    } catch (err) {
      console.error(err);
    }
  };

  // --- Calculations ---

  const stats = {
    activeBookings: upcomingBookings.filter(b => ['confirmed', 'pending'].includes(b.booking_status)).length,
    pendingQuotes: quoteRequests.filter(r => r.status === 'open').length + 
                   quoteRequests.flatMap(r => r.quotes || []).filter(q => q.quote_status === 'pending').length,
    unreadMessages: unreadMessages.length,
    nextPerformance: upcomingBookings.find(b => b.booking_status === 'confirmed') 
      ? `${lkDate(upcomingBookings.find(b => b.booking_status === 'confirmed')!.starts_at)} @ ${lkTime(upcomingBookings.find(b => b.booking_status === 'confirmed')!.starts_at)}`
      : "None scheduled"
  };

  const calculateCompleteness = (): number => {
    if (!venue) return 0;
    const fields = [
      'name_of_venue', 'name_of_location', 'size_of_space', 'url_google_maps_pin',
      'address_row_1', 'address_city', 'address_country', 'required_time_slot',
      'performance_days', 'type_of_occasion', 'music_genre_preference',
      'language_preference', 'contact_person', 'contact_email', 'contact_phone',
      'url_venue_photo', 'meals_for_talent', 'audience_age_range'
    ];
    const completed = fields.filter(f => !!venue[f]).length;
    return Math.round((completed / fields.length) * 100);
  };

  const completeness = calculateCompleteness();

  if (loading) {
    return (
      <div className="min-h-screen bg-brand-dark pt-24 px-4 flex flex-col gap-8 animate-pulse" id="venue-dashboard-loading">
        <div className="h-16 bg-white/5 rounded-xl max-w-7xl mx-auto w-full" />
        <div className="grid grid-cols-1 lg:grid-cols-4 gap-8 max-w-7xl mx-auto w-full">
          <div className="lg:col-span-1 space-y-8">
            <div className="h-64 bg-white/5 rounded-xl" />
            <div className="h-48 bg-white/5 rounded-xl" />
          </div>
          <div className="lg:col-span-3 space-y-8">
            <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
              {[1,2,3,4].map(i => <div key={i} className="h-24 bg-white/5 rounded-xl" />)}
            </div>
            <div className="h-96 bg-white/5 rounded-xl" />
          </div>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="min-h-screen bg-brand-dark flex flex-col items-center justify-center p-4 text-center" id="venue-dashboard-error">
        <AlertCircle size={64} className="text-brand-pink mb-4" />
        <h2 className="text-2xl font-black text-white mb-2">{error}</h2>
        <Button onClick={handleLogout} variant="outline" className="mt-4">Logout</Button>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-brand-dark text-gray-300 font-sans selection:bg-brand-pink selection:text-white" id="venue-dashboard">
      
      {/* Header */}
      <header className="fixed top-0 left-0 right-0 z-40 bg-brand-dark/80 backdrop-blur-md border-b border-white/5 h-20">
        <div className="max-w-7xl mx-auto px-4 h-full flex items-center justify-between">
          <div className="flex items-center gap-4 text-left">
            <h1 className="text-xl font-black text-white uppercase tracking-tighter">{venue?.name_of_venue}</h1>
            {venue?.is_verified ? (
              <span className="bg-brand-lime text-brand-dark text-[10px] font-black uppercase tracking-widest px-2 py-0.5 rounded-full">Verified</span>
            ) : (
              <span className="bg-amber-500/20 text-amber-500 text-[10px] font-black uppercase tracking-widest px-2 py-0.5 rounded-full">Pending Verification</span>
            )}
          </div>

          <div className="flex items-center gap-6">
            <div className="relative">
              <button 
                onClick={() => setShowNotifications(!showNotifications)}
                className="relative p-2 text-gray-400 hover:text-white transition-colors"
                id="notification-bell-btn"
              >
                <Bell size={24} />
                {unreadNotificationCount > 0 && (
                  <span className="absolute top-1 right-1 w-4 h-4 bg-brand-pink text-white text-[10px] font-black flex items-center justify-center rounded-full border-2 border-brand-dark">
                    {unreadNotificationCount}
                  </span>
                )}
              </button>

              {showNotifications && (
                <div className="absolute top-full right-0 mt-4 w-80 bg-brand-surface border border-white/10 rounded-xl shadow-2xl overflow-hidden z-50 text-left">
                  <div className="p-4 border-b border-white/5 flex justify-between items-center bg-white/5">
                    <h4 className="text-xs font-black uppercase tracking-widest text-white">Notifications</h4>
                    <button onClick={() => setShowNotifications(false)}><X size={16} /></button>
                  </div>
                  <div className="max-h-96 overflow-y-auto">
                    {notifications.length === 0 ? (
                      <div className="p-8 text-center text-gray-500 text-sm italic">No unread notifications</div>
                    ) : (
                      notifications.map(n => (
                        <div 
                          key={n.id} 
                          onClick={() => markNotificationRead(n.id)}
                          className="p-4 border-b border-white/5 hover:bg-white/5 cursor-pointer transition-colors flex gap-3"
                        >
                          <div className="w-2 h-2 rounded-full bg-brand-pink mt-1.5 flex-shrink-0" />
                          <div>
                            <p className="text-sm text-gray-300 mb-1">{n.message_preview ?? ''}</p>
                            <p className="text-[10px] text-gray-500 uppercase font-bold">{n.sent_at ? lkTime(n.sent_at) : ''}</p>
                          </div>
                        </div>
                      ))
                    )}
                  </div>
                </div>
              )}
            </div>

            <button 
              onClick={handleLogout}
              className="flex items-center gap-2 text-xs font-black uppercase tracking-widest text-gray-400 hover:text-brand-pink transition-colors"
              id="venue-logout-top-btn"
            >
              <LogOut size={18} />
              <span className="hidden sm:inline">Logout</span>
            </button>
          </div>
        </div>
      </header>

      <div className="max-w-7xl mx-auto px-4 pt-32 pb-20">
        <div className="grid grid-cols-1 lg:grid-cols-4 gap-8">
          
          {/* Sidebar */}
          <aside className="lg:col-span-1 space-y-8 text-left">
            
            {/* Profile Completeness */}
            <div className="bg-brand-surface p-6 rounded-2xl border border-white/5">
              <h3 className="text-xs font-black uppercase tracking-widest text-gray-400 mb-6">Profile Completeness</h3>
              <div className="flex flex-col items-center">
                <div className="relative w-32 h-32 mb-6">
                  <svg className="w-full h-full transform -rotate-90">
                    <circle 
                      cx="64" cy="64" r="58" 
                      stroke="currentColor" strokeWidth="8" fill="transparent" 
                      className="text-white/5"
                    />
                    <circle 
                      cx="64" cy="64" r="58" 
                      stroke="currentColor" strokeWidth="8" fill="transparent" 
                      strokeDasharray={364.4}
                      strokeDashoffset={363.4 - (363.4 * completeness) / 100}
                      className="text-brand-lime transition-all duration-1000"
                    />
                  </svg>
                  <div className="absolute inset-0 flex items-center justify-center">
                    <span className="text-2xl font-black text-white">{completeness}%</span>
                  </div>
                </div>
                
                {venue && completeness < 100 ? (
                  <div className="w-full space-y-2">
                    <p className="text-xs text-gray-500 mb-3 italic text-center">Complete these to reach 100%:</p>
                    <div className="max-h-40 overflow-y-auto pr-2 space-y-1">
                      {['name_of_venue', 'name_of_location', 'size_of_space', 'url_google_maps_pin', 'address_row_1', 'address_city', 'address_country', 'required_time_slot', 'performance_days', 'type_of_occasion', 'music_genre_preference', 'language_preference', 'contact_person', 'contact_email', 'contact_phone', 'url_venue_photo', 'meals_for_talent', 'audience_age_range']
                        .filter(f => !venue[f])
                        .map(f => (
                          <button 
                            key={f}
                            onClick={() => navigate('/venue-profile/edit')}
                            className="block w-full text-left text-[10px] uppercase font-bold text-brand-purple hover:text-brand-pink transition-colors truncate"
                          >
                            + Add {f.replace(/_/g, ' ')}
                          </button>
                        ))
                      }
                    </div>
                  </div>
                ) : (
                  <div className="flex items-center gap-2 text-brand-lime font-bold">
                    <CheckCircle size={20} />
                    <span>Profile Complete</span>
                  </div>
                )}
              </div>
            </div>

            {/* Quick Actions */}
            <div className="bg-brand-surface p-6 rounded-2xl border border-white/5">
              <h3 className="text-xs font-black uppercase tracking-widest text-gray-400 mb-6">Quick Actions</h3>
              <div className="grid grid-cols-2 gap-4">
                <button 
                  onClick={() => setShowBookingForm(true)}
                  className="flex flex-col items-center justify-center p-4 bg-white/5 rounded-xl hover:bg-brand-purple/20 hover:border-brand-purple/40 border border-transparent transition-all group"
                >
                  <Zap className="text-brand-purple mb-2 group-hover:scale-110 transition-transform" />
                  <span className="text-[10px] font-black uppercase tracking-widest text-center">Post Event</span>
                </button>
                <button 
                  onClick={() => navigate('/artists')}
                  className="flex flex-col items-center justify-center p-4 bg-white/5 rounded-xl hover:bg-brand-pink/20 hover:border-brand-pink/40 border border-transparent transition-all group"
                >
                  <Users className="text-brand-pink mb-2 group-hover:scale-110 transition-transform" />
                  <span className="text-[10px] font-black uppercase tracking-widest text-center">Browse Talent</span>
                </button>
                <button 
                  onClick={() => {
                    const el = document.getElementById('confirmed-bookings');
                    el?.scrollIntoView({ behavior: 'smooth' });
                  }}
                  className="flex flex-col items-center justify-center p-4 bg-white/5 rounded-xl hover:bg-brand-lime/20 hover:border-brand-lime/40 border border-transparent transition-all group"
                >
                  <FileText className="text-brand-lime mb-2 group-hover:scale-110 transition-transform" />
                  <span className="text-[10px] font-black uppercase tracking-widest text-center">Contracts</span>
                </button>
                <button 
                  onClick={() => showToast("Payment history coming soon.")}
                  className="flex flex-col items-center justify-center p-4 bg-white/5 rounded-xl hover:bg-brand-indigo/20 hover:border-brand-indigo/40 border border-transparent transition-all group"
                >
                  <CreditCard className="text-brand-indigo mb-2 group-hover:scale-110 transition-transform" />
                  <span className="text-[10px] font-black uppercase tracking-widest text-center">Payments</span>
                </button>
              </div>
            </div>
          </aside>

          {/* Main Content */}
          <main className="lg:col-span-3 space-y-12">
            
            {/* Summary Strip */}
            <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
              <StatCard title="Active Bookings" value={stats.activeBookings} icon={Calendar} accentColor="purple" />
              <StatCard title="Pending Quotes" value={stats.pendingQuotes} icon={TrendingUp} accentColor="pink" />
              <StatCard title="Unread Messages" value={stats.unreadMessages} icon={MessageSquare} accentColor="lime" />
              <StatCard title="Next Performance" value={stats.nextPerformance} icon={Clock} accentColor="indigo" />
            </div>

            {/* Section 2: Quote Requests */}
            <section className="text-left">
              <div className="flex flex-col md:flex-row justify-between items-start md:items-end mb-8 gap-6">
                <div>
                  <h2 className="text-3xl font-black text-white uppercase tracking-tighter">Quote Requests & Responses</h2>
                  <p className="text-xs font-black uppercase tracking-widest text-gray-400 mt-1">Talent quotes received against your open event requests</p>
                </div>
                <Button 
                  onClick={() => setShowBookingForm(true)}
                  className="bg-gradient-to-r from-brand-purple to-brand-pink text-white rounded-full font-bold px-6 py-2 flex items-center gap-2"
                >
                  <Zap size={18} /> Post New Request
                </Button>
              </div>

              <div className="space-y-6">
                {quoteRequests.length === 0 ? (
                  <div className="bg-brand-surface p-12 rounded-2xl border border-white/5 text-center" id="no-quote-requests">
                    <TrendingUp size={48} className="text-gray-600 mx-auto mb-4" />
                    <p className="text-gray-500 italic">No quote requests posted yet.</p>
                  </div>
                ) : (
                  quoteRequests.map(req => (
                    <div key={req.id} className="bg-brand-surface rounded-2xl border border-white/5 overflow-hidden hover:border-brand-purple/40 transition-all">
                      <div 
                        className="p-6 cursor-pointer flex flex-col md:flex-row justify-between items-start md:items-center gap-4"
                        onClick={() => setExpandedQuoteRequest(expandedQuoteRequest === req.id ? null : req.id)}
                      >
                        <div className="flex gap-6 items-center">
                          <div className="bg-white/5 p-3 rounded-xl text-brand-purple">
                            <Zap size={24} />
                          </div>
                          <div>
                            <h4 className="text-lg font-black text-white uppercase tracking-tight">{req.event_type}</h4>
                            <div className="flex flex-wrap gap-4 text-xs font-bold text-gray-500 uppercase tracking-widest mt-1">
                              <span className="flex items-center gap-1"><Calendar size={14} /> {lkDate(req.starts_at, { weekday: 'short', day: 'numeric', month: 'short', year: 'numeric' })}</span>
                              <span className="flex items-center gap-1"><Clock size={14} /> {lkTime(req.starts_at)} · {req.duration_hours} hrs</span>
                              <span className="flex items-center gap-1 text-brand-lime"><CreditCard size={14} /> {req.budget_min}–{req.budget_max} LKR</span>
                            </div>
                          </div>
                        </div>
                        <div className="flex items-center gap-4">
                          <StatusBadge status={req.status ?? 'open'} />
                          {expandedQuoteRequest === req.id ? <ChevronUp size={20} /> : <ChevronDown size={20} />}
                        </div>
                      </div>

                      {expandedQuoteRequest === req.id && (
                        <div className="px-6 pb-6 border-t border-white/5 pt-6 bg-white/5">
                          <div className="mb-8">
                            <h5 className="text-[10px] font-black uppercase tracking-widest text-gray-500 mb-2">Special Requirements</h5>
                            <p className="text-sm text-gray-300 leading-relaxed italic">"{req.special_requirements}"</p>
                          </div>

                          <div className="space-y-4">
                            <h5 className="text-[10px] font-black uppercase tracking-widest text-white mb-4">Quotes Received ({req.quotes?.length || 0})</h5>
                            {(!req.quotes || req.quotes.length === 0) ? (
                              <div className="flex items-center gap-3 text-gray-500 italic text-sm">
                                <div className="w-2 h-2 rounded-full bg-brand-purple animate-ping" />
                                Awaiting responses from talent...
                              </div>
                            ) : (
                              req.quotes.map(quote => (
                                <div key={quote.id} className="bg-brand-dark p-6 rounded-xl border border-white/5 flex flex-col md:flex-row justify-between gap-6 hover:border-brand-purple/20 transition-all">
                                  <div className="flex gap-4">
                                    <img 
                                      src={quote.profiles_talent?.profile_photo_url || 'https://picsum.photos/seed/talent/100/100'} 
                                      alt={quote.profiles_talent?.stage_name}
                                      className="w-12 h-12 rounded-full object-cover border-2 border-white/10"
                                    />
                                    <div>
                                      <h6 className="font-black text-white">{quote.profiles_talent?.stage_name}</h6>
                                      <p className="text-[10px] font-bold text-brand-purple uppercase tracking-widest">{quote.profiles_talent?.type_of_performer}</p>
                                      <div className="mt-1">
                                        <TalentRating stats={quote.profiles_talent?.talent_stats} size={10} className="text-[10px] font-black text-brand-lime" />
                                      </div>
                                    </div>
                                  </div>

                                  <div className="flex-grow md:px-8">
                                    <div className="grid grid-cols-3 gap-4 mb-3">
                                      <div>
                                        <p className="text-[8px] uppercase font-black text-gray-500">Quote</p>
                                        <p className="text-xs font-bold text-white">{quote.quoted_amount}</p>
                                      </div>
                                      <div>
                                        <p className="text-[8px] uppercase font-black text-gray-500">Travel</p>
                                        <p className="text-xs font-bold text-white">{quote.travel_fee || 0}</p>
                                      </div>
                                      <div>
                                        <p className="text-[8px] uppercase font-black text-gray-500">Equip</p>
                                        <p className="text-xs font-bold text-white">{quote.equipment_fee || 0}</p>
                                      </div>
                                    </div>
                                    <p className="text-sm italic text-gray-400 border-l-2 border-brand-purple/30 pl-3">"{quote.notes_to_client}"</p>
                                  </div>

                                  <div className="flex flex-col items-end justify-between gap-4">
                                    <div className="text-right">
                                      <p className="text-[10px] font-black uppercase tracking-widest text-gray-500">Total Price</p>
                                      <p className="text-xl font-black text-brand-lime">{quote.total_client_price}</p>
                                    </div>
                                    <div className="flex gap-2">
                                      <StatusBadge status={quote.quote_status} />
                                        {quote.quote_status === 'pending' && (
                                        <>
                                          <Button 
                                            size="sm" 
                                            onClick={() => handleAcceptQuote(quote.id, req.id)}
                                            className="bg-brand-lime text-brand-dark font-black text-[10px] px-3 py-1 rounded-full animate-fade-in"
                                          >
                                            Accept
                                          </Button>
                                          <Button 
                                            size="sm" 
                                            variant="outline"
                                            onClick={() => handleDeclineQuote(quote.id)}
                                            className="border-brand-pink/40 text-brand-pink hover:bg-brand-pink/10 text-[10px] px-3 py-1 rounded-full animate-fade-in"
                                          >
                                            Decline
                                          </Button>
                                        </>
                                      )}
                                    </div>
                                  </div>
                                </div>
                              ))
                            )}
                          </div>
                        </div>
                      )}
                    </div>
                  ))
                )}
              </div>
            </section>

            {/* Section 3: Confirmed Bookings */}
            <section id="confirmed-bookings" className="text-left">
              <div className="mb-8">
                <h2 className="text-3xl font-black text-white uppercase tracking-tighter">Confirmed Bookings</h2>
                <p className="text-xs font-black uppercase tracking-widest text-gray-400 mt-1">Your upcoming performance schedule</p>
              </div>

              <div className="space-y-6">
                {upcomingBookings.length === 0 ? (
                  <div className="bg-brand-surface p-12 rounded-2xl border border-white/5 text-center" id="no-upcoming-bookings">
                    <Calendar size={48} className="text-gray-600 mx-auto mb-4" />
                    <p className="text-gray-500 italic mb-6">No upcoming performances scheduled.</p>
                    <Button onClick={() => setShowBookingForm(true)} variant="primary">Post a Request</Button>
                  </div>
                ) : (
                  upcomingBookings.map(booking => (
                    <div key={booking.id} className="bg-brand-surface rounded-2xl border border-white/5 overflow-hidden hover:border-brand-lime/40 transition-all">
                      <div className="flex flex-col md:flex-row">
                        {/* Left: Date Tile */}
                        <div className="md:w-32 bg-white/5 flex flex-col items-center justify-center p-6 border-r border-white/5 border-l-4 border-l-brand-lime">
                          <span className="text-3xl font-black text-brand-lime leading-none">{lkDate(booking.starts_at, { day: 'numeric' })}</span>
                          <span className="text-xs font-black text-brand-lime uppercase tracking-widest">{lkDate(booking.starts_at, { month: 'short' })}</span>
                          <div className="mt-4 flex flex-col items-center text-[10px] font-bold text-gray-500 uppercase tracking-tighter">
                            <span>{lkTime(booking.starts_at)}</span>
                            <span className="my-0.5">↓</span>
                            <span>{lkTime(booking.ends_at)}</span>
                          </div>
                        </div>

                        {/* Centre: Talent Info */}
                        <div className="flex-grow p-6 flex flex-col md:flex-row justify-between gap-6">
                          <div className="flex gap-6">
                            <div className="relative flex-shrink-0">
                              <img 
                                src={booking.profiles_talent?.profile_photo_url || 'https://picsum.photos/seed/talent/100/100'} 
                                alt={booking.profiles_talent?.stage_name}
                                className="w-14 h-14 rounded-full object-cover border-2 border-white/10"
                              />
                              {booking.profiles_talent?.is_verified && (
                                <div className="absolute -bottom-1 -right-1 bg-brand-lime text-brand-dark rounded-full p-0.5 border-2 border-brand-surface">
                                  <CheckCircle size={10} fill="currentColor" />
                                </div>
                              )}
                            </div>
                            <div>
                              <h4 className="text-xl font-black text-white">{booking.profiles_talent?.stage_name}</h4>
                              <p className="text-xs font-bold text-brand-purple uppercase tracking-widest mb-2">{booking.profiles_talent?.type_of_performer}</p>
                              <TalentRating stats={booking.profiles_talent?.talent_stats} variant="full" size={12} className="text-xs text-brand-lime" />
                              <button 
                                onClick={() => openMessages(booking)}
                                className="mt-4 flex items-center gap-2 text-[10px] font-black uppercase tracking-widest text-brand-pink hover:text-brand-lime transition-colors"
                              >
                                <MessageSquare size={14} /> Message Talent
                              </button>
                            </div>
                          </div>

                          {/* Right: Status & Financials */}
                          <div className="flex flex-col items-end justify-between gap-4">
                            <div className="flex flex-col items-end gap-2 text-right">
                              <StatusBadge status={booking.booking_status} />
                              <div className="text-right">
                                <p className="text-[10px] font-black uppercase tracking-widest text-gray-500">Gross Amount</p>
                                <p className="text-lg font-black text-white">{booking.client_total_amount} {booking.currency}</p>
                              </div>
                            </div>
                            <div className="flex flex-wrap justify-end gap-2">
                              {/* Contract Badge */}
                              {booking.contracts?.status === 'fully_signed' ? (
                                <span className="bg-brand-lime/10 text-brand-lime text-[8px] font-black uppercase tracking-widest px-2 py-1 rounded-md border border-brand-lime/20">Contract Signed</span>
                              ) : booking.contracts?.status === 'sent' ? (
                                <div className="flex flex-col items-end">
                                  <span className="bg-amber-500/10 text-amber-500 text-[8px] font-black uppercase tracking-widest px-2 py-1 rounded-md border border-amber-500/20">Awaiting Signature</span>
                                  <button className="text-[8px] font-bold text-brand-purple underline mt-1">View Contract</button>
                                </div>
                              ) : (
                                <span className="bg-gray-800 text-gray-500 text-[8px] font-black uppercase tracking-widest px-2 py-1 rounded-md">No Contract</span>
                              )}

                              {/* Payment Badge */}
                              {booking.payments?.some(p => p.payment_type === 'deposit' && p.payment_status === 'completed') ? (
                                <span className="bg-brand-lime/10 text-brand-lime text-[8px] font-black uppercase tracking-widest px-2 py-1 rounded-md border border-brand-lime/20 flex items-center gap-1">
                                  Deposit Paid <CheckCircle size={8} fill="currentColor" />
                                </span>
                              ) : (
                                <span className="bg-amber-500/10 text-amber-500 text-[8px] font-black uppercase tracking-widest px-2 py-1 rounded-md border border-amber-500/20">Deposit Pending</span>
                              )}
                            </div>
                          </div>
                        </div>
                      </div>

                      {/* Expandable Panel */}
                      <div 
                        className="bg-white/5 border-t border-white/5 px-6 py-2 flex justify-center cursor-pointer hover:bg-white/10 transition-colors"
                        onClick={() => setExpandedBooking(expandedBooking === booking.id ? null : booking.id)}
                      >
                        {expandedBooking === booking.id ? <ChevronUp size={16} /> : <ChevronDown size={16} />}
                      </div>

                      {expandedBooking === booking.id && (
                        <div className="p-6 bg-brand-dark/50 border-t border-white/5 space-y-6">
                          <div className="grid grid-cols-1 md:grid-cols-2 gap-8 text-left">
                            <div>
                              <h5 className="text-[10px] font-black uppercase tracking-widest text-gray-500 mb-2">Booking Message</h5>
                              <p className="text-sm text-gray-400 italic">"{booking.message_to_talent || 'No message provided.'}"</p>
                            </div>
                              {['confirmed'].includes(booking.booking_status) && (
                              <div>
                                <h5 className="text-[10px] font-black uppercase tracking-widest text-gray-500 mb-2">Talent Contact Details</h5>
                                <div className="space-y-2">
                                  <p className="text-sm text-white flex items-center gap-2"><Zap size={14} className="text-brand-purple" /> {booking.profiles_talent?.mobile}</p>
                                  <p className="text-sm text-white flex items-center gap-2"><MessageSquare size={14} className="text-brand-purple" /> {booking.profiles_talent?.email}</p>
                                </div>
                              </div>
                            )}
                          </div>
                          {['pending', 'confirmed'].includes(booking.booking_status) && (
                            <div className="pt-4 border-t border-white/5 flex justify-end">
                              <button 
                                onClick={() => handleCancelBooking()}
                                className="text-[10px] font-black uppercase tracking-widest text-brand-pink border border-brand-pink/40 px-4 py-2 rounded-full hover:bg-brand-pink/10 transition-all shadow-md"
                              >
                                Cancel Booking
                              </button>
                            </div>
                          )}
                        </div>
                      )}
                    </div>
                  ))
                )}
              </div>
            </section>

            {/* Section 4: Performance History */}
            <section className="text-left">
              <div className="mb-8">
                <h2 className="text-3xl font-black text-white uppercase tracking-tighter">Performance History</h2>
              </div>

              <div className="bg-brand-surface rounded-2xl border border-white/5 overflow-hidden">
                <div className="overflow-x-auto">
                  <table className="w-full text-left border-collapse">
                    <thead>
                      <tr className="bg-white/5 border-b border-white/5">
                        <th className="p-4 text-[10px] font-black uppercase tracking-widest text-gray-500">Date</th>
                        <th className="p-4 text-[10px] font-black uppercase tracking-widest text-gray-500">Talent</th>
                        <th className="p-4 text-[10px] font-black uppercase tracking-widest text-gray-500">Event Type</th>
                        <th className="p-4 text-[10px] font-black uppercase tracking-widest text-gray-500">Amount</th>
                        <th className="p-4 text-[10px] font-black uppercase tracking-widest text-gray-500">Action</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-white/5">
                      {pastBookings.length === 0 ? (
                        <tr>
                         <td colSpan={5} className="p-12 text-center text-gray-500 italic">No past performances recorded.</td>
                        </tr>
                      ) : (
                        pastBookings.map(b => (
                          <tr key={b.id} className="hover:bg-white/5 transition-colors group">
                            <td className="p-4 text-sm font-bold text-white">
                             {lkDate(b.starts_at, { day: 'numeric', month: 'short', year: 'numeric' })}
                            </td>
                            <td className="p-4">
                              <div className="flex items-center gap-3">
                                <img 
                                  src={b.profiles_talent?.profile_photo_url || 'https://picsum.photos/seed/talent/50/50'} 
                                  className="w-8 h-8 rounded-full object-cover border border-white/10"
                                  alt=""
                                />
                                <span className="text-sm font-bold text-white">{b.profiles_talent?.stage_name}</span>
                              </div>
                            </td>
                            <td className="p-4 text-sm text-gray-400">Corporate Event</td>
                            <td className="p-4 text-sm font-black text-brand-lime">{b.client_total_amount} {b.currency}</td>
                            <td className="p-4">
                              <button className="text-[10px] font-black uppercase tracking-widest text-brand-purple hover:text-brand-pink transition-colors">View Details</button>
                            </td>
                          </tr>
                        ))
                      )}
                    </tbody>
                  </table>
                </div>
                
                {/* Pagination */}
                <div className="p-4 bg-white/5 border-t border-white/5 flex justify-between items-center">
                  <p className="text-[10px] font-bold text-gray-500 uppercase tracking-widest">Showing {pastBookings.length} results</p>
                  <div className="flex gap-2">
                    <button 
                      disabled={historyPage === 1}
                      onClick={() => setHistoryPage(p => p - 1)}
                      className="p-2 rounded-lg bg-brand-dark border border-white/5 text-gray-400 hover:text-white disabled:opacity-30 transition-colors"
                    >
                      <ChevronDown className="rotate-90" size={16} />
                    </button>
                    <button 
                      onClick={() => setHistoryPage(p => p + 1)}
                      className="p-2 rounded-lg bg-brand-dark border border-white/5 text-gray-400 hover:text-white transition-colors"
                    >
                      <ChevronDown className="-rotate-90" size={16} />
                    </button>
                  </div>
                </div>
              </div>
            </section>
          </main>
        </div>
      </div>

      {/* Messages Slide-Over */}
      {activeMessageBooking && (
        <div className="fixed inset-0 z-50 overflow-hidden" id="messages-panel">
          <div className="absolute inset-0 bg-black/60 backdrop-blur-sm" onClick={() => setActiveMessageBooking(null)} />
          <div className="absolute top-0 right-0 h-full w-full max-w-md bg-brand-surface border-l border-white/10 shadow-2xl flex flex-col text-left">
            <div className="p-6 border-b border-white/5 flex justify-between items-center bg-white/5">
              <div className="flex items-center gap-4">
                <img 
                  src={activeMessageBooking.profiles_talent?.profile_photo_url || 'https://picsum.photos/seed/talent/100/100'} 
                  className="w-10 h-10 rounded-full object-cover border-2 border-white/10"
                  alt=""
                />
                <div>
                  <h4 className="text-sm font-black text-white uppercase tracking-tight">{activeMessageBooking.profiles_talent?.stage_name}</h4>
                  <p className="text-[10px] font-bold text-gray-500 uppercase tracking-widest">
                   Booking: {lkDate(activeMessageBooking.starts_at)}
                  </p>
                </div>
              </div>
              <button onClick={() => setActiveMessageBooking(null)} className="p-2 text-gray-400 hover:text-white"><X size={24} /></button>
            </div>

            <div className="flex-grow overflow-y-auto p-6 space-y-6">
              {messages.map((msg, idx) => {
                const isMine = msg.sender_id !== activeMessageBooking.profiles_talent?.user_id; // Simple check for sender
                return (
                  <div key={msg.id || idx} className={`flex ${isMine ? 'justify-end' : 'justify-start'}`}>
                    <div className={`flex gap-3 max-w-[80%] ${isMine ? 'flex-row-reverse' : 'flex-row'}`}>
                      {!isMine && (
                        <img 
                          src={activeMessageBooking.profiles_talent?.profile_photo_url || 'https://picsum.photos/seed/talent/50/50'} 
                          className="w-8 h-8 rounded-full object-cover flex-shrink-0"
                          alt=""
                        />
                      )}
                      <div className={`p-4 rounded-2xl text-sm leading-relaxed ${isMine ? 'bg-brand-purple text-white rounded-tr-none' : 'bg-white/5 text-gray-300 rounded-tl-none'}`}>
                        {msg.content}
                        <p className={`text-[8px] mt-2 font-bold uppercase opacity-50 ${isMine ? 'text-right' : 'text-left'}`}>
                         {msg.created_at ? lkTime(msg.created_at) : ''}
                        </p>
                      </div>
                    </div>
                  </div>
                );
              })}
              <div ref={messageEndRef} />
            </div>

            <form onSubmit={sendMessage} className="p-6 border-t border-white/5 bg-white/5">
              <div className="relative">
                <input 
                  type="text" 
                  value={messageContent}
                  onChange={(e) => setMessageContent(e.target.value)}
                  placeholder="Type your message..."
                  className="w-full bg-brand-dark border border-white/10 rounded-full py-4 pl-6 pr-14 text-sm text-white focus:outline-none focus:border-brand-purple transition-colors"
                />
                <button 
                  type="submit"
                  className="absolute right-2 top-2 w-10 h-10 bg-brand-purple text-white rounded-full flex items-center justify-center hover:bg-brand-pink transition-colors"
                >
                  <Send size={18} />
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Toast Notification */}
      {toast && (
        <div className="fixed bottom-8 right-8 z-50 bg-brand-surface border border-white/10 border-l-4 border-l-brand-pink p-4 rounded-lg shadow-2xl animate-fade-in flex items-center gap-3" id="global-toast">
          <AlertCircle size={20} className="text-brand-pink" />
          <p className="text-sm font-bold text-white">{toast}</p>
        </div>
      )}

      {/* Booking Form Modal (Stubbed for "Post New Request") */}
      {showBookingForm && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4" id="post-request-modal">
          <div className="absolute inset-0 bg-black/80 backdrop-blur-sm" onClick={() => setShowBookingForm(false)} />
          <div className="relative bg-brand-surface w-full max-w-xl rounded-2xl border border-white/10 shadow-2xl overflow-hidden text-center">
             <div className="p-6 border-b border-white/5 flex justify-between items-center text-left">
                <h3 className="text-xl font-black text-white uppercase tracking-tighter">Post New Event Request</h3>
                <button onClick={() => setShowBookingForm(false)}><X size={24} /></button>
             </div>
             <div className="p-8 space-y-6">
                <div className="w-20 h-20 bg-brand-purple/20 rounded-full flex items-center justify-center mx-auto">
                  <Zap size={40} className="text-brand-purple" />
                </div>
                <p className="text-gray-400 leading-relaxed">
                  Post your event requirements to attract the best talent. Our system will notify matching artists who can then send you quotes.
                </p>
                <div className="grid grid-cols-1 gap-4">
                  <Button onClick={() => { setShowBookingForm(false); showToast("Request posted successfully!"); }} variant="primary" className="w-full py-4">Confirm & Post Request</Button>
                  <Button onClick={() => setShowBookingForm(false)} variant="outline" className="w-full py-4">Cancel</Button>
                </div>
             </div>
          </div>
        </div>
      )}

      <style>{`
        @keyframes fade-in {
          from { opacity: 0; transform: translateY(10px); }
          to { opacity: 1; transform: translateY(0); }
        }
        .animate-fade-in {
          animation: fade-in 0.3s ease-out forwards;
        }
      `}</style>
    </div>
  );
};
