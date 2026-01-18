# Testing Checklist: Phase 3 & Phase 4

**Testing Date:** _________________
**Tester Name:** _________________
**Environment:** _________________

---

## Pre-Testing Setup

- [ ] Database is properly seeded with test data
- [ ] At least 3 user accounts created (1 student, 1 teacher, 1 admin)
- [ ] Sample instruments are configured
- [ ] Sample songs exist in the library
- [ ] Test data includes various progress levels

---

# PHASE 3: TEACHER DASHBOARD

## 1. Class Management

### 1.1 Create Classes
- [ ] Navigate to "My Classes" tab as a teacher
- [ ] Click "Create New Class" button
- [ ] Modal opens with form fields
- [ ] Enter class name (e.g., "Music 101")
- [ ] Enter year level (e.g., "Year 9") - Optional field
- [ ] Submit form
- [ ] Class appears in class list
- [ ] Verify class has a unique 6-character class code
- [ ] Verify class code is alphanumeric
- [ ] Create second class to verify unique codes are generated
- [ ] Verify creation date is displayed correctly
- [ ] Verify student count shows "0 students" initially

### 1.2 Class Cards Display
- [ ] Each class displays as a card
- [ ] Card shows class name prominently
- [ ] Card shows year level (if provided)
- [ ] Card shows student count
- [ ] Card shows creation date
- [ ] Hover effect works on class cards
- [ ] Cards are visually organized and readable
- [ ] Click on class card opens class detail view

### 1.3 Archive Classes
- [ ] Archive button/option is available for each class
- [ ] Click archive for a test class
- [ ] Confirmation dialog appears
- [ ] Confirm archiving
- [ ] Class moves to archived section or is hidden
- [ ] Archived classes can be viewed separately (if implemented)
- [ ] Archived classes don't show in active class list

## 2. Class Detail Interface (3-Tab System)

### 2.1 Navigation to Class Details
- [ ] Click on a class card
- [ ] Class detail view opens
- [ ] Class name is displayed in header
- [ ] Class code is visible
- [ ] Three tabs are visible: Roster, Progress Heatmap, Timeline
- [ ] Back button/link returns to class list

### 2.2 Roster Tab

#### Empty State
- [ ] Switch to Roster tab with empty class
- [ ] Empty state message is displayed
- [ ] Class code is shown prominently for student enrollment
- [ ] Instructions for students to join are clear

#### Student List
- [ ] Have a student join the class using the class code
- [ ] Student appears in roster
- [ ] Student name is displayed
- [ ] Join date is shown correctly
- [ ] Student's instruments are displayed with emoji icons
- [ ] Multiple students display in a clean list format
- [ ] Student count in class card updates correctly

#### Student Detail Modal
- [ ] Click on a student in the roster
- [ ] Student detail modal opens
- [ ] Modal shows student name
- [ ] All instruments student is tracking are listed
- [ ] For each instrument:
  - [ ] Current level is displayed
  - [ ] Current branch is shown (if Level 4-5)
  - [ ] Count of "Learning" songs is shown
  - [ ] Count of "Mastered" songs is shown
- [ ] Recently mastered songs section shows up to 5 songs per instrument
- [ ] Mastered songs show dates
- [ ] Modal has good readability (large size)
- [ ] Close button works properly

### 2.3 Progress Heatmap Tab

- [ ] Switch to Progress Heatmap tab
- [ ] Grid/table displays with students on rows
- [ ] Instruments displayed in columns
- [ ] Column headers are sticky (remain visible when scrolling)
- [ ] Each cell shows student's level for that instrument
- [ ] Levels are color-coded (different colors for Level 1-5)
- [ ] Cells show "-" for instruments student hasn't started
- [ ] Colors are visually distinct and readable
- [ ] Easy to scan across rows and columns
- [ ] Works with multiple students (5+ students)
- [ ] Scrolling works smoothly

### 2.4 Timeline Tab

- [ ] Switch to Timeline tab
- [ ] Activity feed displays chronologically (most recent first)
- [ ] Each activity shows:
  - [ ] Student name
  - [ ] Instrument icon/emoji
  - [ ] Action (started/mastered)
  - [ ] Song title
  - [ ] Time ago (e.g., "2h ago", "3d ago")
- [ ] Time-ago formatting is accurate:
  - [ ] "just now" for very recent
  - [ ] "Xm ago" for minutes
  - [ ] "Xh ago" for hours
  - [ ] "Xd ago" for days
- [ ] Loads recent 20 activities
- [ ] Activities are from students in this class only
- [ ] Visual design is clean (left-border accents)
- [ ] Activities update when new progress is made

## 3. Submissions Review

### 3.1 Submissions Feed
- [ ] Navigate to "Submissions" tab (teacher menu)
- [ ] All student song assessments are displayed
- [ ] Each submission shows:
  - [ ] Student name
  - [ ] Song title and artist
  - [ ] Instrument played
  - [ ] Assessed level (1-5)
  - [ ] Submission time/date
- [ ] Submissions are sorted by most recent first
- [ ] Multiple submissions display correctly

### 3.2 Edit Submissions
- [ ] Click on a submission to edit
- [ ] Edit modal/form opens
- [ ] Current assessed level is displayed
- [ ] Can change the level (dropdown or input)
- [ ] Can add notes (if implemented)
- [ ] Save changes
- [ ] Changes are reflected in submission list
- [ ] Changes update student's progress correctly

### 3.3 Filtering (if UI implemented)
- [ ] Filter by class dropdown works
- [ ] Filter by instrument dropdown works
- [ ] Filters update the submission list correctly
- [ ] Clear filters returns to all submissions

## 4. Flagged Ratings System

### 4.1 Automatic Detection
- [ ] Navigate to "Flagged Ratings" tab (teacher menu)
- [ ] Songs with 2+ level discrepancies are displayed
- [ ] Each flagged song shows:
  - [ ] Song title and artist
  - [ ] Discrepancy badge (e.g., "3 level gap")
  - [ ] All student ratings for that song
- [ ] Badge shows the correct discrepancy size (max - min levels)

### 4.2 Review Discrepancies
- [ ] Click on a flagged song
- [ ] Side-by-side comparison of all ratings is shown
- [ ] Can see which students rated it at which levels
- [ ] Student names are visible with their ratings
- [ ] Easy to identify outliers
- [ ] Can edit individual ratings from this view (if implemented)

### 4.3 Quality Assurance
- [ ] Create test scenario with discrepant ratings:
  - [ ] Student A rates song at Level 2
  - [ ] Student B rates same song at Level 4
- [ ] Verify song appears in flagged ratings
- [ ] Verify discrepancy is calculated correctly (2 levels)
- [ ] Edit one rating to reduce discrepancy below 2
- [ ] Verify song is removed from flagged list

## 5. Data Export

### 5.1 CSV Export Functionality
- [ ] Click "Export Data" button (or similar)
- [ ] CSV file downloads automatically
- [ ] Filename includes class name
- [ ] Open CSV file in spreadsheet application

### 5.2 CSV Content Verification
- [ ] CSV contains all students in the class
- [ ] For each student, verify columns:
  - [ ] Student name
  - [ ] Student email
  - [ ] Instrument
  - [ ] Current level
  - [ ] Current branch (for Level 4-5)
  - [ ] Count of "Learning" songs
  - [ ] Count of "Mastered" songs
- [ ] Data is accurate compared to UI display
- [ ] Format is compatible with Excel/Google Sheets
- [ ] No formatting errors or missing data

### 5.3 Multiple Classes
- [ ] Export data from different classes
- [ ] Verify each export contains only that class's data
- [ ] Filenames are distinct for each class

## 6. Student Class Features

### 6.1 Join Classes
- [ ] Log in as a student account
- [ ] Navigate to "My Classes" or join class section
- [ ] Input field for class code is visible
- [ ] Enter a valid 6-character class code
- [ ] Submit the code
- [ ] Success message displays showing class name
- [ ] Class appears in student's class list
- [ ] Verify student appears in teacher's roster

### 6.2 Validation
- [ ] Enter code with wrong length (e.g., 5 characters)
- [ ] Verify validation error appears
- [ ] Enter non-existent code (e.g., "XXXXXX")
- [ ] Verify error message indicates code doesn't exist
- [ ] Try joining same class twice
- [ ] Verify error prevents duplicate joins
- [ ] Success message only appears for valid joins

### 6.3 Class Listing
- [ ] View list of enrolled classes as student
- [ ] Can see class names
- [ ] Can see teacher names (if implemented)
- [ ] Can see when joined

## 7. Role-Based Access Control (Phase 3)

### 7.1 Teacher Role
- [ ] Log in as teacher account
- [ ] Verify "My Classes" tab is visible
- [ ] Verify "Submissions" tab is visible
- [ ] Verify "Flagged Ratings" tab is visible
- [ ] Verify admin tabs are NOT visible
- [ ] Access class management features
- [ ] Create, view, and manage classes

### 7.2 Student Role
- [ ] Log in as student account
- [ ] Verify teacher tabs are NOT visible
- [ ] Verify admin tabs are NOT visible
- [ ] Can access standard student features
- [ ] Can join classes but not create them

### 7.3 Admin Role (inherits teacher access)
- [ ] Log in as admin account
- [ ] Verify teacher tabs ARE visible
- [ ] Verify can perform all teacher functions
- [ ] Can create and manage classes
- [ ] Admin features are also accessible

## 8. Database & Security (Phase 3)

### 8.1 Row-Level Security
- [ ] As Teacher A, create a class
- [ ] As Teacher B (different account), verify cannot see Teacher A's class
- [ ] Verify teachers only see their own classes in the list
- [ ] Verify students in a class can see each other's basic info
- [ ] Verify students cannot access classes they haven't joined

### 8.2 Class Code Generation
- [ ] Create 5 classes rapidly
- [ ] Verify all class codes are unique
- [ ] Verify all codes are 6 characters
- [ ] Verify codes are alphanumeric
- [ ] Check database function `generate_class_code()` handles collisions

### 8.3 Data Integrity
- [ ] Verify class_members table correctly links classes and students
- [ ] Verify joined_at timestamps are accurate
- [ ] Verify student counts are calculated correctly
- [ ] Delete a student from a class (if feature exists)
- [ ] Verify counts update properly

---

# PHASE 4: ADMIN INTERFACE

## 1. System Statistics Dashboard

### 1.1 Navigation to Admin Dashboard
- [ ] Log in as admin account
- [ ] Admin tab is visible in navigation
- [ ] Click on Admin tab/menu
- [ ] Admin dashboard loads
- [ ] Four stat cards are displayed

### 1.2 Statistics Accuracy
- [ ] Total Users count matches actual registered users
- [ ] Count updates when new user is created
- [ ] Songs in Library count shows only approved songs
- [ ] Count excludes pending/unapproved songs
- [ ] Total Ratings count matches song_ratings table
- [ ] Active Classes count matches non-archived classes
- [ ] All counts are real-time/accurate

### 1.3 Visual Design
- [ ] Stat cards are in grid layout
- [ ] Cards are visually distinct and readable
- [ ] Numbers are prominently displayed
- [ ] Labels are clear
- [ ] Responsive layout works on different screen sizes

## 2. Level Management

### 2.1 View All Levels
- [ ] Navigate to "Levels & Checklists" section
- [ ] All levels across all instruments are displayed
- [ ] Each level card shows:
  - [ ] Level number and name
  - [ ] Description text
  - [ ] Skills list
  - [ ] Example songs
  - [ ] Branch information (for Level 4-5)
  - [ ] Instrument icon and name
- [ ] Levels are organized by instrument
- [ ] Multiple levels per instrument display correctly

### 2.2 Edit Level Dialog
- [ ] Click "Edit" on a level card
- [ ] Edit Level modal opens
- [ ] Modal is pre-populated with current data:
  - [ ] Level name
  - [ ] Description
  - [ ] Skills (one per line)
  - [ ] Example songs (comma-separated)
- [ ] Modify level name
- [ ] Modify description
- [ ] Add/remove skills
- [ ] Update example songs
- [ ] Click Save
- [ ] Changes are saved to database
- [ ] Level card updates with new information
- [ ] Close modal

### 2.3 Data Persistence
- [ ] Edit a level
- [ ] Refresh the page
- [ ] Verify changes persist
- [ ] Check database directly if possible
- [ ] Verify skills JSON array is properly stored
- [ ] Verify example songs list is properly stored

## 3. Grading Checklist Editor

### 3.1 Access Checklist Editor
- [ ] Click "Edit Checklist" on a level card
- [ ] Edit Checklist modal opens
- [ ] Current checklist criteria are displayed
- [ ] Each criterion shows name and options

### 3.2 Edit Criteria
- [ ] Modify a criterion name
- [ ] Verify changes appear in form
- [ ] Modify criterion options
- [ ] Add a new criterion using the editor
- [ ] Remove a criterion
- [ ] Reorder criteria (if drag-and-drop implemented)

### 3.3 Save Checklist Changes
- [ ] Click "Save Checklist" button
- [ ] Changes are saved to database
- [ ] Modal closes (or shows success message)
- [ ] Reopen checklist editor
- [ ] Verify all changes persisted
- [ ] Check that grading_checklist_json in levels table is updated

### 3.4 JSON Storage Verification
- [ ] Inspect database levels table
- [ ] Verify grading_checklist_json column contains valid JSON
- [ ] Verify structure matches expected format
- [ ] Test that checklist loads correctly for student assessments

## 4. Instrument Management

### 4.1 View Instruments
- [ ] Navigate to "Instruments" section
- [ ] All instruments are listed
- [ ] Each instrument shows:
  - [ ] Name
  - [ ] Emoji icon
  - [ ] Description
  - [ ] Display order
  - [ ] Level count (number of levels configured)
- [ ] Instruments are sorted by display order

### 4.2 Create New Instrument
- [ ] Click "Add Instrument" button
- [ ] Instrument modal opens with blank form
- [ ] Modal title says "Add Instrument"
- [ ] Fill in:
  - [ ] Instrument name (e.g., "Drums")
  - [ ] Emoji icon (e.g., "🥁")
  - [ ] Description
  - [ ] Display order (number)
- [ ] Submit form
- [ ] New instrument appears in list
- [ ] Instrument is saved to database
- [ ] Can select new instrument elsewhere in app

### 4.3 Edit Instrument
- [ ] Click "Edit" on an existing instrument
- [ ] Instrument modal opens
- [ ] Modal title says "Edit Instrument"
- [ ] Form is pre-populated with current values
- [ ] Modify name
- [ ] Change emoji
- [ ] Update description
- [ ] Change display order
- [ ] Save changes
- [ ] Instrument list updates
- [ ] Changes persist in database

### 4.4 Delete Instrument
- [ ] Click "Delete" on an instrument (that has no data)
- [ ] Confirmation dialog appears
- [ ] Confirm deletion
- [ ] Instrument is removed from list
- [ ] Instrument is deleted from database
- [ ] Try to delete instrument with associated levels
- [ ] Verify error or prevention message (if implemented)

### 4.5 Display Order
- [ ] Create/edit instruments with different display orders
- [ ] Verify list sorts by display order ascending
- [ ] Verify display order affects instrument selection dropdowns
- [ ] Verify display order is consistent throughout app

## 5. Content Moderation

### 5.1 Song Review Dashboard
- [ ] Navigate to "Content Moderation" section
- [ ] All submitted songs are displayed
- [ ] Each song card shows:
  - [ ] Title and artist
  - [ ] Instrument
  - [ ] Submitter name
  - [ ] Status badge (Approved/Pending)
  - [ ] Resource indicators (Chords/Tutorial/YouTube)
  - [ ] Date added

### 5.2 Status Display
- [ ] Approved songs have green badge
- [ ] Pending songs have yellow badge
- [ ] Badge colors are visually distinct
- [ ] Status accurately reflects database approved field

### 5.3 Filter by Status
- [ ] Status filter dropdown is available
- [ ] Select "All" - shows all songs
- [ ] Select "Approved" - shows only approved songs
- [ ] Select "Pending" - shows only pending songs
- [ ] Filter updates list immediately

### 5.4 Filter by Instrument
- [ ] Instrument filter dropdown is available
- [ ] Select specific instrument
- [ ] Only songs for that instrument are shown
- [ ] Select "All Instruments" - shows all songs
- [ ] Combine status and instrument filters
- [ ] Both filters work together correctly

### 5.5 Moderate Song
- [ ] Click on a song card to moderate
- [ ] Song moderation modal opens
- [ ] Modal shows complete song details:
  - [ ] Title, artist, instrument
  - [ ] Resources (chords link, tutorial link, YouTube video)
  - [ ] Submitter information
  - [ ] Current approval status

### 5.6 Approve Song
- [ ] Click "Approve" button on pending song
- [ ] Song status changes to "Approved"
- [ ] Badge updates to green
- [ ] Song appears in student song library
- [ ] Database approved field is set to true

### 5.7 Unapprove Song
- [ ] Click "Unapprove" button on approved song
- [ ] Song status changes to "Pending"
- [ ] Badge updates to yellow
- [ ] Song is hidden from student song library
- [ ] Database approved field is set to false

### 5.8 Delete Song
- [ ] Click "Delete" button
- [ ] Confirmation dialog appears
- [ ] Confirm deletion
- [ ] Song is removed from list
- [ ] Song is permanently deleted from database
- [ ] Verify associated ratings are handled (deleted or orphaned check)

### 5.9 View Song Resources
- [ ] Click on song with chords link
- [ ] Verify link indicator shows checkmark/icon
- [ ] Click on song with tutorial link
- [ ] Verify link indicator shows checkmark/icon
- [ ] Click on song with YouTube video
- [ ] Verify link indicator shows checkmark/icon
- [ ] Resources are clickable (if implemented)

## 6. User Management

### 6.1 User Listing
- [ ] Navigate to "User Management" section
- [ ] All registered users are displayed
- [ ] Each user card shows:
  - [ ] Name and email
  - [ ] Current role (Student/Teacher/Admin)
  - [ ] Number of instruments tracked
  - [ ] User creation date
- [ ] Multiple users display correctly

### 6.2 Role Display
- [ ] Student role has appropriate badge/styling
- [ ] Teacher role has appropriate badge/styling
- [ ] Admin role has appropriate badge/styling
- [ ] Badges are visually distinct

### 6.3 Filter by Role
- [ ] Role filter dropdown is available
- [ ] Select "All" - shows all users
- [ ] Select "Students" - shows only students
- [ ] Select "Teachers" - shows only teachers
- [ ] Select "Admins" - shows only admins
- [ ] Filter updates list immediately

### 6.4 Search Users
- [ ] Search field is available
- [ ] Type user's name
- [ ] List filters to matching users
- [ ] Type user's email
- [ ] List filters to matching users
- [ ] Search is case-insensitive
- [ ] Clear search returns to full list
- [ ] Search works with role filter simultaneously

### 6.5 Edit User Role
- [ ] Click "Edit Role" on a user
- [ ] Edit User Role modal opens
- [ ] Current role is displayed/selected
- [ ] Three role options available:
  - [ ] Student
  - [ ] Teacher
  - [ ] Admin
- [ ] Select different role
- [ ] Save changes
- [ ] User role badge updates in list
- [ ] Database users.role field is updated

### 6.6 Role Change Effects
- [ ] Change student to teacher
- [ ] Log in as that user
- [ ] Verify teacher tabs are now visible
- [ ] Change teacher to student
- [ ] Log in as that user
- [ ] Verify teacher tabs are hidden
- [ ] Change user to admin
- [ ] Log in as that user
- [ ] Verify admin tabs are visible

### 6.7 User Instruments Tracking
- [ ] Verify "Instruments tracked" count is accurate
- [ ] Have user add a new instrument to their pathway
- [ ] Refresh user management
- [ ] Verify count increments

## 7. Admin Interface Structure

### 7.1 Four-Section Tabbed Interface
- [ ] All four sections are accessible via tabs:
  - [ ] Levels & Checklists
  - [ ] Instruments
  - [ ] Content Moderation
  - [ ] User Management
- [ ] Click each tab
- [ ] Correct section content loads
- [ ] Tab navigation is smooth

### 7.2 Active Section Highlighting
- [ ] Click on "Levels & Checklists" tab
- [ ] Tab has active/highlighted style
- [ ] Other tabs are not highlighted
- [ ] Click on "Instruments" tab
- [ ] New tab becomes active
- [ ] Previous tab becomes inactive
- [ ] Visual indicator is clear

### 7.3 Section Persistence
- [ ] Navigate to a specific section
- [ ] Perform actions in that section
- [ ] Navigate to different section
- [ ] Return to original section
- [ ] Verify previous state is maintained (if applicable)

## 8. Role-Based Access Control (Phase 4)

### 8.1 Admin Role Only
- [ ] Log in as admin account
- [ ] Verify Admin tab/menu is visible
- [ ] Access all admin sections successfully

### 8.2 Teacher Account (No Admin Access)
- [ ] Log in as teacher account
- [ ] Verify Admin tab/menu is NOT visible
- [ ] Try to navigate directly to admin route (if URLs are accessible)
- [ ] Verify access is denied or redirected

### 8.3 Student Account (No Admin Access)
- [ ] Log in as student account
- [ ] Verify Admin tab/menu is NOT visible
- [ ] Try to navigate directly to admin route
- [ ] Verify access is denied or redirected

### 8.4 Database Security
- [ ] Verify RLS policies prevent non-admins from modifying:
  - [ ] Levels
  - [ ] Instruments
  - [ ] Other users' roles
- [ ] Test database queries as non-admin user
- [ ] Verify read-only access where appropriate

## 9. Admin Modals and Forms

### 9.1 Modal Functionality
- [ ] Each admin modal opens correctly
- [ ] Modals have proper titles
- [ ] Close buttons work
- [ ] Clicking outside modal closes it (if implemented)
- [ ] ESC key closes modal (if implemented)

### 9.2 Form Validation
- [ ] Required fields are enforced
- [ ] Error messages appear for invalid input
- [ ] Cannot submit forms with missing required fields
- [ ] Success messages appear after successful submission

### 9.3 Form State Management
- [ ] Forms are properly reset after submission
- [ ] Edit forms load with current data
- [ ] Add forms are blank
- [ ] Form mode (add vs. edit) is correctly determined

## 10. System Integration Tests

### 10.1 End-to-End: Add Instrument & Create Levels
- [ ] As admin, create a new instrument
- [ ] Navigate to levels section
- [ ] Verify new instrument has no levels initially
- [ ] Create level for new instrument (if add level feature exists)
- [ ] Verify level appears in admin levels list
- [ ] As student, select new instrument for pathway
- [ ] Verify instrument appears in student interface

### 10.2 End-to-End: Moderate Song & Student Access
- [ ] Have student submit a new song
- [ ] As admin, navigate to Content Moderation
- [ ] Verify song appears with "Pending" status
- [ ] Verify song does NOT appear in student song library
- [ ] Approve the song
- [ ] As student, refresh song library
- [ ] Verify song now appears in library
- [ ] Student can rate the song

### 10.3 End-to-End: User Role Change & Access
- [ ] As admin, change a student to teacher role
- [ ] That user logs out and back in
- [ ] Verify teacher interface is accessible
- [ ] User creates a class
- [ ] Class appears in teacher class list
- [ ] Change user back to student role
- [ ] User logs out and back in
- [ ] Verify teacher interface is hidden
- [ ] Previously created class is still in database but not accessible

### 10.4 End-to-End: Edit Level & Student Experience
- [ ] As admin, edit a level's description and skills
- [ ] Save changes
- [ ] As student, view that level in their pathway
- [ ] Verify updated description appears
- [ ] Verify updated skills appear
- [ ] Student assesses a song at that level
- [ ] Verify grading checklist reflects any changes

---

# Cross-Phase Testing

## 11. Teacher-Admin Integration

### 11.1 Admin as Teacher
- [ ] Admin creates a class
- [ ] Class code is generated
- [ ] Student joins the class
- [ ] Admin views roster as teacher
- [ ] Admin views progress heatmap
- [ ] Admin reviews submissions
- [ ] Admin exports class data
- [ ] All teacher features work for admin

### 11.2 Admin Modifies, Teacher Views
- [ ] Admin edits an instrument name
- [ ] Teacher views class progress heatmap
- [ ] Verify updated instrument name appears
- [ ] Admin approves a song
- [ ] Teacher views submissions for that song
- [ ] Submissions reference correct song

## 12. Data Consistency

### 12.1 Statistics Accuracy
- [ ] Note current system statistics
- [ ] Create a new user via admin interface
- [ ] Refresh statistics
- [ ] Verify "Total Users" increments
- [ ] Approve a pending song
- [ ] Refresh statistics
- [ ] Verify "Songs in Library" increments
- [ ] Student submits a rating
- [ ] Refresh statistics
- [ ] Verify "Total Ratings" increments
- [ ] Teacher creates a class
- [ ] Refresh statistics
- [ ] Verify "Active Classes" increments

### 12.2 Deletion Cascades
- [ ] Create test data: instrument with levels
- [ ] Delete instrument (should fail or cascade)
- [ ] Verify levels are handled appropriately
- [ ] Create test data: song with ratings
- [ ] Delete song via admin
- [ ] Verify ratings are deleted or handled
- [ ] No orphaned data remains

## 13. Performance Testing

### 13.1 Large Dataset Handling
- [ ] Create 20+ students in a class
- [ ] View roster - loads within acceptable time
- [ ] View progress heatmap - renders without lag
- [ ] View timeline - loads recent 20 activities
- [ ] Export CSV - completes within acceptable time

### 13.2 Admin Interface Performance
- [ ] Load user management with 50+ users
- [ ] Filtering and search perform quickly
- [ ] Load content moderation with 100+ songs
- [ ] Filtering updates quickly
- [ ] Load levels section with multiple instruments
- [ ] Page renders without delay

## 14. Mobile/Responsive Testing

### 14.1 Responsive Layouts
- [ ] View teacher interface on mobile device/narrow window
- [ ] Class cards stack vertically
- [ ] Tabs are accessible
- [ ] Modals fit screen
- [ ] View admin interface on mobile device
- [ ] Stat cards stack appropriately
- [ ] Section tabs are usable
- [ ] Forms are usable on small screens

### 14.2 Touch Interactions
- [ ] Tap/touch interactions work on mobile
- [ ] Modals can be dismissed
- [ ] Dropdowns/selects work on touch devices
- [ ] Tab navigation works with touch

## 15. Error Handling

### 15.1 Network Errors
- [ ] Simulate network failure during data load
- [ ] Verify error message appears
- [ ] Retry mechanism works (if implemented)
- [ ] Graceful degradation occurs

### 15.2 Invalid Data
- [ ] Enter invalid class code (student join)
- [ ] Verify appropriate error message
- [ ] Enter duplicate instrument name (admin)
- [ ] Verify validation error (if implemented)
- [ ] Submit form with missing required fields
- [ ] Verify error messages appear

### 15.3 Permission Errors
- [ ] As student, try to access teacher functions via browser console/API
- [ ] Verify 403/permission denied errors
- [ ] As teacher, try to access admin functions
- [ ] Verify permission denied

---

# Final Verification

## 16. Code Quality Checks

- [ ] No console errors in browser console
- [ ] No console warnings (or only expected warnings)
- [ ] All network requests complete successfully
- [ ] No JavaScript errors during normal usage
- [ ] CSS styles load correctly
- [ ] No visual glitches or layout breaks

## 17. Database Integrity

- [ ] All RLS policies are functioning
- [ ] No unauthorized data access is possible
- [ ] Foreign key relationships are maintained
- [ ] Timestamps (created_at, joined_at) are accurate
- [ ] Data types are correct
- [ ] No orphaned records exist

## 18. Documentation Review

- [ ] FEATURES.md accurately describes Phase 3 features
- [ ] FEATURES.md accurately describes Phase 4 features
- [ ] Code comments are clear where complex logic exists
- [ ] Database schema is documented (if schema docs exist)

---

# Testing Summary

**Total Tests Passed:** _____ / _____
**Critical Issues Found:** _____
**Minor Issues Found:** _____
**Blockers:** _____

## Critical Issues
1.
2.
3.

## Minor Issues
1.
2.
3.

## Recommendations
1.
2.
3.

---

**Testing Completed By:** _________________
**Date:** _________________
**Sign-off:** _________________
