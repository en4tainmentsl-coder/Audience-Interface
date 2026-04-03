
import { supabase } from './supabase';
import { ARTISTS } from '../constants';
import { GoogleGenAI } from '@google/genai';

export const bookingService = {
  getAll: async () => {
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return [];

      const { data, error } = await supabase
        .from('quote_requests')
        .select(`
          *,
          profiles_venues (name_of_venue, name_of_location)
        `)
        .eq('client_user_id', user.id)
        .order('event_date', { ascending: false });

      if (error) throw error;
      return data || [];
    } catch (error) {
      console.error('Error fetching bookings:', error);
      return [];
    }
  },

  save: async (formData) => {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) throw new Error("User must be logged in to request a quote.");

    // Generate AI Insight for routing
    let aiInsight = "Analyzing request...";
    try {
      const ai = new GoogleGenAI({ apiKey: process.env.API_KEY });
      const artistContext = ARTISTS.map(a => `${a.name} (${a.category})`).join(', ');
      const response = await ai.models.generateContent({
        model: 'gemini-2.0-flash',
        contents: `A client wants to book an artist for ${formData.location} on ${formData.date}. 
        Notes: "${formData.notes}". 
        Our artists are: ${artistContext}. 
        Which artist or category should we redirect this to? Give a 1-sentence professional recommendation.`,
      });
      aiInsight = response.text || "No specific recommendation.";
    } catch (e) {
      aiInsight = "AI analysis currently unavailable.";
    }

    const { data, error } = await supabase.from('quote_requests').insert({
      client_user_id: user.id,
      venue_id: formData.venueId || null,
      reviewee_talent_id: formData.artistId || null,
      event_type: formData.eventType || 'general',
      event_date: formData.date,
      start_time: formData.time,
      duration_hours: 2,
      location: formData.location,
      budget_min: 0,
      budget_max: null,
      special_requirements: formData.notes || '',
      ai_insight: aiInsight,
      status: 'open'
    }).select().single();

    if (error) throw error;
    return data;
  },

  updateStatus: async (id, status) => {
    const { error } = await supabase
      .from('quote_requests')
      .update({ status })
      .eq('id', id);
    if (error) throw error;
  },

  delete: async (id) => {
    const { error } = await supabase
      .from('quote_requests')
      .delete()
      .eq('id', id);
    if (error) throw error;
  }
};
