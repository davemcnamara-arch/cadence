// Supabase Configuration
// For development, you can hardcode values here temporarily
// For production, use environment variables

export const SUPABASE_URL = 'https://dgwtihpiqgkhokkkxuzo.supabase.co';
export const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRnd3RpaHBpcWdraG9ra2t4dXpvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc0OTQzNjcsImV4cCI6MjA4MzA3MDM2N30.xnD7lrvmBlvW-9XzL0VTabAq6wtwsepxb90Assu8bNo';

// Initialize Supabase client (will be imported from CDN in index.html for now)
// Import Supabase from CDN
import { createClient } from 'https://cdn.skypack.dev/@supabase/supabase-js@2';

// Use let so we can recreate the client when it becomes stale
export let supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// Recreate the Supabase client to recover from stale connections.
// ES module exports are live bindings, so all importers see the new instance.
// Cooldown prevents cascading recreation when multiple queries timeout simultaneously.
let lastRecreatedAt = 0;
const RECREATE_COOLDOWN_MS = 10000;

export function recreateSupabaseClient() {
  const now = Date.now();
  if (now - lastRecreatedAt < RECREATE_COOLDOWN_MS) {
    // Client was recently recreated — return current instance to avoid
    // spawning multiple GoTrueClient instances and navigator lock conflicts.
    return supabase;
  }
  console.warn('Recreating Supabase client to recover from stale connection');
  lastRecreatedAt = now;
  supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
  return supabase;
}

// App Configuration
export const APP_CONFIG = {
  name: 'Cadence',
  version: '1.0.0',
  defaultRole: 'student',
  maxSongsPerPage: 20,
  enableRealtime: true
};
