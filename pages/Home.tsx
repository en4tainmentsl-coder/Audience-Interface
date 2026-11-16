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
          talent_stats (rating_average, rating_count),
          profile_status,
          is_public,
          is_featured,
          feature_sort_order,
          type_of_performer,
          primary_location,
          profile_photo_url,
          talent_media (cloudinary_secure_url, is_featured, resource_type),
          primary_genre:genres!profiles_talent_primary_genre_id_fkey (genre_name),
          secondary_genre:genres!profiles_talent_secondary_genre_id_fkey (genre_name),
          tertiary_genre:genres!profiles_talent_tertiary_genre_id_fkey (genre_name)
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
          const genres: string[] = [talent.primary_genre, talent.secondary_genre, talent.tertiary_genre]
            .filter(Boolean).map((g: any) => g.genre_name);
          const primaryGenre: string = genres[0] || 'Artist';
          const featuredImage: string = media.find(m => m.is_featured && m.resource_type === 'image')?.cloudinary_secure_url || talent.profile_photo_url || '';
          
          return {
            id: talent.id,
            name: talent.stage_name,
            imageUrl: featuredImage,
            description: talent.short_bio || '',
            bio: talent.bio || '',
            category: primaryGenre,
            genres,
            stats: talent.talent_stats,
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
          {/* Stage atmosphere, rendered in CSS. Replaced a 406 kB hotlinked
              Unsplash file that sat at opacity-50 under the gradients below,
              so almost none of the photograph was ever visible. */}
          <div
            className="absolute inset-0 animate-slow-zoom"
            style={{
              backgroundColor: '#0f0518',
              backgroundImage:
                'radial-gradient(ellipse 85% 70% at 22% 2%, rgba(139,92,246,.55), transparent 65%),' +
                'radial-gradient(ellipse 70% 55% at 92% 12%, rgba(236,72,153,.42), transparent 62%),' +
                'radial-gradient(ellipse 100% 60% at 50% 108%, rgba(67,56,202,.50), transparent 68%),' +
                'radial-gradient(ellipse 45% 40% at 75% 70%, rgba(163,230,53,.14), transparent 72%)',
            }}
          />
          <div
            className="absolute inset-0"
            style={{
              backgroundImage:
                'linear-gradient(192deg, rgba(139,92,246,.30) 0%, rgba(139,92,246,.10) 22%, transparent 48%),' +
                'linear-gradient(168deg, rgba(236,72,153,.26) 0%, rgba(236,72,153,.08) 26%, transparent 52%),' +
                'linear-gradient(205deg, rgba(163,230,53,.14) 0%, transparent 38%)',
              backgroundSize: '42% 100%, 38% 100%, 30% 100%',
              backgroundPosition: '14% 0, 68% 0, 42% 0',
              backgroundRepeat: 'no-repeat',
              filter: 'blur(14px)',
            }}
          />
          <div
            className="absolute inset-0 animate-slow-zoom"
            style={{
              backgroundImage:
                'radial-gradient(circle, rgba(255,255,255,.95) 1.5px, transparent 2.4px),' +
                'radial-gradient(circle, rgba(163,230,53,.85) 1.4px, transparent 2.2px),' +
                'radial-gradient(circle, rgba(236,72,153,.85) 2.0px, transparent 3.0px),' +
                'radial-gradient(circle, rgba(255,255,255,.60) 1.1px, transparent 1.9px),' +
                'radial-gradient(circle, rgba(167,139,250,.90) 1.8px, transparent 2.7px)',
              backgroundSize: '211px 173px, 317px 263px, 439px 367px, 157px 199px, 373px 311px',
              backgroundPosition: '0 0, 47px 83px, 131px 29px, 73px 127px, 211px 157px',
              opacity: 0.9,
              WebkitMaskImage:
                'linear-gradient(to bottom, #000 0%, rgba(0,0,0,.85) 30%, rgba(0,0,0,.25) 62%, transparent 85%)',
              maskImage:
                'linear-gradient(to bottom, #000 0%, rgba(0,0,0,.85) 30%, rgba(0,0,0,.25) 62%, transparent 85%)',
            }}
          />
          <div
            className="absolute inset-0"
            style={{
              backgroundImage:
                'radial-gradient(circle 80px at 12% 70%, rgba(236,72,153,.26), transparent 70%),' +
                'radial-gradient(circle 130px at 80% 16%, rgba(139,92,246,.30), transparent 70%),' +
                'radial-gradient(circle 60px at 60% 86%, rgba(163,230,53,.16), transparent 70%),' +
                'radial-gradient(circle 100px at 36% 22%, rgba(255,255,255,.10), transparent 70%),' +
                'radial-gradient(circle 70px at 93% 58%, rgba(236,72,153,.18), transparent 70%)',
              filter: 'blur(3px)',
            }}
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
