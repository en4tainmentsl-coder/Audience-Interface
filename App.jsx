import React, { lazy, Suspense } from 'react';
import { HashRouter as Router, Routes, Route, useLocation } from 'react-router';
import { Navbar } from './components/Navbar';
import { Footer } from './components/Footer';

// Eager: the public browse path. Home is the landing route, and Artists /
// ArtistDetail are the primary journey from it — lazying those would add a
// chunk fetch to the most common sequence on the site.
import { Home } from './pages/Home';
import { Artists } from './pages/Artists';
import { ArtistDetail } from './pages/ArtistDetail';

// Lazy: everything else. These pages are ~65% of application source and a
// first-time visitor reaches none of them. VenuePortal is the only importer of
// framer-motion, so lazying it evicts that library from first paint entirely.
//
// NOTE: every page uses a NAMED export, so each needs the interop below.
// A bare lazy(() => import('./pages/X')) builds cleanly and fails at runtime.
const About           = lazy(() => import('./pages/About').then(m => ({ default: m.About })));
const Contact         = lazy(() => import('./pages/Contact').then(m => ({ default: m.Contact })));
const RequestQuote    = lazy(() => import('./pages/RequestQuote').then(m => ({ default: m.RequestQuote })));
const VenuePortal     = lazy(() => import('./pages/VenuePortal').then(m => ({ default: m.VenuePortal })));
const VenueDashboard  = lazy(() => import('./pages/VenueDashboard').then(m => ({ default: m.VenueDashboard })));
const TalentDashboard = lazy(() => import('./pages/TalentDashboard').then(m => ({ default: m.TalentDashboard })));
const ClientDashboard = lazy(() => import('./pages/ClientDashboard').then(m => ({ default: m.ClientDashboard })));

const ScrollToTop = () => {
  const { pathname } = useLocation();

  React.useEffect(() => {
    window.scrollTo(0, 0);
  }, [pathname]);

  return null;
}

const RouteFallback = () => (
  <div
    className="flex items-center justify-center py-32"
    role="status"
    aria-label="Loading page"
  >
    <div className="w-6 h-6 border-2 border-white/20 border-t-brand-pink rounded-full animate-spin" />
  </div>
);

const App = () => {
  return (
    <Router>
      <ScrollToTop />
      {/* No bg-brand-dark here. It is an opaque background on a STATIC element,
          so it painted over the Home hero's stage rig, whose layers sit at
          z-index -1. index.html already sets the identical colour on <body>,
          so every page looks the same and the rig is no longer covered. */}
      <div className="flex flex-col min-h-screen text-white font-sans antialiased selection:bg-brand-pink selection:text-white">
        <Navbar />
        <main className="flex-grow">
          <Suspense fallback={<RouteFallback />}>
            <Routes>
              <Route path="/" element={<Home />} />
              <Route path="/about" element={<About />} />
              <Route path="/artists" element={<Artists />} />
              <Route path="/artists/:id" element={<ArtistDetail />} />
              <Route path="/request-quote" element={<RequestQuote />} />
              <Route path="/contact" element={<Contact />} />
              <Route path="/venue-portal" element={<VenuePortal />} />
              <Route path="/venue-dashboard" element={<VenueDashboard />} />
              <Route path="/talent-dashboard" element={<TalentDashboard />} />
              <Route path="/client-dashboard" element={<ClientDashboard />} />
            </Routes>
          </Suspense>
        </main>
        <Footer />
      </div>
    </Router>
  );
};

export default App;
