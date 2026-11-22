import React, { useEffect, useState } from 'react';
import { useParams, Link } from 'react-router';
import { Button } from '../components/Button';
import { TalentRating } from '../components/TalentRating';
import { PlayCircle, Heart, AlertCircle, CheckCircle } from 'lucide-react';
import { supabase } from '../services/supabase';
import { User } from '@supabase/supabase-js';
import type { RawTalentStats } from '../types';
import { eventTypeLabel } from '../constants/eventTypes';
import { SignInModal } from '../components/SignInModal';
import { ErrorBanner, LoadingAnnouncement } from '../components/QueryStates';
import { cldImage } from '../utils/cloudinary';

interface ArtistDetailData {
  id: string;
  name: string;
  imageUrl: string;
  description: string;
  bio: string;
  category: string;
  stats: RawTalentStats;
  gallery: string[];
  trailerVideoUrl: string | null;
  livePerformanceVideoUrl: string | null;
}

export const ArtistDetail: React.FC = () => {
  const { id } = useParams<{ id: string }>();
  const [artist, setArtist] = useState<ArtistDetailData | null>(null);
  const [isHearted, setIsHearted] = useState<boolean>(false);
  const [user, setUser] = useState<User | null>(null);
  const [showSignIn, setShowSignIn] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [offeredEventTypes, setOfferedEventTypes] = useState<string[]>([]);
  // Starts true. Previously the only guard was `if (!artist) return "Artist not
  // found"`, which ran for the whole fetch — so every visitor, including anyone
  // opening a link shared on WhatsApp, saw "Artist not found" first and the
  // artist a moment later. loadError is separate from `error` above, which
  // belongs to the heart action.
  const [loading, setLoading] = useState<boolean>(true);
  const [loadError, setLoadError] = useState<boolean>(false);

  // What this performer takes bookings for. From talent_offered_event_types,
  // which carries no rate. No Range shown here: the profile has no event type
  // to resolve one against, and a range without a category is meaningless.
  useEffect(() => {
    if (!id) return;
    let cancelled = false;
    supabase
      .from('talent_offered_event_types')
      .select('event_type')
      .eq('talent_id', id)
      .then(({ data }) => {
        if (cancelled) return;
        setOfferedEventTypes(
          (data ?? []).flatMap(r => (r.event_type ? [r.event_type as string] : []))
        );
      });
    return () => { cancelled = true; };
  }, [id]);

  const fetchArtistData = async (): Promise<void> => {
    if (!id) return;
    setLoading(true);
    setLoadError(false);
    try {
      // Fetch from profiles_talent
      const { data: talentData, error: talentError } = await supabase
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
          url_trailer_video,
          url_live_performance_video,
          talent_media (cloudinary_secure_url, is_featured, resource_type, media_type, sort_order),
          primary_genre:genres!profiles_talent_primary_genre_id_fkey (genre_name),
          secondary_genre:genres!profiles_talent_secondary_genre_id_fkey (genre_name),
          tertiary_genre:genres!profiles_talent_tertiary_genre_id_fkey (genre_name)
        `)
        .eq('id', id)
        .maybeSingle();

      // .single() raises PGRST116 when it matches no row, so a genuinely
      // missing artist arrived as an error rather than as null. .maybeSingle()
      // returns null instead, which keeps "no such artist" separate from "the
      // query failed" — they need different screens.
      if (talentError) {
        console.error('Error fetching artist:', talentError);
        setArtist(null);
        setLoadError(true);
        return;
      }

      if (talentData) {
        // Safe mapping
        const rawMedia = talentData.talent_media;
        const media = Array.isArray(rawMedia)
          ? rawMedia
          : (rawMedia && typeof rawMedia === 'object' ? [rawMedia] : []);
        const genres: string[] = [talentData.primary_genre, talentData.secondary_genre, talentData.tertiary_genre]
          .filter(Boolean).map((g: any) => g.genre_name);

        const primaryGenre: string = genres[0] || 'Artist';
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
          gallery: profilePhotos,
          trailerVideoUrl: talentData.url_trailer_video ?? null,
          livePerformanceVideoUrl: talentData.url_live_performance_video ?? null
        });
            } else {
        setArtist(null);
      }

            // Check Heart if user is logged in
      const { data: { user: authUser } } = await supabase.auth.getUser();
      if (authUser) {
        const { data: heartData, error: heartError } = await supabase
          .from('talent_favourites')
          .select('*')
          .eq('user_id', authUser.id)
          .eq('talent_id', id)
          .maybeSingle();
        // Logged, not surfaced. A failed read here means the heart renders
        // unset, which is recoverable by tapping it — a banner over the whole
        // profile would be louder than the problem.
        if (heartError) console.error('Error reading heart state:', heartError);
        if (heartData) setIsHearted(true);
      }
    } catch (err) {
      console.error('Error fetching artist data:', err);
      setLoadError(true);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    const checkUser = async (): Promise<void> => {
      const { data: { user: authUser } } = await supabase.auth.getUser();
      if (authUser) {
        setUser(authUser);
      }
    };
    checkUser();
    fetchArtistData();
  }, [id]);

  const handleHeart = async (): Promise<void> => {
    setError(null);
    setSuccess(null);
    if (!id) return;

    if (!user) {
      setShowSignIn(true);
      return;
    }

    if (isHearted) {
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
      return;
    }

    try {
      const { error: insertError } = await supabase
        .from('talent_favourites')
        .insert({ user_id: user.id, talent_id: id, app_source: 'en4tainment' });
      if (insertError) {
        if (insertError.code === '23505') {
          setIsHearted(true);
          return;
        }
        throw insertError;
      }
      setIsHearted(true);
      setSuccess('Added to favourites!');
    } catch (err: any) {
      setError('Failed to save your heart: ' + err.message);
    }
  };
  
  // Order matters: loading, then error, then genuinely-not-found. Collapsing
  // these into one !artist check is what put "Artist not found" in front of
  // every visitor for the length of the fetch.
  if (loading) {
    return (
      <div className="pt-32 pb-20 min-h-screen bg-brand-dark" id="artist-detail-loading">
        <LoadingAnnouncement label="Loading artist profile" />
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 animate-pulse" aria-hidden="true">
          <div className="h-[30vh] w-full rounded-2xl bg-brand-surface border border-white/5" />
          <div className="mt-8 space-y-4">
            <div className="h-10 w-1/2 bg-white/10 rounded" />
            <div className="h-4 w-1/4 bg-white/5 rounded" />
            <div className="h-4 w-full bg-white/5 rounded" />
            <div className="h-4 w-5/6 bg-white/5 rounded" />
          </div>
        </div>
      </div>
    );
  }

  if (loadError) {
    return (
      <div className="pt-32 pb-20 min-h-screen bg-brand-dark" id="artist-detail-load-error">
        <div className="max-w-2xl mx-auto px-4">
          <ErrorBanner
            message="We couldn't load this artist just now. Check your connection and try again."
            onRetry={fetchArtistData}
          />
        </div>
      </div>
    );
  }

  if (!artist) {
    return (
      <div className="pt-32 pb-20 min-h-screen bg-brand-dark text-center px-4" id="artist-not-found">
        <h1 className="text-3xl font-bold text-white mb-3">We can't find that artist</h1>
        <p className="text-gray-400 mb-8">They may have been removed, or the link may be incomplete.</p>
        <Link to="/artists" className="text-brand-lime font-bold hover:underline">
          Browse all artists
        </Link>
      </div>
    );
  }

  return (
    <div className="pt-20 min-h-screen bg-brand-dark text-white" id="artist-detail">
      
      <div className="relative h-[50vh] w-full">
        <img 
          src={cldImage(artist.imageUrl, 'hero')} 
          alt={artist.name} 
          fetchPriority="high"
          decoding="async"
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
              aria-pressed={isHearted}
              aria-label={isHearted ? `Remove ${artist.name} from favourites` : `Add ${artist.name} to favourites`}
              className={`p-3 rounded-full backdrop-blur-md transition-all ${
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
          {offeredEventTypes.length > 0 && (
            <div className="flex flex-wrap gap-2 mb-6" id="offered-event-types">
              {offeredEventTypes.map((et) => (
                <span key={et} className="bg-white/5 border border-white/10 text-gray-300 text-xs font-bold uppercase tracking-widest px-3 py-1 rounded-full">
                  {eventTypeLabel(et)}
                </span>
              ))}
            </div>
          )}
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
            <h2 className="text-2xl font-bold mb-6 border-l-4 border-brand-lime pl-4 leading-none">Gallery</h2>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              {artist.gallery.map((img, idx) => (
                <div key={idx} className="relative group rounded-lg overflow-hidden h-64 bg-gray-900" id={`gallery-item-${idx}`}>
                  <img src={cldImage(img, 'gallery')} alt="Gallery" loading="lazy" decoding="async" className="w-full h-full object-cover group-hover:opacity-75 transition-opacity" />
                </div>
              ))}
            </div>
          </section>

          {(artist.trailerVideoUrl || artist.livePerformanceVideoUrl) && (
            <section className="mb-12">
              <h2 className="text-2xl font-bold mb-6 border-l-4 border-brand-purple pl-4 leading-none">Watch</h2>
              <div className="flex flex-wrap gap-4">
                {artist.trailerVideoUrl && (
                  <a
                    href={artist.trailerVideoUrl}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="inline-flex items-center gap-2 px-5 py-3 rounded-xl bg-white/5 border border-white/10 hover:border-brand-purple text-white font-semibold transition-colors"
                    id="video-trailer"
                  >
                    <PlayCircle size={20} /> Watch trailer
                  </a>
                )}
                {artist.livePerformanceVideoUrl && (
                  <a
                    href={artist.livePerformanceVideoUrl}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="inline-flex items-center gap-2 px-5 py-3 rounded-xl bg-white/5 border border-white/10 hover:border-brand-lime text-white font-semibold transition-colors"
                    id="video-live"
                  >
                    <PlayCircle size={20} /> Live performance
                  </a>
                )}
              </div>
            </section>
          )}
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
             <p className="text-white/60 text-xs mt-4">
               You'll sign in and confirm a few contact details first. Bookings are for over-18s only.
             </p>
          </div>
        </div>

      </div>
      <SignInModal
        open={showSignIn}
        onClose={() => setShowSignIn(false)}
        reason="Sign in to save artists you like."
      />
    </div>
  );
};