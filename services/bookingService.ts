
import { Booking, BookingStatus } from '../types';
import { ARTISTS } from '../constants';
import { GoogleGenAI } from '@google/genai';

const STORAGE_KEY = 'en4tainment_bookings';

export const bookingService = {
  getAll: (): Booking[] => {
    const data = localStorage.getItem(STORAGE_KEY);
    return data ? JSON.parse(data) : [];
  },

  save: async (request: any): Promise<Booking> => {
    const bookings = bookingService.getAll();
    
    // Generate AI Insight for routing
    let aiInsight = "Analyzing request...";
    try {
      // Fix: Create GoogleGenAI instance right before making an API call
      const ai = new GoogleGenAI({ apiKey: process.env.API_KEY });
      const artistContext = ARTISTS.map(a => `${a.name} (${a.category})`).join(', ');
      const response = await ai.models.generateContent({
        model: 'gemini-3-flash-preview',
        contents: `A client named ${request.name} wants to book an artist for ${request.location} on ${request.date}. 
        Notes: "${request.notes}". 
        Our artists are: ${artistContext}. 
        Which artist or category should we redirect this to? Give a 1-sentence professional recommendation.`,
      });
      // Fix: Access the text property directly from GenerateContentResponse
      aiInsight = response.text || "No specific recommendation.";
    } catch (e) {
      aiInsight = "AI analysis currently unavailable.";
    }

    const newBooking: Booking = {
      ...request,
      id: Math.random().toString(36).substr(2, 9),
      createdAt: new Date().toISOString(),
      status: 'pending',
      aiInsight
    };

    bookings.push(newBooking);
    localStorage.setItem(STORAGE_KEY, JSON.stringify(bookings));
    return newBooking;
  },

  updateStatus: (id: string, status: BookingStatus) => {
    const bookings = bookingService.getAll();
    const index = bookings.findIndex(b => b.id === id);
    if (index !== -1) {
      bookings[index].status = status;
      localStorage.setItem(STORAGE_KEY, JSON.stringify(bookings));
    }
  },

  delete: (id: string) => {
    const bookings = bookingService.getAll().filter(b => b.id !== id);
    localStorage.setItem(STORAGE_KEY, JSON.stringify(bookings));
  }
};
