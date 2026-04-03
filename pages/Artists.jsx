
import React, { useState, useMemo, useEffect } from 'react';
import { useSearchParams } from 'react-router-dom';
import { ArtistCard } from '../components/ArtistCard';
import { ARTISTS as STATIC_ARTISTS } from '../constants';
import { Search, SlidersHorizontal, X } from 'lucide-react';
import { supabase } from '../services/supabase';

export const Artists = () => {
  const [searchParams, setSearchParams] = useSearchParams();
  const urlQuery = searchParams.get('q') || '';
  
  const [searchTerm, setSearchTerm] = useState(urlQuery);
  const [selectedCategory, setSelectedCategory] = useState('All Categories');
  const [artists, setArtists] = useState(STATIC_ARTISTS);

  useEffect(() => {
    fetchArtists();
  }, []);

  const fetchArtists = async () => {
    try {
      const { data } = await supabase
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
          talent_media (cloudinary_secure_url, is_featured, resource_type),
          talent_genres (genre_id, is_primary, genres (genre_name))
        `)
        .eq('is_public', true)
        .eq('profile_status', 'active');
      
      if (data && data.length > 0) {
        const mappedArtists = data.map(talent => {
          const primaryGenre = talent.talent_genres?.find(g => g.is_primary)?.genres?.genre_name || 'Artist';
          const featuredImage = talent.talent_media?.find(m => m.is_featured && m.resource_type === 'image')?.cloudinary_secure_url || talent.profile_photo_url;
          
          return {
            ...talent,
            name: talent.stage_name,
            imageUrl: featuredImage,
            description: talent.short_bio,
            bio: talent.bio,
            category: primaryGenre,
            rating: talent.rating
          };
        });
        setArtists(mappedArtists);
      } else {
        setArtists(STATIC_ARTISTS);
      }
    } catch (error) {
      console.error('Error fetching artists:', error);
      setArtists(STATIC_ARTISTS);
    }
  };

  const categories = ['All Categories', 'Electronic / DJ', 'Rock / Alternative', 'Jazz / Blues', 'Acoustic / Indie'];

  useEffect(() => {
    setSearchTerm(urlQuery);
  }, [urlQuery]);

  const handleSearchChange = (value) => {
    setSearchTerm(value);
    const newParams = new URLSearchParams(searchParams);
    if (value) {
      newParams.set('q', value);
    } else {
      newParams.delete('q');
    }
    setSearchParams(newParams, { replace: true });
  };

  const filteredArtists = useMemo(() => {
    return artists.filter(artist => {
      const matchesSearch = artist.name.toLowerCase().includes(searchTerm.toLowerCase()) || 
                           artist.description.toLowerCase().includes(searchTerm.toLowerCase()) ||
                           artist.category.toLowerCase().includes(searchTerm.toLowerCase());
      const matchesCategory = selectedCategory === 'All Categories' || artist.category === selectedCategory;
      return matchesSearch && matchesCategory;
    });
  }, [searchTerm, selectedCategory, artists]);

  const clearAllFilters = () => {
    setSearchTerm('');
    setSelectedCategory('All Categories');
    const newParams = new URLSearchParams(searchParams);
    newParams.delete('q');
    setSearchParams(newParams, { replace: true });
  };

  return (
    <div className="pt-32 pb-20 min-h-screen bg-brand-dark">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center mb-12">
          <h1 className="text-4xl md:text-5xl font-black text-white mb-4 uppercase tracking-tighter">Our Talent Roster</h1>
          <p className="text-gray-400 max-w-2xl mx-auto">
            Explore our curated list of exceptional performers. Read bios, watch performances, and rate your favorites.
          </p>
        </div>

        <div className="max-w-4xl mx-auto mb-16 space-y-6">
          <div className="relative group">
            <div className="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none">
              <Search className="h-5 w-5 text-gray-500 group-focus-within:text-brand-purple transition-colors" />
            </div>
            <input
              type="text"
              placeholder="Search for artists, genres, or vibes..."
              value={searchTerm}
              onChange={(e) => handleSearchChange(e.target.value)}
              className="block w-full pl-12 pr-12 py-4 bg-brand-surface border border-white/10 rounded-2xl text-white placeholder:text-gray-600 focus:outline-none focus:ring-2 focus:ring-brand-purple/50 focus:border-brand-purple transition-all shadow-xl"
            />
            {searchTerm && (
              <button 
                onClick={() => handleSearchChange('')}
                className="absolute inset-y-0 right-0 pr-4 flex items-center text-gray-500 hover:text-white transition-colors"
              >
                <X size={20} />
              </button>
            )}
          </div>

          <div className="flex flex-col sm:flex-row items-center gap-4 justify-center">
            <div className="flex items-center gap-2 text-xs font-black text-brand-lime uppercase tracking-widest mr-2">
              <SlidersHorizontal size={14} />
              Filter By:
            </div>
            <div className="flex flex-wrap gap-2 justify-center">
              {categories.map((cat) => (
                <button 
                  key={cat}
                  onClick={() => setSelectedCategory(cat)}
                  className={`px-5 py-2 rounded-full text-xs font-black uppercase tracking-widest transition-all ${
                    selectedCategory === cat 
                      ? 'bg-brand-purple text-white shadow-lg shadow-brand-purple/40 scale-105' 
                      : 'bg-brand-surface text-gray-400 hover:text-white hover:bg-white/10 border border-white/5'
                  }`}
                >
                  {cat.split(' / ')[0]}
                </button>
              ))}
            </div>
          </div>
        </div>

        <div className="mb-8 flex items-center justify-between border-b border-white/5 pb-4">
          <span className="text-sm text-gray-500 font-medium">
            Showing <span className="text-white font-bold">{filteredArtists.length}</span> results
          </span>
          { (searchTerm || selectedCategory !== 'All Categories') && (
            <button 
              onClick={clearAllFilters}
              className="text-xs font-bold text-brand-pink hover:underline uppercase tracking-widest"
            >
              Clear All Filters
            </button>
          )}
        </div>

        {filteredArtists.length > 0 ? (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-8">
            {filteredArtists.map(artist => (
              <div key={artist.id} className="animate-in fade-in slide-in-from-bottom-4 duration-500">
                <ArtistCard artist={artist} />
              </div>
            ))}
          </div>
        ) : (
          <div className="py-20 text-center">
            <div className="inline-flex items-center justify-center w-20 h-20 rounded-full bg-white/5 mb-6 text-gray-600">
              <Search size={40} />
            </div>
            <h3 className="text-2xl font-bold text-white mb-2">No talent found</h3>
            <p className="text-gray-400">Try adjusting your search terms or category filters.</p>
          </div>
        )}
      </div>
    </div>
  );
};
