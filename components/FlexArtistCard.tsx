import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { ArrowRight, Heart, AlertCircle } from 'lucide-react';
import { supabase } from '../services/supabase';
import { Artist } from '../types';

// ─────────────────────────────────────────────────────────────────────────
// FlexArtistCard
//
// Drop-in replacement / companion for ArtistCard.tsx. Same Artist data
// contract — no Supabase query changes required.
//
// Design intent: a festival lineup ticket, not a product-grid tile.
//   - "featured" cards (Rising Stars) run wider, as a headliner billing.
//   - "standard" cards run narrower, as support-act billing.
//   - flex-wrap container (see FlexArtistCardRow below) lets cards of both
//     sizes share one line without a rigid column grid.
//   - the top spotlight bar is the signature element: a thin gradient
//     sweep that stays dormant until hover, echoing the stage-lighting
//     motif from the "Live & Loud" section on Home.tsx.
// ─────────────────────────────────────────────────────────────────────────

interface FlexArtistCardProps {
  artist: Artist;
  featured?: boolean; // true = headliner sizing, tied to is_featured in DB
}

export const FlexArtistCard: React.FC<FlexArtistCardProps> = ({ artist, featured = false }) => {
  const [isHearted, setIsHearted] = useState<boolean>(false);
  interface AuthUser {
    id: string;
    email?: string;
  }
  const [user, setUser] = useState<AuthUser | null>(null);
  const [userRole, setUserRole] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const checkUser = async (): Promise<void> => {
      const { data: { user: authUser } } = await supabase.auth.getUser();
      if (authUser) {
        setUser({ id: authUser.id, email: authUser.email });
        const { data: profile } = await supabase
          .from('profiles_users')
          .select('role')
          .eq('id', authUser.id)
          .single();
        setUserRole(profile?.role);

        const { data: heartData } = await supabase
          .from('talent_favourites')
          .select('id')
          .eq('user_id', authUser.id)
          .eq('talent_id', artist.id)
          .maybeSingle();

        if (heartData) setIsHearted(true);
      }
    };
    checkUser();
  }, [artist.id]);

  const handleHeart = async (e: React.MouseEvent<HTMLButtonElement>): Promise<void> => {
    e.preventDefault();
    e.stopPropagation();
    setError(null);

    if (!user) {
      setError('Log in to favourite');
      setTimeout(() => setError(null), 3000);
      return;
    }

    if (userRole !== 'client') {
      setError('Clients only');
      setTimeout(() => setError(null), 3000);
      return;
    }

    try {
      if (isHearted) {
        const { error: deleteError } = await supabase
          .from('talent_favourites')
          .delete()
          .eq('user_id', user.id)
          .eq('talent_id', artist.id);

        if (deleteError) throw deleteError;
        setIsHearted(false);
      } else {
        const { error: insertError } = await supabase
          .from('talent_favourites')
          .insert({
            user_id: user.id,
            talent_id: artist.id,
            app_source: 'en4tainment'
          });

        if (insertError) throw insertError;
        setIsHearted(true);
      }
    } catch (err) {
      console.error('Heart error:', err);
      setError('Failed to update');
      setTimeout(() => setError(null), 3000);
    }
  };

  return (
    <div
      className={`group relative flex flex-col bg-brand-surface rounded-2xl overflow-hidden border border-white/5 hover:border-brand-purple/40 transition-all duration-300 hover:-translate-y-1.5 ${
        featured ? 'w-full sm:w-[380px]' : 'w-full sm:w-[280px]'
      }`}
      id={`flex-artist-card-${artist.id}`}
    >
      {/* Signature element: dormant spotlight bar, sweeps in on hover */}
      <div className="absolute top-0 left-0 right-0 h-[3px] z-20 overflow-hidden">
        <div
          className="h-full w-full bg-gradient-to-r from-brand-purple via-brand-pink to-brand-lime -translate-x-full group-hover:translate-x-0 transition-transform duration-500 ease-out"
        />
      </div>

      <Link to={`/artists/${artist.id}`} className="block flex-1" id={`flex-artist-link-${artist.id}`}>
        <div className={`relative overflow-hidden ${featured ? 'h-72' : 'h-52'}`}>
          <div className="absolute inset-0 bg-gradient-to-t from-brand-surface via-transparent to-transparent opacity-70 z-10" />
          <img
            src={artist.imageUrl}
            alt={artist.name}
            className="w-full h-full object-cover object-top group-hover:scale-105 transition-transform duration-700 filter saturate-[.65] group-hover:saturate-100"
          />

          {/* Billing tag — reads like a lineup ticket stub */}
          <div className="absolute top-4 left-4 z-20 flex items-center gap-2">
            {featured && (
              <span className="bg-brand-lime text-brand-dark text-[10px] font-black uppercase tracking-widest px-2 py-1 rounded">
                Headliner
              </span>
            )}
            <span className="bg-black/50 backdrop-blur-sm text-white text-[10px] font-bold uppercase tracking-widest px-2 py-1 rounded border border-white/10">
              {artist.category}
            </span>
          </div>
        </div>

        <div className={`p-5 ${featured ? 'space-y-3' : 'space-y-2'}`}>
          <div className="flex items-start justify-between gap-3">
            <h3 className={`font-black text-white group-hover:text-brand-lime transition-colors leading-tight ${featured ? 'text-2xl' : 'text-lg'}`}>
              {artist.name}
            </h3>
            <div className="flex items-center gap-1 text-brand-lime shrink-0 pt-1">
              <span className="text-xs font-black">{artist.rating.toFixed(1)}</span>
            </div>
          </div>

          <p className={`text-gray-400 leading-relaxed ${featured ? 'text-sm line-clamp-2' : 'text-xs line-clamp-1'}`}>
            {artist.description}
          </p>

          <div className="inline-flex items-center text-xs font-bold text-brand-pink group-hover:text-brand-lime transition-colors gap-1 pt-1">
            View profile <ArrowRight size={14} />
          </div>
        </div>
      </Link>

      <button
        onClick={handleHeart}
        className={`absolute top-4 right-4 z-20 p-2 rounded-full backdrop-blur-md transition-all ${
          isHearted ? 'bg-brand-pink text-white' : 'bg-black/40 text-white hover:bg-brand-pink/50'
        }`}
        id={`flex-heart-button-${artist.id}`}
        aria-label={isHearted ? 'Remove favourite' : 'Add favourite'}
      >
        <Heart className={`w-4 h-4 ${isHearted ? 'fill-current' : ''}`} />
      </button>

      {error && (
        <div className="absolute top-16 right-4 z-30 bg-red-500 text-white text-[10px] px-2 py-1 rounded shadow-lg flex items-center gap-1" id={`flex-heart-error-${artist.id}`}>
          <AlertCircle size={10} /> {error}
        </div>
      )}
    </div>
  );
};

// ─────────────────────────────────────────────────────────────────────────
// FlexArtistCardRow
//
// True flex-wrap container. Featured (headliner) cards run first and
// wider; standard cards fill remaining space and wrap naturally — no
// fixed column count, no empty grid cells when counts don't divide evenly.
// ─────────────────────────────────────────────────────────────────────────

interface FlexArtistCardRowProps {
  artists: Artist[];
  featuredIds?: string[]; // ids that should render as headliner cards
}

export const FlexArtistCardRow: React.FC<FlexArtistCardRowProps> = ({ artists, featuredIds = [] }) => {
  return (
    <div className="flex flex-wrap gap-6 justify-center sm:justify-start">
      {artists.map((artist) => (
        <FlexArtistCard
          key={artist.id}
          artist={artist}
          featured={featuredIds.includes(artist.id)}
        />
      ))}
    </div>
  );
};

export default FlexArtistCard;