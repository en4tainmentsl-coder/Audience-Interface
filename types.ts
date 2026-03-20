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

export interface Venue {
  id: string;
  name: string;
  registeredName: string;
  brNumber: string;
  brPhotoUrl: string;
  locationLat: number;
  locationLng: number;
  registeredAddress: string;
  locationAddress: string;
  registeredPhone: string;
  mobileNumber: string;
  username: string;
  status: 'pending' | 'approved' | 'rejected';
  createdAt: string;
}

export interface RecurringBooking {
  id: string;
  venueId: string;
  areaName: string;
  venueSize: number;
  timeSlot: string;
  performanceDays: string;
  mealsProvided: boolean;
  occasionType: string;
  primaryLanguage: string;
  status: 'pending' | 'quoted' | 'confirmed';
  createdAt: string;
}

export interface Review {
  id: string;
  artistId: string;
  userId: string;
  userName: string;
  rating: number;
  Rating_1_to_5: number;
  ReviewerUserUUID: string;
  comment: string;
  createdAt: string;
}

export interface Heart {
  id: string;
  venueId: string;
  artistId: string;
  createdAt: string;
}

export interface Database {
  public: {
    Tables: {
      venues: {
        Row: {
          id: string;
          name: string;
          registered_name: string;
          br_number: string;
          br_photo_url: string;
          location_lat: number;
          location_lng: number;
          registered_address: string;
          location_address: string;
          registered_phone: string;
          mobile_number: string;
          username: string;
          status: 'pending' | 'approved' | 'rejected';
          created_at: string;
        };
        Insert: {
          id?: string;
          name: string;
          registered_name: string;
          br_number: string;
          br_photo_url: string;
          location_lat: number;
          location_lng: number;
          registered_address: string;
          location_address: string;
          registered_phone: string;
          mobile_number: string;
          username: string;
          status?: 'pending' | 'approved' | 'rejected';
          created_at?: string;
        };
        Update: {
          id?: string;
          name?: string;
          registered_name?: string;
          br_number?: string;
          br_photo_url?: string;
          location_lat?: number;
          location_lng?: number;
          registered_address?: string;
          location_address?: string;
          registered_phone?: string;
          mobile_number?: string;
          username?: string;
          status?: 'pending' | 'approved' | 'rejected';
          created_at?: string;
        };
      };
      recurring_bookings: {
        Row: {
          id: string;
          venue_id: string;
          area_name: string;
          venue_size: number;
          time_slot: string;
          performance_days: string;
          meals_provided: boolean;
          occasion_type: string;
          primary_language: string;
          status: 'pending' | 'quoted' | 'confirmed';
          created_at: string;
        };
        Insert: {
          id?: string;
          venue_id: string;
          area_name: string;
          venue_size: number;
          time_slot: string;
          performance_days: string;
          meals_provided: boolean;
          occasion_type: string;
          primary_language: string;
          status?: 'pending' | 'quoted' | 'confirmed';
          created_at?: string;
        };
        Update: {
          id?: string;
          venue_id?: string;
          area_name?: string;
          venue_size?: number;
          time_slot?: string;
          performance_days?: string;
          meals_provided?: boolean;
          occasion_type?: string;
          primary_language?: string;
          status?: 'pending' | 'quoted' | 'confirmed';
          created_at?: string;
        };
      };
      reviews: {
        Row: {
          id: string;
          artist_id: string;
          user_id: string;
          user_name: string;
          rating: number;
          Rating_1_to_5: number;
          ReviewerUserUUID: string;
          comment: string;
          created_at: string;
        };
        Insert: {
          id?: string;
          artist_id: string;
          user_id: string;
          user_name: string;
          rating: number;
          Rating_1_to_5: number;
          ReviewerUserUUID: string;
          comment: string;
          created_at?: string;
        };
        Update: {
          id?: string;
          artist_id?: string;
          user_id?: string;
          user_name?: string;
          rating?: number;
          Rating_1_to_5?: number;
          ReviewerUserUUID?: string;
          comment?: string;
          created_at?: string;
        };
      };
      Reviews_5_Star: {
        Row: {
          id: string;
          artist_id: string;
          ReviewerUserUUID: string;
          OverallRating: number;
          created_at: string;
        };
        Insert: {
          id?: string;
          artist_id: string;
          ReviewerUserUUID: string;
          OverallRating: number;
          created_at?: string;
        };
        Update: {
          id?: string;
          artist_id?: string;
          ReviewerUserUUID?: string;
          OverallRating?: number;
          created_at?: string;
        };
      };
      hearts: {
        Row: {
          id: string;
          venue_id: string;
          artist_id: string;
          created_at: string;
        };
        Insert: {
          id?: string;
          venue_id: string;
          artist_id: string;
          created_at?: string;
        };
        Update: {
          id?: string;
          venue_id?: string;
          artist_id?: string;
          created_at?: string;
        };
      };
      artists: {
        Row: Artist;
        Insert: Omit<Artist, 'id'>;
        Update: Partial<Artist>;
      };
    };
  };
}

