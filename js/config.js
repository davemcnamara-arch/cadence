// Supabase Configuration
// For development, you can hardcode values here temporarily
// For production, use environment variables

export const SUPABASE_URL = import.meta.env?.VITE_SUPABASE_URL || 'YOUR_SUPABASE_URL';
export const SUPABASE_ANON_KEY = import.meta.env?.VITE_SUPABASE_ANON_KEY || 'YOUR_SUPABASE_ANON_KEY';

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
