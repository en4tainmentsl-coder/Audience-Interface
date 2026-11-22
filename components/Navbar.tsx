import React, { useState, useEffect, useRef } from 'react';
import { Link, useLocation, useNavigate, useSearchParams } from 'react-router';
import { Menu, X, Search, LogOut, LayoutDashboard } from 'lucide-react';
import { Button } from './Button';
import { LOGO_URL } from '../constants';
import { supabase } from '../services/supabase';

interface NavLink {
  name: string;
  path: string;
}

type UserRole = 'client' | 'venue' | 'talent' | 'admin';

interface DashboardTarget {
  label: string;
  path: string;
}

// Roles come from the user_role enum: client, venue, talent, admin.
//
// talent and admin deliberately get NO link. A talent works in the separate
// app at app.en4tainment.com, not here. /admin exists in this app but cannot
// work: there is no admin SELECT policy on quote_requests, so the page returns
// an empty table to the very role it was built for, and quote triage has since
// moved to the Directus panel. Sending anyone there would be sending them to a
// dead end.
//
// A user with no profiles_users row yet is mid-onboarding and gets the client
// dashboard, which is where ClientOnboarding leaves them.
const dashboardFor = (role: UserRole | null): DashboardTarget | null => {
  switch (role) {
    case 'venue':
      return { label: 'My Venue', path: '/venue-dashboard' };
    case 'talent':
    case 'admin':
      return null;
    default:
      return { label: 'My Requests', path: '/client-dashboard' };
  }
};

export const Navbar: React.FC = () => {
  const [isOpen, setIsOpen] = useState<boolean>(false);
  const [isSearchOpen, setIsSearchOpen] = useState<boolean>(false);
  const location = useLocation();
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();

  const [navSearch, setNavSearch] = useState<string>(searchParams.get('q') || '');

  const [email, setEmail] = useState<string | null>(null);
  const [role, setRole] = useState<UserRole | null>(null);
  const [menuOpen, setMenuOpen] = useState<boolean>(false);
  const menuRef = useRef<HTMLDivElement | null>(null);

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

  // Session, plus the role that decides where the dashboard link points.
  // onAuthStateChange also fires once on load with the restored session, but
  // getSession is called explicitly so the menu does not flash empty on a
  // cold load before that event arrives.
  useEffect(() => {
    let active = true;
    // Guards against a slow role lookup for a previous user overwriting a
    // newer one after a fast sign-out/sign-in.
    let requestId = 0;

    const applyUser = async (userId: string | undefined, userEmail: string | null) => {
      if (!active) return;
      setEmail(userEmail);
      if (!userId) {
        setRole(null);
        return;
      }
      const thisRequest = ++requestId;
      const { data } = await supabase
        .from('profiles_users')
        .select('role')
        .eq('id', userId)
        .maybeSingle();
      if (!active || thisRequest !== requestId) return;
      setRole((data?.role as UserRole | undefined) ?? null);
    };

    supabase.auth.getSession().then(({ data: { session } }) => {
      void applyUser(session?.user?.id, session?.user?.email ?? null);
    });

    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      void applyUser(session?.user?.id, session?.user?.email ?? null);
    });

    return () => {
      active = false;
      subscription.unsubscribe();
    };
  }, []);

  // Close the account menu on an outside click and on navigation.
  useEffect(() => {
    if (!menuOpen) return;
    const onPointerDown = (e: MouseEvent) => {
      if (menuRef.current && !menuRef.current.contains(e.target as Node)) setMenuOpen(false);
    };
    document.addEventListener('mousedown', onPointerDown);
    return () => document.removeEventListener('mousedown', onPointerDown);
  }, [menuOpen]);

  useEffect(() => {
    setMenuOpen(false);
  }, [location.pathname]);

  const handleSearchChange = (e: React.ChangeEvent<HTMLInputElement>): void => {
    const value: string = e.target.value;
    setNavSearch(value);

    if (location.pathname === '/artists') {
      navigate(`/artists?q=${encodeURIComponent(value)}`, { replace: true });
    } else if (value.trim().length > 0) {
      navigate(`/artists?q=${encodeURIComponent(value)}`);
    }
  };

  const handleSignOut = async (): Promise<void> => {
    setMenuOpen(false);
    setIsOpen(false);
    await supabase.auth.signOut();
    navigate('/');
  };

  const dashboard = dashboardFor(role);
  const initial = (email?.trim()?.[0] ?? '?').toUpperCase();

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

              {email && (
                <div className="relative" ref={menuRef} id="nav-account">
                  <button
                    type="button"
                    onClick={() => setMenuOpen((v) => !v)}
                    aria-haspopup="menu"
                    aria-expanded={menuOpen}
                    aria-label="Account menu"
                    className="w-9 h-9 rounded-full bg-brand-purple text-white text-sm font-semibold flex items-center justify-center hover:ring-2 hover:ring-brand-lime transition-all"
                    id="nav-account-btn"
                  >
                    {initial}
                  </button>

                  {menuOpen && (
                    <div
                      role="menu"
                      className="absolute right-0 mt-2 w-60 bg-brand-surface border border-white/10 rounded-xl shadow-2xl overflow-hidden"
                      id="nav-account-menu"
                    >
                      <div className="px-4 py-3 border-b border-white/10">
                        <p className="text-xs text-gray-400">Signed in as</p>
                        <p className="text-sm text-white truncate" title={email}>{email}</p>
                      </div>

                      {dashboard && (
                        <Link
                          to={dashboard.path}
                          role="menuitem"
                          className="flex items-center gap-3 px-4 py-3 text-sm text-gray-300 hover:text-white hover:bg-white/5 transition-colors"
                          id="nav-account-dashboard"
                        >
                          <LayoutDashboard size={16} />
                          {dashboard.label}
                        </Link>
                      )}

                      <button
                        type="button"
                        role="menuitem"
                        onClick={handleSignOut}
                        className="w-full flex items-center gap-3 px-4 py-3 text-sm text-gray-300 hover:text-white hover:bg-white/5 transition-colors border-t border-white/10"
                        id="nav-account-signout"
                      >
                        <LogOut size={16} />
                        Sign out
                      </button>
                    </div>
                  )}
                </div>
              )}
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

            {email && (
              <div className="border-t border-white/10 mt-2 pt-2" id="mobile-account">
                <p className="px-3 pt-1 pb-2 text-xs text-gray-400 truncate" title={email}>
                  Signed in as {email}
                </p>
                {dashboard && (
                  <Link
                    to={dashboard.path}
                    onClick={() => setIsOpen(false)}
                    className="flex items-center gap-3 px-3 py-2 rounded-md text-base font-medium text-gray-300 hover:text-white hover:bg-white/5"
                    id="mobile-account-dashboard"
                  >
                    <LayoutDashboard size={18} />
                    {dashboard.label}
                  </Link>
                )}
                <button
                  type="button"
                  onClick={handleSignOut}
                  className="w-full flex items-center gap-3 px-3 py-2 rounded-md text-base font-medium text-gray-300 hover:text-white hover:bg-white/5"
                  id="mobile-account-signout"
                >
                  <LogOut size={18} />
                  Sign out
                </button>
              </div>
            )}
          </div>
        </div>
      )}
    </nav>
  );
};
