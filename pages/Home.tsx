import React, { useState, useEffect } from 'react';
import { Link } from 'react-router';
import { Button } from '../components/Button';
import { FlexArtistCardRow } from '../components/FlexArtistCard';

import { Sparkles, Star } from 'lucide-react';
import { supabase } from '../services/supabase';
import { Artist } from '../types';

export const Home: React.FC = () => {
  const [featuredArtists, setFeaturedArtists] = useState<Artist[]>([]);

  const fetchFeaturedArtists = async (): Promise<void> => {
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
        .order('feature_sort_order', { ascending: true })
        .limit(3);
      
      if (data && data.length > 0) {
        const mappedArtists: Artist[] = data.map((talent: any) => {
          const rawMedia = talent.talent_media;
          const media = Array.isArray(rawMedia)
            ? rawMedia
            : (rawMedia && typeof rawMedia === 'object' ? [rawMedia] : []);
          const genres = (talent.talent_genres as Array<{ is_primary: boolean; genres?: { genre_name: string } }>) || [];

          const primaryGenre: string = genres.find(g => g.is_primary)?.genres?.genre_name || 'Artist';
          const featuredImage: string = media.find(m => m.is_featured && m.resource_type === 'image')?.cloudinary_secure_url || talent.profile_photo_url || '';
          
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
        setFeaturedArtists(mappedArtists);
      }
    } catch (error) {
      console.error('Error fetching featured artists:', error);
    }
  };

  useEffect(() => {
    fetchFeaturedArtists();
  }, []);

  // Derive from real is_featured flag rather than an arbitrary slice.
  // Falls back to nothing if the DB hasn't flagged anyone yet — cards
  // simply render at standard size until Rising Stars is populated.
  const featuredIds = featuredArtists.filter(a => a.is_featured).map(a => a.id);

  return (
    <div className="min-h-screen" id="home-page">
      
      <section className="relative h-screen flex items-center overflow-hidden">
        <div className="absolute inset-0 z-0">
          <img 
            src="https://images.unsplash.com/photo-1492684223066-81342ee5ff30?auto=format&fit=crop&q=80&w=1920" 
            alt="Concert Stage Atmosphere" 
            className="w-full h-full object-cover opacity-50 contrast-125 scale-105 animate-slow-zoom"
          />
          <div className="absolute inset-0 bg-gradient-to-t from-brand-dark via-brand-dark/70 to-brand-purple/20" />
          <div className="absolute inset-0 bg-gradient-to-r from-brand-dark via-transparent to-brand-dark" />
        </div>

        <div className="relative z-10 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 text-left">
          <div className="max-w-3xl">
            <div className="inline-flex items-center gap-2 bg-white/10 backdrop-blur-md px-4 py-1.5 rounded-full border border-white/20 mb-8 animate-fade-in-up">
              <Sparkles className="text-brand-lime w-4 h-4" />
              <span className="text-sm font-bold tracking-wider text-brand-lime uppercase">Staging the Future</span>
            </div>
            <h1 className="text-6xl sm:text-8xl font-black text-white leading-tight mb-8 animate-fade-in-up delay-100">
              Discover <br/>
              <span className="text-transparent bg-clip-text bg-gradient-to-r from-brand-pink via-brand-purple to-brand-lime">
                The New Stars
              </span>
            </h1>
            <p className="text-xl text-gray-300 mb-12 max-w-xl leading-relaxed animate-fade-in-up delay-200">
              The premier staging platform for upcoming musicians. Connect with artists, rate their performances, and book them for your next unforgettable event.
            </p>
            <div className="flex flex-col sm:flex-row gap-6 animate-fade-in-up delay-300">
              <Link to="/artists" id="explore-artists-hero">
                <Button size="lg" variant="primary" className="group">
                  Explore Artists
                  <Star className="ml-2 group-hover:rotate-45 transition-transform" size={18} />
                </Button>
              </Link>
              <Link to="/request-quote" id="book-artists-hero">
                <Button size="lg" variant="outline">
                  Book Artists Now
                </Button>
              </Link>
            </div>
          </div>
        </div>
        
        <div className="absolute bottom-1/4 right-1/4 w-96 h-96 bg-brand-pink/20 blur-[150px] rounded-full animate-pulse" />
        <div className="absolute top-1/4 left-1/4 w-64 h-64 bg-brand-purple/20 blur-[120px] rounded-full animate-bounce-slow" />
      </section>

      <section className="py-32 bg-brand-dark relative text-left" id="rising-stars-section">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex flex-col md:flex-row justify-between items-end mb-16 gap-6">
            <div className="max-w-lg">
              <h2 className="text-4xl font-black text-white mb-4 uppercase tracking-tighter">Rising Stars</h2>
              <p className="text-gray-400">Our hand-picked selection of popular artists are ready to headline your next big moment.</p>
              <div className="h-1.5 w-24 bg-brand-lime mt-4 rounded-full"></div>
            </div>
            <Link to="/artists" id="view-entire-roster">
              <Button variant="outline" size="sm">View Entire Roster &rarr;</Button>
            </Link>
          </div>
          
          <FlexArtistCardRow artists={featuredArtists} featuredIds={featuredIds} />
        </div>
      </section>

      <section className="py-40 bg-brand-dark relative overflow-hidden" id="cta-section">
        <div className="absolute inset-0 opacity-10">
          <div className="absolute top-0 left-0 w-full h-full bg-[radial-gradient(circle_at_50%_50%,#8b5cf6_0%,transparent_50%)]" />
        </div>
        <div className="max-w-4xl mx-auto px-4 text-center relative z-10">
          <h2 className="text-5xl md:text-6xl font-black text-white mb-8 uppercase tracking-tighter">Your Event. <br/> Our Soundtrack.</h2>
          <p className="text-xl text-gray-400 mb-12 leading-relaxed">
            From bespoke corporate events to electric public festivals, we provide the artists that turn moments into memories.
          </p>
          <div className="flex flex-col sm:flex-row gap-6 justify-center">
            <Link to="/request-quote" id="request-quote-bottom">
              <Button size="lg" variant="primary" className="px-12 py-5 text-xl animate-pulse-slow">
                Request a Free Quote
              </Button>
            </Link>
          </div>
        </div>
      </section>

      <style>{`
        @keyframes slow-zoom {
          0% { transform: scale(1); }
          50% { transform: scale(1.1); }
          100% { transform: scale(1); }
        }
        .animate-slow-zoom {
          animation: slow-zoom 20s infinite ease-in-out;
        }
        .animate-pulse-slow {
          animation: pulse 4s cubic-bezier(0.4, 0, 0.6, 1) infinite;
        }
        @keyframes fade-in-up {
          from { opacity: 0; transform: translateY(20px); }
          to { opacity: 1; transform: translateY(0); }
        }
        .animate-fade-in-up {
          animation: fade-in-up 0.8s ease-out forwards;
        }
        .delay-100 { animation-delay: 0.1s; }
        .delay-200 { animation-delay: 0.2s; }
        .delay-300 { animation-delay: 0.3s; }
      `}</style>
    </div>
  );
};
