import React, { useState, useEffect } from 'react';
import { supabase } from '../services/supabase';
import { Shield, Eye, Trash2, BrainCircuit, Filter, RefreshCw, Send, AlertCircle } from 'lucide-react';
import type { Database } from '../database.types';

type QuoteRequestStatus = Database['public']['Enums']['quotation_request_status'];

interface AdminQuoteRequest {
  id: string;
  status: QuoteRequestStatus;
  starts_at: string;
  ends_at: string;
  special_requirements?: string;
  ai_insight?: string;
  profiles_clients?: {
    full_name: string;
    email: string;
  };
  profiles_talent?: {
    stage_name: string;
  };
}

export const Admin: React.FC = () => {
  const [bookings, setBookings] = useState<AdminQuoteRequest[]>([]);
  const [selectedBooking, setSelectedBooking] = useState<AdminQuoteRequest | null>(null);
  const [filter, setFilter] = useState<string>('all');
  const [loading, setLoading] = useState<boolean>(true);
  const [error, setError] = useState<string | null>(null);

  const loadBookings = async (): Promise<void> => {
    setLoading(true);
    try {
      // Fetch from quote_requests joining with profiles_clients and profiles_talent
      const { data, error: fetchError } = await supabase
        .from('quote_requests')
        .select(`
          id,
          status,
          event_date,
          special_requirements,
          ai_insight,
          profiles_clients (full_name, email),
          profiles_talent (stage_name)
        `)
        .order('created_at', { ascending: false });

      if (fetchError) throw fetchError;
      
      // Explicitly type the result or cast safely avoiding any
      const typedData = (data as unknown) as AdminQuoteRequest[];
      setBookings(typedData || []);
    } catch (err) {
      console.error('Admin Fetch Error:', err);
      setError('Failed to load quote requests.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadBookings();
  }, []);

  const handleStatusChange = async (id: string, status: AdminQuoteRequest['status']): Promise<void> => {
    try {
      const { error: updateError } = await supabase
        .from('quote_requests')
        .update({ status })
        .eq('id', id);

      if (updateError) throw updateError;
      
      loadBookings();
      if (selectedBooking?.id === id) {
        setSelectedBooking(prev => prev ? { ...prev, status } : null);
      }
    } catch (err) {
      console.error('Status Update Error:', err);
      alert('Failed to update status.');
    }
  };

  const handleDelete = async (id: string): Promise<void> => {
    if (window.confirm("Delete this quote request permanently?")) {
      try {
        const { error: deleteError } = await supabase
          .from('quote_requests')
          .delete()
          .eq('id', id);

        if (deleteError) throw deleteError;
        
        loadBookings();
        setSelectedBooking(null);
      } catch (err) {
        console.error('Delete Error:', err);
        alert('Failed to delete request.');
      }
    }
  };

  const filteredBookings: AdminQuoteRequest[] = bookings.filter(b => filter === 'all' || b.status === filter);

  // Keyed by Record<QuoteRequestStatus, string> so a new enum value added in a
  // migration becomes a compile error here rather than an undefined class name.
  const statusColors: Record<QuoteRequestStatus, string> = {
    open:      'bg-brand-pink/20 text-brand-pink',
    matched:   'bg-brand-purple/20 text-brand-purple',
    converted: 'bg-brand-lime/20 text-brand-lime',
    declined:  'bg-gray-500/20 text-gray-400',
    cancelled: 'bg-gray-500/20 text-gray-400',
    expired:   'bg-red-500/20 text-red-400',
  };

  return (
    <div className="pt-32 pb-20 min-h-screen bg-brand-dark" id="admin-page">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        
        <div className="flex flex-col md:flex-row justify-between items-center mb-10 gap-6">
          <div className="flex items-center gap-4">
            <div className="w-12 h-12 bg-brand-purple/20 rounded-xl flex items-center justify-center text-brand-purple">
              <Shield size={28} />
            </div>
            <div>
              <h1 className="text-3xl font-black text-white uppercase tracking-tighter">Booking Dashboard</h1>
              <p className="text-gray-400 text-sm">Internal Talent Management System</p>
            </div>
          </div>

          <div className="flex items-center gap-4">
            <div className="flex items-center gap-2 bg-brand-surface border border-white/5 rounded-full px-4 py-2">
              <Filter size={16} className="text-gray-500" />
              <select 
                value={filter} 
                onChange={(e: React.ChangeEvent<HTMLSelectElement>) => setFilter(e.target.value)}
                className="bg-transparent text-sm text-gray-300 outline-none cursor-pointer"
              >
                <option value="all">All Statuses</option>
                <option value="open">Open</option>
                <option value="quoted">Quoted</option>
                <option value="accepted">Accepted</option>
                <option value="rejected">Rejected</option>
              </select>
            </div>
            <button onClick={loadBookings} className="p-2 text-gray-400 hover:text-white transition-colors" id="btn-refresh-bookings">
              <RefreshCw size={20} />
            </button>
          </div>
        </div>

        {error && (
          <div className="mb-6 p-4 bg-red-500/10 border border-red-500/20 rounded-xl flex items-center gap-3 text-red-500" id="admin-error">
            <AlertCircle size={20} />
            <p>{error}</p>
          </div>
        )}

        <div className="grid grid-cols-1 xl:grid-cols-3 gap-8">
          
          {/* List Section */}
          <div className="xl:col-span-2 space-y-4">
            {loading ? (
              <div className="flex justify-center py-20" id="admin-loading">
                <div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-brand-purple"></div>
              </div>
            ) : filteredBookings.length > 0 ? (
              <div className="bg-brand-surface border border-white/5 rounded-2xl overflow-hidden" id="bookings-table-container">
                <table className="w-full text-left">
                  <thead>
                    <tr className="border-b border-white/5 bg-white/5">
                      <th className="px-6 py-4 text-xs font-black text-gray-400 uppercase tracking-widest">Client</th>
                      <th className="px-6 py-4 text-xs font-black text-gray-400 uppercase tracking-widest">Event Date</th>
                      <th className="px-6 py-4 text-xs font-black text-gray-400 uppercase tracking-widest">Talent</th>
                      <th className="px-6 py-4 text-xs font-black text-gray-400 uppercase tracking-widest">Status</th>
                      <th className="px-6 py-4 text-xs font-black text-gray-400 uppercase tracking-widest text-right">Actions</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-white/5">
                    {filteredBookings.map((booking: AdminQuoteRequest) => (
                      <tr key={booking.id} className={`hover:bg-white/5 transition-colors cursor-pointer ${selectedBooking?.id === booking.id ? 'bg-brand-purple/10' : ''}`} onClick={() => setSelectedBooking(booking)} id={`row-${booking.id}`}>
                        <td className="px-6 py-4">
                          <div className="text-white font-bold">{booking.profiles_clients?.full_name || 'Anonymous'}</div>
                          <div className="text-gray-500 text-xs">{booking.profiles_clients?.email}</div>
                        </td>
                        <td className="px-6 py-4 text-sm text-gray-300">
                          {new Date(booking.starts_at).toLocaleDateString('en-GB', { timeZone: 'Asia/Colombo' })}
                        </td>
                        <td className="px-6 py-4">
                          <span className="text-xs font-bold text-brand-lime uppercase">
                            {booking.profiles_talent?.stage_name || 'Not Assigned'}
                          </span>
                        </td>
                        <td className="px-6 py-4">
                          <span className={`text-[10px] font-black uppercase px-2 py-1 rounded-full ${statusColors[booking.status]}`}>
                            {booking.status}
                          </span>
                        </td>
                        <td className="px-6 py-4 text-right">
                          <div className="flex justify-end gap-2">
                            <button className="p-2 text-gray-500 hover:text-white" id={`view-btn-${booking.id}`}><Eye size={16} /></button>
                            <button 
                              onClick={(e: React.MouseEvent<HTMLButtonElement>) => { e.stopPropagation(); handleDelete(booking.id); }}
                              className="p-2 text-gray-500 hover:text-brand-pink"
                              id={`delete-btn-${booking.id}`}
                            >
                              <Trash2 size={16} />
                            </button>
                          </div>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            ) : (
              <div className="bg-brand-surface border border-dashed border-white/10 rounded-2xl py-20 text-center" id="no-bookings">
                <p className="text-gray-500">No bookings found for the selected filter.</p>
              </div>
            )}
          </div>

          {/* Detail/Routing Section */}
          <div className="xl:col-span-1">
            {selectedBooking ? (
              <div className="bg-brand-surface border border-white/10 rounded-2xl p-8 sticky top-32 animate-in slide-in-from-right-4 duration-300 shadow-2xl" id="admin-detail-panel">
                <div className="flex justify-between items-start mb-6">
                  <h2 className="text-xl font-black text-white uppercase italic">Booking Details</h2>
                  <button onClick={() => setSelectedBooking(null)} className="text-gray-500 hover:text-white" id="close-detail-btn">
                    <Trash2 size={20} />
                  </button>
                </div>

                <div className="space-y-6">
                  <div>
                    <label className="text-[10px] font-black text-brand-lime uppercase tracking-widest mb-1 block">Special Requirements</label>
                    <p className="text-gray-300 text-sm italic bg-brand-dark/50 p-4 rounded-xl border border-white/5">
                      "{selectedBooking.special_requirements || "No notes provided."}"
                    </p>
                  </div>

                  {/* AI Routing Analysis */}
                  <div className="bg-gradient-to-br from-brand-indigo/20 to-brand-purple/20 p-5 rounded-2xl border border-brand-purple/30">
                    <div className="flex items-center gap-2 mb-3">
                      <BrainCircuit size={18} className="text-brand-purple" />
                      <span className="text-xs font-black text-brand-purple uppercase tracking-widest">AI Routing Suggestion</span>
                    </div>
                    <p className="text-white text-sm leading-relaxed mb-4">
                      {selectedBooking.ai_insight || "AI analysis pending..."}
                    </p>
                    <div className="flex gap-2">
                       <button 
                        onClick={() => handleStatusChange(selectedBooking.id, 'matched')}
                        className="flex-grow bg-brand-purple text-white text-[10px] font-black uppercase py-2 rounded-lg hover:bg-brand-indigo transition-colors flex items-center justify-center gap-2"
                        id="mark-quoted-btn"
                       >
                         <Send size={12} /> Mark as Matched
                       </button>
                    </div>
                  </div>

                  <div className="grid grid-cols-2 gap-4">
                    <div>
                      <label className="text-[10px] font-black text-gray-500 uppercase tracking-widest block mb-1">Status</label>
                      <select 
                        value={selectedBooking.status}
                        onChange={(e: React.ChangeEvent<HTMLSelectElement>) => handleStatusChange(selectedBooking.id, e.target.value as AdminQuoteRequest['status'])}
                        className="w-full bg-brand-dark border border-white/10 rounded-lg p-2 text-xs text-white outline-none"
                      >
                        <option value="open">Open</option>
                        <option value="quoted">Quoted</option>
                        <option value="accepted">Accepted</option>
                        <option value="rejected">Rejected</option>
                        <option value="expired">Expired</option>
                      </select>
                    </div>
                    <div>
                       <label className="text-[10px] font-black text-gray-500 uppercase tracking-widest block mb-1">Assigned To</label>
                       <div className="bg-brand-dark border border-white/10 rounded-lg p-2 text-xs text-brand-lime font-bold">
                         {selectedBooking.profiles_talent?.stage_name || 'Not Assigned'}
                       </div>
                    </div>
                  </div>

                  <div className="pt-6 border-t border-white/5">
                    <button className="w-full py-3 bg-white/5 hover:bg-white/10 text-white text-sm font-bold rounded-xl transition-all">
                      Email Client Directly
                    </button>
                  </div>
                </div>
              </div>
            ) : (
              <div className="bg-brand-surface border border-dashed border-white/10 rounded-2xl h-full flex flex-col items-center justify-center p-12 text-center opacity-50" id="insight-panel-placeholder">
                <Shield size={48} className="text-gray-600 mb-4" />
                <h3 className="text-lg font-bold text-gray-500 mb-2">Manager Insight Panel</h3>
                <p className="text-gray-600 text-sm">Select a booking to view AI analysis and manage redirection.</p>
              </div>
            )}
          </div>

        </div>
      </div>
    </div>
  );
};
