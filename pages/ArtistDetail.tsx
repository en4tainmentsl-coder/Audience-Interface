import React, { useEffect, useState } from 'react';
import { useParams, Link } from 'react-router';
import { ARTISTS as STATIC_ARTISTS } from '../constants';
import { Button } from '../components/Button';
import { StarRating } from '../components/StarRating';
import { PlayCircle, Heart, LogIn, AlertCircle, CheckCircle } from 'lucide-react';
import { supabase } from '../services/supabase';
import { User } from '@supabase/supabase-js';

interface ArtistDetailData {
  id: string;
  name: string;
  imageUrl: string;
  description: string;
  bio: string;
  category: string;
  rating: number;
  gallery: string[];
}

interface ReviewStar {
  id: string;
  reviewee_talent_id: string;
  reviewer_user_id: string;   // was ReviewerUserUUID
  rating: number;              // was Rating_1_to_5
  created_at: string;
  comment?: string;
  user_name?: string;
}

export const ArtistDetail: React.FC = () => {
  const { id } = useParams<{ id: string }>();
  const [artist, setArtist] = useState<ArtistDetailData | null>(null);
  const [reviews, setReviews] = useState<ReviewStar[]>([]);
  const [isHearted, setIsHearted] = useState<boolean>(false);
  const [user, setUser] = useState<User | null>(null);
  const [userRole, setUserRole] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  const fetchArtistData = async (): Promise<void> => {
    if (!id) return;
    try {
      // Fetch from profiles_talent
      const { data: talentData } = await supabase
        .from('profiles_talent')
        .select(`
          id,
          stage_name,
          bio,
          short_bio,
          rating,
          profile_status,
          is_public,
          type_of_performer,
          primary_location,
          talent_media (cloudinary_secure_url, pfp_1_url, pfp_2_url, pfp_3_url, is_featured, resource_type),
          talent_genres (genre_id, is_primary, genres (genre_name))
        `)
        .eq('id', id)
        .single();

      if (talentData) {
        // Safe mapping
        const rawMedia = talentData.talent_media;
        const media = Array.isArray(rawMedia)
          ? rawMedia
          : (rawMedia && typeof rawMedia === 'object' ? [rawMedia] : []);
        const genres = talentData.talent_genres as unknown as Array<{ is_primary: boolean; genres?: { genre_name: string } }> || [];

        const primaryGenre: string = genres.find(g => g.is_primary)?.genres?.genre_name || 'Artist';
        const featuredImage: string =
          media.find(m => m.is_featured && m.resource_type === 'image')?.cloudinary_secure_url
          || media[0]?.pfp_1_url
          || media[0]?.cloudinary_secure_url
          || talentData.profile_photo_url
          || '';
        
        setArtist({
          id: talentData.id,
          name: talentData.stage_name,
          imageUrl: featuredImage,
          description: talentData.short_bio || '',
          bio: talentData.bio || '',
          category: primaryGenre,
          rating: talentData.rating || 0,
          gallery: media.flatMap(m => [
            m.pfp_1_url, m.pfp_2_url, m.pfp_3_url
          ].filter(Boolean)) || []
        });
      } else {
        const found = STATIC_ARTISTS.find(a => a.id === id);
        if (found) {
          setArtist({
            id: found.id,
            name: found.name,
            imageUrl: found.imageUrl,
            description: found.description,
            bio: found.bio,
            category: found.category,
            rating: found.rating,
            gallery: found.gallery
          });
        } else {
          setArtist(null);
        }
      }

      // Fetch Reviews from reviews_star
      const { data: reviewsData } = await supabase
        .from('reviews_star')
        .select('*')
        .eq('reviewee_talent_id', id)
        .order('created_at', { ascending: false });
      
      if (reviewsData) {
        setReviews((reviewsData as unknown) as ReviewStar[]);
      }

      // Check Heart if user is logged in
      const { data: { user: authUser } } = await supabase.auth.getUser();
      if (authUser) {
        const { data: heartData } = await supabase
          .from('talent_favourites')            // ✅ renamed table
          .select('*')
          .eq('user_id', authUser.id)           // ✅ renamed column
          .eq('talent_id', id)
          .single();
        if (heartData) setIsHearted(true);
      }
    } catch (err) {
      console.error('Error fetching artist data:', err);
    }
  };

  useEffect(() => {
    const checkUser = async (): Promise<void> => {
      const { data: { user: authUser } } = await supabase.auth.getUser();
      if (authUser) {
        setUser(authUser);
        const { data: profile } = await supabase
          .from('profiles_users')
          .select('role')
          .eq('id', authUser.id)
          .single();
        setUserRole(profile?.role || null);
      }
    };
    checkUser();
    fetchArtistData();
  }, [id]);

  const handleHeart = async (): Promise<void> => {
    setError(null);
    setSuccess(null);

    if (!user || !id) {
      setError('Please login to favourite this artist.');
      return;
    }

    if (userRole !== 'client') {
      setError('Only client accounts are permitted to favourite artists.');
      return;
    }

    try {
      if (isHearted) {
        const { error: deleteError } = await supabase
          .from('talent_favourites')
          .delete()
          .eq('user_id', user.id)
          .eq('talent_id', id);
        
        if (deleteError) throw deleteError;
        setIsHearted(false);
        setSuccess('Removed from favourites.');
      } else {
        // CORRECT
        const { error: insertError } = await supabase
          .from('talent_favourites')
          .insert({
            user_id: user.id,
            talent_id: id,
            app_source: 'en4tainment'
          });
        
        if (insertError) throw insertError;
        setIsHearted(true);
        setSuccess('Added to favourites!');
      }
    } catch (err: any) {
      setError('Failed to update heart rating: ' + err.message);
    }
  };

  const handleAddReview = async (rating: number): Promise<void> => {
    setError(null);
    setSuccess(null);

    if (!user || !id) {
      setError('Please login to leave a rating.');
      return;
    }

    if (userRole !== 'venue') {
      setError('Only Venue accounts (organisers) are permitted to submit star ratings.');
      return;
    }

    if (rating < 1 || rating > 5) {
      setError('Rating must be between 1 and 5.');
      return;
    }

    try {
      // Check for completed booking
      const { data: venueProfile } = await supabase
        .from('profiles_venues')
        .select('id')
        .eq('user_id', user.id)
        .single();

      if (!venueProfile) {
        setError('Venue profile not found.');
        return;
      }

      const { data: completedBooking } = await supabase
        .from('bookings')
        .select('id')
        .eq('venue_id', venueProfile.id)
        .eq('talent_id', id)
        .eq('booking_status', 'completed')
        .limit(1)
        .single();

      if (!completedBooking) {
        setError('You can only review talent after a completed booking.');
        return;
      }

      const comment: string | null = prompt('Enter your review:');
      if (!comment) return;

      // Insert into reviews_star table
      const { error: reviewError } = await supabase.from('reviews_star').insert({
        reviewee_talent_id: id,
        reviewer_user_id: user.id,
        rating: rating,
        comment: comment,
        booking_id: completedBooking.id   // you already fetch this above as `completedBooking`
      });

      if (reviewError) throw reviewError;

      setSuccess('Rating submitted successfully!');
      fetchArtistData();
    } catch (err: any) {
      setError('Failed to submit rating: ' + err.message);
    }
  };

  if (!artist) return <div className="pt-32 text-center text-white" id="artist-not-found">Artist not found</div>;

  return (
    <div className="pt-20 min-h-screen bg-brand-dark text-white" id="artist-detail">
      
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
            <button 
              onClick={handleHeart}
              className={`p-2 rounded-full backdrop-blur-md transition-all ${
                isHearted ? 'bg-brand-pink text-white' : 'bg-white/10 text-white hover:bg-brand-pink/50'
              }`}
              id="like-artist-btn"
            >
              <Heart className={`w-6 h-6 ${isHearted ? 'fill-current' : ''}`} />
            </button>
          </div>
          <h1 className="text-5xl md:text-7xl font-bold mb-2">{artist.name}</h1>
          <div className="flex items-center gap-4 mb-6" id="rating-summary">
            <StarRating initialRating={artist.rating} readonly size={24} />
            <span className="text-xl font-semibold text-brand-purple">{artist.rating}/5.0</span>
          </div>
          <Link to={`/request-quote?artistId=${artist.id}`} id="request-quote-top-btn">
            <Button size="lg" variant="primary">Request Quotation</Button>
          </Link>
        </div>
      </div>

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-16 grid grid-cols-1 lg:grid-cols-3 gap-12">
        
        <div className="lg:col-span-2 text-left">
          {error && (
            <div className="mb-6 flex items-center gap-2 text-red-500 bg-red-500/10 p-4 rounded-xl border border-red-500/20" id="artist-detail-error">
              <AlertCircle className="w-5 h-5" />
              {error}
            </div>
          )}
          {success && (
            <div className="mb-6 flex items-center gap-2 text-brand-lime bg-brand-lime/10 p-4 rounded-xl border border-brand-lime/20" id="artist-detail-success">
              <CheckCircle className="w-5 h-5" />
              {success}
            </div>
          )}
          <section className="mb-12">
            <h2 className="text-2xl font-bold mb-6 border-l-4 border-brand-pink pl-4 leading-none">About the Artist</h2>
            <p className="text-gray-300 leading-loose text-lg whitespace-pre-line">
              {artist.bio}
            </p>
          </section>

          <section className="mb-12">
            <h2 className="text-2xl font-bold mb-6 border-l-4 border-brand-lime pl-4 leading-none">Gallery & Performances</h2>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              {artist.gallery.map((img, idx) => (
                <div key={idx} className="relative group rounded-lg overflow-hidden h-64 bg-gray-900" id={`gallery-item-${idx}`}>
                  <img src={img} alt="Gallery" className="w-full h-full object-cover group-hover:opacity-75 transition-opacity" />
                  <div className="absolute inset-0 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity">
                    <PlayCircle className="text-white w-12 h-12 drop-shadow-lg" />
                  </div>
                </div>
              ))}
            </div>
          </section>

          <section>
            <h2 className="text-2xl font-bold mb-6 border-l-4 border-brand-purple pl-4 leading-none">Reviews</h2>
            <div className="space-y-6">
              {reviews.length === 0 ? (
                <p className="text-gray-500 italic">No reviews yet. Be the first to leave one!</p>
              ) : (
                reviews.map((review: ReviewStar) => (
                  <div key={review.id} className="bg-brand-surface p-6 rounded-xl border border-white/5" id={`review-${review.id}`}>
                    <div className="flex justify-between items-start mb-4">
                      <div>
                        <h4 className="font-bold">{review.user_name || 'Anonymous'}</h4>
                        <p className="text-xs text-gray-500">{new Date(review.created_at).toLocaleDateString()}</p>
                      </div>
                      <StarRating initialRating={review.rating} readonly size={16} />
                    </div>
                    <p className="text-gray-300">{review.comment || 'Star review details.'}</p>
                  </div>
                ))
              )}
            </div>
          </section>
        </div>

        <div className="lg:col-span-1 space-y-8 text-left">
          <div className="bg-brand-surface p-6 rounded-xl border border-white/5">
            <h3 className="text-xl font-bold mb-4">Rate this Artist</h3>
            {!user ? (
              <div className="text-center py-4">
                <p className="text-gray-400 text-sm mb-4">Please login to rate and review</p>
                <Link to="/venue-portal">
                  <Button variant="outline" className="w-full flex items-center justify-center gap-2">
                    <LogIn className="w-4 h-4" /> Go to Login
                  </Button>
                </Link>
              </div>
            ) : (
              <div className="space-y-4">
                <p className="text-gray-400 text-sm">Seen them live? Leave a rating!</p>
                <div className="flex justify-center py-4 bg-brand-dark/50 rounded-lg">
                   <StarRating initialRating={0} size={32} onRate={handleAddReview} />
                </div>
                <p className="text-xs text-center text-brand-lime">Logged in as {user.email}</p>
                {userRole && <p className="text-[10px] text-center text-gray-500 uppercase tracking-widest">Role: {userRole}</p>}
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
