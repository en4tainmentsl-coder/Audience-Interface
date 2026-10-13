// Sri Lankan mobile numbers arrive in several shapes: 077 379 5144,
// 0773795144, +94773795144, 94773795144. All are stored as E.164.
// Shared by VenuePortal signup and client onboarding — two formatters
// would eventually store the same number two ways.
export const toE164 = (raw: string): string => {
  const digits = raw.replace(/\D/g, '');
  if (raw.trim().startsWith('+')) return '+' + digits;
  if (digits.startsWith('0')) return '+94' + digits.slice(1);
  if (digits.startsWith('94')) return '+' + digits;
  return '+94' + digits;
};