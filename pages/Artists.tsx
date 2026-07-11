import React, { useState, useMemo, useEffect } from 'react';
import { useSearchParams } from 'react-router-dom';
import { FlexArtistCardRow } from '../components/FlexArtistCard';
import { ARTISTS as STATIC_ARTISTS } from '../constants';
import { Search, SlidersHorizontal, X } from 'lucide-react';
import { supabase } from '../services/supabase';
import { Artist } from '../types';

export const Artists: React.FC = () => {
  const [searchParams, setSearchParams] = useSearchParams();
  const urlQuery: string = searchParams.get('q') || '';
  
  const [searchTerm, setSearchTerm] = useState<string>(urlQuery);
  const [selectedCategory, setSelectedCategory] = useState<string>('All Categories');
  const [artists, setArtists] = useState<Artist[]>(STATIC_ARTISTS);

  const fetchArtists = async (): Promise<void> => {
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
          is_featured,
          feature_sort_order,
          type_of_performer,
          primary_location,
          profile_photo_url,
          talent_media (cloudinary_secure_url, is_featured, resource_type),
          talent_genres (genre_id, is_primary, genres (genre_name))
        `)
        .eq('is_public', true)
        .eq('profile_status', 'active')
        .order('is_featured', { ascending: false })
        .order('feature_sort_order', { ascending: true });
      
      if (data && data.length > 0) {
        // Safe casting the returned Supabase types
        const mappedArtists: Artist[] = data.map((talent: any) => {
          const media = (talent.talent_media as Array<{ cloudinary_secure_url: string; is_featured: boolean; resource_type: string }>) || [];
          const genres = (talent.talent_genres as Array<{ is_primary: boolean; genres?: { genre_name: string } }>) || [];

          const primaryGenre: string = genres.find(g => g.is_primary)?.genres?.genre_name || 'Artist';
          const featuredImage: string = 
            media.find(m => m.is_featured && m.resource_type === 'image')
              ?.cloudinary_secure_url 
              || talent.profile_photo_url   // fallback to direct URL on profiles_talent
              || '';                        // final fallback empty string
          
          return {
            id: talent.id,
            name: talent.stage_name,
            imageUrl: featuredImage,
            description: talent.short_bio || '',
            bio: talent.bio || '',
            category: primaryGenre,
            rating: talent.rating || 0,
            gallery: media.filter(m => m.resource_type === 'image').map(m => m.cloudinary_secure_url) || [],
            is_featured: !!talent.is_featured,
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

  useEffect(() => {
    fetchArtists();
  }, []);

  const categories: string[] = ['All Categories', 'Electronic / DJ', 'Rock / Alternative', 'Jazz / Blues', 'Acoustic / Indie'];

  useEffect(() => {
    setSearchTerm(urlQuery);
  }, [urlQuery]);

  const handleSearchChange = (value: string): void => {
    setSearchTerm(value);
    const newParams: URLSearchParams = new URLSearchParams(searchParams);
    if (value) {
      newParams.set('q', value);
    } else {
      newParams.delete('q');
    }
    setSearchParams(newParams, { replace: true });
  };

  const filteredArtists: Artist[] = useMemo(() => {
    return artists.filter((artist: Artist) => {
      const matchesSearch: boolean = artist.name.toLowerCase().includes(searchTerm.toLowerCase()) || 
                                   artist.description.toLowerCase().includes(searchTerm.toLowerCase()) ||
                                   artist.category.toLowerCase().includes(searchTerm.toLowerCase());
      const matchesCategory: boolean = selectedCategory === 'All Categories' || artist.category === selectedCategory;
      return matchesSearch && matchesCategory;
    });
  }, [searchTerm, selectedCategory, artists]);

  // Real is_featured flag drives headliner sizing in the roster view too
  const featuredIds = useMemo(
    () => filteredArtists.filter(a => a.is_featured).map(a => a.id),
    [filteredArtists]
  );

  const clearAllFilters = (): void => {
    setSearchTerm('');
    setSelectedCategory('All Categories');
    const newParams: URLSearchParams = new URLSearchParams(searchParams);
    newParams.delete('q');
    setSearchParams(newParams, { replace: true });
  };

  return (
    <div className="pt-32 pb-20 min-h-screen bg-brand-dark" id="artists-page">
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
              onChange={(e: React.ChangeEvent<HTMLInputElement>) => handleSearchChange(e.target.value)}
              className="block w-full pl-12 pr-12 py-4 bg-brand-surface border border-white/10 rounded-2xl text-white placeholder:text-gray-600 focus:outline-none focus:ring-2 focus:ring-brand-purple/50 focus:border-brand-purple transition-all shadow-xl"
            />
            {searchTerm && (
              <button 
                onClick={() => handleSearchChange('')}
                className="absolute inset-y-0 right-0 pr-4 flex items-center text-gray-500 hover:text-white transition-colors"
                id="clear-search-btn"
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
              {categories.map((cat: string) => (
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
          <span className="text-sm text-gray-500 font-medium text-left">
            Showing <span className="text-white font-bold">{filteredArtists.length}</span> results
          </span>
          { (searchTerm || selectedCategory !== 'All Categories') && (
            <button 
              onClick={clearAllFilters}
              className="text-xs font-bold text-brand-pink hover:underline uppercase tracking-widest"
              id="clear-all-filters-btn"
            >
              Clear All Filters
            </button>
          )}
        </div>

        {filteredArtists.length > 0 ? (
          <FlexArtistCardRow artists={filteredArtists} featuredIds={featuredIds} />
        ) : (
          <div className="py-20 text-center" id="no-artists-found">
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
