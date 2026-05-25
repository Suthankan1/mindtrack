/**
 * API Mode Utilities
 * Manages backend URL configuration.
 */

export function backendUrl(): string {
  const url = process.env.BACKEND_URL;
  if (!url) {
    throw new Error("BACKEND_URL environment variable is missing. Please define it in your environment configurations.");
  }
  return url;
}
