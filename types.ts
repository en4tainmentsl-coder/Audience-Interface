export interface Artist {
  id: string;
  name: string;
  category: string;
  imageUrl: string;
  rating: number;
  description: string;
  bio: string;
  gallery: string[];
}

export interface Performance {
  id: string;
  artistId: string;
  artistName: string;
  date: string;
  venue: string;
  imageUrl: string;
  videoUrl?: string;
}

export type BookingStatus = 'pending' | 'assigned' | 'contacted' | 'completed' | 'cancelled';

export interface Booking {
  id: string;
  createdAt: string;
  name: string;
  email: string;
  phone: string;
  date: string;
  time: string;
  location: string;
  artistId: string;
  notes: string;
  status: BookingStatus;
  aiInsight?: string;
}

export interface QuoteRequest {
  name: string;
  email: string;
  phone: string;
  date: string;
  time: string;
  location: string;
  artistId?: string;
  notes?: string;
}