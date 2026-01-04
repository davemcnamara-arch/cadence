// Supabase Configuration
// For development, you can hardcode values here temporarily
// For production, use environment variables

export const SUPABASE_URL = 'https://dgwtihpiqgkhokkkxuzo.supabase.co';
export const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRnd3RpaHBpcWdraG9ra2t4dXpvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc0OTQzNjcsImV4cCI6MjA4MzA3MDM2N30.xnD7lrvmBlvW-9XzL0VTabAq6wtwsepxb90Assu8bNo';

// Initialize Supabase client (will be imported from CDN in index.html for now)
// Import Supabase from CDN
import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm';

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// App Configuration
export const APP_CONFIG = {
  name: 'Cadence',
  version: '1.0.0',
  defaultRole: 'student',
  maxSongsPerPage: 20,
  enableRealtime: true
};
