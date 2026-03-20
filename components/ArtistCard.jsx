
import React, { useState, useEffect } from 'react';
import { StarRating } from './StarRating';
import { Link } from 'react-router-dom';
import { ArrowRight, Heart, AlertCircle } from 'lucide-react';
import { supabase } from '../services/supabase';

export const ArtistCard = ({ artist }) => {
  const [isHearted, setIsHearted] = useState(false);
  const [user, setUser] = useState(null);
  const [userRole, setUserRole] = useState(null);
  const [error, setError] = useState(null);

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
        
        // Check Heart status
        const { data: heartData } = await supabase
          .from('Reviews_Heart')
          .select('*')
          .eq('UserUUID', authUser.id)
          .eq('TalentUUID', artist.id)
          .single();
        
        if (heartData) setIsHearted(true);
      }
    };
    checkUser();
  }, [artist.id]);

  const handleHeart = async (e) => {
    e.preventDefault();
    e.stopPropagation();
    setError(null);

    if (!user) {
      setError('Please login to favourite.');
      setTimeout(() => setError(null), 3000);
      return;
    }

    if (userRole !== 'user') {
      setError('Only general client accounts can favourite.');
      setTimeout(() => setError(null), 3000);
      return;
    }

    try {
      if (isHearted) {
        const { error: deleteError } = await supabase
          .from('Reviews_Heart')
          .delete()
          .eq('UserUUID', user.id)
          .eq('TalentUUID', artist.id);
        
        if (deleteError) throw deleteError;
        setIsHearted(false);
      } else {
        const { error: insertError } = await supabase
          .from('Reviews_Heart')
          .insert({
            UserUUID: user.id,
            TalentUUID: artist.id,
            AppSource: 'en4tainment'
          });
        
        if (insertError) throw insertError;
        setIsHearted(true);
      }
    } catch (err) {
      console.error('Heart error:', err);
      setError('Failed to update.');
      setTimeout(() => setError(null), 3000);
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
        
        <button 
          onClick={handleHeart}
          className={`absolute top-4 right-4 z-20 p-2 rounded-full backdrop-blur-md transition-all ${
            isHearted ? 'bg-brand-pink text-white' : 'bg-black/40 text-white hover:bg-brand-pink/50'
          }`}
        >
          <Heart className={`w-5 h-5 ${isHearted ? 'fill-current' : ''}`} />
        </button>

        {error && (
          <div className="absolute top-16 right-4 z-30 bg-red-500 text-white text-[10px] px-2 py-1 rounded shadow-lg animate-fade-in flex items-center gap-1">
            <AlertCircle size={10} /> {error}
          </div>
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
