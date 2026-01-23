# Link Moderation Implementation

## Overview
This implementation adds security and moderation for all resource links (YouTube videos, chord charts, and tutorials) in the Cadence application. All existing links have been cleared, and students must now submit links for teacher approval before they become visible.

## Changes Made

### 1. Database Migration (`supabase/migrations/020_add_link_moderation.sql`)

**New Table: `pending_links`**
- Stores link submissions awaiting teacher approval
- Includes: song_id, link_type, url, submitter info, status, reviewer info
- Indexes for performance on status and song_id lookups

**Data Cleanup**
- All existing links (youtube_url, chords_url, tutorial_url) cleared from songs table

**RLS Policies**
- Students can INSERT their own link submissions
- Students can view their own pending links
- Teachers can view all pending links
- Teachers can UPDATE (approve/reject) pending links

**RPC Functions**
- `approve_pending_link(pending_link_id)` - Approves a link and updates the song table
- `reject_pending_link(pending_link_id)` - Marks a link as rejected

### 2. Frontend Changes

**Link Submission (`js/app.js`)**
- Modified `saveResourceUrl()` to check user role:
  - **Students**: Submit to `pending_links` table for approval
  - **Teachers**: Can still update links directly
- Updated `editSongResource()` to show different modal title and warning message for students

**Modal UI (`index.html`)**
- Added warning message for students: "Your link will be submitted for teacher approval"
- Changed button text from "Save" to "Submit" for clarity

**Flagged Tab Enhancement (`js/app.js`)**
- Modified `loadFlaggedRatings()` to also load pending links
- Updated `renderFlaggedRatings()` to show two sections:
  1. **Pending Link Approvals** - Shows count and list of links awaiting approval
  2. **Flagged Rating Discrepancies** - Existing functionality
- Updated notification badge to count both pending links and flagged ratings

**New Functions**
- `approvePendingLink(linkId)` - Approves a link and refreshes views
- `rejectPendingLink(linkId)` - Rejects a link and refreshes views

### 3. UI/UX Flow

**For Students:**
1. Click "Add" or edit icon on a resource link
2. See warning: "Note: Your link will be submitted for teacher approval before it becomes visible to other students."
3. Submit link URL
4. Receive confirmation: "Link submitted for teacher approval"
5. Link does NOT appear in song library yet

**For Teachers:**
1. Navigate to "Flagged" tab
2. See "Pending Link Approvals" section at top with count
3. Each pending link shows:
   - Song title and artist
   - Link type (YouTube Video, Chords/Tabs, Tutorial Video)
   - Submitted by (student name)
   - Submission date
   - Clickable URL preview
   - ✓ Approve and ✗ Reject buttons
4. Click Approve → Link immediately appears in song library for all users
5. Click Reject → Link is marked as rejected and removed from queue

## Security Benefits

1. **Prevents Malicious Links**: Teachers review all URLs before students see them
2. **Content Validation**: Teachers can verify links lead to appropriate educational content
3. **No Phishing**: Prevents students from submitting phishing or harmful websites
4. **Quality Control**: Ensures only high-quality resources are added to the library
5. **Clean Slate**: All old, unverified links have been removed

## Deployment Instructions

### Step 1: Apply Database Migration
```bash
# Connect to your Supabase project and run:
psql <your-database-connection-string> -f supabase/migrations/020_add_link_moderation.sql
```

Or use Supabase SQL Editor:
1. Go to your Supabase dashboard
2. Navigate to SQL Editor
3. Copy and paste the contents of `020_add_link_moderation.sql`
4. Run the migration

### Step 2: Deploy Frontend Changes
```bash
# Commit and push changes
git add .
git commit -m "Add link moderation system for security"
git push

# Deploy to production (if using Vercel)
npm run deploy
```

### Step 3: Test the Flow
1. Log in as a student
2. Try to add a link → Verify it requires approval
3. Log in as a teacher
4. Navigate to Flagged tab → Verify pending link appears
5. Approve the link → Verify it appears in song library

## Database Schema

```sql
CREATE TABLE pending_links (
  id UUID PRIMARY KEY,
  song_id UUID REFERENCES songs(id),
  link_type TEXT, -- 'youtube_url', 'chords_url', 'tutorial_url'
  url TEXT,
  submitted_by_user_id UUID REFERENCES users(id),
  submitted_at TIMESTAMP,
  status TEXT, -- 'pending', 'approved', 'rejected'
  reviewed_by_user_id UUID REFERENCES users(id),
  reviewed_at TIMESTAMP
);
```

## Future Enhancements

1. **Notification System**: Alert teachers when new links are submitted
2. **Link History**: Show students which of their links were approved/rejected
3. **Bulk Actions**: Allow teachers to approve/reject multiple links at once
4. **Link Validation**: Auto-check if URLs are valid before submission
5. **Submission Limits**: Prevent spam by limiting submissions per student
6. **Rejection Reasons**: Let teachers provide feedback on rejected links

## Notes

- Teachers can still add/edit links directly without approval (maintains admin control)
- The flagged tab now serves dual purpose: rating discrepancies + link moderation
- All previous links have been cleared for security - teachers may want to re-add trusted links
- The system uses RLS (Row Level Security) to enforce permissions at the database level
