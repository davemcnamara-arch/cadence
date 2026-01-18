# Cadence - Feature Documentation

## Current Features (MVP - Phase 1)

### Authentication
- ✅ Google OAuth sign-in
- ✅ Automatic user creation on first login
- ✅ Role-based access (student/teacher/admin)
- ✅ Persistent sessions
- ✅ Secure logout

### Instrument Selection
- ✅ Choose from 5 instruments:
  - Guitar 🎸
  - Bass Guitar 🎸
  - Piano/Keyboard 🎹
  - Drums 🥁
  - Vocals 🎤
- ✅ Track multiple instruments simultaneously
- ✅ Add instruments at any time

### Pathway Visualization (All Instruments)
- ✅ Interactive 5-level progression map
- ✅ Clear visual indication of current level
- ✅ Branching at Level 4 (3 specialization paths)
- ✅ Detailed skills for each level
- ✅ Example songs for each level
- ✅ Print-friendly layout
- ✅ Instrument-specific color theming (Guitar: Orange, Bass: Purple, Piano: Cyan, Drums: Red, Vocals: Magenta)
- ✅ Visual tab interface for easy instrument switching
- ✅ Prominent pathway header showing current instrument and level

### Song Grading Tool
- ✅ Add new songs to repository
- ✅ Multi-step grading wizard:
  1. Song details (title, artist, URLs)
  2. Level-specific criteria checklist
  3. Level suggestion based on responses
- ✅ YouTube and Spotify URL support
- ✅ Dynamic checklist generation per level
- ✅ Option to add to "Currently Learning" immediately
- ✅ Prevents duplicate song submissions

### Song Repository
- ✅ Searchable song library
- ✅ Filter by:
  - Search term (title/artist)
  - Instrument
  - Level
- ✅ Aggregate ratings (average level from multiple students)
- ✅ View rating count
- ✅ Direct links to YouTube/Spotify
- ✅ One-click "Start Learning" button

### Progress Tracking
- ✅ "Currently Learning" status for songs
- ✅ "Mastered" status with completion date
- ✅ Progress statistics dashboard:
  - Number of instruments tracking
  - Songs currently learning
  - Songs mastered
- ✅ Organized view of all tracked songs
- ✅ Easy status updates

### Export Functionality
- ✅ CSV export with all progress data
  - Song title, artist, instrument, status, dates
  - Compatible with Excel/Google Sheets
- ✅ Student reflection text generator
  - First-person narrative
  - Summary of instruments and progress
  - List of mastered and learning songs
  - Copy-to-clipboard functionality
  - LMS-ready format (Seqta, etc.)

### User Interface
- ✅ Clean, modern design
- ✅ Fully responsive (mobile, tablet, desktop)
- ✅ Fast loading times
- ✅ Intuitive navigation
- ✅ Toast notifications for user feedback
- ✅ Modal dialogs for complex interactions
- ✅ Print-friendly pages

## Database Features

### Complete Instrument Data
- ✅ All 5 instruments fully seeded
- ✅ 47 total level variations including branches
- ✅ Detailed skills JSON for each level
- ✅ Grading checklists JSON for each level
- ✅ Example songs for each level

### Level Branching System
- ✅ Level 1-3: Linear progression
- ✅ Level 4: 3 specialization branches per instrument
- ✅ Level 5: Advanced techniques matching Level 4 branch

### Security & Privacy
- ✅ Row Level Security (RLS) enabled
- ✅ Students can only see their own progress
- ✅ Song ratings are public (collaborative)
- ✅ Class-based data sharing (for teacher features)
- ✅ Admin-only content editing

## Roadmap (Future Phases)

### Phase 2: All Instruments ✅ COMPLETE
- ✅ Extend pathway visualization to all 5 instruments
- ✅ Instrument-switching interface improvements (visual tabs)
- ✅ Instrument-specific grading workflows
- ✅ Instrument-specific color theming for pathways
- ✅ Enhanced pathway header with current instrument display

### Phase 3: Teacher Dashboard
- ⏳ Create and manage classes
- ⏳ Generate unique class codes
- ⏳ View class roster
- ⏳ Class progress heatmap
- ⏳ Student progression timeline
- ⏳ Recent song submissions feed
- ⏳ Flagged ratings review (2+ level discrepancies)
- ⏳ Approve/edit student submissions
- ⏳ Bulk export class data (CSV)
- ⏳ Individual student progress reports

### Phase 4: Admin Interface
- ⏳ Edit level descriptions via UI
- ⏳ Modify grading checklists
- ⏳ Add/remove instruments
- ⏳ System-wide statistics
- ⏳ Content moderation tools
- ⏳ User management

### Phase 5: Social Features
- ⏳ Real-time "Currently Learning" feed
- ⏳ See what classmates are working on
- ⏳ Collaborative song ratings
- ⏳ Song difficulty consensus algorithm
- ⏳ Popular songs this week
- ⏳ Achievement badges

### Phase 6: Advanced Features
- ⏳ Practice log with time tracking
- ⏳ Goal setting and reminders
- ⏳ Progress charts and analytics
- ⏳ Video upload for teacher review
- ⏳ Peer feedback system
- ⏳ Custom learning paths
- ⏳ Integration with music notation software
- ⏳ Mobile apps (iOS/Android)

## Technical Features

### Performance
- ✅ Lazy loading of data
- ✅ Efficient database queries
- ✅ Indexed searches
- ✅ Minimal bundle size (vanilla JS)
- ✅ Fast page loads

### Scalability
- ✅ Supabase auto-scaling
- ✅ PostgreSQL optimizations
- ✅ Vercel edge network
- ✅ CDN for static assets

### Browser Support
- ✅ Chrome/Edge (latest)
- ✅ Firefox (latest)
- ✅ Safari (latest)
- ✅ Mobile browsers
- ✅ School-locked browsers

### Offline Support
- ⏳ Service worker caching
- ⏳ Offline data viewing
- ⏳ Queue sync when online

## Known Limitations (MVP)

1. **Auto-approval of songs** - All submitted songs are automatically approved (teacher moderation in Phase 3)
2. **No class system yet** - Students can't join classes (Phase 3)
3. **No real-time updates** - Refresh required to see others' submissions
4. **Basic song details** - No thumbnail auto-extraction from YouTube
5. **No video uploads** - Students can only link external videos
6. **Limited analytics** - Basic progress stats only

## Feature Requests

To request features or report bugs, create an issue on the GitHub repository with:
- Clear description
- Expected behavior
- Actual behavior
- Steps to reproduce (for bugs)
- Screenshots if applicable

## API Usage

Current API calls per user session (typical):
- Login: 2-3 calls
- Load instruments: 1 call
- Load levels: 1 call per instrument
- Load songs: 1 call (with filters)
- Grade song: 2-3 calls
- Track progress: 1-2 calls

Estimated: ~10-20 API calls per active session

Supabase free tier: 50,000 API calls/month
Supporting: ~2,500-5,000 active student sessions/month
