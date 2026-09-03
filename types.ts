/** A talent_stats row as PostgREST returns it.
 *  rating_average is a STRING because Postgres numeric serialises as one. */
export interface TalentStatsRow {
  rating_average: string | number | null;
  rating_count: number | string | null;
}

/** PostgREST may embed this as an object or an array, and an unrated talent
 *  has no talent_stats row at all — so null and undefined are valid states. */
export type RawTalentStats = TalentStatsRow | TalentStatsRow[] | null | undefined;

export interface Artist {
  id: string;
  name: string;
  category: string;
  imageUrl: string;
  stats: RawTalentStats;
  description: string;
  bio: string;
  gallery: string[];
  is_featured?: boolean;
}

export interface Quote {
  id: string;
  talent_id: string;
  quoted_amount: number;
  total_client_price: number;
  quote_status: string;
  expires_at?: string;
  notes_to_client?: string;
  travel_fee?: number;
  equipment_fee?: number;
  profiles_talent?: {
    stage_name: string;
    profile_photo_url: string;
    talent_stats?: RawTalentStats;
    type_of_performer: string;
  };
}

export interface QuoteRequest {
  id: string;
  venue_id: string;
  event_type: string;
  starts_at: string;
  ends_at: string;
  duration_hours: number;
  budget_min: number;
  budget_max: number;
  status: string;
  special_requirements?: string;
  quotes?: Quote[];
}

export interface Contract {
  id: string;
  status: string;
  signed_by_talent_at?: string;
  signed_by_venue_at?: string;
}

export interface Payment {
  id: string;
  payment_type: string;
  payment_status: string;
  gross_amount: number;
  paid_at?: string;
  currency: string;
}

export interface Booking {
  id: string;
  venue_id: string;
  starts_at: string;
  ends_at: string;
  booking_status: string;
  agreed_gross_amount: number;
  currency: string;
  message_to_talent?: string;
  profiles_talent?: {
    stage_name: string;
    profile_photo_url: string;
    rating: number;
    type_of_performer: string;
    is_verified?: boolean;
    mobile?: string;
    email?: string;
  };
  contracts?: Contract;
  payments?: Payment[];
  reviews_star?: {
    rating: number;
    comment?: string;
    created_at: string;
  }[];
}

export interface Message {
  id: string;
  booking_id: string;
  sender_id: string;
  content: string;
  is_read: boolean;
  read_at?: string;
  created_at: string;
  bookings?: {
    venue_id: string;
  };
}

export interface VenueProfile {
  id: string;
  user_id: string;
  name_of_venue: string;
  is_verified: boolean;
  name_of_location?: string;
  size_of_space?: string;
  url_google_maps_pin?: string;
  address_row_1?: string;
  address_city?: string;
  address_country?: string;
  required_time_slot?: string;
  performance_days?: string[];
  type_of_occasion?: string;
  music_genre_preference?: string[];
  language_preference?: string;
  contact_person?: string;
  contact_email?: string;
  contact_phone?: string;
  url_venue_photo?: string;
  meals_for_talent?: boolean;
  audience_age_range?: string;
}
