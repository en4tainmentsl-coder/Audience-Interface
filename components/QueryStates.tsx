import React from 'react';
import { AlertCircle } from 'lucide-react';

/**
 * The one feedback pattern for failed and pending queries on the public pages.
 *
 * The repo had three error treatments and no loading state at all on Home,
 * Artists or ArtistDetail. These two components converge on the banner already
 * used in ArtistDetail (red-500 on red-500/10 with a red-500/20 hairline and an
 * AlertCircle) rather than adding a fourth.
 */

interface ErrorBannerProps {
  /** What the reader should do next, not what the system did. */
  message: string;
  onRetry?: () => void;
  id?: string;
}

export const ErrorBanner: React.FC<ErrorBannerProps> = ({ message, onRetry, id }) => (
  <div
    role="alert"
    id={id}
    className="flex items-start gap-3 text-red-500 bg-red-500/10 p-4 rounded-xl border border-red-500/20"
  >
    <AlertCircle className="w-5 h-5 shrink-0 mt-0.5" />
    <div className="flex-1 text-left">
      <p className="text-sm">{message}</p>
      {onRetry && (
        <button
          type="button"
          onClick={onRetry}
          className="mt-2 text-xs font-bold uppercase tracking-widest text-red-400 hover:text-red-300 underline"
        >
          Try again
        </button>
      )}
    </div>
  </div>
);

/**
 * Placeholder cards while a grid loads.
 *
 * A spinner would leave the grid area looking empty, which is the exact
 * impression being fixed here — an empty marketplace. Cards that match the real
 * shape (rounded-2xl on brand-surface with a white/5 hairline) hold the layout
 * and read as "arriving" rather than "nothing here".
 */
export const CardGridSkeleton: React.FC<{ count?: number; id?: string }> = ({ count = 3, id }) => (
  <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-8" id={id} aria-hidden="true">
    {Array.from({ length: count }).map((_, i) => (
      <div
        key={i}
        className="rounded-2xl bg-brand-surface border border-white/5 overflow-hidden animate-pulse"
      >
        <div className="aspect-[4/3] bg-white/5" />
        <div className="p-6 space-y-3">
          <div className="h-5 w-2/3 bg-white/10 rounded-sm" />
          <div className="h-3 w-1/3 bg-white/5 rounded-sm" />
          <div className="h-3 w-full bg-white/5 rounded-sm" />
        </div>
      </div>
    ))}
  </div>
);

/** Screen-reader announcement for a loading region that renders as skeletons. */
export const LoadingAnnouncement: React.FC<{ label: string }> = ({ label }) => (
  <span className="sr-only" role="status" aria-live="polite">{label}</span>
);
