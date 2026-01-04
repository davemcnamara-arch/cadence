# Cadence - Music Skill Progression Tracker

A comprehensive web application for music students to track their skill progression across guitar, bass, piano, drums, and vocals.

## Features

- **Multi-instrument tracking** with 5 progressive levels per instrument
- **Google OAuth authentication** for secure student accounts
- **Song grading tool** with level-specific criteria
- **Crowdsourced song repository** with YouTube/Spotify integration
- **Progress tracking** from "Currently Learning" to "Mastered"
- **Teacher dashboard** for class management and oversight
- **Export functionality** for CSV data and student reflections
- **Admin interface** for content management

## Tech Stack

- **Frontend**: Vanilla JavaScript, HTML5, CSS3
- **Backend**: Supabase (PostgreSQL, Authentication, Real-time)
- **Hosting**: Vercel
- **Authentication**: Google OAuth 2.0

## Setup Instructions

### 1. Supabase Configuration

1. Create a new Supabase project at https://supabase.com
2. Copy your project URL and anon key
3. Create a `.env` file in the root directory:

```env
VITE_SUPABASE_URL=your_supabase_url
VITE_SUPABASE_ANON_KEY=your_supabase_anon_key
```

4. Run the database migrations in `supabase/migrations/`
5. Run the seed data script in `supabase/seed.sql`

### 2. Google OAuth Setup

1. Go to Google Cloud Console: https://console.cloud.google.com
2. Create a new project or select existing
3. Enable Google+ API
4. Create OAuth 2.0 credentials
5. Add authorized redirect URI: `https://your-project.supabase.co/auth/v1/callback`
6. In Supabase Dashboard → Authentication → Providers → Google:
   - Enable Google provider
   - Add your Client ID and Client Secret

### 3. Local Development

```bash
npm install
npm run dev
```

Open http://localhost:3000

### 4. Deployment

```bash
npm run deploy
```

Or connect your GitHub repository to Vercel for automatic deployments.

## Database Structure

- `users` - Student, teacher, and admin accounts
- `instruments` - Guitar, bass, piano, drums, vocals
- `levels` - 5 levels per instrument with skills and grading criteria
- `student_progress` - Current level tracking per student per instrument
- `songs` - Crowdsourced song repository
- `song_ratings` - Student assessments of songs
- `student_songs` - Individual song tracking (learning/mastered)
- `classes` - Teacher-created classes
- `class_members` - Student enrollment in classes

## User Roles

- **Student**: Track progress, grade songs, export data
- **Teacher**: Manage classes, view student progress, export class data
- **Admin**: Manage content, edit levels, moderate submissions

## MVP Features (Phase 1)

- ✅ Google authentication
- ✅ Guitar pathway visualization
- ✅ Song grading with dynamic checklists
- ✅ Song repository
- ✅ Currently Learning / Mastered tracking
- ✅ Progress export (CSV + reflection text)

## Future Enhancements (Phases 2-4)

- All 5 instruments fully implemented
- Teacher dashboard with class analytics
- Admin content management interface
- Real-time "Currently Learning" social features
- Advanced song search and filtering
- Mobile app versions

## License

MIT
