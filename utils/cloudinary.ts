// Cloudinary serves the untouched original unless the delivery URL carries a
// transform segment. Nothing in this app added one, so avatars rendered at
// 32px were being sent full-resolution PNGs, and the ArtistDetail banner
// visibly painted in strips as it streamed in.
//
// Four presets rather than per-element widths: every distinct transform
// creates a separate derived asset on Cloudinary, and this account is on the
// free plan where derived storage and transformation counts are quota'd.
// Sizing each element exactly would fragment the CDN cache for almost no
// additional saving.

export type ImageSize = 'avatar' | 'card' | 'gallery' | 'hero';

const WIDTHS: Record<ImageSize, number> = {
  avatar: 160,   // covers every 32-80px avatar at 2x DPI
  card: 600,     // artist listing cards
  gallery: 800,  // gallery grid, half-width at md and up
  hero: 1600,    // ArtistDetail banner - the LCP element
};

const UPLOAD = '/image/upload/';

/**
 * Inserts f_auto,q_auto,w_<preset> into a Cloudinary delivery URL.
 *
 * Returns the input unchanged for anything that is not a plain Cloudinary
 * delivery URL - the logo, a local asset like /avatar-placeholder.svg, an already
 * transformed URL - so call sites never have to check first. Returns undefined
 * for an empty value, which omits the src attribute rather than emitting
 * src="" (that re-requests the page itself).
 */
export const cldImage = (
  url: string | null | undefined,
  size: ImageSize,
): string | undefined => {
  if (!url) return undefined;

  const at = url.indexOf(UPLOAD);
  if (at === -1) return url;

  const tail = url.slice(at + UPLOAD.length);

  // An untransformed delivery URL has the version next: /image/upload/v123/...
  // Anything else already carries a transform, so leave it rather than
  // stacking a second one on top.
  if (!/^v\d+\//.test(tail)) return url;

  return `${url.slice(0, at + UPLOAD.length)}f_auto,q_auto,w_${WIDTHS[size]}/${tail}`;
};
