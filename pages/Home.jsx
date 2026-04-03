
import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { Button } from '../components/Button';
import { ArtistCard } from '../components/ArtistCard';
import { ARTISTS as STATIC_ARTISTS, RECENT_PERFORMANCES } from '../constants';
import { Play, Sparkles, Star, Calendar } from 'lucide-react';
import { supabase } from '../services/supabase';

export const Home = () => {
  const [featuredArtists, setFeaturedArtists] = useState(STATIC_ARTISTS.slice(0, 3));

  useEffect(() => {
    fetchFeaturedArtists();
  }, []);

  const fetchFeaturedArtists = async () => {
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
        .eq('profile_status', 'active')
        .limit(3);
      
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
        setFeaturedArtists(mappedArtists);
      }
    } catch (error) {
      console.error('Error fetching featured artists:', error);
    }
  };

  return (
    <div className="min-h-screen">
      
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

        <div className="relative z-10 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
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
              <Link to="/artists">
                <Button size="lg" variant="primary" className="group">
                  Explore Artists
                  <Star className="ml-2 group-hover:rotate-45 transition-transform" size={18} />
                </Button>
              </Link>
              <Link to="/request-quote">
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

      <section className="py-32 bg-brand-dark relative">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex flex-col md:flex-row justify-between items-end mb-16 gap-6">
            <div className="max-w-lg">
              <h2 className="text-4xl font-black text-white mb-4 uppercase tracking-tighter">Rising Stars</h2>
              <p className="text-gray-400">Our hand-picked selection of popular artists are ready to headline your next big moment.</p>
              <div className="h-1.5 w-24 bg-brand-lime mt-4 rounded-full"></div>
            </div>
            <Link to="/artists">
              <Button variant="outline" size="sm">View Entire Roster &rarr;</Button>
            </Link>
          </div>
          
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-10">
            {featuredArtists.map(artist => (
              <ArtistCard key={artist.id} artist={artist} />
            ))}
          </div>
        </div>
      </section>

      <section className="py-32 bg-brand-surface relative overflow-hidden">
        <div className="absolute top-0 left-0 w-full h-1.5 bg-gradient-to-r from-brand-purple via-brand-pink to-brand-lime" />
        
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-20">
            <h2 className="text-5xl font-black text-white mb-4 uppercase tracking-tighter">Live & Loud</h2>
            <p className="text-gray-400 max-w-2xl mx-auto">Witness the energy. Experience the sound. Recent highlights from En4tainment stages.</p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
            {RECENT_PERFORMANCES.map((perf) => (
              <div key={perf.id} className="group relative rounded-2xl overflow-hidden aspect-[4/5] shadow-2xl cursor-pointer">
                <img 
                  src={perf.imageUrl} 
                  alt={perf.venue} 
                  className="w-full h-full object-cover transition-transform duration-1000 group-hover:scale-110 filter brightness-75 group-hover:brightness-100"
                />
                <div className="absolute inset-0 bg-gradient-to-t from-brand-dark via-brand-dark/20 to-transparent" />
                
                <div className="absolute inset-0 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity duration-500">
                  <div className="w-20 h-20 rounded-full bg-brand-lime flex items-center justify-center pl-1 shadow-2xl shadow-brand-lime/30 transform scale-50 group-hover:scale-100 transition-transform duration-500">
                    <Play fill="#0f0518" className="text-brand-dark" size={32} />
                  </div>
                </div>

                <div className="absolute bottom-0 left-0 right-0 p-8 transform translate-y-4 group-hover:translate-y-0 transition-transform duration-500">
                  <div className="flex items-center gap-2 mb-2">
                    <Calendar size={14} className="text-brand-lime" />
                    <span className="text-brand-lime text-xs font-bold uppercase tracking-widest">
                      {new Date(perf.date).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })}
                    </span>
                  </div>
                  <h4 className="text-2xl font-black text-white mb-1 group-hover:text-brand-pink transition-colors">{perf.artistName}</h4>
                  <p className="text-gray-300 text-sm italic">Live at {perf.venue}</p>
                </div>
              </div>
            ))}
          </div>
          
          <div className="mt-20 text-center">
             <Link to="/artists">
              <Button variant="secondary" size="lg">Rate a Performance</Button>
             </Link>
          </div>
        </div>
      </section>

      <section className="py-40 bg-brand-dark relative overflow-hidden">
        <div className="absolute inset-0 opacity-10">
          <div className="absolute top-0 left-0 w-full h-full bg-[radial-gradient(circle_at_50%_50%,#8b5cf6_0%,transparent_50%)]" />
        </div>
        <div className="max-w-4xl mx-auto px-4 text-center relative z-10">
          <h2 className="text-5xl md:text-6xl font-black text-white mb-8 uppercase tracking-tighter">Your Event. <br/> Our Soundtrack.</h2>
          <p className="text-xl text-gray-400 mb-12 leading-relaxed">
            From bespoke corporate events to electric public festivals, we provide the artists that turn moments into memories.
          </p>
          <div className="flex flex-col sm:flex-row gap-6 justify-center">
            <Link to="/request-quote">
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
