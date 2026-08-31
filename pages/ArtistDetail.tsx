import React, { useEffect, useState } from 'react';
import { useParams, Link } from 'react-router';
import { Button } from '../components/Button';
import { TalentRating } from '../components/TalentRating';
import { PlayCircle, Heart, AlertCircle, CheckCircle } from 'lucide-react';
import { supabase } from '../services/supabase';
import { User } from '@supabase/supabase-js';
import type { RawTalentStats } from '../types';

// Stable per-browser identifier for anonymous hearts. Module scope deliberately:
// it is used by both the initial fetch and the heart handler, which are separate
// closures. Defining it inside the fetch left the handler referencing an
// out-of-scope name — a runtime ReferenceError on every anonymous heart.
const getVisitorId = (): string => {
  let vid = localStorage.getItem('en4_visitor_id');
  if (!vid) {
    vid = crypto.randomUUID();
    localStorage.setItem('en4_visitor_id', vid);
  }
  return vid;
};

interface ArtistDetailData {
  id: string;
  name: string;
  imageUrl: string;
  description: string;
  bio: string;
  category: string;
  stats: RawTalentStats;
  gallery: string[];
}

export const ArtistDetail: React.FC = () => {
  const { id } = useParams<{ id: string }>();
  const [artist, setArtist] = useState<ArtistDetailData | null>(null);
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
          talent_stats (rating_average, rating_count),
          profile_status,
          is_public,
          type_of_performer,
          primary_location,
          profile_photo_url,
          talent_media (cloudinary_secure_url, is_featured, resource_type, media_type, sort_order),
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
        // The three profile photos are talent_media rows with
        // media_type 'profile_photo', at sort_order 0, 1 and 2 — written by the
        // Talent PWA's FEATURE_SLOTS. Slot 0 is the lead image.
        const profilePhotos: string[] = media
          .filter(m => m.media_type === 'profile_photo' && m.cloudinary_secure_url)
          .sort((a, b) => (a.sort_order ?? 0) - (b.sort_order ?? 0))
          .map(m => m.cloudinary_secure_url as string);

        const featuredImage: string =
          profilePhotos[0]
          || media.find(m => m.is_featured && m.resource_type === 'image')?.cloudinary_secure_url
          || media[0]?.cloudinary_secure_url
          || talentData.profile_photo_url
          || '';
        
        setArtist({
          id: talentData.id,
          name: talentData.stage_name || 'Unnamed artist',
          imageUrl: featuredImage,
          description: talentData.short_bio || '',
          bio: talentData.bio || '',
          category: primaryGenre,
          stats: talentData.talent_stats,
          gallery: profilePhotos
        });
            } else {
        setArtist(null);
      }

      // Check Heart if user is logged in
      const { data: { user: authUser } } = await supabase.auth.getUser();
      if (authUser) {
        const { data: heartData } = await supabase
          .from('talent_favourites')
          .select('*')
          .eq('user_id', authUser.id)
          .eq('talent_id', id)
          .single();
        if (heartData) setIsHearted(true);
      } else {
        const visitorId = getVisitorId();
        const { data: heartData } = await supabase
          .from('talent_favourites')
          .select('*')
          .eq('visitor_id', visitorId)
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
  if (!id) return;

  if (isHearted) {
    if (user && userRole === 'client') {
      try {
        const { error: deleteError } = await supabase
          .from('talent_favourites')
          .delete()
          .eq('user_id', user.id)
          .eq('talent_id', id);
        if (deleteError) throw deleteError;
        setIsHearted(false);
        setSuccess('Removed from favourites.');
      } catch (err: any) {
        setError('Failed to remove heart: ' + err.message);
      }
    } else {
      setError("You've already hearted this artist.");
    }
    return;
  }

  try {
    if (user && userRole === 'client') {
      const { error: insertError } = await supabase
        .from('talent_favourites')
        .insert({ user_id: user.id, talent_id: id, app_source: 'en4tainment' });
      if (insertError) throw insertError;
    } else {
      const visitorId = getVisitorId();
      const { error: insertError } = await supabase
        .from('talent_favourites')
        .insert({ visitor_id: visitorId, talent_id: id, app_source: 'en4tainment' });
      if (insertError) {
        if (insertError.code === '23505') {
          setError("You've already hearted this artist.");
          setIsHearted(true);
          return;
        }
        throw insertError;
      }
    }
    setIsHearted(true);
    setSuccess('Added to favourites!');
  } catch (err: any) {
    setError('Failed to save your heart: ' + err.message);
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
            <TalentRating stats={artist.stats} variant="full" size={24} className="text-xl font-semibold" />
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
        </div>

        <div className="lg:col-span-1 space-y-8 text-left">
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