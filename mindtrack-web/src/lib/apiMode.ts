/**
 * API Mode Utilities
 * Manages demo mode checks and backend URL configurations.
 */

export function isDemoModeEnabled(): boolean {
  return process.env.NEXT_PUBLIC_ENABLE_DEMO === "true" || process.env.ENABLE_DEMO === "true";
}

export function isDemoToken(token: string | undefined | null): boolean {
  if (!token) return false;
  return isDemoModeEnabled() && token === "demo-mock-jwt-token-data";
}

export function backendUrl(): string {
  const url = process.env.BACKEND_URL;
  if (!url) {
    throw new Error("BACKEND_URL environment variable is missing. Please define it in your environment configurations.");
  }
  return url;
}
