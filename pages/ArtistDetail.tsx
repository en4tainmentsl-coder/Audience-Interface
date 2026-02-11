
import React, { useEffect, useState } from 'react';
import { useParams, Link } from 'react-router-dom';
import { ARTISTS } from '../constants';
import { Artist } from '../types';
import { Button } from '../components/Button';
import { StarRating } from '../components/StarRating';
import { PlayCircle } from 'lucide-react';

export const ArtistDetail: React.FC = () => {
  const { id } = useParams<{ id: string }>();
  const [artist, setArtist] = useState<Artist | null>(null);

  useEffect(() => {
    const found = ARTISTS.find(a => a.id === id);
    setArtist(found || null);
  }, [id]);

  if (!artist) return <div className="pt-32 text-center text-white">Artist not found</div>;

  return (
    <div className="pt-20 min-h-screen bg-brand-dark text-white">
      
      <div className="relative h-[50vh] w-full">
        <img 
          src={artist.imageUrl} 
          alt={artist.name} 
          className="w-full h-full object-cover object-top opacity-60"
        />
        <div className="absolute inset-0 bg-gradient-to-t from-brand-dark via-brand-dark/50 to-transparent" />
        <div className="absolute bottom-0 left-0 w-full p-8 md:p-12 max-w-7xl mx-auto">
          <span className="bg-brand-lime text-brand-dark font-bold px-3 py-1 rounded mb-4 inline-block">
            {artist.category}
          </span>
          <h1 className="text-5xl md:text-7xl font-bold mb-2">{artist.name}</h1>
          <div className="flex items-center gap-4 mb-6">
            <StarRating initialRating={artist.rating} readonly size={24} />
            <span className="text-xl font-semibold text-brand-purple">{artist.rating}/5.0</span>
          </div>
          <Link to={`/request-quote?artistId=${artist.id}`}>
            <Button size="lg" variant="primary">Request Quotation</Button>
          </Link>
        </div>
      </div>

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-16 grid grid-cols-1 lg:grid-cols-3 gap-12">
        
        <div className="lg:col-span-2">
          <section className="mb-12">
            <h2 className="text-2xl font-bold mb-6 border-l-4 border-brand-pink pl-4">About the Artist</h2>
            <p className="text-gray-300 leading-loose text-lg">
              {artist.bio}
            </p>
          </section>

          <section>
            <h2 className="text-2xl font-bold mb-6 border-l-4 border-brand-lime pl-4">Gallery & Performances</h2>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              {artist.gallery.map((img, idx) => (
                <div key={idx} className="relative group rounded-lg overflow-hidden h-64 bg-gray-900">
                  <img src={img} alt="Gallery" className="w-full h-full object-cover group-hover:opacity-75 transition-opacity" />
                  <div className="absolute inset-0 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity">
                    <PlayCircle className="text-white w-12 h-12 drop-shadow-lg" />
                  </div>
                </div>
              ))}
            </div>
          </section>
        </div>

        <div className="lg:col-span-1 space-y-8">
          <div className="bg-brand-surface p-6 rounded-xl border border-white/5">
            <h3 className="text-xl font-bold mb-4">Rate this Artist</h3>
            <p className="text-gray-400 text-sm mb-4">Seen them live? Leave a rating!</p>
            <div className="flex justify-center py-4 bg-brand-dark/50 rounded-lg">
               <StarRating initialRating={0} size={32} onRate={(val) => alert(`You rated ${val} stars! (Demo)`)} />
            </div>
          </div>
          
          <div className="bg-gradient-to-br from-brand-indigo to-brand-purple p-6 rounded-xl shadow-xl">
             <h3 className="text-xl font-bold mb-2">Want to book {artist.name}?</h3>
             <p className="text-white/80 text-sm mb-6">Dates fill up fast. Secure your spot today.</p>
             <Link to={`/request-quote?artistId=${artist.id}`} className="block">
               <button className="w-full py-3 bg-white text-brand-purple font-bold rounded-lg hover:bg-brand-lime hover:text-brand-dark transition-colors">
                 Get a Quote
               </button>
             </Link>
          </div>
        </div>

      </div>
    </div>
  );
};
