import React, { useState, useEffect } from 'react';
import { Link, useLocation, useNavigate, useSearchParams } from 'react-router-dom';
import { Menu, X, Search } from 'lucide-react';
import { Button } from './Button';
import { LOGO_URL } from '../constants';

interface NavLink {
  name: string;
  path: string;
}

export const Navbar: React.FC = () => {
  const [isOpen, setIsOpen] = useState<boolean>(false);
  const [isSearchOpen, setIsSearchOpen] = useState<boolean>(false);
  const location = useLocation();
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  
  const [navSearch, setNavSearch] = useState<string>(searchParams.get('q') || '');

  const navLinks: NavLink[] = [
    { name: 'Home', path: '/' },
    { name: 'About Us', path: '/about' },
    { name: 'Artists', path: '/artists' },
    { name: 'Venue Portal', path: '/venue-portal' },
    { name: 'Contact', path: '/contact' },
  ];

  const isActive = (path: string): boolean => location.pathname === path;

  useEffect(() => {
    const q: string = searchParams.get('q') || '';
    setNavSearch(q);
  }, [searchParams]);

  const handleSearchChange = (e: React.ChangeEvent<HTMLInputElement>): void => {
    const value: string = e.target.value;
    setNavSearch(value);
    
    if (location.pathname === '/artists') {
      navigate(`/artists?q=${encodeURIComponent(value)}`, { replace: true });
    } else if (value.trim().length > 0) {
      navigate(`/artists?q=${encodeURIComponent(value)}`);
    }
  };

  return (
    <nav className="fixed top-0 w-full z-50 bg-brand-dark/90 backdrop-blur-md border-b border-white/10" id="main-nav">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between h-20">
          
          <Link to="/" className="flex items-center gap-2 group flex-shrink-0" id="nav-logo-link">
            <img
              src={LOGO_URL}
              alt="En4tainment"
              className="h-10 md:h-12 w-auto object-contain transition-transform duration-300 group-hover:scale-105"
            />
          </Link>

          <div className="hidden md:flex items-center space-x-6 flex-grow justify-end">
            
            <div className={`relative flex items-center transition-all duration-300 ${isSearchOpen ? 'w-64' : 'w-10'}`} id="desktop-search-container">
              <button 
                onClick={() => setIsSearchOpen(!isSearchOpen)}
                className="absolute left-0 p-2 text-gray-400 hover:text-brand-lime transition-colors z-10"
                id="search-toggle-btn"
              >
                <Search size={20} />
              </button>
              <input
                type="text"
                placeholder="Search artists..."
                value={navSearch}
                onChange={handleSearchChange}
                onFocus={() => setIsSearchOpen(true)}
                className={`bg-white/5 border border-white/10 rounded-full py-1.5 pl-10 pr-4 text-sm text-white focus:outline-none focus:ring-1 focus:ring-brand-purple transition-all duration-300 ${
                  isSearchOpen ? 'opacity-100' : 'opacity-0 cursor-default pointer-events-none'
                }`}
              />
            </div>

            <div className="flex items-center space-x-8" id="desktop-links">
              {navLinks.map((link: NavLink) => (
                <Link
                  key={link.name}
                  to={link.path}
                  className={`text-sm font-medium transition-colors hover:text-brand-pink ${
                    isActive(link.path) ? 'text-brand-lime' : 'text-gray-300'
                  }`}
                >
                  {link.name}
                </Link>
              ))}
              <Link to="/request-quote" id="nav-bookings-link">
                <Button size="sm" variant="primary">Bookings</Button>
              </Link>
            </div>
          </div>

          <div className="md:hidden flex items-center gap-4" id="mobile-menu-burger">
            <button 
              onClick={() => {
                navigate('/artists');
                setIsOpen(false);
              }} 
              className="text-gray-400 hover:text-white"
              id="mobile-search-btn"
            >
              <Search size={24} />
            </button>
            <button
              onClick={() => setIsOpen(!isOpen)}
              className="text-gray-300 hover:text-white focus:outline-none"
              id="mobile-nav-toggle"
            >
              {isOpen ? <X size={28} /> : <Menu size={28} />}
            </button>
          </div>
        </div>
      </div>

      {isOpen && (
        <div className="md:hidden bg-brand-surface border-t border-white/10" id="mobile-menu-dropdown">
          <div className="px-2 pt-2 pb-3 space-y-1 sm:px-3">
            {navLinks.map((link: NavLink) => (
              <Link
                key={link.name}
                to={link.path}
                onClick={() => setIsOpen(false)}
                className={`block px-3 py-2 rounded-md text-base font-medium ${
                  isActive(link.path) 
                    ? 'text-brand-lime bg-white/5' 
                    : 'text-gray-300 hover:text-white hover:bg-white/5'
                }`}
              >
                {link.name}
              </Link>
            ))}
            <div className="pt-4 px-3 pb-2">
              <Link to="/request-quote" onClick={() => setIsOpen(false)} id="mobile-request-quote-link">
                <Button className="w-full">Request Quote</Button>
              </Link>
            </div>
          </div>
        </div>
      )}
    </nav>
  );
};
