
import React, { useEffect, useState } from 'react';
import { useParams, Link } from 'react-router-dom';
import { ARTISTS as STATIC_ARTISTS } from '../constants';
import { Button } from '../components/Button';
import { StarRating } from '../components/StarRating';
import { PlayCircle, Heart, LogIn, MessageSquare, AlertCircle, CheckCircle } from 'lucide-react';
import { supabase } from '../services/supabase';

export const ArtistDetail = () => {
  const { id } = useParams();
  const [artist, setArtist] = useState(null);
  const [reviews, setReviews] = useState([]);
  const [isHearted, setIsHearted] = useState(false);
  const [user, setUser] = useState(null);
  const [userRole, setUserRole] = useState(null);
  const [error, setError] = useState(null);
  const [success, setSuccess] = useState(null);

  useEffect(() => {
    const checkUser = async () => {
      const { data: { user: authUser } } = await supabase.auth.getUser();
      if (authUser) {
        setUser(authUser);
        const { data: profile } = await supabase
          .from('Profiles_Users')
          .select('Role')
          .eq('UserUUID_PK', authUser.id)
          .single();
        setUserRole(profile?.Role);
      }
    };
    checkUser();
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
      .from('Reviews')
      .select('*')
      .eq('artist_id', id)
      .order('created_at', { ascending: false });
    
    if (reviewsData) setReviews(reviewsData);

    // Check Heart if user is logged in
    const { data: { user: authUser } } = await supabase.auth.getUser();
    if (authUser) {
      const { data: heartData } = await supabase
        .from('Reviews_Heart')
        .select('*')
        .eq('UserUUID', authUser.id)
        .eq('TalentUUID', id)
        .single();
      if (heartData) setIsHearted(true);
    }
  };

  const handleHeart = async () => {
    setError(null);
    setSuccess(null);

    if (!user) {
      setError('Please login to favourite this artist.');
      return;
    }

    if (userRole !== 'user') {
      setError('Only general client accounts are permitted to favourite artists.');
      return;
    }

    try {
      if (isHearted) {
        const { error: deleteError } = await supabase
          .from('Reviews_Heart')
          .delete()
          .eq('UserUUID', user.id)
          .eq('TalentUUID', id);
        
        if (deleteError) throw deleteError;
        setIsHearted(false);
        setSuccess('Removed from favourites.');
      } else {
        const { error: insertError } = await supabase
          .from('Reviews_Heart')
          .insert({
            UserUUID: user.id,
            TalentUUID: id,
            AppSource: 'en4tainment'
          });
        
        if (insertError) throw insertError;
        setIsHearted(true);
        setSuccess('Added to favourites!');
      }
    } catch (err) {
      setError('Failed to update heart rating: ' + err.message);
    }
  };

  const handleAddReview = async (rating) => {
    setError(null);
    setSuccess(null);

    if (!user) {
      setError('Please login to leave a rating.');
      return;
    }

    if (userRole !== 'organiser') {
      setError('Only Venue accounts (organisers) are permitted to submit star ratings.');
      return;
    }

    if (rating < 1 || rating > 5) {
      setError('Rating must be between 1 and 5.');
      return;
    }

    const comment = prompt('Enter your review:');
    if (!comment) return;

    try {
      // Insert into Reviews table
      const { error: reviewError } = await supabase.from('Reviews').insert({
        artist_id: id,
        ReviewerUserUUID: user.id,
        Rating_1_to_5: rating,
        comment: comment
      });

      if (reviewError) throw reviewError;

      // Insert into Reviews_5_Star table
      const { error: starError } = await supabase.from('Reviews_5_Star').insert({
        TalentUUID: id,
        ReviewerUserUUID: user.id,
        OverallRating: rating
      });

      if (starError) throw starError;

      setSuccess('Rating submitted successfully!');
      fetchArtistData();
    } catch (err) {
      setError('Failed to submit rating: ' + err.message);
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
            <button 
              onClick={handleHeart}
              className={`p-2 rounded-full backdrop-blur-md transition-all ${
                isHearted ? 'bg-brand-pink text-white' : 'bg-white/10 text-white hover:bg-brand-pink/50'
              }`}
            >
              <Heart className={`w-6 h-6 ${isHearted ? 'fill-current' : ''}`} />
            </button>
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
          {error && (
            <div className="mb-6 flex items-center gap-2 text-red-500 bg-red-500/10 p-4 rounded-xl border border-red-500/20">
              <AlertCircle className="w-5 h-5" />
              {error}
            </div>
          )}
          {success && (
            <div className="mb-6 flex items-center gap-2 text-brand-lime bg-brand-lime/10 p-4 rounded-xl border border-brand-lime/20">
              <CheckCircle className="w-5 h-5" />
              {success}
            </div>
          )}
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
                        <h4 className="font-bold">{review.user_name || 'Anonymous'}</h4>
                        <p className="text-xs text-gray-500">{new Date(review.created_at).toLocaleDateString()}</p>
                      </div>
                      <StarRating initialRating={review.Rating_1_to_5} readonly size={16} />
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
