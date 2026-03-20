
import React, { useEffect, useState } from 'react';
import { useParams, Link } from 'react-router-dom';
import { ARTISTS as STATIC_ARTISTS } from '../constants';
import { Artist, Review } from '../types';
import { Button } from '../components/Button';
import { StarRating } from '../components/StarRating';
import { PlayCircle, Heart, LogIn, MessageSquare } from 'lucide-react';
import { supabase } from '../services/supabase';

export const ArtistDetail: React.FC = () => {
  const { id } = useParams<{ id: string }>();
  const [artist, setArtist] = useState<Artist | null>(null);
  const [reviews, setReviews] = useState<Review[]>([]);
  const [isHearted, setIsHearted] = useState(false);
  const [user, setUser] = useState<any>(null);
  const venueUser = JSON.parse(localStorage.getItem('venue_user') || 'null');

  useEffect(() => {
    const storedUser = localStorage.getItem('general_user');
    if (storedUser) setUser(JSON.parse(storedUser));
    
    fetchArtistData();
  }, [id]);

  const fetchArtistData = async () => {
    // Try to fetch from Supabase first
    const { data: supabaseArtist } = await supabase
      .from('artists')
      .select('*')
      .eq('id', id)
      .single();

    if (supabaseArtist) {
      setArtist(supabaseArtist);
    } else {
      const found = STATIC_ARTISTS.find(a => a.id === id);
      setArtist(found || null);
    }

    // Fetch Reviews
    const { data: reviewsData } = await supabase
      .from('reviews')
      .select('*')
      .eq('artist_id', id)
      .order('created_at', { ascending: false });
    
    if (reviewsData) setReviews(reviewsData);

    // Check Heart if venue
    if (venueUser) {
      const { data: heartData } = await supabase
        .from('hearts')
        .select('*')
        .eq('venue_id', venueUser.id)
        .eq('artist_id', id)
        .single();
      if (heartData) setIsHearted(true);
    }
  };

  const handleHeart = async () => {
    if (!venueUser) return;
    if (isHearted) {
      await supabase.from('hearts').delete().eq('venue_id', venueUser.id).eq('artist_id', id);
      setIsHearted(false);
    } else {
      await supabase.from('hearts').insert({ venue_id: venueUser.id, artist_id: id } as any);
      setIsHearted(true);
    }
  };

  const handleGoogleLogin = () => {
    const mockUser = { id: 'user_' + Math.random().toString(36).substr(2, 9), name: 'Guest User', email: 'guest@example.com' };
    localStorage.setItem('general_user', JSON.stringify(mockUser));
    setUser(mockUser);
  };

  const handleAddReview = async (rating: number) => {
    // Check if user is an organiser (venue user)
    if (!venueUser) {
      alert('Only organisers (Venue accounts) are permitted to submit star ratings. Please login as a Venue to rate artists.');
      return;
    }

    // Validate rating value (1-5)
    if (rating < 1 || rating > 5) {
      alert('Rating must be between 1 and 5 stars.');
      return;
    }

    const comment = prompt('Enter your review:');
    if (!comment) return;

    try {
      // 1. Insert into reviews table
      const { error: reviewError } = await supabase.from('reviews').insert({
        artist_id: id,
        user_id: venueUser.id,
        user_name: venueUser.name,
        rating: rating, // keeping legacy column for compatibility if needed
        Rating_1_to_5: rating,
        ReviewerUserUUID: venueUser.id,
        comment: comment
      } as any);

      if (reviewError) throw reviewError;

      // 2. Insert into Reviews_5_Star table
      const { error: starError } = await supabase.from('Reviews_5_Star').insert({
        artist_id: id,
        ReviewerUserUUID: venueUser.id,
        OverallRating: rating
      } as any);

      if (starError) throw starError;

      alert('Rating submitted successfully! Ratings are final and cannot be edited or deleted.');
      fetchArtistData();
    } catch (err: any) {
      console.error('Error submitting rating:', err);
      alert('Failed to submit rating. Please try again.');
    }
  };

  if (!artist) return <div className="pt-32 text-center text-white">Artist not found</div>;

  return (
    <div className="pt-20 min-h-screen bg-brand-dark text-white">
      
      <div className="relative h-[50vh] w-full">
        <img 
          src={artist.imageUrl} 
          alt={artist.name} 
          className="w-full h-full object-cover object-top opacity-60"
        />
        <div className="absolute inset-0 bg-gradient-to-t from-brand-dark via-brand-dark/50 to-transparent" />
        <div className="absolute bottom-0 left-0 w-full p-8 md:p-12 max-w-7xl mx-auto">
          <div className="flex items-center gap-4 mb-4">
            <span className="bg-brand-lime text-brand-dark font-bold px-3 py-1 rounded">
              {artist.category}
            </span>
            {venueUser && (
              <button 
                onClick={handleHeart}
                className={`p-2 rounded-full backdrop-blur-md transition-all ${
                  isHearted ? 'bg-brand-pink text-white' : 'bg-white/10 text-white hover:bg-brand-pink/50'
                }`}
              >
                <Heart className={`w-6 h-6 ${isHearted ? 'fill-current' : ''}`} />
              </button>
            )}
          </div>
          <h1 className="text-5xl md:text-7xl font-bold mb-2">{artist.name}</h1>
          <div className="flex items-center gap-4 mb-6">
            <StarRating initialRating={artist.rating} readonly size={24} />
            <span className="text-xl font-semibold text-brand-purple">{artist.rating}/5.0</span>
          </div>
          <Link to={`/request-quote?artistId=${artist.id}`}>
            <Button size="lg" variant="primary">Request Quotation</Button>
          </Link>
        </div>
      </div>

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-16 grid grid-cols-1 lg:grid-cols-3 gap-12">
        
        <div className="lg:col-span-2">
          <section className="mb-12">
            <h2 className="text-2xl font-bold mb-6 border-l-4 border-brand-pink pl-4">About the Artist</h2>
            <p className="text-gray-300 leading-loose text-lg">
              {artist.bio}
            </p>
          </section>

          <section className="mb-12">
            <h2 className="text-2xl font-bold mb-6 border-l-4 border-brand-lime pl-4">Gallery & Performances</h2>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              {artist.gallery.map((img, idx) => (
                <div key={idx} className="relative group rounded-lg overflow-hidden h-64 bg-gray-900">
                  <img src={img} alt="Gallery" className="w-full h-full object-cover group-hover:opacity-75 transition-opacity" />
                  <div className="absolute inset-0 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity">
                    <PlayCircle className="text-white w-12 h-12 drop-shadow-lg" />
                  </div>
                </div>
              ))}
            </div>
          </section>

          <section>
            <h2 className="text-2xl font-bold mb-6 border-l-4 border-brand-purple pl-4">Reviews</h2>
            <div className="space-y-6">
              {reviews.length === 0 ? (
                <p className="text-gray-500 italic">No reviews yet. Be the first to leave one!</p>
              ) : (
                reviews.map((review) => (
                  <div key={review.id} className="bg-brand-surface p-6 rounded-xl border border-white/5">
                    <div className="flex justify-between items-start mb-4">
                      <div>
                        <h4 className="font-bold">{review.userName}</h4>
                        <p className="text-xs text-gray-500">{new Date(review.createdAt).toLocaleDateString()}</p>
                      </div>
                      <StarRating initialRating={review.rating} readonly size={16} />
                    </div>
                    <p className="text-gray-300">{review.comment}</p>
                  </div>
                ))
              )}
            </div>
          </section>
        </div>

        <div className="lg:col-span-1 space-y-8">
          <div className="bg-brand-surface p-6 rounded-xl border border-white/5">
            <h3 className="text-xl font-bold mb-4">Rate this Artist</h3>
            {!venueUser ? (
              <div className="text-center py-4">
                <p className="text-gray-400 text-sm mb-4">Only Venue accounts can rate artists</p>
                <Link to="/venue-portal">
                  <Button variant="outline" className="w-full flex items-center justify-center gap-2">
                    <LogIn className="w-4 h-4" /> Venue Login
                  </Button>
                </Link>
              </div>
            ) : (
              <div className="space-y-4">
                <p className="text-gray-400 text-sm">Seen them live? Leave a rating!</p>
                <div className="flex justify-center py-4 bg-brand-dark/50 rounded-lg">
                   <StarRating initialRating={0} size={32} onRate={handleAddReview} />
                </div>
                <p className="text-xs text-center text-brand-lime">Logged in as {venueUser.name} (Organiser)</p>
              </div>
            )}
          </div>
          
          <div className="bg-gradient-to-br from-brand-indigo to-brand-purple p-6 rounded-xl shadow-xl">
             <h3 className="text-xl font-bold mb-2">Want to book {artist.name}?</h3>
             <p className="text-white/80 text-sm mb-6">Dates fill up fast. Secure your spot today.</p>
             <Link to={`/request-quote?artistId=${artist.id}`} className="block">
               <button className="w-full py-3 bg-white text-brand-purple font-bold rounded-lg hover:bg-brand-lime hover:text-brand-dark transition-colors">
                 Get a Quote
               </button>
             </Link>
          </div>
        </div>

      </div>
    </div>
  );
};
