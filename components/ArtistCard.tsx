
import React, { useState, useEffect } from 'react';
import { Artist } from '../types';
import { StarRating } from './StarRating';
import { Link } from 'react-router-dom';
import { ArrowRight, Heart } from 'lucide-react';
import { supabase } from '../services/supabase';

interface ArtistCardProps {
  artist: Artist;
}

export const ArtistCard: React.FC<ArtistCardProps> = ({ artist }) => {
  const [isHearted, setIsHearted] = useState(false);
  const venueUser = JSON.parse(localStorage.getItem('venue_user') || 'null');

  useEffect(() => {
    if (venueUser) {
      checkHeartStatus();
    }
  }, [artist.id]);

  const checkHeartStatus = async () => {
    const { data } = await supabase
      .from('hearts')
      .select('*')
      .eq('venue_id', venueUser.id)
      .eq('artist_id', artist.id)
      .single();
    
    if (data) setIsHearted(true);
  };

  const handleHeart = async (e: React.MouseEvent) => {
    e.preventDefault();
    e.stopPropagation();
    if (!venueUser) return;

    if (isHearted) {
      await supabase
        .from('hearts')
        .delete()
        .eq('venue_id', venueUser.id)
        .eq('artist_id', artist.id);
      setIsHearted(false);
    } else {
      await supabase
        .from('hearts')
        .insert({
          venue_id: venueUser.id,
          artist_id: artist.id
        } as any);
      setIsHearted(true);
    }
  };

  return (
    <div className="group relative bg-brand-surface rounded-2xl overflow-hidden hover:-translate-y-2 transition-transform duration-300 shadow-xl border border-white/5 hover:border-brand-purple/50">
      
      <div className="relative h-64 overflow-hidden">
        <div className="absolute inset-0 bg-gradient-to-t from-brand-surface to-transparent opacity-60 z-10" />
        <img 
          src={artist.imageUrl} 
          alt={artist.name} 
          className="w-full h-full object-cover group-hover:scale-110 transition-transform duration-500 filter saturate-50 group-hover:saturate-100" 
        />
        <div className="absolute bottom-4 left-4 z-20">
          <span className="bg-brand-purple text-white text-xs px-2 py-1 rounded-md uppercase tracking-wide font-bold">
            {artist.category}
          </span>
        </div>
        
        {venueUser && (
          <button 
            onClick={handleHeart}
            className={`absolute top-4 right-4 z-20 p-2 rounded-full backdrop-blur-md transition-all ${
              isHearted ? 'bg-brand-pink text-white' : 'bg-black/40 text-white hover:bg-brand-pink/50'
            }`}
          >
            <Heart className={`w-5 h-5 ${isHearted ? 'fill-current' : ''}`} />
          </button>
        )}
      </div>

      <div className="p-6">
        <div className="flex justify-between items-start mb-2">
          <h3 className="text-xl font-bold text-white group-hover:text-brand-lime transition-colors">
            {artist.name}
          </h3>
          <StarRating initialRating={artist.rating} readonly size={16} />
        </div>
        
        <p className="text-gray-400 text-sm mb-6 line-clamp-2">
          {artist.description}
        </p>

        <Link 
          to={`/artists/${artist.id}`} 
          className="inline-flex items-center text-sm font-semibold text-brand-pink hover:text-brand-lime transition-colors gap-1"
        >
          View Profile <ArrowRight size={16} />
        </Link>
      </div>
    </div>
  );
};
