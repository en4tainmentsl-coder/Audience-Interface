
import React from 'react';
import { Facebook, Twitter, Instagram, Mail, Phone, MapPin, ShieldCheck, Youtube } from 'lucide-react';
import { Link } from 'react-router-dom';
import { LOGO_URL, SOCIAL_LINKS } from '../constants';

export const Footer: React.FC = () => {
  return (
    <footer className="bg-brand-surface border-t border-white/5 pt-16 pb-8">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="grid grid-cols-1 md:grid-cols-4 gap-12">
          
          <div className="col-span-1 md:col-span-1">
             <div className="flex items-center gap-2 mb-4">
               <Link to="/">
                 <img
                   src={LOGO_URL}
                   alt="En4tainment"
                   className="h-12 w-auto object-contain"
                 />
               </Link>
            </div>
            <p className="text-gray-400 text-sm leading-relaxed">
              Elevating upcoming artists to the main stage. Connect, rate, and book the future stars of music.
            </p>
          </div>

          <div>
            <h3 className="text-white font-semibold mb-4 border-b border-brand-lime w-fit pb-1">Quick Links</h3>
            <ul className="space-y-2">
              <li><Link to="/about" className="text-gray-400 hover:text-brand-lime transition-colors">About Us</Link></li>
              <li><Link to="/artists" className="text-gray-400 hover:text-brand-lime transition-colors">Find Artists</Link></li>
              <li><Link to="/request-quote" className="text-gray-400 hover:text-brand-lime transition-colors">Bookings</Link></li>
              <li><Link to="/contact" className="text-gray-400 hover:text-brand-lime transition-colors">Contact</Link></li>
            </ul>
          </div>

          <div>
            <h3 className="text-white font-semibold mb-4 border-b border-brand-lime w-fit pb-1">Contact Us</h3>
            <ul className="space-y-3">
              <li className="flex items-start gap-3 text-gray-400">
                <MapPin size={18} className="text-brand-pink mt-1" />
                <span>723/122,<br />3rd Lane, Lake Terrace,<br />Athurugiriya</span>
              </li>
              <li className="flex items-center gap-3 text-gray-400">
                <Phone size={18} className="text-brand-pink" />
                <span>+94 (77) 718-6162</span>
              </li>
              <li className="flex items-center gap-3 text-gray-400">
                <Mail size={18} className="text-brand-pink" />
                <span>booking@en4tainment.com</span>
              </li>
            </ul>
          </div>

          <div>
            <h3 className="text-white font-semibold mb-4 border-b border-brand-lime w-fit pb-1">Follow Us</h3>
            <div className="flex flex-wrap gap-4 mb-8">
              <a 
                href={SOCIAL_LINKS.facebook} 
                target="_blank" 
                rel="noopener noreferrer"
                aria-label="Facebook"
                className="bg-white/5 p-3 rounded-full hover:bg-brand-purple hover:text-white transition-all text-gray-400"
              >
                <Facebook size={20} />
              </a>
              <a 
                href={SOCIAL_LINKS.instagram} 
                target="_blank" 
                rel="noopener noreferrer"
                aria-label="Instagram"
                className="bg-white/5 p-3 rounded-full hover:bg-brand-pink hover:text-white transition-all text-gray-400"
              >
                <Instagram size={20} />
              </a>
              <a 
                href={SOCIAL_LINKS.youtube} 
                target="_blank" 
                rel="noopener noreferrer"
                aria-label="YouTube"
                className="bg-white/5 p-3 rounded-full hover:bg-brand-lime hover:text-brand-dark transition-all text-gray-400"
              >
                <Youtube size={20} />
              </a>
            </div>
            
            <Link to="/admin" className="inline-flex items-center gap-2 text-[10px] font-black uppercase tracking-widest text-gray-600 hover:text-brand-purple transition-colors border border-white/5 px-3 py-1.5 rounded-lg hover:border-brand-purple/30">
              <ShieldCheck size={14} /> Admin Access
            </Link>
          </div>
        </div>

        <div className="mt-16 pt-8 border-t border-white/5 text-center text-gray-500 text-sm">
          <p>&copy; {new Date().getFullYear()} En4tainment. All rights reserved.</p>
        </div>
      </div>
    </footer>
  );
};
