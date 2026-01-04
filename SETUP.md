# Cadence Setup Guide

This guide will walk you through setting up the Cadence music skill progression tracker from scratch.

## Prerequisites

- A Supabase account (free tier is fine)
- A Google Cloud Console account (for OAuth)
- Node.js installed (for local development)
- A Vercel account (for deployment, optional)

## Step 1: Set Up Supabase

### 1.1 Create a New Project

1. Go to [supabase.com](https://supabase.com) and sign in
2. Click "New Project"
3. Choose your organization
4. Enter project details:
   - **Name**: Cadence Music Tracker
   - **Database Password**: Choose a strong password (save this!)
   - **Region**: Choose closest to your users
5. Click "Create new project"
6. Wait 2-3 minutes for project to be provisioned

### 1.2 Run Database Migrations

1. In your Supabase project dashboard, go to the **SQL Editor**
2. Click "New Query"
3. Copy the entire contents of `supabase/migrations/001_initial_schema.sql`
4. Paste into the SQL editor
5. Click "Run" (bottom right)
6. Wait for confirmation: "Success. No rows returned"

### 1.3 Seed the Database

1. Still in the SQL Editor, click "New Query"
2. Copy the entire contents of `supabase/seed.sql`
3. Paste into the SQL editor
4. Click "Run"
5. You should see: "Success. No rows returned"

### 1.4 Verify Data

1. Go to **Table Editor** in the left sidebar
2. Click on the `instruments` table
3. You should see 5 instruments (Guitar, Bass, Piano, Drums, Vocals)
4. Click on the `levels` table
5. You should see 47 levels total (5 instruments × ~9 levels each with branches)

### 1.5 Get Your Supabase Credentials

1. Go to **Project Settings** (gear icon in sidebar)
2. Click **API** in the left menu
3. Copy these two values:
   - **Project URL**: `https://xxxxx.supabase.co`
   - **anon public** key (under "Project API keys")
4. Save these for later!

## Step 2: Configure Google OAuth

### 2.1 Create Google Cloud Project

1. Go to [console.cloud.google.com](https://console.cloud.google.com)
2. Click "Select a project" → "New Project"
3. Enter project name: "Cadence Music Tracker"
4. Click "Create"

### 2.2 Enable Google+ API

1. In the left sidebar, go to **APIs & Services** → **Library**
2. Search for "Google+ API"
3. Click it and press "Enable"

### 2.3 Create OAuth Credentials

1. Go to **APIs & Services** → **Credentials**
2. Click "+ CREATE CREDENTIALS" → "OAuth client ID"
3. If prompted, configure the OAuth consent screen:
   - User Type: External
   - App name: Cadence Music Tracker
   - User support email: your email
   - Developer contact: your email
   - Save and continue through all screens
4. Back at "Create OAuth client ID":
   - Application type: Web application
   - Name: Cadence Web Client
   - Authorized JavaScript origins: (leave empty for now)
   - Authorized redirect URIs: `https://YOUR_PROJECT_ID.supabase.co/auth/v1/callback`
     - Replace YOUR_PROJECT_ID with your actual Supabase project ID
5. Click "Create"
6. Copy the **Client ID** and **Client Secret**

### 2.4 Configure Google OAuth in Supabase

1. Back in your Supabase dashboard
2. Go to **Authentication** → **Providers**
3. Find "Google" in the list
4. Toggle it to **Enabled**
5. Paste your **Client ID** and **Client Secret**
6. Click "Save"

## Step 3: Configure the Application

### 3.1 Update Configuration

**Option A: For development/testing (quick method)**

1. Open `js/config.js`
2. Replace the placeholder values:
   ```javascript
   export const SUPABASE_URL = 'https://YOUR_PROJECT_ID.supabase.co';
   export const SUPABASE_ANON_KEY = 'your_anon_key_here';
   ```

**Option B: For production (recommended)**

1. Copy `.env.example` to `.env`
2. Fill in your Supabase credentials
3. Use a build tool like Vite to handle environment variables

### 3.2 Install Dependencies

```bash
npm install
```

## Step 4: Test Locally

### 4.1 Run Development Server

```bash
npm run dev
```

This will start a local server at http://localhost:3000

### 4.2 Test Authentication

1. Click "Sign in with Google"
2. Authorize the app
3. You should be redirected back and see the instrument selection screen
4. Select "Guitar"
5. You should see the 5-level pathway visualization

### 4.3 Test Song Grading

1. Click the "Song Library" tab
2. Click "+ Grade New Song"
3. Fill in song details:
   - Title: "Wonderwall"
   - Artist: "Oasis"
   - Instrument: Guitar
   - Level: 2
4. Click "Next"
5. Answer the grading questions
6. Click "Next" → "Submit"
7. The song should appear in the library

### 4.4 Test Progress Tracking

1. From the song library, click "Start Learning" on a song
2. Go to "My Progress" tab
3. You should see it under "Currently Learning"
4. Click "Mark Mastered"
5. It should move to "Mastered Songs"

### 4.5 Test Export

1. In "My Progress", click "Export Data"
2. Try "Download CSV" - a CSV file should download
3. Try "Generate Reflection" - text should appear
4. Click "Copy to Clipboard" - text should be copied

## Step 5: Deploy to Vercel

### 5.1 Push to GitHub

```bash
git init
git add .
git commit -m "Initial commit - Cadence Music Tracker"
git branch -M main
git remote add origin YOUR_GITHUB_REPO_URL
git push -u origin main
```

### 5.2 Deploy to Vercel

1. Go to [vercel.com](https://vercel.com)
2. Click "Add New..." → "Project"
3. Import your GitHub repository
4. Configure:
   - Framework Preset: Other
   - Root Directory: ./
   - Build Command: (leave empty)
   - Output Directory: (leave empty)
5. Add Environment Variables:
   - `VITE_SUPABASE_URL`: your Supabase URL
   - `VITE_SUPABASE_ANON_KEY`: your Supabase anon key
6. Click "Deploy"

### 5.3 Update OAuth Redirect URI

1. Once deployed, copy your Vercel URL (e.g., `https://cadence-abc123.vercel.app`)
2. Go back to Google Cloud Console → Credentials
3. Edit your OAuth client
4. Add to "Authorized JavaScript origins":
   - `https://cadence-abc123.vercel.app`
5. Add to "Authorized redirect URIs":
   - Keep the Supabase one
   - The redirect already works through Supabase
6. Save

### 5.4 Test Production

1. Visit your Vercel URL
2. Test login and all features
3. Everything should work!

## Step 6: Optional Enhancements

### 6.1 Custom Domain

1. In Vercel, go to your project → Settings → Domains
2. Add your custom domain (e.g., cadence.yourdomain.com)
3. Follow DNS configuration instructions
4. Update Google OAuth allowed origins with your custom domain

### 6.2 Enable Row Level Security Testing

Row Level Security is already enabled in the schema. To test:

1. Create two separate Google accounts
2. Log in as User A, add some songs
3. Log out, log in as User B
4. Verify you can't see User A's personal progress
5. Verify you CAN see User A's song ratings (public)

### 6.3 Add Admin User

1. In Supabase, go to Table Editor → users
2. Find your user row
3. Edit the `role` column
4. Change from `student` to `admin`
5. (Admin features can be built in Phase 4)

## Troubleshooting

### "Invalid project URL or anon key"

- Double-check you copied the correct values from Supabase Settings → API
- Make sure there are no extra spaces

### "Authentication failed"

- Verify Google OAuth redirect URI matches exactly: `https://YOUR_PROJECT_ID.supabase.co/auth/v1/callback`
- Check that Google provider is enabled in Supabase Auth settings

### "No instruments showing"

- Verify seed data ran successfully
- Check Supabase Table Editor → instruments table
- Should have 5 rows

### "Cannot insert into table"

- Check Row Level Security policies
- Make sure you're signed in
- Verify user was created in users table

### Songs not appearing

- Check that songs have `approved = true`
- Verify you're filtering correctly
- Check browser console for errors

## Next Steps

Now that your MVP is running:

1. **Gather feedback** from students and teachers
2. **Phase 2**: Implement teacher dashboard
3. **Phase 3**: Add admin content management
4. **Phase 4**: Add real-time features and social elements
5. **Future**: Mobile apps, advanced analytics, badges/achievements

## Support

For issues or questions:
- Check the browser console for errors
- Review Supabase logs in Dashboard → Logs
- Check the GitHub issues page

## Security Notes

- Never commit `.env` file to version control (it's in `.gitignore`)
- Anon key is safe to expose (it's used client-side)
- Service role key should NEVER be used in frontend code
- Row Level Security protects all sensitive data
