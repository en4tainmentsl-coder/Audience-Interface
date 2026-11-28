import React from 'react';
import { Music, Star, Users } from 'lucide-react';

export const About: React.FC = () => {
  return (
    <div className="pt-20 min-h-screen bg-brand-dark text-white" id="about-page">
      
      {/* Hero */}
      <div className="relative h-[400px] flex items-center justify-center bg-brand-surface overflow-hidden">
        {/* Stage atmosphere in CSS. Replaced a random picsum.photos image that
            rendered at opacity-30 with mix-blend-overlay, so what showed here
            was never a design decision. */}
        <div
          className="absolute inset-0"
          style={{
            backgroundColor: '#1e1b2e',
            backgroundImage:
              'radial-gradient(ellipse 80% 90% at 18% 0%, rgba(139,92,246,.42), transparent 66%),' +
              'radial-gradient(ellipse 65% 80% at 88% 8%, rgba(236,72,153,.30), transparent 64%),' +
              'radial-gradient(ellipse 70% 70% at 55% 100%, rgba(67,56,202,.34), transparent 70%)',
          }}
        />
        <div
          className="absolute inset-0"
          style={{
            backgroundImage:
              'radial-gradient(circle, rgba(255,255,255,.80) 1.3px, transparent 2.1px),' +
              'radial-gradient(circle, rgba(163,230,53,.70) 1.2px, transparent 2.0px),' +
              'radial-gradient(circle, rgba(236,72,153,.72) 1.7px, transparent 2.6px)',
            backgroundSize: '197px 163px, 311px 257px, 419px 353px',
            backgroundPosition: '0 0, 43px 79px, 127px 31px',
            opacity: 0.75,
            WebkitMaskImage: 'linear-gradient(to bottom, #000 0%, rgba(0,0,0,.6) 45%, transparent 88%)',
            maskImage: 'linear-gradient(to bottom, #000 0%, rgba(0,0,0,.6) 45%, transparent 88%)',
          }}
        />
        <div className="absolute inset-0 bg-linear-to-b from-transparent to-brand-dark" />
        <div className="relative z-10 text-center px-4">
          <h1 className="text-5xl font-bold mb-4">About En4tainment</h1>
          <p className="text-xl text-gray-300">Staging the future of music.</p>
        </div>
      </div>

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-20">
        
        {/* Mission Section */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-16 items-center mb-24">
          <div>
            <h2 className="text-3xl font-bold text-white mb-6">Our Mission</h2>
            <p className="text-gray-300 text-lg leading-relaxed mb-6">
              En4tainment exists to bridge the gap between talented emerging artists and the audiences who crave authentic live performances. 
              We believe that every artist deserves a stage, and every event deserves a soundtrack that resonates.
            </p>
            <p className="text-gray-300 text-lg leading-relaxed">
              Inspired by the vibrant energy of live music culture, we have built a platform that is visually immersive and functionally seamless, 
              allowing the You to not just book artists, but to become part of their journey through our unique rating system.
            </p>
          </div>
          <div className="relative">
             <div className="absolute -inset-4 bg-linear-to-r from-brand-pink to-brand-purple rounded-xl opacity-30 blur-lg"></div>
             <img 
              src="https://picsum.photos/id/452/600/400" 
              alt="Mission" 
              className="relative rounded-xl shadow-2xl border border-white/10 w-full"
            />
          </div>
        </div>

        {/* How it works */}
        <div className="mb-20">
           <h2 className="text-3xl font-bold text-center text-white mb-16">How It Works</h2>
           <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
              <div className="bg-brand-surface p-8 rounded-2xl border border-white/5 text-center hover:border-brand-lime/50 transition-colors">
                <div className="w-16 h-16 bg-brand-purple/20 rounded-full flex items-center justify-center mx-auto mb-6 text-brand-purple">
                  <Users size={32} />
                </div>
                <h3 className="text-xl font-bold mb-4">For Artists</h3>
                <p className="text-gray-400">
                  Create a stunning profile, upload your best performances, and get discovered by event planners and fans.
                </p>
              </div>

              <div className="bg-brand-surface p-8 rounded-2xl border border-white/5 text-center hover:border-brand-pink/50 transition-colors">
                <div className="w-16 h-16 bg-brand-pink/20 rounded-full flex items-center justify-center mx-auto mb-6 text-brand-pink">
                  <Star size={32} />
                </div>
                <h3 className="text-xl font-bold mb-4">Rate & Review</h3>
                <p className="text-gray-400">
                  Fans can view performances and leave 5-star ratings, helping top talent rise to the featured spot on our homepage.
                </p>
              </div>

              <div className="bg-brand-surface p-8 rounded-2xl border border-white/5 text-center hover:border-brand-lime/50 transition-colors">
                <div className="w-16 h-16 bg-brand-lime/20 rounded-full flex items-center justify-center mx-auto mb-6 text-brand-lime">
                  <Music size={32} />
                </div>
                <h3 className="text-xl font-bold mb-4">Book Live Music</h3>
                <p className="text-gray-400">
                  Request a quotation for any artist directly through the platform. We connect the artist so you can enjoy the show.
                </p>
              </div>
           </div>
        </div>

      </div>
    </div>
  );
};
