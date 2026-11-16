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
        {/* Stage rig, entirely in CSS - ten lamps in four composited groups.
            No image files, no blur filters, nothing on the main thread.

            These layers are FIXED, not absolute, at z-index -1. Pinning them to
            the viewport is what keeps the rig lit while the page scrolls over
            it; -1 puts them behind every static element (the Footer included)
            without needing a z-index on each section. The sections below are
            translucent so the rig reads through them. */}
        <div className="stage-layer stage-wash" aria-hidden="true" />
        <div className="stage-layer stage-beam stage-beam1" aria-hidden="true" />
        <div className="stage-layer stage-beam stage-beam2" aria-hidden="true" />
        <div className="stage-layer stage-beam stage-beam3" aria-hidden="true" />
        <div className="stage-layer stage-beam stage-beam4" aria-hidden="true" />
        <div className="stage-layer stage-pool" aria-hidden="true" />
        <div className="stage-layer stage-specks" aria-hidden="true" />
        <div className="stage-layer stage-grad-t" aria-hidden="true" />
        <div className="stage-layer stage-grad-r" aria-hidden="true" />

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

      <section className="pt-[13rem] pb-32 relative text-left stage-veil-first" id="rising-stars-section">
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

      <section className="py-40 relative overflow-hidden stage-veil" id="cta-section">
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

        /* ---------------- STAGE RIG ----------------
           Ten lamps in four rotating groups. Each group carries its own beams
           AND their lamp glows so a beam stays attached to its fixture, and
           pivots as one truss. Four composited textures, not ten.

           Beams are conic gradients: soft edges for free, with no blur filter
           and so no per-frame GPU work on a low-end phone.

           0deg points up and angles grow clockwise; each wedge peaks about
           16deg after its "from", so effective aim is roughly from + 16.
           180 is straight down. */

        .stage-layer {
          position: fixed;
          inset: 0;
          z-index: -1;
          pointer-events: none;
        }
        .stage-beam { will-change: transform; }

        .stage-wash {
          background-color: #0f0518;
          background-image:
            radial-gradient(ellipse 55% 42% at 50% 0%,    rgba(124,58,237,.30), transparent 70%),
            radial-gradient(ellipse 85% 70% at 22% 2%,    rgba(139,92,246,.40), transparent 65%),
            radial-gradient(ellipse 70% 55% at 88% 6%,    rgba(124,58,237,.34), transparent 62%),
            radial-gradient(ellipse 100% 62% at 50% 108%, rgba(67,56,202,.40),  transparent 68%);
        }

        /* LEFT BANK - 3 lamps on the left edge, raking right and down */
        .stage-beam1 {
          transform-origin: 2% 31%;
          background:
            radial-gradient(circle 44px at 3% 13%, rgba(167,139,250,.30), transparent 72%),
            radial-gradient(circle 8px  at 3% 13%, rgba(237,233,254,.92), transparent 75%),
            radial-gradient(circle 48px at 2% 31%, rgba(139,92,246,.30), transparent 72%),
            radial-gradient(circle 9px  at 2% 31%, rgba(245,243,255,.94), transparent 75%),
            radial-gradient(circle 42px at 3% 49%, rgba(124,58,237,.26), transparent 72%),
            radial-gradient(circle 7px  at 3% 49%, rgba(221,214,254,.84), transparent 75%),
            conic-gradient(from 129deg at 3% 13%,
              transparent 0deg, rgba(167,139,250,.00) 4deg, rgba(167,139,250,.32) 11deg,
              rgba(221,214,254,.42) 16deg, rgba(167,139,250,.27) 22deg, rgba(167,139,250,.00) 30deg, transparent 35deg),
            conic-gradient(from 116deg at 2% 31%,
              transparent 0deg, rgba(139,92,246,.00) 4deg, rgba(139,92,246,.24) 11deg,
              rgba(196,181,253,.31) 16deg, rgba(139,92,246,.19) 22deg, rgba(139,92,246,.00) 29deg, transparent 34deg),
            conic-gradient(from 104deg at 3% 49%,
              transparent 0deg, rgba(124,58,237,.00) 4deg, rgba(124,58,237,.20) 10deg,
              rgba(196,181,253,.26) 15deg, rgba(124,58,237,.16) 21deg, rgba(124,58,237,.00) 28deg, transparent 33deg);
        }

        /* OVERHEAD - inner pair */
        .stage-beam2 {
          transform-origin: 24% 1%;
          background:
            radial-gradient(circle 46px at 12% 1%, rgba(167,139,250,.31), transparent 72%),
            radial-gradient(circle 8px  at 12% 1%, rgba(237,233,254,.92), transparent 75%),
            radial-gradient(circle 50px at 37% 1%, rgba(139,92,246,.33), transparent 72%),
            radial-gradient(circle 9px  at 37% 1%, rgba(245,243,255,.95), transparent 75%),
            conic-gradient(from 139deg at 12% 1%,
              transparent 0deg, rgba(167,139,250,.00) 4deg, rgba(167,139,250,.29) 11deg,
              rgba(237,233,254,.38) 16deg, rgba(167,139,250,.23) 22deg, rgba(167,139,250,.00) 30deg, transparent 35deg),
            conic-gradient(from 156deg at 37% 1%,
              transparent 0deg, rgba(139,92,246,.00) 4deg, rgba(139,92,246,.27) 11deg,
              rgba(221,214,254,.36) 16deg, rgba(139,92,246,.21) 22deg, rgba(139,92,246,.00) 29deg, transparent 34deg);
        }

        /* OVERHEAD - outer pair */
        .stage-beam3 {
          transform-origin: 76% 1%;
          background:
            radial-gradient(circle 50px at 63% 1%, rgba(139,92,246,.33), transparent 72%),
            radial-gradient(circle 9px  at 63% 1%, rgba(245,243,255,.95), transparent 75%),
            radial-gradient(circle 46px at 88% 1%, rgba(167,139,250,.31), transparent 72%),
            radial-gradient(circle 8px  at 88% 1%, rgba(237,233,254,.92), transparent 75%),
            conic-gradient(from 172deg at 63% 1%,
              transparent 0deg, rgba(139,92,246,.00) 4deg, rgba(139,92,246,.27) 11deg,
              rgba(221,214,254,.36) 16deg, rgba(139,92,246,.21) 22deg, rgba(139,92,246,.00) 29deg, transparent 34deg),
            conic-gradient(from 189deg at 88% 1%,
              transparent 0deg, rgba(167,139,250,.00) 4deg, rgba(167,139,250,.29) 11deg,
              rgba(237,233,254,.38) 16deg, rgba(167,139,250,.23) 22deg, rgba(167,139,250,.00) 30deg, transparent 35deg);
        }

        /* RIGHT BANK - 3 lamps on the right edge, raking left and down */
        .stage-beam4 {
          transform-origin: 98% 31%;
          background:
            radial-gradient(circle 44px at 97% 13%, rgba(167,139,250,.30), transparent 72%),
            radial-gradient(circle 8px  at 97% 13%, rgba(237,233,254,.92), transparent 75%),
            radial-gradient(circle 48px at 98% 31%, rgba(139,92,246,.30), transparent 72%),
            radial-gradient(circle 9px  at 98% 31%, rgba(245,243,255,.94), transparent 75%),
            radial-gradient(circle 42px at 97% 49%, rgba(124,58,237,.26), transparent 72%),
            radial-gradient(circle 7px  at 97% 49%, rgba(221,214,254,.84), transparent 75%),
            conic-gradient(from 199deg at 97% 13%,
              transparent 0deg, rgba(167,139,250,.00) 4deg, rgba(167,139,250,.32) 11deg,
              rgba(221,214,254,.42) 16deg, rgba(167,139,250,.27) 22deg, rgba(167,139,250,.00) 30deg, transparent 35deg),
            conic-gradient(from 212deg at 98% 31%,
              transparent 0deg, rgba(139,92,246,.00) 4deg, rgba(139,92,246,.24) 11deg,
              rgba(196,181,253,.31) 16deg, rgba(139,92,246,.19) 22deg, rgba(139,92,246,.00) 29deg, transparent 34deg),
            conic-gradient(from 224deg at 97% 49%,
              transparent 0deg, rgba(124,58,237,.00) 4deg, rgba(124,58,237,.20) 10deg,
              rgba(196,181,253,.26) 15deg, rgba(124,58,237,.16) 21deg, rgba(124,58,237,.00) 28deg, transparent 33deg);
        }

        .stage-pool {
          background-image:
            radial-gradient(ellipse 30% 5% at 24% 100%, rgba(139,92,246,.16), transparent 70%),
            radial-gradient(ellipse 36% 6% at 46% 99%,  rgba(167,139,250,.24), transparent 70%),
            radial-gradient(ellipse 34% 5% at 68% 100%, rgba(167,139,250,.20), transparent 70%),
            radial-gradient(ellipse 26% 4% at 88% 100%, rgba(139,92,246,.13), transparent 70%);
        }

        .stage-specks {
          background-image:
            radial-gradient(circle, rgba(237,233,254,.90) 1.4px, transparent 2.3px),
            radial-gradient(circle, rgba(167,139,250,.75) 1.3px, transparent 2.1px),
            radial-gradient(circle, rgba(196,181,253,.80) 1.9px, transparent 2.8px),
            radial-gradient(circle, rgba(139,92,246,.85) 1.7px, transparent 2.6px);
          background-size: 211px 173px, 317px 263px, 439px 367px, 373px 311px;
          background-position: 0 0, 47px 83px, 131px 29px, 211px 157px;
          opacity: .85;
          -webkit-mask-image: linear-gradient(to bottom, #000 0%, rgba(0,0,0,.8) 32%, rgba(0,0,0,.2) 64%, transparent 86%);
          mask-image: linear-gradient(to bottom, #000 0%, rgba(0,0,0,.8) 32%, rgba(0,0,0,.2) 64%, transparent 86%);
        }

        /* These two were the hero's contrast gradients. Now the stack is
           pinned they darken the bottom and sides of EVERY screen, not just
           the hero, so both are much softer than they were - at the old
           strength they erased the rig behind the sections entirely. */
        .stage-grad-t {
          background-image: linear-gradient(to top,
            rgba(15,5,24,.58) 0%, rgba(15,5,24,.40) 30%, rgba(15,5,24,.22) 62%, rgba(139,92,246,.18) 100%);
        }
        .stage-grad-r {
          background-image: linear-gradient(to right,
            rgba(15,5,24,.72) 0%, rgba(15,5,24,.38) 26%, transparent 52%, rgba(15,5,24,.30) 100%);
        }

        /* Sections are translucent so the rig stays visible behind them.
           The first one fades in rather than cutting across the beams on a
           hard line. Raise .86 toward .92 if body copy feels strained. */
        .stage-veil { background-color: rgba(15,5,24,.86); }
        .stage-veil-first {
          background-image: linear-gradient(to bottom,
            rgba(15,5,24,0) 0, rgba(15,5,24,.86) 190px, rgba(15,5,24,.86) 100%);
        }

        /* Scroll-driven sweep. animation-timeline runs on the compositor -
           no scroll listener, no rAF, nothing that stutters when the main
           thread is busy. The side banks shoot near-horizontally, so the same
           few degrees moves their far end much further: they swing less. */
        @keyframes stage-sweep-a { from { transform: rotate(-3deg); } to { transform: rotate(4deg); } }
        @keyframes stage-sweep-b { from { transform: rotate(4deg); }  to { transform: rotate(-5deg); } }
        @keyframes stage-sweep-c { from { transform: rotate(-3deg); } to { transform: rotate(7deg); } }
        @keyframes stage-sweep-d { from { transform: rotate(3deg); }  to { transform: rotate(-4deg); } }
        @keyframes stage-drift   { from { transform: translateY(0); } to { transform: translateY(-14%); } }

        @supports (animation-timeline: scroll()) {
          .stage-beam1  { animation: stage-sweep-a linear both; animation-timeline: scroll(); animation-range: 0 240vh; }
          .stage-beam2  { animation: stage-sweep-b linear both; animation-timeline: scroll(); animation-range: 0 240vh; }
          .stage-beam3  { animation: stage-sweep-c linear both; animation-timeline: scroll(); animation-range: 0 240vh; }
          .stage-beam4  { animation: stage-sweep-d linear both; animation-timeline: scroll(); animation-range: 0 240vh; }
          .stage-specks { animation: stage-drift   linear both; animation-timeline: scroll(); animation-range: 0 240vh; }
        }
        /* Browsers without scroll timelines still get motion, just on a timer. */
        @supports not (animation-timeline: scroll()) {
          .stage-beam1 { animation: stage-sweep-a 14s ease-in-out infinite alternate; }
          .stage-beam2 { animation: stage-sweep-b 17s ease-in-out infinite alternate; }
          .stage-beam3 { animation: stage-sweep-c 12s ease-in-out infinite alternate; }
          .stage-beam4 { animation: stage-sweep-d 19s ease-in-out infinite alternate; }
        }
        @media (prefers-reduced-motion: reduce) {
          .stage-beam, .stage-specks { animation: none !important; }
        }
        /* -------------- END STAGE RIG -------------- */
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
