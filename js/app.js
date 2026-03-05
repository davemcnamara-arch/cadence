// Main Application Module
import { supabase } from './config.js';
import { auth } from './auth.js';

// Expose for debugging
window.supabase = supabase;

class CadenceApp {
  // ============================================
  // CORE: Initialization & Setup
  // ============================================

  constructor() {
    this.currentInstrument = null;
    this.currentFilterInstrument = null;
    this.instruments = [];
    this.levels = [];
    this.songs = [];
    this.studentProgress = [];
    this.studentSongs = [];
    this.currentView = 'pathway';
    this.currentStep = 1;
    this.gradingData = {};

    // Teacher-specific properties
    this.classes = [];
    this.currentClass = null;
    this.classStudents = [];
    this.allTeacherStudents = null;
    this.teacherSongStudentCounts = null;
    this.flaggedRatings = [];

    // Trending songs cache
    this._trendingSongs = null;
    this._trendingSongsCacheInstrument = undefined; // undefined = never loaded

    // Guard against double initialization
    this.initializing = false;

    // Preview mode state
    this.previewMode = {
      active: false,
      studentId: null,
      studentName: null,
      originalUser: null,
      originalView: null,
      originalStudentProgress: null,
      originalInstruments: null,
      originalCurrentInstrument: null,
      originalStudentSongs: null,
      originalLevels: null
    };
  }

  async init() {
    // Show loading screen
    this.showLoading(true);

    // Initialize auth
    auth.onAuthStateChange = async (user) => {
      if (user) {
        try {
          await this.onUserSignedIn(user);
        } catch (error) {
          console.error('Error in onUserSignedIn:', error);
          this.showToast('Failed to load your account. Please refresh the page.', 'error');
        }
      } else {
        this.showLoginScreen();
      }
    };

    // Handle role selection for new users
    auth.onNeedRoleSelection = (authUser) => {
      this.showRoleSelection();
    };

    try {
      await auth.init();
    } catch (error) {
      console.error('Auth init error:', error);
      this.showLoginScreen();
    }

    // Set up event listeners
    this.setupEventListeners();

    // Set up back button after auth (URL hash is now cleaned)
    this.setupBackButtonHandler();

    // Start connection keepalive to prevent stale connections after idle
    this.startConnectionKeepalive();

    this.showLoading(false);
  }

  // Keepalive mechanism to prevent Supabase connection from going stale
  // Uses direct fetch to avoid hanging on stale connections
  startConnectionKeepalive() {
    // Ping every 2 minutes to keep connection alive
    const KEEPALIVE_INTERVAL = 2 * 60 * 1000;

    const pingConnection = async () => {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 5000);

      try {
        const response = await fetch(
          'https://dgwtihpiqgkhokkkxuzo.supabase.co/rest/v1/instruments?select=id&limit=1',
          {
            method: 'GET',
            headers: {
              'apikey': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRnd3RpaHBpcWdraG9ra2t4dXpvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc0OTQzNjcsImV4cCI6MjA4MzA3MDM2N30.xnD7lrvmBlvW-9XzL0VTabAq6wtwsepxb90Assu8bNo'
            },
            signal: controller.signal
          }
        );
        clearTimeout(timeoutId);
        return response.ok;
      } catch (err) {
        clearTimeout(timeoutId);
        console.warn('🎯 Keepalive ping failed:', err.message);
        return false;
      }
    };

    setInterval(async () => {
      // Only ping if the page is visible (don't waste resources when tab is hidden)
      if (document.visibilityState === 'visible') {
        await pingConnection();
      }
    }, KEEPALIVE_INTERVAL);

    // Also reconnect when page becomes visible after being hidden
    document.addEventListener('visibilitychange', async () => {
      if (document.visibilityState === 'visible') {
        // Small delay to let browser wake up
        await new Promise(resolve => setTimeout(resolve, 100));
        // Force-refresh auth session (getSession only returns cached token)
        try {
          await supabase.auth.refreshSession();
        } catch (e) {
          console.warn('Failed to refresh session on visibility change:', e.message);
        }
        await pingConnection();

        // Re-establish realtime subscription if WebSocket died while hidden
        try {
          if (this.songUpdatesSubscription) {
            const state = this.songUpdatesSubscription.state;
            if (state === 'errored' || state === 'closed') {
              console.log('Realtime subscription lost, re-establishing...');
              await this.songUpdatesSubscription.unsubscribe();
              this.setupSongUpdatesSubscription();
            }
          }
        } catch (e) {
          console.warn('Failed to re-establish realtime subscription:', e.message);
        }
      }
    });
  }

  setupEventListeners() {
    // Login
    const loginBtn = document.getElementById('google-login-btn');
    if (loginBtn) {
      loginBtn.addEventListener('click', () => auth.signInWithGoogle());
    }

    // Role Selection
    const studentRoleBtn = document.getElementById('select-student-role');
    if (studentRoleBtn) {
      studentRoleBtn.addEventListener('click', () => this.selectRole('student'));
    }

    const teacherRoleBtn = document.getElementById('select-teacher-role');
    if (teacherRoleBtn) {
      teacherRoleBtn.addEventListener('click', () => this.selectRole('teacher'));
    }

    // Logout
    const logoutBtn = document.getElementById('logout-btn');
    if (logoutBtn) {
      logoutBtn.addEventListener('click', async (e) => {
        e.preventDefault();
        e.stopPropagation();
        try {
          // Unsubscribe from real-time updates with timeout
          if (this.songUpdatesSubscription) {
            try {
              await Promise.race([
                this.songUpdatesSubscription.unsubscribe(),
                new Promise((resolve) => setTimeout(resolve, 1000))
              ]);
            } catch (unsubError) {
              // Ignore unsubscribe errors during logout
            }
          }

          await auth.signOut();
        } catch (error) {
          console.error('Error during sign out:', error);
        }
        // Always reset app state and show login screen directly
        this.resetAppState();
        this.showLoginScreen();
      });
    }

    // Exit preview mode
    const exitPreviewBtn = document.getElementById('exit-preview-btn');
    if (exitPreviewBtn) {
      exitPreviewBtn.addEventListener('click', () => this.exitStudentPreview());
    }

    // Navigation
    document.querySelectorAll('.nav-tab').forEach(tab => {
      tab.addEventListener('click', (e) => {
        const view = e.target.dataset.view;
        this.switchView(view);
      });
    });

    // Add instrument
    const addInstrumentBtn = document.getElementById('add-instrument-btn');
    if (addInstrumentBtn) {
      addInstrumentBtn.addEventListener('click', () => {
        this.showInstrumentSelection();
      });
    }

    // Remove instrument
    const removeInstrumentBtn = document.getElementById('remove-instrument-btn');
    if (removeInstrumentBtn) {
      removeInstrumentBtn.addEventListener('click', () => this.removeCurrentInstrument());
    }

    // Instrument selection
    const instrumentDropdown = document.getElementById('current-instrument');
    if (instrumentDropdown) {
      instrumentDropdown.addEventListener('change', (e) => {
        this.selectInstrument(e.target.value);
      });
    }

    // Grade new song
    const gradeNewSongBtn = document.getElementById('grade-new-song-btn');
    if (gradeNewSongBtn) {
      gradeNewSongBtn.addEventListener('click', () => this.showSongGradingModal());
    }

    // Song grading form
    this.setupSongGradingForm();

    // Edit resource modal
    this.setupEditResourceModal();

    // Rate resources modal
    this.setupRateResourcesModal();

    // Student resources modals
    this.setupResourceModals();

    // Export
    const exportBtn = document.getElementById('export-progress-btn');
    if (exportBtn) {
      exportBtn.addEventListener('click', () => this.showExportModal());
    }

    // Join Class toggle
    const joinClassToggleBtn = document.getElementById('join-class-toggle-btn');
    if (joinClassToggleBtn) {
      joinClassToggleBtn.addEventListener('click', () => this.toggleJoinClassSection());
    }

    // Modal close buttons
    document.querySelectorAll('.modal-close').forEach(btn => {
      btn.addEventListener('click', (e) => {
        e.target.closest('.modal').classList.add('hidden');
      });
    });

    // Search and filters
    const searchInput = document.getElementById('song-search');
    if (searchInput) {
      searchInput.addEventListener('input', (e) => this.filterSongs());
    }

    const filterInstrument = document.getElementById('filter-instrument');
    if (filterInstrument) {
      filterInstrument.addEventListener('change', () => this.filterSongs());
    }

    const filterLevel = document.getElementById('filter-level');
    if (filterLevel) {
      filterLevel.addEventListener('change', () => this.filterSongs());
    }

    const filterIncludeArchived = document.getElementById('filter-include-archived');
    if (filterIncludeArchived) {
      filterIncludeArchived.addEventListener('change', () => this.renderSongs());
    }

    // Class search
    const classSearchInput = document.getElementById('class-search');
    if (classSearchInput) {
      classSearchInput.addEventListener('input', () => this.filterClasses());
    }

    // Student search (across all classes)
    const studentSearchInput = document.getElementById('student-search');
    if (studentSearchInput) {
      studentSearchInput.addEventListener('input', () => this.filterStudents());
    }

    // Teacher: Student Songs filters
    const studentSongsSearch = document.getElementById('student-songs-search');
    if (studentSongsSearch) {
      studentSongsSearch.addEventListener('input', () => this.filterStudentSongs());
    }
    const studentSongsClassFilter = document.getElementById('student-songs-class-filter');
    if (studentSongsClassFilter) {
      studentSongsClassFilter.addEventListener('change', () => this.filterStudentSongs());
    }
    const studentSongsInstrumentFilter = document.getElementById('student-songs-instrument-filter');
    if (studentSongsInstrumentFilter) {
      studentSongsInstrumentFilter.addEventListener('change', () => this.filterStudentSongs());
    }

    // Teacher: Create class
    const createClassBtn = document.getElementById('create-class-btn');
    if (createClassBtn) {
      createClassBtn.addEventListener('click', () => this.showCreateClassModal());
    }

    // Teacher: Class tabs
    document.querySelectorAll('.class-tab').forEach(tab => {
      tab.addEventListener('click', (e) => {
        this.switchClassTab(e.target.dataset.tab);
      });
    });

    // Teacher: Back to classes list
    const backToClassesBtn = document.getElementById('back-to-classes-btn');
    if (backToClassesBtn) {
      backToClassesBtn.addEventListener('click', () => this.showClassesList());
    }

    // Teacher: Export class data
    const exportClassBtn = document.getElementById('export-class-data-btn');
    if (exportClassBtn) {
      exportClassBtn.addEventListener('click', () => this.exportClassData());
    }

    // Teacher: Edit class
    const editClassBtn = document.getElementById('edit-class-btn');
    if (editClassBtn) {
      editClassBtn.addEventListener('click', () => this.showEditClassModal());
    }

    // Teacher: Archive class
    const archiveClassBtn = document.getElementById('archive-class-btn');
    if (archiveClassBtn) {
      archiveClassBtn.addEventListener('click', () => this.showArchiveClassModal());
    }

    // Teacher: Bulk add students
    const bulkAddStudentsBtn = document.getElementById('bulk-add-students-btn');
    if (bulkAddStudentsBtn) {
      bulkAddStudentsBtn.addEventListener('click', () => this.showBulkAddStudentsModal());
    }

    // Teacher: Submit bulk emails
    const submitBulkEmailsBtn = document.getElementById('submit-bulk-emails-btn');
    if (submitBulkEmailsBtn) {
      submitBulkEmailsBtn.addEventListener('click', () => this.submitBulkEmails());
    }

    // Teacher: Confirm archive
    const confirmArchiveBtn = document.getElementById('confirm-archive-btn');
    if (confirmArchiveBtn) {
      confirmArchiveBtn.addEventListener('click', () => {
        // Close modal immediately for better UX
        document.getElementById('archive-class-modal').classList.add('hidden');
        this.archiveClass();
      });
    }

    // Teacher: Show archived classes toggle
    const showArchivedCheckbox = document.getElementById('show-archived-classes');
    if (showArchivedCheckbox) {
      showArchivedCheckbox.addEventListener('change', () => this.loadClasses());
    }

    // Student: Join class
    const joinClassBtn = document.getElementById('join-class-btn');
    if (joinClassBtn) {
      joinClassBtn.addEventListener('click', () => this.joinClass());
    }

    // Setup teacher forms
    this.setupCreateClassForm();
    this.setupEditClassForm();
    this.setupEditStudentForm();
    this.setupEditSongLevelForm();
    this.setupEditSongDetailsForm();
    this.setupFlaggedFilters();

    // Teacher: Confirm remove student
    const confirmRemoveStudentBtn = document.getElementById('confirm-remove-student-btn');
    if (confirmRemoveStudentBtn) {
      confirmRemoveStudentBtn.addEventListener('click', () => this.removeStudentFromClass());
    }

    // Teacher/Admin: Confirm transfer student
    const confirmTransferStudentBtn = document.getElementById('confirm-transfer-student-btn');
    if (confirmTransferStudentBtn) {
      confirmTransferStudentBtn.addEventListener('click', () => this.executeTransferStudent());
    }

    // Admin: Section tabs
    document.querySelectorAll('.admin-section-tab').forEach(tab => {
      tab.addEventListener('click', (e) => {
        this.switchAdminSection(e.target.dataset.section);
      });
    });

    // Admin: Level instrument filter
    const adminLevelInstrument = document.getElementById('admin-level-instrument');
    if (adminLevelInstrument) {
      adminLevelInstrument.addEventListener('change', (e) => {
        this.currentAdminLevelInstrument = e.target.value;
        this.renderAdminLevels();
      });
    }

    // Admin: Add instrument button
    const addInstrumentAdminBtn = document.getElementById('add-instrument-admin-btn');
    if (addInstrumentAdminBtn) {
      addInstrumentAdminBtn.addEventListener('click', () => this.showAddInstrumentModal());
    }

    // Admin: Content filters
    const contentFilterStatus = document.getElementById('content-filter-status');
    if (contentFilterStatus) {
      contentFilterStatus.addEventListener('change', () => this.loadContentModeration());
    }

    const contentSearch = document.getElementById('content-search');
    if (contentSearch) {
      contentSearch.addEventListener('input', () => this.renderContentModeration());
    }

    // Admin: User filters
    const userFilterRole = document.getElementById('user-filter-role');
    if (userFilterRole) {
      userFilterRole.addEventListener('change', () => this.loadUsersManagement());
    }

    const userSearch = document.getElementById('user-search');
    if (userSearch) {
      userSearch.addEventListener('input', () => this.renderUsersManagement());
    }

    // Admin: Song moderation buttons
    const approveSongBtn = document.getElementById('approve-song-btn');
    if (approveSongBtn) {
      approveSongBtn.addEventListener('click', () => this.approveSong(true));
    }

    const unapproveSongBtn = document.getElementById('unapprove-song-btn');
    if (unapproveSongBtn) {
      unapproveSongBtn.addEventListener('click', () => this.approveSong(false));
    }

    const editModerateSongBtn = document.getElementById('edit-moderate-song-btn');
    if (editModerateSongBtn) {
      editModerateSongBtn.addEventListener('click', () => {
        const song = this.adminContentList?.find(s => s.id === this.currentModeratingSongId);
        if (song) {
          this.editSongDetails(song.id, song.title, song.artist, song.suggested_level || null);
        }
      });
    }

    const deleteSongBtn = document.getElementById('delete-song-btn');
    if (deleteSongBtn) {
      deleteSongBtn.addEventListener('click', () => this.deleteSong());
    }

    // Scan duplicates button
    const scanDuplicatesBtn = document.getElementById('scan-duplicates-btn');
    if (scanDuplicatesBtn) {
      scanDuplicatesBtn.addEventListener('click', () => this.scanForDuplicates());
    }

    // Confirm merge button
    const confirmMergeBtn = document.getElementById('confirm-merge-btn');
    if (confirmMergeBtn) {
      confirmMergeBtn.addEventListener('click', () => this.executeMerge());
    }

    // Setup admin forms
    this.setupAdminForms();

    // Account Management: Create teacher button
    const createTeacherBtn = document.getElementById('create-teacher-btn');
    if (createTeacherBtn) {
      createTeacherBtn.addEventListener('click', () => this.showCreateTeacherModal());
    }

    // Account Management: Create teacher form
    const createTeacherForm = document.getElementById('create-teacher-form');
    if (createTeacherForm) {
      createTeacherForm.addEventListener('submit', (e) => {
        e.preventDefault();
        this.createTeacherAccount();
      });
    }

    // Account Management: Delete account confirmation
    const confirmDeleteBtn = document.getElementById('confirm-delete-account-btn');
    if (confirmDeleteBtn) {
      confirmDeleteBtn.addEventListener('click', () => this.deleteUserAccount());
    }

    // Account Management: Promote to teacher confirmation
    const confirmPromoteBtn = document.getElementById('confirm-promote-teacher-btn');
    if (confirmPromoteBtn) {
      confirmPromoteBtn.addEventListener('click', () => this.promoteToTeacher());
    }

    // Account Management: Search and filter
    const accountsSearch = document.getElementById('accounts-search');
    if (accountsSearch) {
      accountsSearch.addEventListener('input', () => this.renderAccountsList());
    }

    const accountsRoleFilter = document.getElementById('accounts-role-filter');
    if (accountsRoleFilter) {
      accountsRoleFilter.addEventListener('change', () => this.renderAccountsList());
    }
  }

  async onUserSignedIn(user) {
    // Prevent concurrent initialization (Supabase can fire SIGNED_IN twice)
    if (this.initializing) {
      return;
    }
    this.initializing = true;

    try {
    // Load user data
    await this.loadInstruments();
    await this.loadStudentProgress();

    // Initialize instrument dropdown after loading data
    this.updateInstrumentDropdown();

    // Set up real-time subscription for song updates (approved links)
    this.setupSongUpdatesSubscription();

    // Update UI
    document.getElementById('user-name').textContent = user.name;
    this.showApp();

    // Check if user was auto-enrolled in classes (from pending enrollments)
    if (auth.lastEnrollmentResult && auth.lastEnrollmentResult.enrolled_count > 0) {
      const result = auth.lastEnrollmentResult;
      const classNames = result.class_names.join(', ');
      this.showToast(`Welcome! You've been added to: ${classNames}`, 'success');
      auth.lastEnrollmentResult = null; // Clear after showing
    }

    // Restore saved view from sessionStorage (if valid for this role)
    const savedView = sessionStorage.getItem('cadence_currentView');
    const validViews = {
      student: ['pathway', 'songs', 'progress'],
      teacher: ['songs', 'classes', 'student-songs', 'flagged', 'accounts'],
      admin: ['songs', 'classes', 'flagged', 'accounts', 'admin']
    };
    const restoredView = savedView && validViews[user.role]?.includes(savedView) ? savedView : null;

    // Show/hide tabs and features based on role
    if (user.role === 'student') {
      // Show student tabs and features
      document.querySelectorAll('.student-tab').forEach(tab => tab.classList.remove('hidden'));
      // Student tabs will be active by default
      await this.loadStudentClassesHeader();
    } else if (user.role === 'teacher') {
      // Hide student-only features for teachers
      document.querySelectorAll('.student-tab').forEach(tab => tab.classList.add('hidden'));
      document.getElementById('join-class-toggle-btn')?.classList.add('hidden');
      document.getElementById('export-progress-btn')?.classList.add('hidden');

      // Show teacher tabs
      document.querySelectorAll('.teacher-tab').forEach(tab => tab.classList.remove('hidden'));
      document.getElementById('include-archived-filter')?.classList.remove('hidden');
      await this.loadTeacherData();

      // Switch to saved view or teacher's default view
      this.switchView(restoredView || 'classes');
    } else if (user.role === 'admin') {
      // Hide student-only features for admins
      document.querySelectorAll('.student-tab').forEach(tab => tab.classList.add('hidden'));
      document.getElementById('join-class-toggle-btn')?.classList.add('hidden');
      document.getElementById('export-progress-btn')?.classList.add('hidden');

      // Show admin tabs (includes Classes tab for managing all teachers' classes)
      document.querySelectorAll('.admin-tab').forEach(tab => tab.classList.remove('hidden'));
      document.getElementById('include-archived-filter')?.classList.remove('hidden');

      // Change "My Classes" to "Classes" for admin view
      const classesTitle = document.getElementById('classes-view-title');
      if (classesTitle) classesTitle.textContent = 'Classes';

      // Show admin-only account management features
      document.getElementById('create-teacher-btn')?.classList.remove('hidden');
      document.getElementById('pending-accounts-section')?.classList.remove('hidden');

      await this.loadAdminData();
      await this.loadClasses();

      // Switch to saved view or admin view as default for admins
      this.switchView(restoredView || 'admin');
    }

    // Check if user has selected instruments (students only)
    if (user.role === 'student') {
      if (this.studentProgress.length === 0) {
        this.showInstrumentSelection();
      } else {
        // Keep current instrument if it's still valid, otherwise select first
        const validInstrument = this.currentInstrument &&
          this.studentProgress.some(p => p.instrument_id === this.currentInstrument);
        if (!validInstrument) {
          this.currentInstrument = this.studentProgress[0].instrument_id;
        }
        await this.loadLevels(this.currentInstrument);
        await this.loadSongs();
        this.updatePathwayInstrument();
        this.renderPathway();
        this.updateInstrumentDropdown();

        // Restore saved view if different from default pathway
        if (restoredView && restoredView !== 'pathway') {
          this.switchView(restoredView);
        }
      }
    }
    } finally {
      this.initializing = false;
    }
  }

  async loadTeacherData() {
    // Load teacher's classes
    await this.loadClasses();
  }

  // ============================================
  // DATA LOADING: Core Data & Real-time Updates
  // ============================================

  async loadInstruments() {
    // Use direct fetch to bypass stale Supabase client connections
    const { data, error } = await this.callSelectDirect(
      'instruments',
      '*',
      {},
      { order: 'display_order.asc' }
    );

    if (error) {
      console.error('Error loading instruments:', error);
      this.showToast('Failed to load instruments', 'error');
      return;
    }

    this.instruments = data;
  }

  async loadStudentProgress() {
    const user = auth.getCurrentUser();
    // Use student ID if in preview mode, otherwise use current user
    const userId = this.previewMode.active ? this.previewMode.studentId : user.id;

    // Retry once on failure - a transient error here causes the app to think
    // the student has no instruments, skipping all song loading
    for (let attempt = 0; attempt < 2; attempt++) {
      const { data, error } = await this.callSelectDirect(
        'student_progress',
        '*',
        { eq: { user_id: userId } }
      );

      if (!error) {
        this.studentProgress = data || [];
        return;
      }

      console.error(`Error loading progress (attempt ${attempt + 1}):`, error);
      if (attempt === 0) {
        await new Promise(resolve => setTimeout(resolve, 1000));
      }
    }
  }

  async loadLevels(instrumentId) {
    const { data, error } = await this.callSelectDirect(
      'levels',
      '*',
      { eq: { instrument_id: instrumentId } },
      { order: 'level_number.asc' }
    );

    if (error) {
      console.error('Error loading levels:', error);
      this.showToast('Failed to load levels', 'error');
      return;
    }

    this.levels = data;
  }

  async loadSongs() {
    // Prevent concurrent calls, but allow retry if stuck for >30s
    if (this.loadingSongs) {
      if (this.loadingSongsStarted && Date.now() - this.loadingSongsStarted > 30000) {
        console.warn('loadSongs appears stuck, allowing retry');
      } else {
        return;
      }
    }
    this.loadingSongs = true;
    this.loadingSongsStarted = Date.now();

    try {
      // Use direct fetch to bypass stale Supabase client connections
      const { data, error } = await this.callSelectDirect(
        'songs',
        '*,instruments(id,name,icon),song_ratings(assessed_level,instrument_id,user_id)',
        { eq: { approved: true } },
        { order: 'title.asc' }
      );

      if (error) {
        console.error('Error loading songs:', error);
        this.showToast('Failed to load songs. Please try again.', 'error');
        return;
      }

    // Load resource ratings separately and attach to songs
    const { data: resourceRatings } = await this.callSelectDirect(
      'resource_ratings',
      '*,student_songs!inner(song_id)'
    );

    // Create a map of song_id to ratings
    const ratingsMap = {};
    if (resourceRatings) {
      resourceRatings.forEach(rating => {
        const songId = rating.student_songs.song_id;
        if (!ratingsMap[songId]) {
          ratingsMap[songId] = { chords: [], tutorial: [] };
        }
        if (rating.chords_rating) {
          ratingsMap[songId].chords.push(rating.chords_rating);
        }
        if (rating.tutorial_rating) {
          ratingsMap[songId].tutorial.push(rating.tutorial_rating);
        }
      });
    }

    // Load resource counts (all types: tutorials, links, files)
    const { data: resourceCounts } = await this.callSelectDirect(
      'student_resources', 'song_id', { eq: { status: 'approved' } }
    );

    const resourceCountMap = {};
    if (resourceCounts) {
      resourceCounts.forEach(r => {
        resourceCountMap[r.song_id] = (resourceCountMap[r.song_id] || 0) + 1;
      });
    }

    // Attach resource ratings and counts to songs
    this.songs = (data || []).map(song => ({
      ...song,
      resource_ratings: ratingsMap[song.id] || { chords: [], tutorial: [] },
      resource_count: resourceCountMap[song.id] || 0
    }));

    // Remove duplicate songs if any
    const seen = new Set();
    this.songs = this.songs.filter(song => {
      if (seen.has(song.id)) {
        return false;
      }
      seen.add(song.id);
      return true;
    });

    // Load student's own pending links so they can see what they've already submitted
    if (auth.hasRole('student')) {
      try {
        const currentUser = auth.getCurrentUser();
        const { data: myPending } = await this.callSelectDirect(
          'pending_links',
          'id,song_id,link_type,url,submitted_at,status',
          { eq: { submitted_by_user_id: currentUser.id, status: 'pending' } }
        );
        this.myPendingLinks = myPending || [];
      } catch (e) {
        console.error('Error loading pending links:', e);
        this.myPendingLinks = [];
      }
    }
    } finally {
      this.loadingSongs = false;
    }
  }

  setupSongUpdatesSubscription() {
    // Subscribe to all changes in the songs table (INSERT, UPDATE, DELETE)
    const subscription = supabase
      .channel('song-updates')
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'songs'
        },
        (payload) => {
          // Skip if we're already handling this update via approvePendingLink
          if (this.approvingLink) {
            return;
          }

          const eventType = payload.eventType;
          let toastMessage = 'Song library updated!';
          if (eventType === 'INSERT') {
            toastMessage = 'New song added to the library!';
          } else if (eventType === 'UPDATE') {
            toastMessage = 'Song updated!';
          } else if (eventType === 'DELETE') {
            toastMessage = 'Song removed from library';
          }

          // Reload and re-render based on current view
          const handleReloadError = (context) => (err) => {
            console.error(`Failed to reload ${context}:`, err);
            this.showToast('Failed to sync latest changes. Try refreshing.', 'error');
          };

          if (this.currentView === 'songs') {
            this.loadSongs().then(() => {
              this.filterSongs();
              this.showToast(toastMessage, 'info');
            }).catch(handleReloadError('songs view'));
          } else if (this.currentView === 'progress') {
            // Also update progress view if it shows songs
            this.loadSongs().then(() => {
              this.renderProgress();
            }).catch(handleReloadError('progress view'));
          } else if (this.currentView === 'pathway') {
            // Update pathway view as it also shows songs
            this.loadSongs().then(() => {
              this.renderPathway();
            }).catch(handleReloadError('pathway view'));
          } else if (this.currentView === 'admin') {
            // Check if admin content moderation section is visible
            const contentSection = document.getElementById('content-section');
            if (contentSection && contentSection.classList.contains('active')) {
              this.loadContentModeration().then(() => {
                this.showToast(toastMessage, 'info');
              }).catch(handleReloadError('content moderation'));
            }
            // Also update background song data
            this.loadSongs().catch(handleReloadError('background song data'));
          } else {
            // Still update the data in background so it's fresh when they switch views
            this.loadSongs().catch(handleReloadError('background song data'));
          }
        }
      )
      .subscribe();

    // Store subscription so we can unsubscribe later if needed
    this.songUpdatesSubscription = subscription;
  }

  // ============================================
  // INSTRUMENTS: Selection & Management
  // ============================================

  showInstrumentSelection() {
    const container = document.getElementById('instrument-selection');
    const grid = document.getElementById('instrument-grid');

    // Filter out already selected instruments
    const selectedIds = this.studentProgress.map(p => p.instrument_id);
    const availableInstruments = this.instruments.filter(i => !selectedIds.includes(i.id));

    if (availableInstruments.length === 0) {
      this.showToast('You are already tracking all instruments!', 'info');
      return;
    }

    grid.innerHTML = availableInstruments.map(instrument => `
      <div class="instrument-card" data-id="${instrument.id}">
        <div class="icon">${instrument.icon}</div>
        <div class="name">${instrument.name}</div>
      </div>
    `).join('');

    // Add click handlers
    grid.querySelectorAll('.instrument-card').forEach(card => {
      card.addEventListener('click', () => {
        const id = card.dataset.id;
        this.addInstrument(id);
      });
    });

    container.classList.remove('hidden');
  }

  async addInstrument(instrumentId) {
    const user = auth.getCurrentUser();
    // Use student ID if in preview mode, otherwise use current user
    const userId = this.previewMode.active ? this.previewMode.studentId : user.id;

    const { data, error } = await this.callRpcDirect('add_instrument_for_student', {
      p_student_id: userId,
      p_instrument_id: instrumentId
    });

    if (error) {
      console.error('Error adding instrument:', error);
      this.showToast('Failed to add instrument', 'error');
      return;
    }

    this.studentProgress.push(data);
    document.getElementById('instrument-selection').classList.add('hidden');

    // If this is the first instrument, show it
    if (this.studentProgress.length === 1) {
      this.currentInstrument = instrumentId;
      await this.loadLevels(instrumentId);
      await this.loadSongs();
      this.updatePathwayInstrument();
      this.renderPathway();
      this.updateInstrumentDropdown();
    } else {
      this.updateInstrumentDropdown();
      this.renderInstrumentTabs();
    }

    this.showToast('Instrument added successfully!', 'success');
  }

  async removeCurrentInstrument() {
    if (!this.currentInstrument) {
      this.showToast('No instrument selected', 'error');
      return;
    }

    const instrumentName = this.instruments.find(i => i.id === this.currentInstrument)?.name;

    if (!confirm(`Are you sure you want to remove ${instrumentName}? This will delete all your progress and songs for this instrument.`)) {
      return;
    }

    const user = auth.getCurrentUser();
    // Use student ID if in preview mode, otherwise use current user
    const userId = this.previewMode.active ? this.previewMode.studentId : user.id;

    const { error } = await this.callRpcDirect('remove_instrument_for_student', {
      p_student_id: userId,
      p_instrument_id: this.currentInstrument
    });

    if (error) {
      console.error('Error removing instrument:', error);
      this.showToast('Failed to remove instrument', 'error');
      return;
    }

    // Remove from local array
    this.studentProgress = this.studentProgress.filter(p => p.instrument_id !== this.currentInstrument);

    // If there are other instruments, switch to the first one
    if (this.studentProgress.length > 0) {
      const nextInstrument = this.studentProgress[0].instrument_id;
      this.currentInstrument = nextInstrument;
      await this.loadLevels(nextInstrument);
      await this.loadSongs();
      this.updatePathwayInstrument();
      this.renderPathway();
      this.updateInstrumentDropdown();
    } else {
      // No instruments left, show instrument selection
      this.currentInstrument = null;
      this.levels = [];
      this.songs = [];
      document.getElementById('pathway-container').innerHTML = '<p>Select an instrument to get started!</p>';
      this.updateInstrumentDropdown();
      this.showInstrumentSelection();
    }

    this.showToast(`${instrumentName} removed successfully`, 'success');
  }

  async selectInstrument(instrumentId) {
    this.currentInstrument = instrumentId;
    await this.loadLevels(instrumentId);
    this.updatePathwayInstrument();
    this.renderPathway();
  }

  updatePathwayInstrument() {
    const pathwayView = document.getElementById('pathway-view');
    const instrument = this.instruments.find(i => i.id === this.currentInstrument);

    if (pathwayView && instrument) {
      // Set data attribute for instrument-specific styling
      const instrumentSlug = instrument.name.toLowerCase().split('/')[0].replace(/\s+/g, '');
      pathwayView.setAttribute('data-instrument', instrumentSlug);
    }

    // Render instrument tabs
    this.renderInstrumentTabs();
  }

  renderInstrumentTabs() {
    const container = document.querySelector('.instrument-selector');
    if (!container) return;

    const tabsHtml = this.studentProgress.map(progress => {
      const instrument = this.instruments.find(i => i.id === progress.instrument_id);
      const isActive = progress.instrument_id === this.currentInstrument;
      const instrumentSlug = instrument.name.toLowerCase().split('/')[0].replace(/\s+/g, '');

      return `
        <button
          class="instrument-tab ${instrumentSlug} ${isActive ? 'active' : ''}"
          data-instrument-id="${instrument.id}"
          onclick="app.selectInstrument('${instrument.id}')">
          ${instrument.icon} ${instrument.name}
        </button>
      `;
    }).join('');

    const addRemoveButtons = `
      <div style="margin-left: auto; display: flex; gap: 0.5rem;">
        <button id="add-instrument-btn" class="btn-text" onclick="app.showInstrumentSelection()">+ Add Another</button>
        <button id="remove-instrument-btn" class="btn-text btn-danger" onclick="app.removeCurrentInstrument()">Remove Current</button>
      </div>
    `;

    container.innerHTML = `
      <div class="instrument-tabs">
        ${tabsHtml}
        ${addRemoveButtons}
      </div>
    `;
  }

  updateInstrumentDropdown() {
    const dropdown = document.getElementById('current-instrument');
    const filterDropdown = document.getElementById('filter-instrument');
    const gradingDropdown = document.getElementById('grading-instrument');
    const user = auth.getCurrentUser();

    // Only build student progress dropdown if there is progress
    let html = '';
    if (this.studentProgress && this.studentProgress.length > 0) {
      html = this.studentProgress.map(progress => {
        const instrument = this.instruments.find(i => i.id === progress.instrument_id);
        return `<option value="${instrument.id}">${instrument.icon} ${instrument.name}</option>`;
      }).join('');
    }

    if (dropdown) {
      dropdown.innerHTML = html;
      // Restore selection to the currently active instrument
      if (this.currentInstrument && dropdown.querySelector(`option[value="${this.currentInstrument}"]`)) {
        dropdown.value = this.currentInstrument;
      }
    }

    // Update filter dropdown with all instruments
    if (filterDropdown) {
      // Save current selection before rebuilding
      const currentSelection = filterDropdown.value;

      // For teachers/admins, don't show "My Instruments" option
      let allInstrumentsHtml;
      if (user.role === 'teacher' || user.role === 'admin') {
        allInstrumentsHtml = '<option value="">All Instruments</option>' +
          (this.instruments || []).map(i => `<option value="${i.id}">${i.icon} ${i.name}</option>`).join('');
      } else {
        allInstrumentsHtml = '<option value="my-instruments">My Instruments</option>' +
          '<option value="">All Instruments</option>' +
          (this.instruments || []).map(i => `<option value="${i.id}">${i.icon} ${i.name}</option>`).join('');
      }
      filterDropdown.innerHTML = allInstrumentsHtml;

      // Restore previous selection if it exists, otherwise use appropriate default
      if (currentSelection && filterDropdown.querySelector(`option[value="${currentSelection}"]`)) {
        filterDropdown.value = currentSelection;
      } else if (user.role === 'teacher' || user.role === 'admin') {
        // Teachers default to "All Instruments"
        filterDropdown.value = '';
      } else {
        // Students default to "My Instruments"
        filterDropdown.value = 'my-instruments';
      }
    }

    // Update grading dropdown
    // Teachers can grade for any instrument, students only for their own
    if (gradingDropdown) {
      // Only preserve selection if the grading modal is currently visible (background rebuild);
      // when the modal is hidden (initial open), default to the user's active instrument
      const modalOpen = !document.getElementById('song-grading-modal').classList.contains('hidden');
      const gradingSelection = modalOpen ? gradingDropdown.value : null;

      if (user.role === 'teacher' || user.role === 'admin') {
        const allInstrumentsHtml = this.instruments.map(i =>
          `<option value="${i.id}">${i.icon} ${i.name}</option>`
        ).join('');
        gradingDropdown.innerHTML = allInstrumentsHtml;
      } else {
        gradingDropdown.innerHTML = html;
      }

      // Restore previous selection if modal was open, otherwise default to active instrument
      if (gradingSelection && gradingDropdown.querySelector(`option[value="${gradingSelection}"]`)) {
        gradingDropdown.value = gradingSelection;
      } else if (this.currentInstrument && gradingDropdown.querySelector(`option[value="${this.currentInstrument}"]`)) {
        gradingDropdown.value = this.currentInstrument;
      }
    }
  }

  // ============================================
  // STUDENT: Pathway & Progress Visualization
  // ============================================

  renderPathway() {
    const container = document.getElementById('pathway-container');

    // Handle case where no instrument is selected yet
    if (!this.currentInstrument || this.studentProgress.length === 0) {
      if (this.previewMode.active && this.previewMode.dataLoaded) {
        container.innerHTML = '<p style="color: var(--text-secondary);">This student hasn\'t started any instruments yet.</p>';
      } else {
        container.innerHTML = '<p style="color: var(--text-secondary);">Loading pathway...</p>';
      }
      return;
    }

    const progress = this.studentProgress.find(p => p.instrument_id === this.currentInstrument);

    if (!progress) {
      container.innerHTML = '<p style="color: var(--text-secondary);">Loading pathway...</p>';
      return;
    }

    // Handle case where levels haven't been loaded yet
    if (!this.levels || this.levels.length === 0) {
      container.innerHTML = '<p style="color: var(--text-secondary);">Loading pathway...</p>';
      return;
    }

    const currentLevel = progress.current_level;
    const currentBranch = progress.current_branch;
    const instrument = this.instruments.find(i => i.id === this.currentInstrument);

    // Group levels
    const regularLevels = this.levels.filter(l => !l.is_branch && l.level_number <= 3);
    const level4Branches = this.levels.filter(l => l.is_branch && l.level_number === 4);
    const level5Branches = this.levels.filter(l => l.is_branch && l.level_number === 5);

    // Build pathway header
    let html = `
      <div class="pathway-header">
        <div class="pathway-header-icon">${instrument.icon}</div>
        <div class="pathway-header-content">
          <h2>${instrument.name} Pathway</h2>
          <p>Currently at Level ${currentLevel}${currentBranch ? ` - ${currentBranch}` : ''}</p>
        </div>
      </div>
    `;

    html += '<div class="pathway-map">';

    // Render levels 1-3
    regularLevels.forEach(level => {
      const isComplete = currentLevel > level.level_number;
      const isCurrent = currentLevel === level.level_number && !currentBranch;
      html += this.renderLevelNode(level, isComplete, isCurrent);
    });

    // Always show Level 4 branches (students need to see what's ahead)
    if (level4Branches.length > 0) {
      html += '<h3 style="margin-top: 2rem; margin-bottom: 1rem; color: var(--text-secondary);">Level 4: Choose Your Path</h3>';
      html += '<div class="branch-container">';
      level4Branches.forEach(branch => {
        const isSelected = currentBranch === branch.branch_name && currentLevel === 4;
        const isComplete = currentLevel > 4 && currentBranch === branch.branch_name;
        html += this.renderBranchNode(branch, isSelected, isComplete);
      });
      html += '</div>';
    }

    // Always show Level 5 branches (show all 3 options for now)
    if (level5Branches.length > 0) {
      html += '<h3 style="margin-top: 2rem; margin-bottom: 1rem; color: var(--text-secondary);">Level 5: Advanced Mastery</h3>';
      html += '<div class="branch-container">';
      level5Branches.forEach(branch => {
        const isSelected = currentBranch === branch.branch_name && currentLevel === 5;
        const isComplete = false; // Level 5 is the final level
        html += this.renderBranchNode(branch, isSelected, isComplete);
      });
      html += '</div>';
    }

    html += '</div>';
    container.innerHTML = html;

    // Add click handlers to level nodes and branch nodes
    container.querySelectorAll('.level-node, .branch-node').forEach(node => {
      node.addEventListener('click', (e) => {
        // Don't navigate when interacting with the details toggle
        if (e.target.closest('.level-details-toggle')) {
          return;
        }
        const levelNumber = parseInt(node.dataset.level);
        if (levelNumber) {
          this.navigateToLevelSongs(levelNumber);
        }
      });
    });

    // Load and render currently-learning songs strip at top of pathway
    this.loadLearningSongsForStrip().then(songs => this.renderLearningSongsStrip(songs));
  }

  navigateToLevelSongs(levelNumber) {
    // Switch to songs view
    this.switchView('songs');

    // Set filter dropdowns
    const filterLevel = document.getElementById('filter-level');
    const filterInstrument = document.getElementById('filter-instrument');

    if (filterLevel) {
      filterLevel.value = levelNumber.toString();
    }

    if (filterInstrument && this.currentInstrument) {
      filterInstrument.value = this.currentInstrument;
    }

    // Apply filters
    this.filterSongs();

    // Show filter banner
    this.showFilterBanner(levelNumber);
  }

  showFilterBanner(levelNumber) {
    // Remove existing banner if present
    const existingBanner = document.getElementById('filter-banner');
    if (existingBanner) {
      existingBanner.remove();
    }

    // Get instrument name
    const instrumentName = this.instruments.find(i => i.id === this.currentInstrument)?.name || '';

    // Create and insert banner
    const banner = document.createElement('div');
    banner.id = 'filter-banner';
    banner.className = 'filter-banner';
    banner.innerHTML = `
      <span>Showing Level ${levelNumber} songs${instrumentName ? ` for ${instrumentName}` : ''}</span>
      <button class="filter-banner-close" onclick="app.clearLevelFilter()">Clear filter</button>
    `;

    // Insert before songs grid
    const songsGrid = document.getElementById('songs-grid');
    if (songsGrid && songsGrid.parentNode) {
      songsGrid.parentNode.insertBefore(banner, songsGrid);
    }
  }

  clearLevelFilter() {
    // Clear filter dropdowns
    const filterLevel = document.getElementById('filter-level');
    if (filterLevel) {
      filterLevel.value = '';
    }

    // Re-apply filters
    this.filterSongs();

    // Remove banner
    const banner = document.getElementById('filter-banner');
    if (banner) {
      banner.remove();
    }
  }

  renderLevelNode(level, isComplete, isCurrent) {
    const skills = typeof level.skills_json === 'string' ? JSON.parse(level.skills_json) : (level.skills_json || []);
    const statusClass = isComplete ? 'completed' : (isCurrent ? 'current' : '');

    const detailsContent = `
      <p class="level-description">${level.description}</p>
      <ul class="level-skills">
        ${skills.map(skill => `<li>${skill}</li>`).join('')}
      </ul>
      ${level.example_songs && level.example_songs.length > 0 ? `
        <div class="example-songs">
          <strong>Example songs:</strong> ${level.example_songs.join(', ')}
        </div>
      ` : ''}
    `;

    if (isComplete) {
      return `
        <div class="level-node ${statusClass}" data-level="${level.level_number}">
          <div class="level-header">
            <span class="level-number">Level ${level.level_number}</span>
            <span>✓</span>
          </div>
          <h3 class="level-name">${level.name}</h3>
          <details class="level-details-toggle">
            <summary>Show details</summary>
            ${detailsContent}
          </details>
        </div>
      `;
    }

    return `
      <div class="level-node ${statusClass}" data-level="${level.level_number}">
        <div class="level-header">
          <span class="level-number">Level ${level.level_number}</span>
        </div>
        <h3 class="level-name">${level.name}</h3>
        ${detailsContent}
      </div>
    `;
  }

  renderBranchNode(branch, isSelected, isComplete) {
    const skills = typeof branch.skills_json === 'string' ? JSON.parse(branch.skills_json) : (branch.skills_json || []);
    const statusClass = isSelected ? 'selected' : (isComplete ? 'completed' : '');

    return `
      <div class="branch-node ${statusClass}" data-branch="${branch.branch_name}" data-level="${branch.level_number}">
        <h4>${branch.name}</h4>
        <p style="font-size: 0.875rem; color: var(--text-secondary); margin: 0.5rem 0;">
          ${branch.description}
        </p>
        <ul style="list-style: none; padding: 0; font-size: 0.813rem;">
          ${skills.slice(0, 3).map(skill => `<li style="padding: 0.25rem 0;">• ${skill}</li>`).join('')}
        </ul>
      </div>
    `;
  }

  // ============================================
  // VIEW NAVIGATION: Tab Switching & UI State
  // ============================================

  switchView(viewName, { addToHistory = true } = {}) {
    // Push a browser history entry so the back button can return here
    if (addToHistory) {
      if (this.currentView && this.currentView !== viewName) {
        history.pushState({ cadenceView: viewName }, '', window.location.pathname + window.location.search);
      } else if (!this.currentView) {
        // First view load: replace the initial placeholder with the real starting view
        // so the back button never lands on a view that doesn't belong to this role
        history.replaceState({ cadenceView: viewName }, '', window.location.pathname + window.location.search);
      }
    }

    // Increment switch counter to detect stale async results
    this._viewSwitchId = (this._viewSwitchId || 0) + 1;
    const switchId = this._viewSwitchId;

    // Update nav tabs
    document.querySelectorAll('.nav-tab').forEach(tab => {
      tab.classList.toggle('active', tab.dataset.view === viewName);
    });

    // Update views
    document.querySelectorAll('.view').forEach(view => {
      view.classList.remove('active');
    });

    const targetView = document.getElementById(`${viewName}-view`);
    if (targetView) {
      targetView.classList.add('active');
      targetView.classList.remove('hidden');
      this.currentView = viewName;

      // Persist current view so it survives page refresh
      sessionStorage.setItem('cadence_currentView', viewName);

      // Helper: run an async view loader, but discard results if user switched away
      const loadViewAsync = async (fn) => {
        try {
          await fn();
        } catch (err) {
          // Only show error if user is still on this view
          if (this._viewSwitchId === switchId) {
            console.error(`Error loading ${viewName} view:`, err);
          }
        }
      };

      // Load data for the view if needed
      if (viewName === 'pathway') {
        this.renderPathway();
      } else if (viewName === 'songs') {
        // Update instrument dropdown before rendering songs
        this.updateInstrumentDropdown();
        loadViewAsync(() => this.renderSongs());
      } else if (viewName === 'progress') {
        loadViewAsync(() => this.renderProgress());
      } else if (viewName === 'classes') {
        this.renderClassesList();
      } else if (viewName === 'student-songs') {
        loadViewAsync(() => this.loadStudentSongs());
      } else if (viewName === 'flagged') {
        // Load flagged ratings
        if (this.classes.length > 0) {
          loadViewAsync(() => this.loadFlaggedRatings());
        }
      } else if (viewName === 'accounts') {
        loadViewAsync(() => this.loadAccountsData());
      } else if (viewName === 'admin') {
        // Load admin data
        this.renderAdminStats(this.adminStats || {students: 0, teachers: 0, songs: 0, classes: 0});
        this.renderAdminLevels();
      }
    }
  }

  // ============================================
  // SONG LIBRARY: Display & Filtering
  // ============================================

  async loadTrendingSongs() {
    const instrumentName = this.instruments.find(i => i.id === this.currentInstrument)?.name || null;

    // Serve from cache if instrument hasn't changed
    if (this._trendingSongsCacheInstrument === instrumentName && this._trendingSongs !== null) {
      return this._trendingSongs;
    }

    try {
      const result = await this.callRpcDirect('get_trending_songs', {
        days_back: 14,
        limit_count: 10,
        instrument_filter: instrumentName
      });
      this._trendingSongs = result.data || [];
    } catch (err) {
      console.warn('Could not load trending songs:', err);
      this._trendingSongs = [];
    }

    this._trendingSongsCacheInstrument = instrumentName;
    return this._trendingSongs;
  }

  renderTrendingStrip(songs) {
    const container = document.getElementById('trending-strip-container');
    const strip = document.getElementById('trending-strip');
    if (!container || !strip) return;

    if (!songs || songs.length === 0) {
      container.classList.add('hidden');
      return;
    }

    strip.innerHTML = songs.map(song => `
      <div class="trending-card" data-song-id="${song.song_id}" role="button" tabindex="0">
        <div class="trending-card-title">${this.escapeHtml(song.title)}</div>
        <div class="trending-card-artist">${this.escapeHtml(song.artist)}</div>
        <span class="trending-card-badge">${song.trending_score} student${song.trending_score !== 1 ? 's' : ''} this fortnight</span>
      </div>
    `).join('');

    strip.querySelectorAll('.trending-card').forEach(card => {
      const songId = card.dataset.songId;
      card.addEventListener('click', () => this.viewSongDetails(songId));
      card.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault();
          this.viewSongDetails(songId);
        }
      });
    });

    container.classList.remove('hidden');
  }

  async loadLearningSongsForStrip() {
    // In preview mode, use the already-loaded student songs (which include song data)
    if (this.previewMode.active) {
      return this.studentSongs.filter(s => s.status === 'learning' && s.songs);
    }

    const user = auth.getCurrentUser();
    if (!user) return [];

    // If studentSongs already has embedded song data (loaded by renderProgress), reuse it
    if (this.studentSongs.some(s => s.songs)) {
      return this.studentSongs.filter(s => s.status === 'learning' && s.songs);
    }

    try {
      const { data } = await this.callSelectDirect(
        'student_songs',
        '*,songs(*)',
        { eq: { user_id: user.id, status: 'learning' } },
        { order: 'date_started.desc' }
      );
      return data || [];
    } catch (err) {
      console.warn('Could not load learning songs for pathway strip:', err);
      return [];
    }
  }

  renderLearningSongsStrip(songs) {
    const container = document.getElementById('learning-strip-container');
    const strip = document.getElementById('learning-strip');
    if (!container || !strip) return;

    if (!songs || songs.length === 0) {
      container.classList.add('hidden');
      return;
    }

    strip.innerHTML = songs.map(studentSong => {
      const song = studentSong.songs;
      if (!song) return '';

      const instrument = this.instruments.find(i => i.id === studentSong.instrument_id);
      const instrumentIcon = instrument?.icon || '';
      const instrumentName = instrument?.name || '';
      const chordsUrlField = this.getChordsUrlField(instrumentName);
      const chordsLabel = this.getChordsLabelForInstrument(instrumentName);
      const chordsUrl = song[chordsUrlField];
      const youtubeUrl = song.youtube_url;

      const tutorialUrl = song.tutorial_url;

      const links = [];
      if (youtubeUrl) {
        links.push(`<a href="${this.escapeHtml(youtubeUrl)}" target="_blank" class="song-resource-link song-resource-link--youtube" onclick="event.stopPropagation()">▶ YouTube</a>`);
      }
      // Always show a Learning Resources button so students can access the full modal
      links.push(`<button class="learning-card-link learning-card-resources-btn" onclick="event.stopPropagation(); app.showSongResourcesModal('${song.id}', '${studentSong.instrument_id}')">Learning Resources</button>`);

      return `
        <div class="trending-card" data-song-id="${song.id}" role="button" tabindex="0">
          <div class="trending-card-title">${this.escapeHtml(song.title)}</div>
          <div class="trending-card-artist">${this.escapeHtml(song.artist)}</div>
          <span class="trending-card-badge learning-badge">${instrumentIcon} ${this.escapeHtml(instrumentName)}</span>
          <div class="learning-card-links">${links.join('')}</div>
        </div>
      `;
    }).filter(Boolean).join('');

    strip.querySelectorAll('.trending-card').forEach(card => {
      const songId = card.dataset.songId;
      card.addEventListener('click', (e) => {
        if (e.target.tagName === 'A' || e.target.tagName === 'BUTTON') return;
        this.viewSongDetails(songId);
      });
      card.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault();
          this.viewSongDetails(songId);
        }
      });
    });

    container.classList.remove('hidden');
  }

  async renderSongs() {
    await this.loadSongs();

    // Load student songs if not in preview mode
    if (!this.previewMode.active) {
      const user = auth.getCurrentUser();
      if (user) {
        const { data: studentSongs } = await this.callSelectDirect(
          'student_songs',
          '*',
          { eq: { user_id: user.id } }
        );
        this.studentSongs = studentSongs || [];

        // Load student-song counts for teachers to show badges on song cards
        if (user.role === 'teacher' || user.role === 'admin') {
          try {
            const includeArchived = document.getElementById('filter-include-archived')?.checked || false;
            const result = await this.callRpcDirect('get_teacher_student_song_counts', { p_include_archived: includeArchived });
            this.teacherSongStudentCounts = {};
            if (result.data) {
              result.data.forEach(row => {
                this.teacherSongStudentCounts[row.song_id] = {
                  learning: parseInt(row.learning_count) || 0,
                  mastered: parseInt(row.mastered_count) || 0
                };
              });
            }
          } catch (err) {
            console.warn('Could not load student song counts:', err);
            this.teacherSongStudentCounts = {};
          }
        }
      }
    }

    // Load and render trending strip (cached per instrument)
    this.loadTrendingSongs().then(trending => this.renderTrendingStrip(trending));

    this.filterSongs();
  }

  filterSongs() {
    const searchTerm = document.getElementById('song-search')?.value.toLowerCase() || '';
    const instrumentFilter = document.getElementById('filter-instrument')?.value || '';
    const levelFilter = document.getElementById('filter-level')?.value || '';

    // Store current filter instrument for use in rendering
    this.currentFilterInstrument = instrumentFilter;

    // Check for duplicates in this.songs before filtering
    const songIds = this.songs.map(s => s.id);
    const uniqueIds = [...new Set(songIds)];
    if (songIds.length !== uniqueIds.length) {
      console.error('⚠️ DUPLICATES FOUND IN this.songs DURING filterSongs!');
      const duplicates = songIds.filter((id, index) => songIds.indexOf(id) !== index);
      console.error('Duplicate IDs:', duplicates);
    }

    let filteredSongs = this.songs;

    if (searchTerm) {
      filteredSongs = filteredSongs.filter(song =>
        song.title.toLowerCase().includes(searchTerm) ||
        song.artist.toLowerCase().includes(searchTerm)
      );
    }

    if (instrumentFilter === 'my-instruments') {
      // Filter to show only songs for instruments the user is learning
      const myInstrumentIds = this.studentProgress.map(p => p.instrument_id);
      filteredSongs = filteredSongs.filter(song => {
        // Check if song has an instrument the user is learning OR has ratings for one of those instruments
        return myInstrumentIds.includes(song.instrument_id) ||
               song.song_ratings?.some(r => myInstrumentIds.includes(r.instrument_id));
      });
    } else if (instrumentFilter) {
      filteredSongs = filteredSongs.filter(song => {
        // Check if song has this specific instrument assigned OR has ratings for this instrument
        return song.instrument_id === instrumentFilter ||
               song.song_ratings?.some(r => r.instrument_id === instrumentFilter);
      });
    }

    if (levelFilter) {
      filteredSongs = filteredSongs.filter(song => {
        // Check suggested level OR rated level
        const levelNum = parseInt(levelFilter);
        if (song.suggested_level === levelNum) return true;
        // When instrument filter is active, only count ratings for that specific instrument
        if (instrumentFilter && instrumentFilter !== 'my-instruments') {
          return song.song_ratings?.some(r => r.assessed_level === levelNum && r.instrument_id === instrumentFilter);
        } else if (instrumentFilter === 'my-instruments') {
          const myInstrumentIds = this.studentProgress.map(p => p.instrument_id);
          return song.song_ratings?.some(r => r.assessed_level === levelNum && myInstrumentIds.includes(r.instrument_id));
        }
        return song.song_ratings?.some(r => r.assessed_level === levelNum);
      });
    }

    const grid = document.getElementById('songs-grid');
    if (!filteredSongs || filteredSongs.length === 0) {
      grid.innerHTML = '<p style="color: var(--text-secondary);">No songs found. Be the first to grade a song!</p>';
      return;
    }

    // Check for duplicates by ID
    const filteredIds = filteredSongs.map(s => s.id);
    const uniqueFilteredIds = [...new Set(filteredIds)];
    if (filteredIds.length !== uniqueFilteredIds.length) {
      console.error('⚠️ DUPLICATES BY ID IN FILTERED RESULTS!');
      const dups = filteredIds.filter((id, index) => filteredIds.indexOf(id) !== index);
      console.error('Duplicate IDs in filtered:', dups);
      // Show details of duplicate songs
      dups.forEach(dupId => {
        const duplicateSongs = filteredSongs.filter(s => s.id === dupId);
        console.error(`Duplicate song "${duplicateSongs[0].title}" appears ${duplicateSongs.length} times:`);
        duplicateSongs.forEach((s, idx) => {
          console.error(`  Instance ${idx + 1}:`, {
            id: s.id,
            title: s.title,
            artist: s.artist,
            chords_url: s.chords_url,
            tutorial_url: s.tutorial_url,
            youtube_url: s.youtube_url,
            num_ratings: s.song_ratings?.length,
            instrument_id: s.instrument_id
          });
        });
      });
    }

    // Also check for duplicates by title/artist (same song, different IDs)
    const titleArtistKeys = filteredSongs.map(s => `${s.title}|||${s.artist}`);
    const uniqueTitleArtist = [...new Set(titleArtistKeys)];
    if (titleArtistKeys.length !== uniqueTitleArtist.length) {
      console.error('⚠️ DUPLICATES BY TITLE/ARTIST IN FILTERED RESULTS!');
      const dupTitles = titleArtistKeys.filter((key, index) => titleArtistKeys.indexOf(key) !== index);
      console.error('Duplicate title/artist combinations:', dupTitles);
      dupTitles.forEach(dupKey => {
        const [title, artist] = dupKey.split('|||');
        const duplicateSongs = filteredSongs.filter(s => s.title === title && s.artist === artist);
        console.error(`"${title}" by "${artist}" appears ${duplicateSongs.length} times with different IDs:`);
        duplicateSongs.forEach((s, idx) => {
          console.error(`  Instance ${idx + 1}:`, {
            id: s.id,
            chords_url: s.chords_url,
            tutorial_url: s.tutorial_url,
            youtube_url: s.youtube_url,
            num_ratings: s.song_ratings?.length
          });
        });
      });
    }

    const renderedHTML = filteredSongs.map((song, index) => {
      const html = this.renderSongCard(song);
      // Add a comment to track which index each song is from
      return `<!-- Song ${index}: ${song.title} (ID: ${song.id}) -->\n${html}`;
    }).join('\n');
    grid.innerHTML = renderedHTML;

    // Verify no duplicate data-song-id attributes in DOM
    const domSongIds = Array.from(grid.querySelectorAll('.song-card')).map(card => card.dataset.songId);
    const uniqueDomIds = [...new Set(domSongIds)];
    if (domSongIds.length !== uniqueDomIds.length) {
      console.error('⚠️ DUPLICATE data-song-id IN DOM!');
      const dupDomIds = domSongIds.filter((id, index) => domSongIds.indexOf(id) !== index);
      console.error('Duplicate song IDs in DOM:', dupDomIds);
    }

    // Add event listeners to song cards
    grid.querySelectorAll('.song-card').forEach(card => {
      const songId = card.dataset.songId;
      card.addEventListener('click', () => this.viewSongDetails(songId));
    });

    // Scroll to and highlight a song card if navigation was triggered via goToSongCard()
    if (this._highlightSongId) {
      const targetCard = grid.querySelector(`.song-card[data-song-id="${this._highlightSongId}"]`);
      this._highlightSongId = null;
      if (targetCard) {
        targetCard.scrollIntoView({ behavior: 'smooth', block: 'center' });
        targetCard.classList.add('song-card-highlight');
        targetCard.addEventListener('animationend', () => targetCard.classList.remove('song-card-highlight'), { once: true });
      }
    }
  }

  formatResourceRating(ratings) {
    if (!ratings || ratings.length === 0) return '';
    const avg = (ratings.reduce((sum, r) => sum + r, 0) / ratings.length).toFixed(1);
    return `<span class="resource-rating" title="${ratings.length} rating${ratings.length !== 1 ? 's' : ''}">★${avg}</span>`;
  }

  renderSongCard(song) {
    const allRatings = song.song_ratings || [];

    // Determine which instrument to show ratings for
    const instrumentFilter = document.getElementById('filter-instrument')?.value || '';
    let activeInstrument;

    if (instrumentFilter && instrumentFilter !== 'my-instruments' && instrumentFilter !== '') {
      // Specific instrument filter is active
      activeInstrument = instrumentFilter;
    } else if (instrumentFilter === 'my-instruments' && this.studentProgress?.length > 0) {
      // "My Instruments" filter - prefer current instrument, fall back to any of the student's instruments
      const currentRatings = allRatings.filter(r => r.instrument_id === this.currentInstrument);
      if (currentRatings.length > 0) {
        activeInstrument = this.currentInstrument;
      } else {
        // Fall back to whichever of the student's instruments has ratings for this song
        const myInstrumentIds = this.studentProgress.map(p => p.instrument_id);
        const matchingRating = allRatings.find(r => myInstrumentIds.includes(r.instrument_id));
        if (matchingRating) {
          activeInstrument = matchingRating.instrument_id;
        } else {
          // None of the student's instruments have ratings for this song
          return this.renderSongCardWithData(song, '?', 'Not rated', 0);
        }
      }
    } else if (this.currentInstrument) {
      // Student with current instrument selected (non-"my-instruments" filter, e.g. "All Instruments")
      activeInstrument = this.currentInstrument;
    } else {
      // No specific instrument filter (teacher viewing all, or "my instruments")
      // Check if ANY instrument has discrepancies
      const byInstrument = {};
      allRatings.forEach(r => {
        if (!byInstrument[r.instrument_id]) byInstrument[r.instrument_id] = [];
        byInstrument[r.instrument_id].push(r.assessed_level);
      });

      // If song has been resolved with an official level, show that
      if (song.suggested_level) {
        return this.renderSongCardWithData(song, song.suggested_level, `Level ${song.suggested_level}`, allRatings.length);
      }

      let hasAnyDiscrepancy = false;
      Object.values(byInstrument).forEach(levels => {
        if (levels.length >= 2) {
          const min = Math.min(...levels);
          const max = Math.max(...levels);
          if (max - min >= 2) hasAnyDiscrepancy = true;
        }
      });

      if (hasAnyDiscrepancy) {
        return this.renderSongCardWithData(song, '⚠️', 'Flagged for Review', allRatings.length);
      } else if (allRatings.length > 0) {
        const avgLevel = (allRatings.reduce((sum, r) => sum + r.assessed_level, 0) / allRatings.length).toFixed(1);
        return this.renderSongCardWithData(song, avgLevel, `Level ${avgLevel}`, allRatings.length);
      } else {
        return this.renderSongCardWithData(song, '?', 'Not rated', 0);
      }
    }

    // Filter ratings for specific instrument
    const ratings = allRatings.filter(r => r.instrument_id === activeInstrument);
    let levelDisplay, levelLabel;

    // If song has been resolved with an official level, show that
    if (song.suggested_level) {
      levelDisplay = song.suggested_level;
      levelLabel = `Level ${song.suggested_level}`;
    } else if (ratings.length > 0) {
      // Check for discrepancies (2+ level difference) for this instrument
      const levels = ratings.map(r => r.assessed_level);
      const min = Math.min(...levels);
      const max = Math.max(...levels);
      const hasDiscrepancy = (max - min >= 2) && ratings.length >= 2;

      if (hasDiscrepancy) {
        levelDisplay = '⚠️';
        levelLabel = 'Flagged for Review';
      } else {
        const avgLevel = (ratings.reduce((sum, r) => sum + r.assessed_level, 0) / ratings.length).toFixed(1);
        levelDisplay = avgLevel;
        levelLabel = `Level ${avgLevel}`;
      }
    } else {
      levelDisplay = '?';
      levelLabel = 'Not rated';
    }

    return this.renderSongCardWithData(song, levelDisplay, levelLabel, ratings.length);
  }

  renderSongCardWithData(song, levelDisplay, levelLabel, ratingsCount) {

    // Check which instruments this song has been rated for
    const ratedInstrumentIds = [...new Set((song.song_ratings || []).map(r => r.instrument_id))];
    const hasMultipleInstruments = ratedInstrumentIds.length > 1;

    // Get instrument data for display
    // Priority:
    // 1. Specific filter selection (if song is rated for that instrument)
    // 2. Current instrument (if song is rated for that instrument)
    // 3. First instrument the song was actually rated for
    // 4. Song's assigned instrument (legacy)
    let instrumentId = this.currentFilterInstrument;
    if (instrumentId === 'my-instruments' || !instrumentId) {
      instrumentId = this.currentInstrument;
    }

    // Only use the filter/current instrument if the song has actually been rated for it
    let instrument = null;
    if (instrumentId && ratedInstrumentIds.includes(instrumentId)) {
      instrument = this.instruments.find(i => i.id === instrumentId);
    }

    // Fallback to first rated instrument or song's assigned instrument
    if (!instrument) {
      if (ratedInstrumentIds.length > 0) {
        // Use the first instrument the song has been rated for
        instrument = this.instruments.find(i => i.id === ratedInstrumentIds[0]);
      } else if (song.instruments) {
        instrument = song.instruments;
      }
    }

    const instrumentName = instrument?.name || '';
    const instrumentIcon = instrument?.icon || '';

    // Check user role - show "Start Learning" button for students or in preview mode
    const user = auth.getCurrentUser();
    const isStudent = user.role === 'student' || this.previewMode.active;

    // Check if student is already tracking this song
    const studentSong = this.studentSongs.find(ss =>
      ss.song_id === song.id && ss.instrument_id === this.currentInstrument
    );

    let actionButton = '';
    if (isStudent) {
      if (studentSong) {
        if (studentSong.status === 'mastered') {
          actionButton = `<button class="btn btn-secondary" disabled style="opacity: 0.6; cursor: not-allowed;">Already Mastered</button>`;
        } else {
          actionButton = `<button class="btn btn-secondary" disabled style="opacity: 0.6; cursor: not-allowed;">Already Learning</button>`;
        }
      } else {
        actionButton = `<button class="btn btn-primary" onclick="event.stopPropagation(); app.addSongToLearning('${song.id}')">Start Learning</button>`;
      }
    } else {
      // Teachers/admins get delete and edit buttons
      actionButton = `
        <div style="display: flex; flex-direction: column; gap: 0.5rem;">
          <button class="btn btn-danger" onclick="event.stopPropagation(); app.deleteSongFromLibrary('${song.id}', '${song.title.replace(/'/g, "\\'")}', '${song.artist.replace(/'/g, "\\'")}')" title="Delete this song from the library">Delete Song</button>
          <button class="btn btn-secondary" onclick="event.stopPropagation(); app.editSongDetails('${song.id}', '${song.title.replace(/'/g, "\\'")}', '${song.artist.replace(/'/g, "\\'")}', ${song.suggested_level || 'null'})" title="Edit song details">Edit Details</button>
        </div>`;
    }

    // Build instrument display - dropdown if multiple, static tag if single
    let instrumentDisplay = '';
    if (hasMultipleInstruments) {
      // Build dropdown with all rated instruments
      const instrumentOptions = ratedInstrumentIds.map(instId => {
        const inst = this.instruments.find(i => i.id === instId);
        if (!inst) return '';
        const isSelected = inst.id === instrument?.id;
        return `<option value="${inst.id}" ${isSelected ? 'selected' : ''}>${inst.icon} ${inst.name}</option>`;
      }).join('');

      // Store ratings data as JSON for the change handler
      const ratingsData = JSON.stringify(song.song_ratings || []).replace(/"/g, '&quot;');

      instrumentDisplay = `
        <select class="song-instrument-select"
                onchange="event.stopPropagation(); app.onSongCardInstrumentChange('${song.id}', this.value, this)"
                onclick="event.stopPropagation()"
                data-ratings="${ratingsData}">
          ${instrumentOptions}
        </select>
      `;
    } else if (instrument) {
      instrumentDisplay = `<span class="song-tag instrument">${instrumentIcon} ${instrumentName}</span>`;
    }

    // Build student count badge for teachers
    let studentCountBadge = '';
    if (this.teacherSongStudentCounts) {
      const counts = this.teacherSongStudentCounts[song.id];
      if (counts) {
        const total = counts.learning + counts.mastered;
        const parts = [];
        if (counts.mastered > 0) parts.push(`${counts.mastered} mastered`);
        if (counts.learning > 0) parts.push(`${counts.learning} learning`);
        studentCountBadge = `<span class="song-tag students" title="${parts.join(', ')}">${total} student${total !== 1 ? 's' : ''}</span>`;
      }
    }

    return `
      <div class="song-card" data-song-id="${song.id}">
        <div class="song-header">
          <div>
            <h3 class="song-title">${song.title}</h3>
            <p class="song-artist">${song.artist}</p>
          </div>
          ${actionButton}
        </div>
        <div class="song-meta">
          ${instrumentDisplay}
          <span class="song-tag level" data-song-id="${song.id}">${levelLabel}</span>
          ${studentCountBadge}
        </div>
        <div class="song-actions">
          ${song.youtube_url ? `
            <div class="resource-link-group">
              <a href="${song.youtube_url}" target="_blank" class="song-resource-link song-resource-link--youtube" onclick="event.stopPropagation()">▶ YouTube</a>
              <button class="btn-icon" onclick="event.stopPropagation(); app.editSongResource('${song.id}', 'youtube_url', '${song.youtube_url.replace(/'/g, "\\'")}', '${song.title.replace(/'/g, "\\'")}', '${song.artist.replace(/'/g, "\\'")}', '${instrumentName.replace(/'/g, "\\'")}')" title="Edit YouTube link">✎</button>
            </div>
          ` : this.getMyPendingLink(song.id, 'youtube_url') ? `
            <span class="btn btn-secondary btn-pending" onclick="event.stopPropagation()" title="Your YouTube link is awaiting teacher approval" style="opacity: 0.7; cursor: default; font-style: italic;">⏳ YouTube Pending</span>
          ` : `
            <button class="btn btn-secondary btn-add" onclick="event.stopPropagation(); app.editSongResource('${song.id}', 'youtube_url', '', '${song.title.replace(/'/g, "\\'")}', '${song.artist.replace(/'/g, "\\'")}', '${instrumentName.replace(/'/g, "\\'")}')" title="Add YouTube link">+ YouTube</button>
          `}
          <button class="btn btn-secondary btn-resources ${song.resource_count > 0 ? 'has-resources' : ''}" onclick="event.stopPropagation(); app.showSongResourcesModal('${song.id}', '${instrument?.id || ''}')" title="View learning resources">
            Learning Resources${song.resource_count > 0 ? ` <span class="resource-count">${song.resource_count}</span>` : ''}
          </button>
        </div>
      </div>
    `;
  }

  // Handle instrument change on song card dropdown
  onSongCardInstrumentChange(songId, instrumentId, selectElement) {
    // Get ratings data from the select element
    const ratingsData = selectElement.dataset.ratings;
    let allRatings = [];
    try {
      allRatings = JSON.parse(ratingsData.replace(/&quot;/g, '"'));
    } catch (e) {
      console.error('Failed to parse ratings data:', e);
      return;
    }

    // Filter ratings for the selected instrument
    const ratings = allRatings.filter(r => r.instrument_id === instrumentId);

    // Find the song to check for suggested_level
    const song = this.songs.find(s => s.id === songId);

    // Calculate level display
    let levelLabel;
    if (song?.suggested_level) {
      levelLabel = `Level ${song.suggested_level}`;
    } else if (ratings.length > 0) {
      const levels = ratings.map(r => r.assessed_level);
      const min = Math.min(...levels);
      const max = Math.max(...levels);
      const hasDiscrepancy = (max - min >= 2) && ratings.length >= 2;

      if (hasDiscrepancy) {
        levelLabel = 'Flagged for Review';
      } else {
        const avgLevel = (ratings.reduce((sum, r) => sum + r.assessed_level, 0) / ratings.length).toFixed(1);
        levelLabel = `Level ${avgLevel}`;
      }
    } else {
      levelLabel = 'Not rated';
    }

    // Update the level tag on this card
    const card = selectElement.closest('.song-card');
    const levelTag = card?.querySelector('.song-tag.level');
    if (levelTag) {
      levelTag.textContent = levelLabel;
    }

    // Update the chords/bass tab/drum notation link for the new instrument
    if (card && song) {
      const instrument = this.instruments.find(i => i.id === instrumentId);
      const instName = instrument?.name || '';
      const label = this.getChordsLabelForInstrument(instName);
      const urlField = this.getChordsUrlField(instName);
      const url = song[urlField] || '';
      const escapedTitle = song.title.replace(/'/g, "\\'");
      const escapedArtist = song.artist.replace(/'/g, "\\'");
      const escapedInstName = instName.replace(/'/g, "\\'");
      const chordsRating = this.formatResourceRating(song.resource_ratings?.chords);

      const container = card.querySelector('.chords-link-container');
      if (container) {
        if (url) {
          const escapedUrl = url.replace(/'/g, "\\'");
          container.innerHTML = `
            <div class="resource-link-group">
              <a href="${url}" target="_blank" class="btn btn-secondary" onclick="event.stopPropagation()">${label}</a>
              ${chordsRating}
              <button class="btn-icon" onclick="event.stopPropagation(); app.editSongResource('${song.id}', '${urlField}', '${escapedUrl}', '${escapedTitle}', '${escapedArtist}', '${escapedInstName}')" title="Edit ${label.toLowerCase()} link">✎</button>
            </div>`;
        } else {
          container.innerHTML = `
            <button class="btn btn-secondary btn-add" onclick="event.stopPropagation(); app.editSongResource('${song.id}', '${urlField}', '', '${escapedTitle}', '${escapedArtist}', '${escapedInstName}')" title="Add ${label.toLowerCase()} link">+ ${label}</button>`;
        }
      }

      // Update the Learning Resources button to use the newly selected instrument
      const resourcesBtn = card.querySelector('.btn-resources');
      if (resourcesBtn) {
        resourcesBtn.setAttribute('onclick', `event.stopPropagation(); app.showSongResourcesModal('${song.id}', '${instrumentId}')`);
      }
    }
  }

  async viewSongDetails(songId) {
    const song = this.songs.find(s => s.id === songId);
    if (!song) {
      console.error('Song not found:', songId);
      return;
    }

    const user = auth.getCurrentUser();
    const isTeacherOrAdmin = user.role === 'teacher' || user.role === 'admin';

    // Get list of students if user is a teacher (to show their names)
    let studentMap = {};
    let songStudents = [];
    if (isTeacherOrAdmin) {
      try {
        const includeArchived = document.getElementById('filter-include-archived')?.checked || false;
        const [studentsResult, songStudentsResult] = await Promise.all([
          this.callRpcDirect('get_all_teacher_students', {}),
          this.callRpcDirect('get_song_students_for_teacher', { p_song_id: songId, p_include_archived: includeArchived })
        ]);
        if (studentsResult.data) {
          studentsResult.data.forEach(s => {
            studentMap[s.user_id] = s.name;
          });
        }
        if (songStudentsResult.data) {
          songStudents = songStudentsResult.data;
        }
      } catch (err) {
        console.warn('Could not load teacher students:', err);
      }
    }

    // Fetch all ratings for this song (without user join due to RLS)
    const { data: ratings, error } = await this.callSelectDirect(
      'song_ratings',
      '*,instruments(icon,name)',
      { eq: { song_id: songId } },
      { order: 'date_graded.desc' }
    );

    if (error) {
      console.error('Error loading song ratings:', error);
      this.showToast('Failed to load song ratings', 'error');
      return;
    }

    // Update modal title with instrument if available (use song's instrument or current filter instrument)
    const currentInstrument = this.instruments.find(i => i.id === this.currentInstrument);
    const instrumentDisplay = song.instruments
      ? ` (${song.instruments.icon} ${song.instruments.name})`
      : (currentInstrument ? ` (${currentInstrument.icon} ${currentInstrument.name})` : '');
    document.getElementById('song-details-title').textContent = `${song.title} - ${song.artist}${instrumentDisplay}`;

    // Render content
    const content = document.getElementById('song-details-content');

    // Build "Your Students" section for teachers
    let studentSectionHTML = '';
    if (isTeacherOrAdmin && songStudents.length > 0) {
      const learning = songStudents.filter(s => s.status === 'learning');
      const mastered = songStudents.filter(s => s.status === 'mastered');

      studentSectionHTML = `
        <div class="song-students-section" style="margin-bottom: 2rem;">
          <h3>Your Students (${songStudents.length})</h3>
          ${mastered.length > 0 ? `
            <div style="margin-bottom: 1rem;">
              <div class="song-students-status-label mastered">Mastered (${mastered.length})</div>
              <div class="song-students-list">
                ${mastered.map(s => `
                  <div class="song-student-item" data-student-id="${s.user_id}" data-class-id="${s.class_id}">
                    <div class="song-student-info">
                      <strong>${s.name}</strong>
                      <span class="song-student-meta">${s.instrument_icon} ${s.instrument_name} &middot; ${s.class_name}</span>
                    </div>
                    ${s.date_completed ? `<span class="song-student-date">${this.getTimeAgo(s.date_completed)}</span>` : ''}
                  </div>
                `).join('')}
              </div>
            </div>
          ` : ''}
          ${learning.length > 0 ? `
            <div>
              <div class="song-students-status-label learning">Currently Learning (${learning.length})</div>
              <div class="song-students-list">
                ${learning.map(s => `
                  <div class="song-student-item" data-student-id="${s.user_id}" data-class-id="${s.class_id}">
                    <div class="song-student-info">
                      <strong>${s.name}</strong>
                      <span class="song-student-meta">${s.instrument_icon} ${s.instrument_name} &middot; ${s.class_name}</span>
                    </div>
                    <span class="song-student-date">Started ${this.getTimeAgo(s.date_started)}</span>
                  </div>
                `).join('')}
              </div>
            </div>
          ` : ''}
        </div>
      `;
    } else if (isTeacherOrAdmin) {
      studentSectionHTML = `
        <div class="song-students-section" style="margin-bottom: 2rem;">
          <h3>Your Students</h3>
          <p style="color: var(--text-secondary); font-size: 0.875rem;">None of your students are currently learning or have mastered this song.</p>
        </div>
      `;
    }

    if (!ratings || ratings.length === 0) {
      content.innerHTML = `
        ${studentSectionHTML}
        <p style="color: var(--text-secondary); text-align: center; padding: 2rem;">
          No ratings yet for this song.
        </p>
      `;
    } else {
      const avgLevel = (ratings.reduce((sum, r) => sum + r.assessed_level, 0) / ratings.length).toFixed(1);

      content.innerHTML = `
        ${studentSectionHTML}
        <div style="margin-bottom: 2rem;">
          <h3>Overall</h3>
          <p><strong>Average Level:</strong> ${avgLevel} (based on ${ratings.length} rating${ratings.length !== 1 ? 's' : ''})</p>
        </div>
        <div>
          <h3>All Ratings</h3>
          <div style="display: flex; flex-direction: column; gap: 1rem;">
            ${ratings.map(rating => {
              const timeAgo = this.getTimeAgo(rating.date_graded);

              // Determine user name display
              let userName;
              if (rating.user_id === user.id) {
                userName = 'You';
              } else if (studentMap[rating.user_id]) {
                userName = studentMap[rating.user_id]; // Teacher viewing their student
              } else {
                userName = 'Student'; // Anonymous for other students
              }

              const instrumentDisplay = rating.instruments ? `${rating.instruments.icon} ${rating.instruments.name}` : 'Unknown Instrument';

              return `
                <div style="border: 1px solid var(--border); border-radius: 8px; padding: 1rem;">
                  <div style="display: flex; justify-content: space-between; align-items: start; margin-bottom: 0.5rem;">
                    <div>
                      <strong>${userName}</strong>
                      <div style="color: var(--text-secondary); font-size: 0.875rem;">${instrumentDisplay} • ${timeAgo}</div>
                    </div>
                    <div style="font-weight: 600; color: var(--primary);">Level ${rating.assessed_level}</div>
                  </div>
                  ${rating.notes ? `
                    <div style="margin-top: 0.75rem; padding: 0.75rem; background: var(--bg-secondary); border-radius: 4px;">
                      <div style="font-size: 0.875rem; font-weight: 600; margin-bottom: 0.25rem;">Notes:</div>
                      <div style="font-size: 0.875rem; white-space: pre-wrap;">${rating.notes}</div>
                    </div>
                  ` : ''}
                </div>
              `;
            }).join('')}
          </div>
        </div>
      `;
    }

    // Show modal
    document.getElementById('song-details-modal').classList.remove('hidden');

    // Attach click handlers for student items (teachers can click to view student detail)
    if (isTeacherOrAdmin) {
      content.querySelectorAll('.song-student-item').forEach(el => {
        el.addEventListener('click', () => {
          const studentId = el.dataset.studentId;
          const studentName = el.querySelector('strong')?.textContent;
          if (studentId) {
            document.getElementById('song-details-modal').classList.add('hidden');
            this.viewStudentDetail(studentId, studentName);
          }
        });
      });
    }
  }

  async addSongToLearning(songId) {
    const user = auth.getCurrentUser();
    // Use student ID if in preview mode, otherwise use current user
    const userId = this.previewMode.active ? this.previewMode.studentId : user.id;

    // Validate that an instrument is selected
    if (!this.currentInstrument) {
      this.showToast('Please select an instrument first', 'warning');
      return;
    }

    // Use direct RPC call to bypass stale Supabase client connections
    let data;
    try {
      const result = await this.callRpcDirect('add_student_song', {
        p_student_id: userId,
        p_song_id: songId,
        p_instrument_id: this.currentInstrument,
        p_status: 'learning'
      });
      data = result.data;
    } catch (error) {
      console.error('Error adding song:', error);
      if (error.message?.includes('Already tracking')) {
        this.showToast('Already tracking this song!', 'info');
      } else if (error.message?.includes('Permission denied')) {
        this.showToast('Permission denied', 'error');
      } else {
        this.showToast('Failed to add song', 'error');
      }
      return;
    }

    this.showToast('Song added to Currently Learning!', 'success');

    // Reload data and re-render current view
    // Note: renderSongs/renderProgress load fresh data internally, so no separate loadSongs() needed
    if (this.previewMode.active) {
      await this.loadStudentPreviewData(this.previewMode.studentId);
    }

    if (this.currentView === 'songs') {
      await this.renderSongs();
    } else if (this.currentView === 'progress') {
      await this.renderProgress();
    } else if (this.currentView === 'pathway') {
      await this.loadSongs();
      this.renderPathway();
    }
  }

  async deleteSongFromLibrary(songId, title, artist) {
    // Confirm deletion with song details
    if (!confirm(`Are you sure you want to delete "${title}" by ${artist} from the library?\n\nThis will permanently remove the song and all associated ratings and student progress. This action cannot be undone.`)) {
      return;
    }

    const { error } = await this.callDeleteDirect('songs', { eq: { id: songId } });

    if (error) {
      console.error('Error deleting song:', error);
      this.showToast('Failed to delete song', 'error');
      return;
    }

    this.showToast('Song deleted successfully', 'success');

    // Re-render songs view (renderSongs loads fresh data internally)
    await this.renderSongs();
  }

  // ============================================
  // SONG GRADING: Rating & Resource Management
  // ============================================

  setupSongGradingForm() {
    const form = document.getElementById('song-grading-form');
    const nextBtn = document.getElementById('next-step-btn');
    const prevBtn = document.getElementById('prev-step-btn');
    const submitBtn = document.getElementById('submit-grade-btn');

    // Search button event listeners
    const searchYoutubeBtn = document.getElementById('search-youtube-btn');
    const searchChordsBtn = document.getElementById('search-chords-btn');
    const searchTutorialBtn = document.getElementById('search-tutorial-btn');

    if (searchYoutubeBtn) {
      searchYoutubeBtn.addEventListener('click', () => {
        const title = document.getElementById('song-title').value;
        const artist = document.getElementById('song-artist').value;
        if (title && artist) {
          const searchQuery = `${title} ${artist} youtube`;
          const searchUrl = `https://www.google.com/search?q=${encodeURIComponent(searchQuery)}`;
          window.open(searchUrl, '_blank');
        } else {
          this.showToast('Please enter song title and artist first', 'warning');
        }
      });
    }

    if (searchChordsBtn) {
      searchChordsBtn.addEventListener('click', () => {
        const title = document.getElementById('song-title').value;
        const artist = document.getElementById('song-artist').value;
        if (title && artist) {
          const searchTerm = this.getChordsSearchTerm();
          const searchQuery = `${title} ${artist} ${searchTerm}`;
          const searchUrl = `https://www.google.com/search?q=${encodeURIComponent(searchQuery)}`;
          window.open(searchUrl, '_blank');
        } else {
          this.showToast('Please enter song title and artist first', 'warning');
        }
      });
    }

    if (searchTutorialBtn) {
      searchTutorialBtn.addEventListener('click', () => {
        const title = document.getElementById('song-title').value;
        const artist = document.getElementById('song-artist').value;
        const instrument = document.getElementById('grading-instrument').value;
        const instrumentName = this.instruments.find(i => i.id === instrument)?.name || '';
        if (title && artist) {
          const searchQuery = `${title} ${artist} ${instrumentName} tutorial`;
          const searchUrl = `https://www.google.com/search?q=${encodeURIComponent(searchQuery)}`;
          window.open(searchUrl, '_blank');
        } else {
          this.showToast('Please enter song title and artist first', 'warning');
        }
      });
    }

    // Similar songs detection - debounced input handlers
    const songTitleInput = document.getElementById('song-title');
    const songArtistInput = document.getElementById('song-artist');
    const dismissSimilarSongsBtn = document.getElementById('dismiss-similar-songs');

    // Debounce timer
    let similarSongsDebounceTimer = null;

    const checkForSimilarSongs = () => {
      clearTimeout(similarSongsDebounceTimer);
      similarSongsDebounceTimer = setTimeout(() => {
        this.findSimilarSongs();
      }, 500); // Wait 500ms after user stops typing
    };

    if (songTitleInput) {
      songTitleInput.addEventListener('input', checkForSimilarSongs);
    }

    if (songArtistInput) {
      songArtistInput.addEventListener('input', checkForSimilarSongs);
    }

    if (dismissSimilarSongsBtn) {
      dismissSimilarSongsBtn.addEventListener('click', () => {
        document.getElementById('similar-songs-container').classList.add('hidden');
        this.similarSongsDismissed = true;
      });
    }

    // Update chords label/button when instrument changes
    const gradingInstrumentSelect = document.getElementById('grading-instrument');
    if (gradingInstrumentSelect) {
      gradingInstrumentSelect.addEventListener('change', () => {
        this.updateChordsLabel();
        this.populateSimilarSongLinks();
      });
    }

    // Navigation buttons
    if (nextBtn) {
      nextBtn.addEventListener('click', () => this.nextGradingStep());
    }

    if (prevBtn) {
      prevBtn.addEventListener('click', () => this.prevGradingStep());
    }

    // Form submission
    if (form) {
      form.addEventListener('submit', (e) => {
        e.preventDefault();
        this.submitSongGrading();
      });
    }
  }

  getChordsLabelForInstrument(instrumentName) {
    const name = (instrumentName || '').toLowerCase();
    if (name.includes('bass')) return 'Bass Tab';
    if (name.includes('drum')) return 'Drum Notation';
    return 'Chords';
  }

  getChordsUrlField(instrumentName) {
    const name = (instrumentName || '').toLowerCase();
    if (name.includes('bass')) return 'bass_tab_url';
    if (name.includes('drum')) return 'drum_notation_url';
    return 'chords_url';
  }

  // Find a student's own pending link for a given song and link type
  getMyPendingLink(songId, linkType) {
    if (!this.myPendingLinks) return null;
    return this.myPendingLinks.find(l => l.song_id === songId && l.link_type === linkType);
  }

  getChordsUrlForInstrument(song, instrumentName) {
    const field = this.getChordsUrlField(instrumentName);
    return song[field];
  }

  getChordsSearchTerm() {
    const instrumentId = document.getElementById('grading-instrument').value;
    const instrument = this.instruments.find(i => i.id === instrumentId);
    return this.getChordsLabelForInstrument(instrument?.name).toLowerCase();
  }

  getChordsLabel() {
    const instrumentId = document.getElementById('grading-instrument').value;
    const instrument = this.instruments.find(i => i.id === instrumentId);
    return this.getChordsLabelForInstrument(instrument?.name);
  }

  updateChordsLabel() {
    const label = this.getChordsLabel();
    const chordsLabel = document.querySelector('label[for="song-chords"]');
    const searchChordsBtn = document.getElementById('search-chords-btn');
    if (chordsLabel) chordsLabel.textContent = `${label} URL (optional)`;
    if (searchChordsBtn) searchChordsBtn.title = `Search for ${label.toLowerCase()}`;
  }

  setupEditResourceModal() {
    const form = document.getElementById('edit-resource-form');
    const cancelBtn = document.getElementById('cancel-edit-resource');

    // Cancel button
    if (cancelBtn) {
      cancelBtn.addEventListener('click', () => {
        document.getElementById('edit-resource-modal').classList.add('hidden');
      });
    }

    // Form submit handler
    if (form) {
      form.addEventListener('submit', async (e) => {
        e.preventDefault();
        e.stopPropagation();
        await this.saveResourceUrl();
      });
    } else {
      console.error('🎵 Edit resource form not found!');
    }
  }

  setupRateResourcesModal() {
    const form = document.getElementById('rate-resources-form');
    const skipBtn = document.getElementById('skip-rating-btn');

    // Set up star rating interactions
    const ratingStars = document.querySelectorAll('.rating-stars');
    ratingStars.forEach(container => {
      const stars = container.querySelectorAll('.star');
      const field = container.dataset.field;
      const hiddenInput = document.getElementById(`${field}-rating`);

      stars.forEach(star => {
        // Click to select rating
        star.addEventListener('click', () => {
          const value = star.dataset.value;
          hiddenInput.value = value;

          // Update visual state
          stars.forEach(s => {
            if (parseInt(s.dataset.value) <= parseInt(value)) {
              s.classList.add('active');
            } else {
              s.classList.remove('active');
            }
          });
        });

        // Hover effects
        star.addEventListener('mouseenter', () => {
          const value = star.dataset.value;
          stars.forEach(s => {
            if (parseInt(s.dataset.value) <= parseInt(value)) {
              s.classList.add('hovered');
            } else {
              s.classList.remove('hovered');
            }
          });
        });

        container.addEventListener('mouseleave', () => {
          stars.forEach(s => s.classList.remove('hovered'));
        });
      });
    });

    // Skip button - marks mastered without rating
    if (skipBtn) {
      skipBtn.addEventListener('click', async () => {
        document.getElementById('rate-resources-modal').classList.add('hidden');
        await this.completeMasteredMarking();
      });
    }

    // Submit with ratings
    if (form) {
      form.addEventListener('submit', async (e) => {
        e.preventDefault();
        await this.submitResourceRatings();
      });
    }
  }

  editSongResource(songId, fieldName, currentValue, title, artist, instrumentName = '') {
    // Store data for submission
    this.editingResource = {
      songId,
      fieldName,
      currentValue
    };

    // Get instrument-specific chords label
    const chordsLabel = this.getChordsLabelForInstrument(instrumentName);

    // If adding a new link (not editing), open a search to help user find it
    if (!currentValue) {
      let searchQuery = '';
      if (fieldName === 'chords_url' || fieldName === 'bass_tab_url' || fieldName === 'drum_notation_url') {
        searchQuery = `${title} ${artist} ${chordsLabel.toLowerCase()}`;
      } else if (fieldName === 'tutorial_url') {
        searchQuery = instrumentName ? `${title} ${instrumentName} tutorial` : `${title} tutorial`;
      } else if (fieldName === 'youtube_url') {
        searchQuery = `${title} ${artist} youtube`;
      }

      if (searchQuery) {
        const searchUrl = `https://www.google.com/search?q=${encodeURIComponent(searchQuery)}`;
        window.open(searchUrl, '_blank');
      }
    }

    // Update modal UI
    const fieldLabels = {
      'chords_url': 'Chords URL',
      'bass_tab_url': 'Bass Tab URL',
      'drum_notation_url': 'Drum Notation URL',
      'tutorial_url': 'Tutorial URL',
      'youtube_url': 'YouTube URL'
    };

    const isStudent = auth.hasRole('student');
    const modalTitle = isStudent
      ? (currentValue ? 'Submit Resource Link for Approval' : 'Submit Resource Link for Approval')
      : (currentValue ? 'Edit Resource Link' : 'Add Resource Link');
    const fieldLabel = fieldLabels[fieldName] || 'URL';

    document.getElementById('edit-resource-title').textContent = modalTitle;
    document.getElementById('edit-resource-song-info').textContent = `${title} - ${artist}`;
    document.getElementById('resource-url-label').textContent = fieldLabel;
    document.getElementById('resource-url').value = currentValue;

    // Show/hide approval message for students
    const approvalMessage = document.getElementById('pending-approval-message');
    if (approvalMessage) {
      if (isStudent) {
        approvalMessage.classList.remove('hidden');
      } else {
        approvalMessage.classList.add('hidden');
      }
    }

    // Show modal
    document.getElementById('edit-resource-modal').classList.remove('hidden');
    document.getElementById('resource-url').focus();
  }

  async saveResourceUrl() {
    try {
      const url = document.getElementById('resource-url').value.trim();
      const { songId, fieldName } = this.editingResource;

      // Get the current session token from localStorage (Supabase stores it there)
      const sessionKey = `sb-dgwtihpiqgkhokkkxuzo-auth-token`;
      const sessionData = localStorage.getItem(sessionKey);

      if (!sessionData) {
        throw new Error('Not authenticated - no session found');
      }

      const session = JSON.parse(sessionData);
      const accessToken = session.access_token;

      if (!accessToken) {
        throw new Error('Not authenticated - no access token');
      }

      // Check if user is a student - if so, submit for approval instead
      const isStudent = auth.hasRole('student');

      if (isStudent) {
        // Students submit links for teacher approval

        const response = await fetch('https://dgwtihpiqgkhokkkxuzo.supabase.co/rest/v1/pending_links', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'apikey': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRnd3RpaHBpcWdraG9ra2t4dXpvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc0OTQzNjcsImV4cCI6MjA4MzA3MDM2N30.xnD7lrvmBlvW-9XzL0VTabAq6wtwsepxb90Assu8bNo',
            'Authorization': `Bearer ${accessToken}`,
            'Prefer': 'return=minimal'
          },
          body: JSON.stringify({
            song_id: songId,
            link_type: fieldName,
            url: url,
            submitted_by_user_id: auth.getCurrentUser().id
          })
        });

        if (!response.ok) {
          const errorText = await response.text();
          console.error('🎵 Response error:', errorText);
          throw new Error(`Submission failed: ${response.status} ${errorText}`);
        }

        // Add to local pending links so UI immediately shows pending state
        if (!this.myPendingLinks) this.myPendingLinks = [];
        this.myPendingLinks.push({
          song_id: songId,
          link_type: fieldName,
          url: url,
          status: 'pending',
          submitted_at: new Date().toISOString()
        });

        // Close modal
        document.getElementById('edit-resource-modal').classList.add('hidden');

        // Show success message
        this.showToast('Link submitted for teacher approval', 'success');

        // Re-render current view so pending state is visible
        if (this.currentView === 'songs') {
          this.filterSongs();
        } else if (this.currentView === 'progress') {
          this.renderProgress();
        }
      } else {
        // Teachers can update links directly
        const response = await fetch(`https://dgwtihpiqgkhokkkxuzo.supabase.co/rest/v1/songs?id=eq.${songId}`, {
          method: 'PATCH',
          headers: {
            'Content-Type': 'application/json',
            'apikey': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRnd3RpaHBpcWdraG9ra2t4dXpvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc0OTQzNjcsImV4cCI6MjA4MzA3MDM2N30.xnD7lrvmBlvW-9XzL0VTabAq6wtwsepxb90Assu8bNo',
            'Authorization': `Bearer ${accessToken}`,
            'Prefer': 'return=minimal'
          },
          body: JSON.stringify({ [fieldName]: url || null })
        });

        if (!response.ok) {
          const errorText = await response.text();
          console.error('🎵 Response error:', errorText);
          throw new Error(`Update failed: ${response.status} ${errorText}`);
        }

        // Update the local song object immediately so UI reflects the change
        const song = this.songs.find(s => s.id === songId);
        if (song) {
          song[fieldName] = url || null;
        }

        // Also update the song data within studentSongs for progress view
        if (this.studentSongs) {
          this.studentSongs.forEach(studentSong => {
            if (studentSong.songs && studentSong.songs.id === songId) {
              studentSong.songs[fieldName] = url || null;
            }
          });
        }

        // Close modal
        document.getElementById('edit-resource-modal').classList.add('hidden');

        // Show success message
        this.showToast('Resource link updated successfully', 'success');

        // Re-render the current view with updated local data (don't reload from DB)
        if (this.currentView === 'songs') {
          this.filterSongs();
        } else if (this.currentView === 'progress') {
          this.renderProgress();
        } else if (this.currentView === 'student-songs') {
          if (this.teacherStudentSongs) {
            this.teacherStudentSongs.forEach(row => {
              if (row.song_id === songId) row[fieldName] = url || null;
            });
          }
          this.filterStudentSongs();
          requestAnimationFrame(() => {
            document.querySelector(`.student-song-item[data-song-id="${songId}"]`)
              ?.scrollIntoView({ block: 'nearest' });
          });
        }
      }
    } catch (error) {
      console.error('🎵 Error updating resource:', error);
      this.showToast('Failed to update resource link: ' + error.message, 'error');
    }
  }

  showSongGradingModal() {
    this.currentStep = 1;
    this.gradingData = {};
    this.selectedSimilarSong = null; // Reset so we don't skip URLs for a different song
    this.selectedSimilarSongTutorials = [];
    this.similarSongsDismissed = false; // Reset dismissal state
    document.getElementById('song-grading-form').reset(); // Reset form first, before populating dropdowns
    this.updateInstrumentDropdown(); // Populate instrument dropdown (sets current instrument)
    document.getElementById('song-grading-modal').classList.remove('hidden');
    document.getElementById('similar-songs-container').classList.add('hidden'); // Hide suggestions
    this.updateChordsLabel(); // Update label based on selected instrument
    this.updateGradingStep();
  }

  async findSimilarSongs() {
    // Don't search if user dismissed suggestions for this session
    if (this.similarSongsDismissed) return;

    const title = document.getElementById('song-title').value.trim();
    const artist = document.getElementById('song-artist').value.trim();
    const container = document.getElementById('similar-songs-container');
    const list = document.getElementById('similar-songs-list');

    // Need at least 2 characters in both fields to search
    if (title.length < 2 || artist.length < 2) {
      container.classList.add('hidden');
      return;
    }

    try {
      const { data, error } = await this.callRpcDirect('find_similar_songs', {
        p_title: title,
        p_artist: artist,
        p_threshold: 0.3,
        p_limit: 5
      });

      if (error) {
        console.error('Error finding similar songs:', error);
        container.classList.add('hidden');
        return;
      }

      // Filter to show only reasonably similar matches (combined score > 0.4)
      const relevantMatches = (data || []).filter(s => s.similarity_score > 0.4);

      if (relevantMatches.length === 0) {
        container.classList.add('hidden');
        return;
      }

      // Display the suggestions
      list.innerHTML = relevantMatches.map(song => `
        <div class="similar-song-item" data-song-id="${song.id}" data-title="${this.escapeHtml(song.title)}" data-artist="${this.escapeHtml(song.artist)}">
          <div class="similar-song-info">
            <span class="similar-song-title">${this.escapeHtml(song.title)}</span>
            <span class="similar-song-artist">${this.escapeHtml(song.artist)}</span>
          </div>
          <span class="similar-song-match">${Math.round(song.similarity_score * 100)}% match</span>
        </div>
      `).join('');

      // Add click handlers to each suggestion
      list.querySelectorAll('.similar-song-item').forEach(item => {
        item.addEventListener('click', () => this.selectSimilarSong(item));
      });

      container.classList.remove('hidden');
    } catch (error) {
      console.error('Error in findSimilarSongs:', error);
      container.classList.add('hidden');
    }
  }

  async selectSimilarSong(item) {
    const title = item.dataset.title;
    const artist = item.dataset.artist;
    const songId = item.dataset.songId;

    // Populate the form fields with the selected song's data
    document.getElementById('song-title').value = title;
    document.getElementById('song-artist').value = artist;

    // Hide the suggestions
    document.getElementById('similar-songs-container').classList.add('hidden');

    // Fetch the existing song's approved links to pre-populate URL fields
    try {
      const { data: songs } = await this.rawSelect('songs',
        `select=youtube_url,chords_url,bass_tab_url,drum_notation_url,tutorial_url&id=eq.${songId}`
      );

      const song = songs?.[0];
      if (song) {
        this.selectedSimilarSong = song;

        // Fetch approved tutorial resources for this song
        const { data: tutorials } = await this.rawSelect('student_resources',
          `select=file_url,instrument_id&song_id=eq.${songId}&status=eq.approved&file_type=eq.tutorial&order=created_at.asc`
        );
        this.selectedSimilarSongTutorials = tutorials || [];

        // Populate URL fields based on current instrument
        this.populateSimilarSongLinks();
      }
    } catch (err) {
      console.warn('Could not fetch existing song links:', err);
    }

    this.showToast(`Selected "${title}" by ${artist}`, 'success');
  }

  populateSimilarSongLinks() {
    const song = this.selectedSimilarSong;
    if (!song) return;

    const instrumentId = document.getElementById('grading-instrument').value;
    const instrument = this.instruments.find(i => i.id === instrumentId);

    // YouTube URL is universal - always pre-populate
    document.getElementById('song-youtube').value = song.youtube_url || '';

    // Chords/Tab/Notation is instrument-specific
    // getChordsUrlField maps: Bass→bass_tab_url, Drums→drum_notation_url, others→chords_url
    const chordsField = this.getChordsUrlField(instrument?.name);
    document.getElementById('song-chords').value = song[chordsField] || '';

    // Tutorial: prefer instrument-specific, then universal, then legacy fallback
    const tutorials = this.selectedSimilarSongTutorials || [];
    const instrumentTutorial = instrumentId
      ? tutorials.find(t => t.instrument_id === instrumentId)
      : null;
    const universalTutorial = tutorials.find(t => !t.instrument_id);

    if (instrumentTutorial) {
      document.getElementById('song-tutorial').value = instrumentTutorial.file_url;
    } else if (universalTutorial) {
      document.getElementById('song-tutorial').value = universalTutorial.file_url;
    } else if (tutorials.length === 0 && song.tutorial_url) {
      // Legacy fallback: only use if no tutorial resources exist at all
      document.getElementById('song-tutorial').value = song.tutorial_url;
    } else {
      document.getElementById('song-tutorial').value = '';
    }
  }

  generateComprehensiveChecklist() {
    const instrumentId = document.getElementById('grading-instrument').value;

    // Get the instrument name for display
    const instrument = this.instruments.find(i => i.id === instrumentId);
    const instrumentName = instrument ? instrument.name : 'this instrument';

    // Get instrument-specific questions (shared with scoring)
    const questionSets = this.getInstrumentQuestions();
    const questions = questionSets[instrumentName] || questionSets['Guitar'];

    const container = document.getElementById('grading-checklist');

    container.innerHTML = `
      <p class="grading-intro">Pick the closest answer for each — no wrong answers!</p>
      ${Object.entries(questions).map(([question, options], index) => `
        <div class="checklist-item">
          <div class="checklist-question">${question}</div>
          <div class="checklist-options checklist-options-chips">
            ${options.map((option, optIndex) => `
              <label class="chip-option">
                <input type="radio" name="question-${index}" value="${option}" required>
                <span class="chip-label">${option}</span>
              </label>
            `).join('')}
          </div>
        </div>
      `).join('')}
    `;
  }

  async generateGradingChecklist(levelNumber) {
    const instrumentId = document.getElementById('grading-instrument').value;
    const level = this.levels.find(l =>
      l.instrument_id === instrumentId &&
      l.level_number === levelNumber &&
      !l.is_branch
    );

    if (!level) return;

    const checklist = typeof level.grading_checklist_json === 'string' ? JSON.parse(level.grading_checklist_json) : (level.grading_checklist_json || {});
    const container = document.getElementById('grading-checklist');

    container.innerHTML = Object.entries(checklist).map(([question, options], index) => `
      <div class="checklist-item">
        <div class="checklist-question">${question}</div>
        <div class="checklist-options">
          ${Array.isArray(options) ? options.map((option, optIndex) => `
            <label>
              <input type="radio" name="question-${index}" value="${option}" required>
              ${option}
            </label>
          `).join('') : `
            ${options.map((option, optIndex) => `
              <label>
                <input type="checkbox" name="question-${index}" value="${option}">
                ${option}
              </label>
            `).join('')}
          `}
        </div>
      </div>
    `).join('');
  }

  nextGradingStep() {
    if (this.currentStep === 1) {
      // Validate step 1
      const title = document.getElementById('song-title').value;
      const artist = document.getElementById('song-artist').value;
      const instrument = document.getElementById('grading-instrument').value;

      if (!title || !artist || !instrument) {
        this.showToast('Please fill in all required fields', 'warning');
        return;
      }

      this.gradingData.title = title;
      this.gradingData.artist = artist;
      this.gradingData.instrument = instrument;

      // Get URLs from form, but skip any that already match the existing
      // song's approved values — sending them again just creates unnecessary
      // pending approval requests for the teacher.
      const existingSong = this.selectedSimilarSong;
      const youtubeVal = document.getElementById('song-youtube').value;
      const tutorialVal = document.getElementById('song-tutorial').value;
      this.gradingData.youtube_url = (existingSong && youtubeVal === (existingSong.youtube_url || '')) ? null : youtubeVal;
      this.gradingData.tutorial_url = (existingSong && tutorialVal === (existingSong.tutorial_url || '')) ? null : tutorialVal;

      // Save chords URL to the correct field based on instrument
      const inst = this.instruments.find(i => i.id === instrument);
      const chordsUrlField = this.getChordsUrlField(inst?.name);
      const chordsValue = document.getElementById('song-chords').value;
      const existingChordsVal = existingSong ? (existingSong[chordsUrlField] || '') : '';
      const skipChords = existingSong && chordsValue === existingChordsVal;
      this.gradingData.chords_url = chordsUrlField === 'chords_url' ? (skipChords ? null : chordsValue) : null;
      this.gradingData.bass_tab_url = chordsUrlField === 'bass_tab_url' ? (skipChords ? null : chordsValue) : null;
      this.gradingData.drum_notation_url = chordsUrlField === 'drum_notation_url' ? (skipChords ? null : chordsValue) : null;

      // Generate the comprehensive checklist for step 2
      this.currentStep++;
      this.updateGradingStep();
      this.generateComprehensiveChecklist();
      return;
    }

    if (this.currentStep === 2) {
      // Validate all questions are answered
      const allAnswered = Array.from(document.querySelectorAll('#grading-checklist .checklist-item')).every(item => {
        return item.querySelector('input:checked') !== null;
      });

      if (!allAnswered) {
        this.showToast('Please answer all questions', 'warning');
        return;
      }

      // Collect checklist responses
      const responses = {};
      document.querySelectorAll('#grading-checklist .checklist-item').forEach((item, index) => {
        const question = item.querySelector('.checklist-question').textContent;
        const selected = item.querySelector('input:checked');
        if (selected) {
          responses[question] = selected.value;
        }
      });
      this.gradingData.checklistResponses = responses;

      // Show suggestion
      this.showLevelSuggestion();
    }

    this.currentStep++;
    this.updateGradingStep();
  }

  prevGradingStep() {
    this.currentStep--;
    this.updateGradingStep();
  }

  updateGradingStep() {
    document.querySelectorAll('.form-step').forEach((step, index) => {
      step.classList.toggle('active', index + 1 === this.currentStep);
    });

    document.getElementById('prev-step-btn').classList.toggle('hidden', this.currentStep === 1);
    document.getElementById('next-step-btn').classList.toggle('hidden', this.currentStep === 3);
    document.getElementById('submit-grade-btn').classList.toggle('hidden', this.currentStep !== 3);
  }

  calculateLevelFromResponses() {
    const responses = this.gradingData.checklistResponses;
    if (!responses || Object.keys(responses).length === 0) {
      return 1;
    }

    // Get current instrument's question set to map answer positions to levels
    const instrument = this.instruments.find(i => i.id === this.gradingData.instrument);
    if (!instrument) return 1;

    const questionSets = this.getInstrumentQuestions();
    const questions = questionSets[instrument.name] || questionSets['Guitar'];

    // Each question has 5 ordered answers (index 0 = Level 1, index 4 = Level 5).
    // Find which index was selected for each question and average the levels.
    let totalLevel = 0;
    let answered = 0;

    Object.entries(responses).forEach(([question, answer]) => {
      const options = questions[question];
      if (!options) return;
      const idx = options.indexOf(answer);
      if (idx >= 0) {
        totalLevel += (idx + 1); // 1-based level
        answered++;
      }
    });

    if (answered === 0) return 1;

    // Round to nearest level
    return Math.round(totalLevel / answered);
  }

  // Shared instrument question definitions used by both checklist generation and scoring
  getInstrumentQuestions() {
    return {
      'Guitar': {
        "Chords": [
          "1-3 open chords",
          "4-5 chords, maybe a barre",
          "Barre chords + 7ths/sus",
          "Extensions, jazz voicings",
          "Complex harmony throughout"
        ],
        "Strumming & picking": [
          "Simple downstrokes",
          "Basic up/down patterns",
          "Fingerpicking or arpeggios",
          "Mixed techniques (hybrid, percussive)",
          "Tapping, harmonics, or advanced techniques"
        ],
        "Rhythm": [
          "Steady and simple",
          "Some off-beats or syncopation",
          "Swing or shuffle feel",
          "Odd time or frequent changes",
          "Polyrhythmic or very complex"
        ],
        "Song structure": [
          "One repeating section",
          "Verse + chorus",
          "Verse, chorus + bridge",
          "Multiple distinct sections",
          "Complex or unusual form"
        ],
        "Overall difficulty": [
          "Beginner — easy to pick up",
          "Beginner+ — needs a bit of practice",
          "Intermediate — solid skills needed",
          "Advanced — experienced players",
          "Expert — very challenging"
        ]
      },
      'Bass Guitar': {
        "Note complexity": [
          "Root notes only",
          "Roots + 5ths, simple patterns",
          "Scalar runs, some fills",
          "Chromatic lines, complex patterns",
          "Advanced harmony, chordal bass"
        ],
        "Technique": [
          "Basic fingerstyle",
          "Alternating fingers, simple muting",
          "Slap/pop or pick technique",
          "Ghost notes, hammer-ons, slides",
          "Tapping, advanced slap, harmonics"
        ],
        "Groove & rhythm": [
          "Straight and simple",
          "Slightly syncopated",
          "Funky or swing feel",
          "Complex syncopation, odd time",
          "Polyrhythmic or very advanced"
        ],
        "Fretboard range": [
          "First 4 frets only",
          "Up to 7th fret",
          "Full neck, some position shifts",
          "Wide range with fast shifts",
          "Entire fretboard, all positions"
        ],
        "Overall difficulty": [
          "Beginner — easy to pick up",
          "Beginner+ — needs a bit of practice",
          "Intermediate — solid skills needed",
          "Advanced — experienced players",
          "Expert — very challenging"
        ]
      },
      'Piano/Keyboard': {
        "Harmony": [
          "Single notes or simple triads",
          "Basic chords, both hands",
          "7ths, inversions, some extensions",
          "Complex voicings, key changes",
          "Advanced jazz or classical harmony"
        ],
        "Hand independence": [
          "Hands play together or one at a time",
          "Simple left hand, melody in right",
          "Both hands with different patterns",
          "Complex independence required",
          "Full polyphonic independence"
        ],
        "Technique": [
          "Single fingers, block chords",
          "Basic scales, arpeggios",
          "Runs, crossovers, pedal use",
          "Octaves, fast passages, dynamics",
          "Virtuosic — trills, leaps, speed"
        ],
        "Rhythm": [
          "Steady and simple",
          "Some syncopation",
          "Swing, shuffle, or mixed meter",
          "Complex rhythms between hands",
          "Polyrhythmic or very advanced"
        ],
        "Overall difficulty": [
          "Beginner — easy to pick up",
          "Beginner+ — needs a bit of practice",
          "Intermediate — solid skills needed",
          "Advanced — experienced players",
          "Expert — very challenging"
        ]
      },
      'Drums': {
        "Beat complexity": [
          "Basic rock/pop beat",
          "Variations with simple fills",
          "Groove patterns (funk, shuffle)",
          "Complex patterns, odd time",
          "Advanced polyrhythmic grooves"
        ],
        "Limb independence": [
          "Hi-hat + kick + snare basics",
          "Adding simple variations",
          "Each limb doing its own thing",
          "High independence required",
          "Full 4-way independence"
        ],
        "Fills & transitions": [
          "No fills or very basic",
          "Simple 1-bar fills",
          "Multi-bar fills, some flair",
          "Technical fills, odd groupings",
          "Blazing or very complex fills"
        ],
        "Dynamics & feel": [
          "One volume, straight feel",
          "Basic loud/soft changes",
          "Ghost notes, accents, groove",
          "Nuanced touch and expression",
          "Full dynamic mastery"
        ],
        "Overall difficulty": [
          "Beginner — easy to pick up",
          "Beginner+ — needs a bit of practice",
          "Intermediate — solid skills needed",
          "Advanced — experienced players",
          "Expert — very challenging"
        ]
      },
      'Vocals': {
        "Melody & range": [
          "Small range, simple melody",
          "Moderate range, stepwise motion",
          "Wide range with some leaps",
          "Demanding range, big intervals",
          "Extreme range or very complex melody"
        ],
        "Vocal technique": [
          "Straight singing, no extras",
          "Basic dynamics and breath control",
          "Vibrato, runs, or belt",
          "Melisma, mixed voice, advanced control",
          "Whistle tones, vocal percussion, extreme technique"
        ],
        "Rhythm & phrasing": [
          "Follows the beat simply",
          "Some syncopation or swing",
          "Complex phrasing, behind/ahead of beat",
          "Rapid-fire or intricate rhythms",
          "Free rhythm or very advanced phrasing"
        ],
        "Expression": [
          "Minimal dynamic change",
          "Basic loud and soft sections",
          "Noticeable emotional shaping",
          "Highly expressive performance",
          "Deep artistry and interpretation"
        ],
        "Overall difficulty": [
          "Beginner — easy to pick up",
          "Beginner+ — needs a bit of practice",
          "Intermediate — solid skills needed",
          "Advanced — experienced players",
          "Expert — very challenging"
        ]
      }
    };
  }

  showLevelSuggestion() {
    const suggested = this.calculateLevelFromResponses();
    const container = document.getElementById('level-suggestion');

    // Update the grading data with the suggested level
    this.gradingData.level = suggested;

    container.innerHTML = `
      <div class="suggested-level">Level ${suggested}</div>
      <p><strong>Based on your responses, this song appears to be at Level ${suggested}</strong></p>
      <p style="margin-top: 0.5rem; font-size: 0.9rem; color: var(--text-secondary);">
        <em>This level was calculated from your answers to the questionnaire.</em>
      </p>
      <div class="form-group" style="margin-top: 1.5rem;">
        <label for="final-level-select">You can adjust this if you think it should be different:</label>
        <select id="final-level-select" class="form-control">
          <option value="1" ${suggested === 1 ? 'selected' : ''}>Level 1 - Getting Started</option>
          <option value="2" ${suggested === 2 ? 'selected' : ''}>Level 2 - Expanding Skills</option>
          <option value="3" ${suggested === 3 ? 'selected' : ''}>Level 3 - Building Technique</option>
          <option value="4" ${suggested === 4 ? 'selected' : ''}>Level 4 - Finding Your Style</option>
          <option value="5" ${suggested === 5 ? 'selected' : ''}>Level 5 - Mastering It</option>
        </select>
      </div>
    `;

    // Add event listener to update the grading data when user adjusts
    document.getElementById('final-level-select').addEventListener('change', (e) => {
      this.gradingData.level = parseInt(e.target.value);
    });
  }

  async submitSongGrading() {
    const user = auth.getCurrentUser();
    // Use student ID if in preview mode, otherwise use current user
    const userId = this.previewMode.active ? this.previewMode.studentId : user.id;

    if (!this.gradingData.level) {
      this.showToast('Error: Level not set. Please refresh and try again.', 'error');
      console.error('🎯 Level is missing from gradingData');
      return;
    }

    try {
      const rpcParams = {
        p_student_id: userId,
        p_title: this.gradingData.title,
        p_artist: this.gradingData.artist,
        p_instrument_id: this.gradingData.instrument,
        p_assessed_level: this.gradingData.level,
        p_checklist_responses_json: this.gradingData.checklistResponses,
        p_youtube_url: this.gradingData.youtube_url || null,
        p_chords_url: this.gradingData.chords_url || null,
        p_tutorial_url: this.gradingData.tutorial_url || null,
        p_add_to_learning: document.getElementById('add-to-learning').checked,
        p_bass_tab_url: this.gradingData.bass_tab_url || null,
        p_drum_notation_url: this.gradingData.drum_notation_url || null
      };

      // Use direct fetch to bypass potentially stale Supabase client
      const result = await this.callRpcDirect('grade_song', rpcParams);

      if (result.error) throw result.error;

      // Save tutorial URL as a resource with file_type='tutorial'
      const gradedSongId = result.data?.song_id;
      if (gradedSongId && this.gradingData.tutorial_url) {
        try {
          const isTeacher = auth.hasRole('teacher') || auth.hasRole('admin');
          await this.rawInsert('student_resources', {
            song_id: gradedSongId,
            file_url: this.gradingData.tutorial_url,
            file_type: 'tutorial',
            title: 'Tutorial Video',
            instrument_id: this.gradingData.instrument,
            user_id: auth.getCurrentUser().id,
            status: isTeacher ? 'approved' : 'pending'
          });
        } catch (tutErr) {
          // Don't fail the grading if tutorial insert fails (e.g. duplicate)
          console.warn('Could not save tutorial resource:', tutErr);
          this.showToast('Tutorial link could not be saved, but grading succeeded.', 'warning');
        }
      }

      // Close modal and refresh
      document.getElementById('song-grading-modal').classList.add('hidden');
      this.showToast('Song graded successfully!', 'success');

      // Refresh data and re-render current view in a separate try/catch
      // so a stale-connection refresh failure doesn't mask the successful grading
      try {
        if (this.previewMode.active) {
          await this.loadStudentPreviewData(this.previewMode.studentId);
        }

        if (this.currentView === 'songs') {
          await this.renderSongs();
        } else if (this.currentView === 'progress') {
          await this.renderProgress();
        } else if (this.currentView === 'pathway') {
          await this.loadSongs();
          this.renderPathway();
        } else if (this.currentView === 'flagged') {
          await this.loadFlaggedRatings();
        }
      } catch (refreshErr) {
        console.warn('Post-grading view refresh failed:', refreshErr.message);
        this.showToast('Song was graded — refresh the page to see it in the list', 'warning');
      }
    } catch (error) {
      console.error('🎯 Error submitting grading:', error);
      console.error('🎯 Error details:', {
        message: error.message,
        details: error.details,
        hint: error.hint,
        code: error.code
      });

      // If it's a timeout, suggest refreshing the page (case-insensitive to catch REFRESH_TIMEOUT, SESSION_TIMEOUT, etc.)
      if (error.message?.toLowerCase().includes('timed out') || error.message?.toLowerCase().includes('timeout')) {
        this.showToast('Connection lost - please refresh the page and try again', 'error');
      } else {
        const errorMsg = error.message || error.details || 'Failed to submit grading';
        this.showToast(`Failed to submit grading: ${errorMsg}`, 'error');
      }
    }
  }

  // Get auth session with timeout protection - getSession can hang if Supabase client is stale
  async getSessionWithTimeout() {
    try {
      const result = await Promise.race([
        supabase.auth.getSession(),
        new Promise((_, reject) => setTimeout(() => reject(new Error('SESSION_TIMEOUT')), 5000))
      ]);
      return result.data?.session;
    } catch (e) {
      if (e.message === 'SESSION_TIMEOUT') {
        // getSession hung - try refreshSession as fallback
        try {
          const refreshResult = await Promise.race([
            supabase.auth.refreshSession(),
            new Promise((_, reject) => setTimeout(() => reject(new Error('REFRESH_TIMEOUT')), 5000))
          ]);
          return refreshResult.data?.session;
        } catch (refreshErr) {
          if (refreshErr.message === 'REFRESH_TIMEOUT') {
            // Both Supabase client methods hung - read token directly from localStorage as last resort
            console.warn('Supabase client stale, falling back to localStorage token');
            const storageKey = Object.keys(localStorage).find(key =>
              key.startsWith('sb-') && key.endsWith('-auth-token')
            );
            const tokenData = storageKey ? JSON.parse(localStorage.getItem(storageKey)) : null;
            if (tokenData?.access_token) {
              return { access_token: tokenData.access_token };
            }
          }
          throw refreshErr;
        }
      }
      throw e;
    }
  }

  // Direct RPC call using fetch to bypass stale Supabase client connections
  async callRpcDirect(functionName, params, _isRetry = false) {
    const session = await this.getSessionWithTimeout();

    if (!session?.access_token) {
      throw new Error('Not authenticated - please refresh the page and log in again');
    }

    const accessToken = session.access_token;

    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 30000);

    try {
      const response = await fetch(
        `https://dgwtihpiqgkhokkkxuzo.supabase.co/rest/v1/rpc/${functionName}`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'apikey': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRnd3RpaHBpcWdraG9ra2t4dXpvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc0OTQzNjcsImV4cCI6MjA4MzA3MDM2N30.xnD7lrvmBlvW-9XzL0VTabAq6wtwsepxb90Assu8bNo',
            'Authorization': `Bearer ${accessToken}`
          },
          body: JSON.stringify(params),
          signal: controller.signal
        }
      );

      clearTimeout(timeoutId);

      // On 401, force-refresh the token and retry once
      if (response.status === 401 && !_isRetry) {
        const { data: { session: refreshed } } = await supabase.auth.refreshSession();
        if (refreshed?.access_token) {
          return this.callRpcDirect(functionName, params, true);
        }
        throw new Error('Session expired - please log in again');
      }

      if (!response.ok) {
        const errorData = await response.json().catch(() => ({}));
        throw {
          message: errorData.message || `HTTP ${response.status}`,
          details: errorData.details,
          hint: errorData.hint,
          code: errorData.code
        };
      }

      // Handle empty responses (some RPC functions don't return data)
      const text = await response.text();
      const data = text ? JSON.parse(text) : null;
      return { data, error: null };
    } catch (err) {
      clearTimeout(timeoutId);
      if (err.name === 'AbortError') {
        throw new Error('Request timed out - please refresh the page and try again');
      }
      throw err;
    }
  }

  // Wrapper for Supabase queries that may stall on stale connections
  // Returns { data, error } - on timeout, shows toast and returns null data
  async queryWithTimeout(queryPromise, timeoutMs = 15000, context = 'data') {
    const timeoutPromise = new Promise((_, reject) =>
      setTimeout(() => reject(new Error('QUERY_TIMEOUT')), timeoutMs)
    );

    try {
      return await Promise.race([queryPromise, timeoutPromise]);
    } catch (error) {
      if (error.message === 'QUERY_TIMEOUT') {
        console.warn(`Query timeout while loading ${context}`);
        this.showToast('Connection lost. Retrying...', 'error');
        return { data: null, error: { message: 'Connection timeout' } };
      }
      throw error;
    }
  }

  // Direct SELECT query using fetch to bypass stale Supabase client connections
  // Supports nested selects (e.g. '*,songs(*)') and in filters (e.g. { in: { col: [v1,v2] } })
  async callSelectDirect(table, select = '*', filters = {}, options = {}, _isRetry = false) {
    const session = await this.getSessionWithTimeout();
    const accessToken = session?.access_token;

    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), options.timeout || 15000);

    // Build query string
    const params = new URLSearchParams();
    params.set('select', select);

    // Add filters (e.g., { eq: { column: value }, in: { column: [v1, v2] } })
    for (const [op, conditions] of Object.entries(filters)) {
      for (const [column, value] of Object.entries(conditions)) {
        if (op === 'in' && Array.isArray(value)) {
          params.append(column, `in.(${value.join(',')})`);
        } else {
          params.append(column, `${op}.${value}`);
        }
      }
    }

    // Add order if specified
    if (options.order) {
      params.set('order', options.order);
    }

    // Add limit if specified
    if (options.limit) {
      params.set('limit', options.limit);
    }

    try {
      const headers = {
        'Content-Type': 'application/json',
        'apikey': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRnd3RpaHBpcWdraG9ra2t4dXpvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc0OTQzNjcsImV4cCI6MjA4MzA3MDM2N30.xnD7lrvmBlvW-9XzL0VTabAq6wtwsepxb90Assu8bNo'
      };
      if (accessToken) {
        headers['Authorization'] = `Bearer ${accessToken}`;
      }

      const response = await fetch(
        `https://dgwtihpiqgkhokkkxuzo.supabase.co/rest/v1/${table}?${params.toString()}`,
        {
          method: 'GET',
          headers,
          signal: controller.signal
        }
      );

      clearTimeout(timeoutId);

      // On 401, force-refresh the token and retry once
      if (response.status === 401 && !_isRetry) {
        const { data: { session: refreshed } } = await supabase.auth.refreshSession();
        if (refreshed?.access_token) {
          return this.callSelectDirect(table, select, filters, options, true);
        }
      }

      if (!response.ok) {
        const errorData = await response.json().catch(() => ({}));
        return {
          data: null,
          error: {
            message: errorData.message || `HTTP ${response.status}`,
            details: errorData.details
          }
        };
      }

      const data = await response.json();
      return { data, error: null };
    } catch (err) {
      clearTimeout(timeoutId);
      if (err.name === 'AbortError') {
        this.showToast('Connection lost. Retrying...', 'error');
        return { data: null, error: { message: 'Connection timeout' } };
      }
      return { data: null, error: { message: err.message } };
    }
  }

  // Direct DELETE query using fetch to bypass stale Supabase client connections
  async callDeleteDirect(table, filters = {}, options = {}, _isRetry = false) {
    const session = await this.getSessionWithTimeout();
    const accessToken = session?.access_token;

    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), options.timeout || 15000);

    // Build query string from filters
    const params = new URLSearchParams();
    for (const [op, conditions] of Object.entries(filters)) {
      for (const [column, value] of Object.entries(conditions)) {
        params.append(column, `${op}.${value}`);
      }
    }

    try {
      const headers = {
        'Content-Type': 'application/json',
        'apikey': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRnd3RpaHBpcWdraG9ra2t4dXpvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc0OTQzNjcsImV4cCI6MjA4MzA3MDM2N30.xnD7lrvmBlvW-9XzL0VTabAq6wtwsepxb90Assu8bNo'
      };
      if (accessToken) {
        headers['Authorization'] = `Bearer ${accessToken}`;
      }

      const response = await fetch(
        `https://dgwtihpiqgkhokkkxuzo.supabase.co/rest/v1/${table}?${params.toString()}`,
        {
          method: 'DELETE',
          headers,
          signal: controller.signal
        }
      );

      clearTimeout(timeoutId);

      // On 401, force-refresh the token and retry once
      if (response.status === 401 && !_isRetry) {
        const { data: { session: refreshed } } = await supabase.auth.refreshSession();
        if (refreshed?.access_token) {
          return this.callDeleteDirect(table, filters, options, true);
        }
      }

      if (!response.ok) {
        const errorData = await response.json().catch(() => ({}));
        return {
          data: null,
          error: {
            message: errorData.message || `HTTP ${response.status}`,
            details: errorData.details
          }
        };
      }

      return { data: null, error: null };
    } catch (err) {
      clearTimeout(timeoutId);
      if (err.name === 'AbortError') {
        this.showToast('Connection lost. Retrying...', 'error');
        return { data: null, error: { message: 'Connection timeout' } };
      }
      return { data: null, error: { message: err.message } };
    }
  }


  // ============================================
  // STUDENT: Progress Tracking & Mastery
  // ============================================

  async renderProgress(useLocalData = false) {
    const user = auth.getCurrentUser();
    let studentSongsWithRatings;

    // If in preview mode or using local data after a mutation, use already-loaded data
    if (this.previewMode.active || useLocalData) {
      // Data already has resource_ratings from RPC function or previous fetch
      studentSongsWithRatings = this.studentSongs || [];
    } else {
      // Load fresh data for current user
      const userId = user.id;

      // Use direct fetch to bypass stale Supabase client connections
      const { data: studentSongs } = await this.callSelectDirect(
        'student_songs',
        '*,songs(*)',
        { eq: { user_id: userId } },
        { order: 'date_started.desc' }
      );

      // Load resource ratings for these student songs
      const studentSongIds = studentSongs?.map(s => s.id) || [];
      const { data: resourceRatings } = studentSongIds.length > 0
        ? await this.callSelectDirect(
            'resource_ratings',
            '*',
            { in: { student_song_id: studentSongIds } }
          )
        : { data: [] };

      // Create a map of student_song_id to ratings
      const ratingsMap = {};
      if (resourceRatings) {
        resourceRatings.forEach(rating => {
          if (!ratingsMap[rating.student_song_id]) {
            ratingsMap[rating.student_song_id] = { chords: [], tutorial: [] };
          }
          if (rating.chords_rating) {
            ratingsMap[rating.student_song_id].chords.push(rating.chords_rating);
          }
          if (rating.tutorial_rating) {
            ratingsMap[rating.student_song_id].tutorial.push(rating.tutorial_rating);
          }
        });
      }

      // Attach ratings to student songs and save to local state
      // so subsequent local mutations (remove, master, unmaster) can re-render without re-fetching
      studentSongsWithRatings = studentSongs?.map(s => ({
        ...s,
        resource_ratings: ratingsMap[s.id] || { chords: [], tutorial: [] }
      }));
      this.studentSongs = studentSongsWithRatings || [];
    }

    // Calculate stats
    const learning = studentSongsWithRatings?.filter(s => s.status === 'learning') || [];
    const mastered = studentSongsWithRatings?.filter(s => s.status === 'mastered') || [];

    // Group songs by song_id to show same song across instruments together
    const groupedBySong = {};
    studentSongsWithRatings?.forEach(s => {
      const songId = s.songs?.id || s.song_id;
      if (!groupedBySong[songId]) {
        groupedBySong[songId] = {
          song: s.songs,
          instruments: []
        };
      }
      groupedBySong[songId].instruments.push(s);
    });

    // Separate into learning (any instrument still learning) vs mastered (all instruments mastered)
    const learningGroups = [];
    const masteredGroups = [];
    Object.values(groupedBySong).forEach(group => {
      const hasLearning = group.instruments.some(i => i.status === 'learning');
      if (hasLearning) {
        learningGroups.push(group);
      } else {
        masteredGroups.push(group);
      }
    });

    // Sort by most recent date_started
    learningGroups.sort((a, b) => {
      const aDate = Math.max(...a.instruments.map(i => new Date(i.date_started || 0).getTime()));
      const bDate = Math.max(...b.instruments.map(i => new Date(i.date_started || 0).getTime()));
      return bDate - aDate;
    });
    masteredGroups.sort((a, b) => {
      const aDate = Math.max(...a.instruments.map(i => new Date(i.date_mastered || i.date_started || 0).getTime()));
      const bDate = Math.max(...b.instruments.map(i => new Date(i.date_mastered || i.date_started || 0).getTime()));
      return bDate - aDate;
    });

    // Render stats (count unique songs, not individual entries)
    const statsContainer = document.getElementById('progress-stats');
    statsContainer.innerHTML = `
      <div class="stat-card">
        <div class="stat-value">${this.studentProgress.length}</div>
        <div class="stat-label">Instruments</div>
      </div>
      <div class="stat-card">
        <div class="stat-value">${learningGroups.length}</div>
        <div class="stat-label">Songs Learning</div>
      </div>
      <div class="stat-card">
        <div class="stat-value">${masteredGroups.length}</div>
        <div class="stat-label">Songs Mastered</div>
      </div>
    `;

    // Render song lists (grouped by song)
    document.getElementById('learning-songs').innerHTML = learningGroups.length > 0
      ? learningGroups.map(g => this.renderGroupedSongItem(g)).join('')
      : '<p style="color: var(--text-secondary);">No songs in progress</p>';

    document.getElementById('mastered-songs').innerHTML = masteredGroups.length > 0
      ? masteredGroups.map(g => this.renderGroupedSongItem(g)).join('')
      : '<p style="color: var(--text-secondary);">No mastered songs yet</p>';
  }

  renderGroupedSongItem(group) {
    const song = group.song;
    if (!song) return '';

    // Sort instruments: learning first, then mastered
    const sortedInstruments = [...group.instruments].sort((a, b) => {
      if (a.status === 'learning' && b.status !== 'learning') return -1;
      if (a.status !== 'learning' && b.status === 'learning') return 1;
      return 0;
    });

    // Build instrument badges with status
    const instrumentBadges = sortedInstruments.map(studentSong => {
      const instrument = this.instruments.find(i => i.id === studentSong.instrument_id);
      const instrumentName = instrument?.name || 'Unknown';
      const instrumentIcon = instrument?.icon || '';
      const isMastered = studentSong.status === 'mastered';

      return `
        <span class="instrument-status-badge ${isMastered ? 'mastered' : 'learning'}"
              title="${instrumentName}: ${isMastered ? 'Mastered' : 'Learning'}">
          ${instrumentIcon} ${instrumentName}
          ${isMastered ? '<span class="status-icon">✓</span>' : ''}
        </span>
      `;
    }).join('');

    // Get first student song for resource links
    const firstStudentSong = sortedInstruments[0];
    const firstInstrument = this.instruments.find(i => i.id === firstStudentSong.instrument_id);
    const firstInstrumentName = firstInstrument?.name || '';
    const chordsRating = this.formatResourceRating(firstStudentSong.resource_ratings?.chords);

    // Build separate links for each unique instrument resource type (each uses its own URL field)
    const seenFields = new Set();
    const chordsLinks = sortedInstruments.map(si => {
      const inst = this.instruments.find(i => i.id === si.instrument_id);
      const instName = inst?.name || '';
      const label = this.getChordsLabelForInstrument(instName);
      const urlField = this.getChordsUrlField(instName);
      if (seenFields.has(urlField)) return '';
      seenFields.add(urlField);
      const url = song[urlField];
      const isFirst = seenFields.size === 1;
      if (url) {
        return `
          <span style="display: inline-flex; align-items: center; gap: 2px;">
            <a href="${url}" target="_blank" style="font-size: 12px; color: var(--secondary-color);">${label}</a>
            ${isFirst ? chordsRating : ''}
            <button class="btn-icon-small" onclick="app.editSongResource('${song.id}', '${urlField}', '${url.replace(/'/g, "\\'")}', '${song.title.replace(/'/g, "\\'")}', '${song.artist.replace(/'/g, "\\'")}', '${instName.replace(/'/g, "\\'")}')" title="Edit ${label.toLowerCase()} link">✎</button>
          </span>`;
      } else if (this.getMyPendingLink(song.id, urlField)) {
        return `
          <span style="display: inline-flex; align-items: center; gap: 2px; font-size: 12px; color: var(--text-secondary); font-style: italic;" title="Your ${label.toLowerCase()} link is awaiting teacher approval">⏳ ${label} Pending</span>`;
      } else {
        return `
          <button class="btn-link-add" onclick="app.editSongResource('${song.id}', '${urlField}', '', '${song.title.replace(/'/g, "\\'")}', '${song.artist.replace(/'/g, "\\'")}', '${instName.replace(/'/g, "\\'")}')" title="Add ${label.toLowerCase()} link">+ ${label}</button>`;
      }
    }).filter(Boolean).join('\n            ');

    // Build actions for each instrument
    const instrumentActions = sortedInstruments.map(studentSong => {
      const instrument = this.instruments.find(i => i.id === studentSong.instrument_id);
      const instrumentName = instrument?.name || 'Unknown';
      const instrumentIcon = instrument?.icon || '';
      const isMastered = studentSong.status === 'mastered';

      if (isMastered) {
        return `
          <div class="instrument-action-row">
            <span class="instrument-action-label">${instrumentIcon}</span>
            <button class="btn btn-sm btn-secondary" onclick="app.unmasterSong('${studentSong.id}')">Unmaster</button>
            <button class="btn-text btn-sm btn-danger" onclick="app.removeSong('${studentSong.id}')">Remove</button>
          </div>
        `;
      } else {
        return `
          <div class="instrument-action-row">
            <span class="instrument-action-label">${instrumentIcon}</span>
            <button class="btn btn-sm btn-primary" onclick="app.markSongMastered('${studentSong.id}')">Mastered</button>
            <button class="btn-text btn-sm btn-danger" onclick="app.removeSong('${studentSong.id}')">Remove</button>
          </div>
        `;
      }
    }).join('');

    return `
      <div class="song-list-item grouped">
        <div class="info">
          <div class="title">${song.title}</div>
          <div class="artist">${song.artist}</div>
          <div class="instrument-badges" style="margin-top: 4px; display: flex; gap: 6px; flex-wrap: wrap;">
            ${instrumentBadges}
          </div>
          <div class="song-links" style="margin-top: 8px; display: flex; gap: 8px; flex-wrap: wrap; align-items: center;">
            ${song.youtube_url ? `
              <span style="display: inline-flex; align-items: center; gap: 4px;">
                <a href="${song.youtube_url}" target="_blank" class="song-resource-link song-resource-link--youtube" onclick="event.stopPropagation()">▶ YouTube</a>
                <button class="btn-icon-small" onclick="app.editSongResource('${song.id}', 'youtube_url', '${song.youtube_url.replace(/'/g, "\\'")}', '${song.title.replace(/'/g, "\\'")}', '${song.artist.replace(/'/g, "\\'")}', '${firstInstrumentName.replace(/'/g, "\\'")}')" title="Edit YouTube link">✎</button>
              </span>
            ` : this.getMyPendingLink(song.id, 'youtube_url') ? `
              <span class="btn btn-secondary btn-pending" onclick="event.stopPropagation()" title="Your YouTube link is awaiting teacher approval" style="opacity: 0.7; cursor: default; font-style: italic;">⏳ YouTube Pending</span>
            ` : `
              <button class="btn btn-secondary btn-add" onclick="app.editSongResource('${song.id}', 'youtube_url', '', '${song.title.replace(/'/g, "\\'")}', '${song.artist.replace(/'/g, "\\'")}', '${firstInstrumentName.replace(/'/g, "\\'")}')" title="Add YouTube link">+ YouTube</button>
            `}
            <button class="btn btn-secondary btn-resources" onclick="app.showSongResourcesModal('${song.id}', '${firstStudentSong.instrument_id}')" title="View learning resources">Learning Resources</button>
          </div>
        </div>
        <div class="actions-grouped">
          ${instrumentActions}
        </div>
      </div>
    `;
  }

  renderStudentSongItem(studentSong) {
    const song = studentSong.songs;
    const instrument = this.instruments.find(i => i.id === studentSong.instrument_id);
    const instrumentName = instrument?.name || '';
    const instrumentIcon = instrument?.icon || '';

    return `
      <div class="song-list-item">
        <div class="info">
          <div class="title">${song.title}</div>
          <div class="artist">${song.artist}</div>
          ${instrument ? `<div class="instrument-tag" style="font-size: 12px; color: var(--text-secondary); margin-top: 2px;">${instrumentIcon} ${instrumentName}</div>` : ''}
          <div class="song-links" style="margin-top: 4px; display: flex; gap: 8px; flex-wrap: wrap; align-items: center;">
            ${song.youtube_url ? `
              <span style="display: inline-flex; align-items: center; gap: 4px;">
                <a href="${song.youtube_url}" target="_blank" class="song-resource-link song-resource-link--youtube" onclick="event.stopPropagation()">▶ YouTube</a>
                <button class="btn-icon-small" onclick="app.editSongResource('${song.id}', 'youtube_url', '${song.youtube_url.replace(/'/g, "\\'")}', '${song.title.replace(/'/g, "\\'")}', '${song.artist.replace(/'/g, "\\'")}', '${instrumentName.replace(/'/g, "\\'")}')" title="Edit YouTube link">✎</button>
              </span>
            ` : this.getMyPendingLink(song.id, 'youtube_url') ? `
              <span class="btn btn-secondary btn-pending" onclick="event.stopPropagation()" title="Your YouTube link is awaiting teacher approval" style="opacity: 0.7; cursor: default; font-style: italic;">⏳ YouTube Pending</span>
            ` : `
              <button class="btn btn-secondary btn-add" onclick="event.stopPropagation(); app.editSongResource('${song.id}', 'youtube_url', '', '${song.title.replace(/'/g, "\\'")}', '${song.artist.replace(/'/g, "\\'")}', '${instrumentName.replace(/'/g, "\\'")}')" title="Add YouTube link">+ YouTube</button>
            `}
            <button class="btn btn-secondary btn-resources" onclick="event.stopPropagation(); app.showSongResourcesModal('${song.id}', '${studentSong.instrument_id}')">Learning Resources</button>
          </div>
        </div>
        <div class="actions">
          ${studentSong.status === 'learning' ? `
            <button class="btn btn-primary" onclick="app.markSongMastered('${studentSong.id}')">
              Mark Mastered
            </button>
            <button class="btn-text btn-danger" onclick="app.removeSong('${studentSong.id}')">
              Remove
            </button>
          ` : `
            <span style="color: var(--secondary-color); font-weight: 600; margin-right: 8px;">✓ Mastered</span>
            <button class="btn btn-secondary" onclick="app.unmasterSong('${studentSong.id}')">
              Unmaster
            </button>
            <button class="btn-text btn-danger" onclick="app.removeSong('${studentSong.id}')">
              Remove
            </button>
          `}
        </div>
      </div>
    `;
  }

  async markSongMastered(studentSongId) {
    const user = auth.getCurrentUser();

    // Get the student song to check which instrument it's for
    // Use direct RPC call to bypass stale connections and RLS when in preview mode
    let studentSong;
    try {
      const result = await this.callRpcDirect('get_student_song_detail', {
        p_student_song_id: studentSongId
      });
      studentSong = result.data;
    } catch (error) {
      console.error('Error getting student song:', error);
      this.showToast('Failed to load song details', 'error');
      return;
    }

    if (!studentSong) return;

    // Store for later use
    this.pendingMasteredSong = {
      studentSongId,
      instrumentId: studentSong.instrument_id
    };

    // Check if song has chords/tab/notation or tutorial links
    const inst = this.instruments.find(i => i.id === studentSong.instrument_id);
    const hasChords = studentSong.songs[this.getChordsUrlField(inst?.name)];
    const hasTutorial = studentSong.songs.tutorial_url;

    if (!hasChords && !hasTutorial) {
      // No resources to rate, mark as mastered directly
      await this.completeMasteredMarking();
      return;
    }

    // Show rating modal
    this.showRateResourcesModal(studentSong.songs, hasChords, hasTutorial);
  }

  showRateResourcesModal(song, hasChords, hasTutorial) {
    // Update modal content with instrument if available (use song's instrument or current filter instrument)
    const currentInstrument = this.instruments.find(i => i.id === this.currentInstrument);
    const instrumentDisplay = song.instruments
      ? ` (${song.instruments.icon} ${song.instruments.name})`
      : (currentInstrument ? ` (${currentInstrument.icon} ${currentInstrument.name})` : '');
    document.getElementById('rate-resources-song-info').textContent =
      `${song.title} - ${song.artist}${instrumentDisplay}`;

    // Show/hide rating groups based on what resources exist
    const chordsGroup = document.getElementById('chords-rating-group');
    const tutorialGroup = document.getElementById('tutorial-rating-group');

    if (hasChords) {
      chordsGroup.classList.remove('hidden');
      // Reset stars
      chordsGroup.querySelectorAll('.star').forEach(s => s.classList.remove('active'));
      document.getElementById('chords-rating').value = '';
    } else {
      chordsGroup.classList.add('hidden');
    }

    if (hasTutorial) {
      tutorialGroup.classList.remove('hidden');
      // Reset stars
      tutorialGroup.querySelectorAll('.star').forEach(s => s.classList.remove('active'));
      document.getElementById('tutorial-rating').value = '';
    } else {
      tutorialGroup.classList.add('hidden');
    }

    // Show modal
    document.getElementById('rate-resources-modal').classList.remove('hidden');
  }

  async submitResourceRatings() {
    const chordsRating = document.getElementById('chords-rating').value;
    const tutorialRating = document.getElementById('tutorial-rating').value;

    // Save ratings if provided - use direct RPC call to bypass stale connections
    if (chordsRating || tutorialRating) {
      try {
        await this.callRpcDirect('submit_resource_ratings', {
          p_student_song_id: this.pendingMasteredSong.studentSongId,
          p_chords_rating: chordsRating ? parseInt(chordsRating) : null,
          p_tutorial_rating: tutorialRating ? parseInt(tutorialRating) : null
        });
      } catch (error) {
        console.error('Error saving ratings:', error);
        this.showToast('Resource ratings could not be saved, but your progress was updated.', 'warning');
        // Continue anyway - don't block mastering due to rating error
      }
    }

    // Close modal
    document.getElementById('rate-resources-modal').classList.add('hidden');

    // Complete the mastered marking
    await this.completeMasteredMarking();
  }

  async completeMasteredMarking() {
    if (!this.pendingMasteredSong) return;

    const { studentSongId, instrumentId } = this.pendingMasteredSong;

    // Use direct RPC call to bypass stale Supabase client connections
    try {
      await this.callRpcDirect('update_student_song_status', {
        p_student_song_id: studentSongId,
        p_status: 'mastered',
        p_date_completed: new Date().toISOString()
      });
    } catch (error) {
      console.error('Error marking song mastered:', error);
      this.showToast('Failed to update song', 'error');
      return;
    }

    // Update local studentSongs data to reflect the change
    const studentSong = this.studentSongs.find(ss => ss.id === studentSongId);
    if (studentSong) {
      studentSong.status = 'mastered';
      studentSong.date_completed = new Date().toISOString();
    }

    this.showToast('Song marked as mastered!', 'success');

    // Check for level advancement
    await this.checkLevelAdvancement(instrumentId);

    this.renderProgress(true);

    // Clear pending data
    this.pendingMasteredSong = null;
  }

  async checkLevelAdvancement(instrumentId) {
    const user = auth.getCurrentUser();
    // Use student ID if in preview mode, otherwise use current user
    const userId = this.previewMode.active ? this.previewMode.studentId : user.id;

    // Get current progress for this instrument
    const progress = this.studentProgress.find(p => p.instrument_id === instrumentId);
    if (!progress) {
      return;
    }

    const currentLevel = progress.current_level;

    // Count mastered songs at current level for this instrument
    // Use direct fetch to avoid stale Supabase client after idle/background
    const { data: masteredSongs, error: queryError } = await this.callSelectDirect(
      'student_songs',
      '*, songs!inner(*)',
      { eq: { user_id: userId, instrument_id: instrumentId, status: 'mastered' } }
    );

    if (queryError) {
      console.error('Error querying mastered songs:', queryError);
      return;
    }

    // Filter by suggested level in JavaScript since Supabase join syntax is tricky
    const levelSongs = masteredSongs?.filter(ss => ss.songs?.suggested_level === currentLevel) || [];
    const masteredCount = levelSongs.length;
    const requiredSongs = 3; // Songs needed to advance

    if (masteredCount >= requiredSongs && currentLevel < 5) {
      // Advance to next level!
      const newLevel = currentLevel + 1;

      // Use direct fetch to avoid stale Supabase client after idle/background
      const { error } = await this.rawUpdate('student_progress', progress.id, { current_level: newLevel });

      if (!error) {
        // Reload student progress from database to ensure all instruments have correct levels
        await this.loadStudentProgress();

        const instrumentName = this.instruments.find(i => i.id === instrumentId)?.name;
        this.showToast(`🎉 Congratulations! You've advanced to Level ${newLevel} on ${instrumentName}!`, 'success');

        // Refresh the pathway if viewing this instrument
        if (this.currentInstrument === instrumentId) {
          await this.loadLevels(instrumentId);
          this.renderPathway();
        }
      } else {
        console.error('Error updating level:', error);
      }
    }
  }

  async unmasterSong(studentSongId) {
    // Use direct RPC call to bypass stale Supabase client connections
    try {
      await this.callRpcDirect('update_student_song_status', {
        p_student_song_id: studentSongId,
        p_status: 'learning',
        p_date_completed: null
      });
    } catch (error) {
      console.error('Error unmarking song:', error);
      this.showToast('Failed to unmaster song', 'error');
      return;
    }

    // Update local studentSongs data to reflect the change
    const studentSong = this.studentSongs.find(ss => ss.id === studentSongId);
    if (studentSong) {
      studentSong.status = 'learning';
      studentSong.date_completed = null;
    }

    this.showToast('Song moved back to learning', 'success');
    this.renderProgress(true);
  }

  async removeSong(studentSongId) {
    if (!confirm('Are you sure you want to remove this song from your progress?')) {
      return;
    }

    // Use direct RPC call to bypass stale Supabase client connections
    try {
      await this.callRpcDirect('remove_student_song', {
        p_student_song_id: studentSongId
      });
    } catch (error) {
      console.error('Error removing song:', error);
      this.showToast('Failed to remove song', 'error');
      return;
    }

    // Update local studentSongs data to remove the song
    const index = this.studentSongs.findIndex(ss => ss.id === studentSongId);
    if (index !== -1) {
      this.studentSongs.splice(index, 1);
    }

    this.showToast('Song removed successfully', 'success');
    this.renderProgress(true);
  }

  // ============================================
  // STUDENT: Export & AI Reflection
  // ============================================

  showExportModal() {
    document.getElementById('export-modal').classList.remove('hidden');

    const exportCsvBtn = document.getElementById('export-csv-btn');
    const exportReflectionBtn = document.getElementById('export-reflection-btn');
    const copyReflectionBtn = document.getElementById('copy-reflection-btn');
    const reflectionText = document.getElementById('reflection-text');

    exportCsvBtn.onclick = () => this.exportCSV();
    exportReflectionBtn.onclick = async () => {
      try {
        exportReflectionBtn.disabled = true;
        exportReflectionBtn.textContent = 'Generating...';

        const text = await this.generateReflection();
        reflectionText.value = text;
        reflectionText.classList.remove('hidden');
        copyReflectionBtn.classList.remove('hidden');

        this.showToast('Reflection generated!', 'success');
      } catch (error) {
        console.error('Error generating reflection:', error);
        this.showToast('Failed to generate reflection', 'error');
      } finally {
        exportReflectionBtn.disabled = false;
        exportReflectionBtn.textContent = 'Generate Reflection';
      }
    };
    copyReflectionBtn.onclick = () => {
      reflectionText.select();
      document.execCommand('copy');
      this.showToast('Copied to clipboard!', 'success');
    };
  }

  async exportCSV() {
    const user = auth.getCurrentUser();

    // Get all data
    const { data: studentSongs, error } = await supabase
      .from('student_songs')
      .select(`
        *,
        songs (*)
      `)
      .eq('user_id', user.id);

    if (error) {
      console.error('Error fetching student songs:', error);
      this.showToast('Failed to export data', 'error');
      return;
    }

    if (!studentSongs || studentSongs.length === 0) {
      this.showToast('No songs to export yet!', 'info');
      return;
    }

    // Get instrument names
    const instrumentIds = [...new Set(studentSongs.map(ss => ss.instrument_id))];
    const { data: instruments } = await supabase
      .from('instruments')
      .select('id, name')
      .in('id', instrumentIds);

    const instrumentMap = {};
    instruments.forEach(i => instrumentMap[i.id] = i.name);

    // Create CSV
    let csv = 'Song Title,Artist,Instrument,Status,Date Started,Date Completed\n';

    studentSongs.forEach(ss => {
      const instrumentName = instrumentMap[ss.instrument_id] || 'Unknown';
      csv += `"${ss.songs.title}","${ss.songs.artist}","${instrumentName}","${ss.status}","${new Date(ss.date_started).toLocaleDateString()}","${ss.date_completed ? new Date(ss.date_completed).toLocaleDateString() : ''}"\n`;
    });

    // Download
    const blob = new Blob([csv], { type: 'text/csv' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `cadence-progress-${new Date().toISOString().split('T')[0]}.csv`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);

    this.showToast('CSV exported successfully!', 'success');
  }

  async generateReflection() {
    const user = auth.getCurrentUser();

    const { data: studentSongs, error: songsError } = await supabase
      .from('student_songs')
      .select(`
        *,
        songs (*)
      `)
      .eq('user_id', user.id);

    if (songsError) {
      console.error('Error fetching student songs for reflection:', songsError);
      throw new Error('Failed to fetch songs');
    }

    const learning = studentSongs?.filter(s => s.status === 'learning') || [];
    const mastered = studentSongs?.filter(s => s.status === 'mastered') || [];

    // Get instrument names
    const instrumentIds = [...new Set((studentSongs || []).map(ss => ss.instrument_id))];
    const { data: instruments, error: instrumentsError } = await supabase
      .from('instruments')
      .select('id, name')
      .in('id', instrumentIds);

    if (instrumentsError) {
      console.error('Error fetching instruments for reflection:', instrumentsError);
      throw new Error('Failed to fetch instruments');
    }

    const instrumentMap = {};
    instruments?.forEach(i => instrumentMap[i.id] = i.name);

    const instrumentNames = [...new Set(this.studentProgress.map(p => {
      const inst = this.instruments.find(i => i.id === p.instrument_id);
      return inst?.name;
    }))].filter(Boolean);

    let reflection = `Music Skill Progression Reflection\n\n`;

    // Summary section with relevant details
    reflection += `MY PROGRESS SUMMARY\n`;
    reflection += `-------------------\n`;

    if (instrumentNames.length > 0) {
      reflection += `Instrument(s): ${instrumentNames.join(', ')}\n`;
    }

    reflection += `Total songs this term: ${learning.length + mastered.length}\n`;

    if (mastered.length > 0) {
      reflection += `\nSongs I have mastered (${mastered.length}):\n`;
      mastered.forEach(ss => {
        const instrumentName = instrumentMap[ss.instrument_id] || 'Unknown';
        reflection += `  • "${ss.songs.title}" by ${ss.songs.artist} (${instrumentName})\n`;
      });
    }

    if (learning.length > 0) {
      reflection += `\nSongs I am currently learning (${learning.length}):\n`;
      learning.forEach(ss => {
        const instrumentName = instrumentMap[ss.instrument_id] || 'Unknown';
        reflection += `  • "${ss.songs.title}" by ${ss.songs.artist} (${instrumentName})\n`;
      });
    }

    if (this.studentProgress && this.studentProgress.length > 0) {
      reflection += `\nMy current level(s):\n`;
      this.studentProgress.forEach(progress => {
        const inst = this.instruments.find(i => i.id === progress.instrument_id);
        if (inst) {
          let levelText = `  • ${inst.name}: Level ${progress.current_level}`;
          if (progress.current_branch) {
            levelText += ` (${progress.current_branch})`;
          }
          reflection += levelText + '\n';
        }
      });
    }

    // Reflection prompts section
    reflection += `\n\nMY REFLECTION\n`;
    reflection += `-------------\n\n`;
    reflection += `One thing I did well was...\n\n\n`;
    reflection += `One thing I struggled with was...\n\n\n`;
    reflection += `Next time, I'll try...\n\n\n`;
    reflection += `My teacher can help me best by...\n\n`;

    return reflection;
  }

  // ============================================
  // UI STATE: Login, Role Selection & App Display
  // ============================================

  showLoading(show) {
    document.getElementById('loading-screen').classList.toggle('hidden', !show);
  }

  resetAppState() {
    this.currentInstrument = null;
    this.instruments = [];
    this.levels = [];
    this.songs = [];
    this.studentProgress = [];
    this.studentSongs = [];
    this.currentView = 'pathway';
    this.classes = [];
    this.currentClass = null;
    sessionStorage.removeItem('cadence_currentView');
    this.classStudents = [];
    this.flaggedRatings = [];
    this.loadingSongs = false;
    this.initializing = false;
    this.previewMode = {
      active: false,
      studentId: null,
      studentName: null,
      originalUser: null,
      originalView: null,
      originalStudentProgress: null,
      originalInstruments: null,
      originalCurrentInstrument: null,
      originalStudentSongs: null,
      originalLevels: null
    };
  }

  showLoginScreen() {
    document.getElementById('login-screen').classList.remove('hidden');
    document.getElementById('role-selection-screen').classList.add('hidden');
    document.getElementById('app').classList.add('hidden');
  }

  showRoleSelection() {
    document.getElementById('login-screen').classList.add('hidden');
    document.getElementById('role-selection-screen').classList.remove('hidden');
    document.getElementById('app').classList.add('hidden');
  }

  async selectRole(role) {
    // Complete signup with selected role
    const result = await auth.completeSignupWithRole(role);

    if (result.success) {
      // The onAuthStateChange callback will be triggered automatically
      // which will call onUserSignedIn
    } else {
      console.error('🎵 Cadence: Failed to complete signup:', result.error);
      this.showToast('Failed to complete signup. Please try again.', 'error');
    }
  }

  showApp() {
    document.getElementById('login-screen').classList.add('hidden');
    document.getElementById('role-selection-screen').classList.add('hidden');
    document.getElementById('app').classList.remove('hidden');
  }

  // ============================================
  // TEACHER: Class Management
  // ============================================

  async loadClasses() {
    const user = auth.getCurrentUser();

    // Check if we should include archived classes
    const showArchived = document.getElementById('show-archived-classes')?.checked || false;

    // Use direct RPC call to bypass stale Supabase client connections
    let data;
    try {
      const result = await this.callRpcDirect('get_teacher_classes', {
        p_teacher_id: user.id,
        p_include_archived: showArchived
      });
      data = result.data;
    } catch (error) {
      console.error('Error loading classes:', error);
      this.classes = [];
      return;
    }

    this.classes = data || [];
    if (this.currentView === 'classes') {
      this.renderClassesList();
    }

    // Load flagged ratings to update notification badge
    if (this.classes.length > 0) {
      this.loadFlaggedRatings();
    }
  }

  async showCreateClassModal() {
    const user = auth.getCurrentUser();
    const teacherGroup = document.getElementById('class-teacher-group');
    const teacherSelect = document.getElementById('class-teacher');

    // Show teacher dropdown for admins
    if (user && user.role === 'admin') {
      teacherGroup.classList.remove('hidden');
      await this.loadTeachersForDropdown(teacherSelect);
    } else {
      teacherGroup.classList.add('hidden');
    }

    document.getElementById('create-class-modal').classList.remove('hidden');
  }

  async loadTeachersForDropdown(selectElement) {
    // Fetch all teachers and admins
    const [usersRes, pendingRes] = await Promise.all([
      supabase
        .from('users')
        .select('id, name, email, role')
        .in('role', ['teacher', 'admin'])
        .order('name'),
      supabase
        .from('pre_registered_accounts')
        .select('id, name, email, role')
        .order('name')
    ]);

    if (usersRes.error) {
      console.error('Error loading teachers:', usersRes.error);
      return;
    }

    // Clear existing options except the first one
    selectElement.innerHTML = '<option value="">-- Select a teacher (or leave empty for yourself) --</option>';

    // Add active teacher/admin options
    const activeTeachers = usersRes.data || [];
    activeTeachers.forEach(teacher => {
      const option = document.createElement('option');
      option.value = teacher.id;
      option.textContent = `${teacher.name || teacher.email}${teacher.role === 'admin' ? ' (Admin)' : ''}`;
      selectElement.appendChild(option);
    });

    // Add pending teacher options (use email prefix to identify them)
    const pendingTeachers = pendingRes.data || [];
    if (pendingTeachers.length > 0) {
      // Add a separator
      const separator = document.createElement('option');
      separator.disabled = true;
      separator.textContent = '── Pending Teachers ──';
      selectElement.appendChild(separator);

      pendingTeachers.forEach(teacher => {
        const option = document.createElement('option');
        // Use 'pending:email' format to identify pending teachers
        option.value = `pending:${teacher.email}`;
        option.textContent = `${teacher.name || teacher.email} (Pending)`;
        selectElement.appendChild(option);
      });
    }
  }

  setupCreateClassForm() {
    const form = document.getElementById('create-class-form');
    if (!form) {
      return;
    }

    form.addEventListener('submit', async (e) => {
      e.preventDefault();

      const className = document.getElementById('class-name').value;
      const yearLevel = document.getElementById('class-year-level').value;
      const teacherSelect = document.getElementById('class-teacher');
      const teacherId = teacherSelect ? teacherSelect.value : null;

      if (!className || className.trim() === '') {
        this.showToast('Please enter a class name', 'error');
        return;
      }

      await this.createClass(className, yearLevel, teacherId || null);
    });
  }

  async createClass(className, yearLevel, teacherId = null) {
    try {
      const user = auth.getCurrentUser();

      if (!user) {
        console.error('No user logged in');
        this.showToast('You must be logged in to create a class', 'error');
        return;
      }

      // Generate unique class code using database function
      const { data: codeData, error: codeError } = await supabase
        .rpc('generate_class_code');

      if (codeError) {
        console.error('Error generating class code:', codeError);
        this.showToast('Failed to generate class code', 'error');
        return;
      }

      const classCode = codeData;

      // Check if assigning to a pending teacher (value starts with 'pending:')
      let assignedTeacherId = user.id;
      let pendingTeacherEmail = null;

      if (teacherId && teacherId.startsWith('pending:')) {
        // Pending teacher - store email and use admin as temporary owner
        pendingTeacherEmail = teacherId.substring(8); // Remove 'pending:' prefix
        assignedTeacherId = user.id; // Admin is temporary owner
      } else if (teacherId) {
        // Regular teacher - use their ID
        assignedTeacherId = teacherId;
      }

      // Create the class
      const { data, error } = await supabase
        .from('classes')
        .insert([{
          class_code: classCode,
          name: className,
          teacher_id: assignedTeacherId,
          year_level: yearLevel || null,
          pending_teacher_email: pendingTeacherEmail
        }])
        .select()
        .single();

      if (error) {
        console.error('Error creating class:', error);
        this.showToast('Failed to create class', 'error');
        return;
      }

      this.classes.push(data);
      document.getElementById('create-class-modal').classList.add('hidden');
      document.getElementById('create-class-form').reset();
      this.renderClassesList();
      this.showToast(`Class created! Code: ${classCode}`, 'success');
    } catch (error) {
      console.error('Unexpected error creating class:', error);
      this.showToast('An unexpected error occurred. Please try again.', 'error');
    }
  }

  showEditClassModal() {
    if (!this.currentClass) {
      this.showToast('No class selected', 'error');
      return;
    }

    // Populate form with current values
    document.getElementById('edit-class-name').value = this.currentClass.name;
    document.getElementById('edit-class-year-level').value = this.currentClass.year_level || '';

    // Show modal
    document.getElementById('edit-class-modal').classList.remove('hidden');
  }

  setupEditClassForm() {
    const form = document.getElementById('edit-class-form');
    if (!form) {
      return;
    }

    form.addEventListener('submit', async (e) => {
      e.preventDefault();

      const className = document.getElementById('edit-class-name').value;
      const yearLevel = document.getElementById('edit-class-year-level').value;

      if (!className || className.trim() === '') {
        this.showToast('Please enter a class name', 'error');
        return;
      }

      await this.updateClass(className, yearLevel);
    });
  }

  async updateClass(className, yearLevel) {
    try {
      if (!this.currentClass) {
        this.showToast('No class selected', 'error');
        return;
      }

      // Update the class
      const { data, error } = await supabase
        .from('classes')
        .update({
          name: className,
          year_level: yearLevel || null
        })
        .eq('id', this.currentClass.id)
        .select()
        .single();

      if (error) {
        console.error('Error updating class:', error);
        this.showToast('Failed to update class', 'error');
        return;
      }

      // Update local data
      const classIndex = this.classes.findIndex(c => c.id === this.currentClass.id);
      if (classIndex !== -1) {
        this.classes[classIndex] = data;
      }
      this.currentClass = data;

      // Update UI
      document.getElementById('class-detail-name').textContent = data.name;
      const yearLevelEl = document.getElementById('class-detail-year-level');
      if (yearLevelEl) {
        yearLevelEl.textContent = data.year_level || '';
      }

      // Close modal and show success
      document.getElementById('edit-class-modal').classList.add('hidden');
      document.getElementById('edit-class-form').reset();
      this.renderClassesList();
      this.showToast('Class updated successfully', 'success');
    } catch (error) {
      console.error('Unexpected error updating class:', error);
      this.showToast('An unexpected error occurred. Please try again.', 'error');
    }
  }

  showArchiveClassModal() {
    if (!this.currentClass) {
      this.showToast('No class selected', 'error');
      return;
    }

    // Populate modal with class name
    document.getElementById('archive-class-name').textContent = this.currentClass.name;

    // Show modal
    document.getElementById('archive-class-modal').classList.remove('hidden');
  }

  async archiveClass() {
    try {
      if (!this.currentClass) {
        this.showToast('No class selected', 'error');
        return;
      }

      const className = this.currentClass.name;

      // Update the class to set archived = true
      const { data, error } = await supabase
        .from('classes')
        .update({
          archived: true
        })
        .eq('id', this.currentClass.id)
        .select()
        .single();

      if (error) {
        console.error('Error archiving class:', error);
        this.showToast('Failed to archive class', 'error');
        return;
      }

      // Go back to classes list
      this.showClassesList();

      // Reload classes to update the view
      await this.loadClasses();

      this.showToast(`Class "${className}" archived successfully`, 'success');
    } catch (error) {
      console.error('Unexpected error archiving class:', error);
      this.showToast('An unexpected error occurred. Please try again.', 'error');
    }
  }

  async unarchiveClass(classId) {
    try {
      // Update the class to set archived = false
      const { data, error } = await supabase
        .from('classes')
        .update({
          archived: false
        })
        .eq('id', classId)
        .select()
        .single();

      if (error) {
        console.error('Error unarchiving class:', error);
        this.showToast('Failed to unarchive class', 'error');
        return;
      }

      // Reload classes to update the view
      await this.loadClasses();

      this.showToast(`Class "${data.name}" unarchived successfully`, 'success');
    } catch (error) {
      console.error('Unexpected error unarchiving class:', error);
      this.showToast('An unexpected error occurred. Please try again.', 'error');
    }
  }

  // ============================================
  // TEACHER: Bulk Student Enrollment
  // ============================================

  showBulkAddStudentsModal() {
    if (!this.currentClass) {
      this.showToast('No class selected', 'error');
      return;
    }

    // Clear previous input
    document.getElementById('bulk-emails').value = '';

    // Load existing pending enrollments
    this.loadPendingEnrollments();

    // Show modal
    document.getElementById('bulk-add-students-modal').classList.remove('hidden');
  }

  async loadPendingEnrollments() {
    const container = document.getElementById('pending-enrollments-list');
    if (!container || !this.currentClass) return;

    container.innerHTML = '<p style="color: var(--text-secondary);">Loading...</p>';

    try {
      // Use direct RPC call to bypass stale connections
      const result = await this.callRpcDirect('get_pending_enrollments', {
        p_class_id: this.currentClass.id
      });
      const data = result.data;

      if (!data || data.length === 0) {
        container.innerHTML = '<p style="color: var(--text-secondary); font-style: italic;">No pending enrollments</p>';
        return;
      }

      // Clear container and build elements safely
      container.innerHTML = '';
      data.forEach(enrollment => {
        const item = document.createElement('div');
        item.className = 'pending-enrollment-item';
        item.style.cssText = 'display: flex; justify-content: space-between; align-items: center; padding: 0.5rem; border-bottom: 1px solid var(--border-color);';

        const emailSpan = document.createElement('span');
        emailSpan.style.fontSize = '0.875rem';
        emailSpan.textContent = enrollment.email;

        const removeBtn = document.createElement('button');
        removeBtn.className = 'btn-text';
        removeBtn.style.cssText = 'color: var(--error-color); font-size: 0.75rem;';
        removeBtn.textContent = 'Remove';
        removeBtn.onclick = () => this.removePendingEnrollment(enrollment.id);

        item.appendChild(emailSpan);
        item.appendChild(removeBtn);
        container.appendChild(item);
      });
    } catch (error) {
      console.error('Unexpected error loading pending enrollments:', error);
      container.innerHTML = '<p style="color: var(--error-color);">An error occurred</p>';
    }
  }

  async submitBulkEmails() {
    if (!this.currentClass) {
      this.showToast('No class selected', 'error');
      return;
    }

    const textarea = document.getElementById('bulk-emails');
    const rawInput = textarea.value.trim();

    if (!rawInput) {
      this.showToast('Please enter at least one email address', 'error');
      return;
    }

    // Parse emails - split by newlines, commas, semicolons, or spaces
    const emails = rawInput
      .split(/[\n,;\s]+/)
      .map(email => email.trim().toLowerCase())
      .filter(email => email && email.includes('@'));

    if (emails.length === 0) {
      this.showToast('No valid email addresses found', 'error');
      return;
    }

    try {
      // Use direct RPC call to bypass stale Supabase client connections
      const { data } = await this.callRpcDirect('add_pending_enrollments', {
        p_class_id: this.currentClass.id,
        p_emails: emails
      });

      if (data.success) {
        // Clear the textarea
        textarea.value = '';

        // Reload pending enrollments list and refresh class roster
        this.loadPendingEnrollments();
        await this.loadClassStudents();
        this.renderClassRoster();

        // Reload classes to update pending count in class cards
        await this.loadClasses();

        // Show success message
        this.showToast(data.message, 'success');
      } else {
        this.showToast(data.message || 'Failed to add students', 'error');
      }
    } catch (error) {
      console.error('Unexpected error adding pending enrollments:', error);
      this.showToast('An unexpected error occurred. Please try again.', 'error');
    }
  }

  async removePendingEnrollment(enrollmentId) {
    try {
      // Use direct RPC call to bypass stale Supabase client connections
      const { data } = await this.callRpcDirect('remove_pending_enrollment', {
        p_enrollment_id: enrollmentId
      });

      if (data.success) {
        // Reload the list in modal and refresh class roster
        this.loadPendingEnrollments();
        await this.loadClassStudents();
        this.renderClassRoster();

        // Reload classes to update pending count in class cards
        await this.loadClasses();

        this.showToast('Email removed', 'success');
      } else {
        this.showToast(data.message || 'Failed to remove enrollment', 'error');
      }
    } catch (error) {
      console.error('Unexpected error removing pending enrollment:', error);
      this.showToast('An unexpected error occurred', 'error');
    }
  }

  // ============================================
  // TEACHER: Student Management (Edit/Remove)
  // ============================================

  showEditStudentModal(studentId, studentName) {
    document.getElementById('edit-student-id').value = studentId;
    document.getElementById('edit-student-name-input').value = studentName;
    document.getElementById('edit-student-modal').classList.remove('hidden');
  }

  setupEditStudentForm() {
    const form = document.getElementById('edit-student-form');
    if (!form) return;

    form.addEventListener('submit', async (e) => {
      e.preventDefault();
      await this.updateStudentName();
    });
  }

  async updateStudentName() {
    const studentId = document.getElementById('edit-student-id').value;
    const newName = document.getElementById('edit-student-name-input').value.trim();

    if (!studentId || !newName) {
      this.showToast('Please enter a valid name', 'error');
      return;
    }

    if (!this.currentClass) {
      this.showToast('No class selected', 'error');
      return;
    }

    try {
      // Use direct RPC call to bypass stale Supabase client connections
      const { data } = await this.callRpcDirect('update_student_name', {
        p_class_id: this.currentClass.id,
        p_student_id: studentId,
        p_new_name: newName
      });

      if (data.success) {
        document.getElementById('edit-student-modal').classList.add('hidden');
        this.showToast('Student name updated', 'success');
        // Reload the roster
        await this.loadClassStudents();
        this.renderClassRoster();
      } else {
        this.showToast(data.message || 'Failed to update student name', 'error');
      }
    } catch (error) {
      console.error('Unexpected error updating student name:', error);
      this.showToast('An unexpected error occurred', 'error');
    }
  }

  showRemoveStudentModal(studentId, studentName) {
    document.getElementById('remove-student-id').value = studentId;
    document.getElementById('remove-student-name').textContent = studentName;
    document.getElementById('remove-student-modal').classList.remove('hidden');
  }

  async removeStudentFromClass() {
    const studentId = document.getElementById('remove-student-id').value;

    if (!studentId) {
      this.showToast('No student selected', 'error');
      return;
    }

    if (!this.currentClass) {
      this.showToast('No class selected', 'error');
      return;
    }

    try {
      // Use direct RPC call to bypass stale Supabase client connections
      const { data } = await this.callRpcDirect('remove_student_from_class', {
        p_class_id: this.currentClass.id,
        p_student_id: studentId
      });

      if (data.success) {
        document.getElementById('remove-student-modal').classList.add('hidden');
        this.showToast(data.message, 'success');
        // Reload the roster
        await this.loadClassStudents();
        this.renderClassRoster();
        // Update the student count in the header
        document.getElementById('class-detail-count').textContent =
          `${this.classStudents.length} student${this.classStudents.length !== 1 ? 's' : ''}`;
      } else {
        this.showToast(data.message || 'Failed to remove student', 'error');
      }
    } catch (error) {
      console.error('Unexpected error removing student:', error);
      this.showToast('An unexpected error occurred', 'error');
    }
  }

  // ============================================
  // TEACHER/ADMIN: Transfer Student Between Classes
  // ============================================

  showTransferStudentModal(studentId, studentName) {
    if (!this.currentClass) {
      this.showToast('No class selected', 'error');
      return;
    }

    document.getElementById('transfer-student-id').value = studentId;
    document.getElementById('transfer-student-name').textContent = studentName;

    const select = document.getElementById('transfer-target-class');
    select.innerHTML = '';

    // Populate the destination class dropdown from already-loaded data
    this.loadClassesForTransfer(select);

    document.getElementById('transfer-student-modal').classList.remove('hidden');
  }

  loadClassesForTransfer(selectElement) {
    const user = auth.getCurrentUser();
    const currentClassId = this.currentClass?.id;

    // this.classes already contains all classes for admin, or teacher's own classes for teacher
    const targetClasses = (this.classes || []).filter(c => c.id !== currentClassId && !c.archived);

    selectElement.innerHTML = '';

    if (targetClasses.length === 0) {
      selectElement.innerHTML = '<option value="">No other classes available</option>';
      return;
    }

    const placeholder = document.createElement('option');
    placeholder.value = '';
    placeholder.textContent = '-- Select a class --';
    selectElement.appendChild(placeholder);

    targetClasses
      .sort((a, b) => a.name.localeCompare(b.name, undefined, { sensitivity: 'base' }))
      .forEach(cls => {
        const option = document.createElement('option');
        option.value = cls.id;
        const teacherLabel = user.role === 'admin' && cls.teacher_name ? ` (${cls.teacher_name})` : '';
        option.textContent = `${cls.name}${teacherLabel}`;
        selectElement.appendChild(option);
      });
  }

  async executeTransferStudent() {
    const studentId = document.getElementById('transfer-student-id').value;
    const targetClassId = document.getElementById('transfer-target-class').value;

    if (!studentId || !targetClassId) {
      this.showToast('Please select a destination class', 'error');
      return;
    }

    if (!this.currentClass) {
      this.showToast('No source class selected', 'error');
      return;
    }

    try {
      const { data } = await this.callRpcDirect('transfer_student_between_classes', {
        p_student_id: studentId,
        p_from_class_id: this.currentClass.id,
        p_to_class_id: targetClassId
      });

      if (data.success) {
        document.getElementById('transfer-student-modal').classList.add('hidden');
        this.showToast(data.message, 'success');
        // Reload the roster
        await this.loadClassStudents();
        this.renderClassRoster();
        document.getElementById('class-detail-count').textContent =
          `${this.classStudents.length} student${this.classStudents.length !== 1 ? 's' : ''}`;
      } else {
        this.showToast(data.message || 'Failed to transfer student', 'error');
      }
    } catch (error) {
      console.error('Unexpected error transferring student:', error);
      this.showToast('An unexpected error occurred', 'error');
    }
  }

  filterClasses() {
    const searchTerm = document.getElementById('class-search')?.value.toLowerCase() || '';

    let filteredClasses = this.classes;

    if (searchTerm) {
      filteredClasses = filteredClasses.filter(cls =>
        cls.name.toLowerCase().includes(searchTerm) ||
        cls.class_code.toLowerCase().includes(searchTerm) ||
        (cls.year_level && cls.year_level.toLowerCase().includes(searchTerm)) ||
        (cls.teacher_name && cls.teacher_name.toLowerCase().includes(searchTerm))
      );
    }

    this.renderClassesList(filteredClasses);
  }

  renderClassesList(classesToRender = null) {
    const container = document.getElementById('classes-list');
    if (!container) return;

    const classes = classesToRender || this.classes;
    const isAdmin = auth.getCurrentUser()?.role === 'admin';

    if (this.classes.length === 0) {
      container.innerHTML = `
        <div style="text-align: center; padding: 4rem; color: var(--text-secondary);">
          <p style="font-size: 1.125rem; margin-bottom: 1rem;">No classes yet</p>
          <p>${isAdmin ? 'No classes have been created by any teachers' : 'Create your first class to get started'}</p>
        </div>
      `;
      return;
    }

    if (classes.length === 0) {
      container.innerHTML = `
        <div style="text-align: center; padding: 4rem; color: var(--text-secondary);">
          <p style="font-size: 1.125rem; margin-bottom: 1rem;">No classes found</p>
          <p>Try a different search term</p>
        </div>
      `;
      return;
    }

    // Sort classes alphabetically by name
    const sortedClasses = [...classes].sort((a, b) =>
      a.name.localeCompare(b.name, undefined, { sensitivity: 'base' })
    );

    const html = sortedClasses.map(cls => {
      const memberCount = cls.student_count || 0;
      const pendingCount = cls.pending_count || 0;
      const isArchived = cls.archived;
      const teacherLabel = isAdmin && cls.teacher_name ? `<p style="color: var(--text-secondary); font-size: 0.8125rem;">Teacher: ${cls.teacher_name}</p>` : '';

      // Build student count text with pending indicator
      let studentCountText = `${memberCount} student${memberCount !== 1 ? 's' : ''}`;
      if (pendingCount > 0) {
        studentCountText += ` <span class="roster-pending-badge">${pendingCount} pending</span>`;
      }

      if (isArchived) {
        // Archived class card with unarchive button
        return `
          <div class="class-card" style="opacity: 0.7; position: relative;">
            <div class="class-card-header">
              <div>
                <h3>${cls.name} <span style="background-color: var(--text-secondary); color: white; padding: 0.125rem 0.5rem; border-radius: 4px; font-size: 0.75rem; font-weight: normal;">ARCHIVED</span></h3>
                ${cls.year_level ? `<p style="color: var(--text-secondary); font-size: 0.875rem;">${cls.year_level}</p>` : ''}
                ${teacherLabel}
              </div>
              <span class="class-code-badge">${cls.class_code}</span>
            </div>
            <div class="class-card-meta">
              <span>${studentCountText}</span>
              <span>Created ${new Date(cls.created_at).toLocaleDateString('en-GB')}</span>
            </div>
            <div style="margin-top: 0.75rem; padding-top: 0.75rem; border-top: 1px solid var(--border);">
              <button class="btn btn-secondary btn-sm" onclick="event.stopPropagation(); app.unarchiveClass('${cls.id}')" style="width: 100%;">Unarchive Class</button>
            </div>
          </div>
        `;
      } else {
        // Active class card (clickable)
        return `
          <div class="class-card" onclick="app.viewClass('${cls.id}')">
            <div class="class-card-header">
              <div>
                <h3>${cls.name}</h3>
                ${cls.year_level ? `<p style="color: var(--text-secondary); font-size: 0.875rem;">${cls.year_level}</p>` : ''}
                ${teacherLabel}
              </div>
              <span class="class-code-badge">${cls.class_code}</span>
            </div>
            <div class="class-card-meta">
              <span>${studentCountText}</span>
              <span>Created ${new Date(cls.created_at).toLocaleDateString('en-GB')}</span>
            </div>
          </div>
        `;
      }
    }).join('');

    container.innerHTML = html;
  }

  async viewClass(classId) {
    this.currentClass = this.classes.find(c => c.id === classId);
    if (!this.currentClass) return;

    // Clear stale data from previous class
    this.classStudents = [];

    // Clear any rendered tab content from previous class
    const timelineContainer = document.getElementById('class-timeline');
    if (timelineContainer) timelineContainer.innerHTML = '';
    const rosterContainer = document.getElementById('class-roster');
    if (rosterContainer) rosterContainer.innerHTML = '';
    const progressContainer = document.getElementById('progress-heatmap');
    if (progressContainer) progressContainer.innerHTML = '';

    // Close any open modals
    const modal = document.getElementById('student-detail-modal');
    if (modal) modal.classList.add('hidden');

    // Clear student search state
    const studentSearch = document.getElementById('student-search');
    if (studentSearch) studentSearch.value = '';
    const studentResults = document.getElementById('student-search-results');
    if (studentResults) {
      studentResults.classList.add('hidden');
      studentResults.innerHTML = '';
    }
    this.allTeacherStudents = null;

    // Hide classes list, show class detail
    // Push a history entry so the phone back button returns to the classes list
    // instead of whatever view was in the initial history placeholder
    history.pushState({ cadenceView: 'classes' }, '', window.location.pathname + window.location.search);
    document.getElementById('classes-list').classList.add('hidden');
    document.getElementById('class-detail-view').classList.remove('hidden');

    // Update header
    const currentUser = auth.getCurrentUser();
    const isAdmin = currentUser?.role === 'admin';
    const isOwnClass = this.currentClass.teacher_id === currentUser?.id;

    document.getElementById('class-detail-name').textContent = this.currentClass.name;
    const yearLevelEl = document.getElementById('class-detail-year-level');
    if (yearLevelEl) {
      const teacherInfo = isAdmin && this.currentClass.teacher_name ? ` — Teacher: ${this.currentClass.teacher_name}` : '';
      yearLevelEl.textContent = (this.currentClass.year_level || '') + teacherInfo;
    }
    document.getElementById('class-detail-code').textContent = this.currentClass.class_code;

    // Show/hide class management buttons based on ownership
    // Admins can bulk add to any class but shouldn't edit/archive other teachers' classes
    document.getElementById('edit-class-btn')?.classList.toggle('hidden', isAdmin && !isOwnClass);
    document.getElementById('archive-class-btn')?.classList.toggle('hidden', isAdmin && !isOwnClass);
    document.getElementById('export-class-data-btn')?.classList.toggle('hidden', isAdmin && !isOwnClass);

    // Load class data
    await this.loadClassStudents();
    this.renderClassRoster();
  }

  showClassesList() {
    // Close any open modals
    const modal = document.getElementById('student-detail-modal');
    if (modal) modal.classList.add('hidden');

    document.getElementById('class-detail-view').classList.add('hidden');
    document.getElementById('classes-list').classList.remove('hidden');
    // Clear student search state
    const studentSearch = document.getElementById('student-search');
    if (studentSearch) studentSearch.value = '';
    const studentResults = document.getElementById('student-search-results');
    if (studentResults) {
      studentResults.classList.add('hidden');
      studentResults.innerHTML = '';
    }
    this.allTeacherStudents = null;
    this.currentClass = null;
    this.classStudents = [];
  }

  switchClassTab(tabName) {
    // Close any open modals
    const modal = document.getElementById('student-detail-modal');
    if (modal) modal.classList.add('hidden');

    // Update tab buttons
    document.querySelectorAll('.class-tab').forEach(tab => {
      tab.classList.toggle('active', tab.dataset.tab === tabName);
    });

    // Update tab panes
    document.querySelectorAll('.tab-pane').forEach(pane => {
      pane.classList.add('hidden');
    });

    if (tabName === 'roster') {
      document.getElementById('roster-tab').classList.remove('hidden');
      document.getElementById('roster-tab').classList.add('active');
      this.renderClassRoster();
    } else if (tabName === 'progress') {
      document.getElementById('progress-tab').classList.remove('hidden');
      document.getElementById('progress-tab').classList.add('active');
      this.renderProgressHeatmap();
    } else if (tabName === 'timeline') {
      document.getElementById('timeline-tab').classList.remove('hidden');
      document.getElementById('timeline-tab').classList.add('active');
      this.renderClassTimeline();
    }
  }

  // ============================================
  // TEACHER: Student Monitoring & Progress Views
  // ============================================

  async loadClassStudents() {
    if (!this.currentClass) return;

    try {
      // Load both active students and pending enrollments in parallel using direct RPC calls
      const [studentsResult, pendingResult] = await Promise.all([
        this.callRpcDirect('get_class_students', { p_class_id: this.currentClass.id })
          .catch(err => ({ data: null, error: err })),
        this.callRpcDirect('get_pending_enrollments', { p_class_id: this.currentClass.id })
          .catch(err => ({ data: null, error: err }))
      ]);

      if (studentsResult.error) {
        console.error('Error loading class students:', studentsResult.error);
        this.classStudents = [];
      } else {
        this.classStudents = studentsResult.data || [];
      }

      if (pendingResult.error) {
        console.error('Error loading pending enrollments:', pendingResult.error);
        this.pendingEnrollments = [];
      } else {
        this.pendingEnrollments = pendingResult.data || [];
      }

      // Update student count (including pending)
      const activeCount = this.classStudents.length;
      const pendingCount = this.pendingEnrollments.length;
      const totalCount = activeCount + pendingCount;

      let countText = `${activeCount} student${activeCount !== 1 ? 's' : ''}`;
      if (pendingCount > 0) {
        countText += ` (${pendingCount} pending)`;
      }
      document.getElementById('class-detail-count').textContent = countText;
    } catch (err) {
      console.error('Exception in loadClassStudents:', err);
      this.classStudents = [];
      this.pendingEnrollments = [];
      document.getElementById('class-detail-count').textContent = '0 students';
    }
  }

  renderClassRoster() {
    // Close any open modals to prevent showing students from other classes
    const modal = document.getElementById('student-detail-modal');
    if (modal) modal.classList.add('hidden');

    const container = document.getElementById('class-roster');
    if (!container) return;

    const pendingEnrollments = this.pendingEnrollments || [];
    const hasStudents = this.classStudents.length > 0 || pendingEnrollments.length > 0;

    if (!hasStudents) {
      container.innerHTML = `
        <div style="text-align: center; padding: 3rem; color: var(--text-secondary);">
          <p style="font-size: 1.125rem; margin-bottom: 0.5rem;">No students yet</p>
          <p>Share your class code <strong>${this.currentClass.class_code}</strong> with students to join</p>
        </div>
      `;
      return;
    }

    // Render active students
    const activeStudentsHtml = this.classStudents.map(member => {
      const student = member.users;
      const progress = member.student_progress || [];
      const instruments = progress.map(p => {
        const inst = this.instruments.find(i => i.id === p.instrument_id);
        return inst ? inst.icon : '';
      }).join(' ');

      return `
        <div class="roster-item">
          <div class="roster-student-info" onclick="app.viewStudentDetail('${student.id}')" style="cursor: pointer; flex: 1;">
            <div class="roster-student-name">${student.name}</div>
            <div class="roster-student-meta">
              ${progress.length} instrument${progress.length !== 1 ? 's' : ''}
              • Joined ${new Date(member.joined_at).toLocaleDateString()}
            </div>
          </div>
          <div class="roster-student-instruments">${instruments}</div>
          <div class="roster-actions" style="display: flex; gap: 0.5rem; margin-left: 1rem;">
            <button class="btn-text" style="font-size: 0.75rem;" onclick="event.stopPropagation(); app.showEditStudentModal('${student.id}', '${student.name.replace(/'/g, "\\'")}')">Edit</button>
            <button class="btn-text" style="font-size: 0.75rem; color: var(--primary-color);" onclick="event.stopPropagation(); app.showTransferStudentModal('${student.id}', '${student.name.replace(/'/g, "\\'")}')">Transfer</button>
            <button class="btn-text" style="font-size: 0.75rem; color: var(--error-color);" onclick="event.stopPropagation(); app.showRemoveStudentModal('${student.id}', '${student.name.replace(/'/g, "\\'")}')">Remove</button>
          </div>
        </div>
      `;
    }).join('');

    // Render pending students
    const pendingStudentsHtml = pendingEnrollments.map(enrollment => {
      // Extract display name from email (part before @)
      const displayName = enrollment.email.split('@')[0];

      return `
        <div class="roster-item roster-item-pending">
          <div class="roster-student-info" style="flex: 1;">
            <div class="roster-student-name">
              ${this.escapeHtml(displayName)}
              <span class="roster-pending-badge">Pending</span>
            </div>
            <div class="roster-student-meta">
              ${this.escapeHtml(enrollment.email)} • Added ${new Date(enrollment.created_at).toLocaleDateString()}
            </div>
          </div>
          <div class="roster-student-instruments" style="color: var(--text-secondary); font-size: 0.875rem;">Awaiting login</div>
          <div class="roster-actions" style="display: flex; gap: 0.5rem; margin-left: 1rem;">
            <button class="btn-text" style="font-size: 0.75rem; color: var(--error-color);" onclick="event.stopPropagation(); app.removePendingEnrollment('${enrollment.id}')">Remove</button>
          </div>
        </div>
      `;
    }).join('');

    container.innerHTML = activeStudentsHtml + pendingStudentsHtml;
  }

  async filterStudents() {
    const searchTerm = document.getElementById('student-search')?.value.toLowerCase() || '';
    const resultsContainer = document.getElementById('student-search-results');
    const classesListContainer = document.getElementById('classes-list');
    if (!resultsContainer || !classesListContainer) return;

    // When search is empty, hide results and show classes list
    if (!searchTerm) {
      resultsContainer.classList.add('hidden');
      resultsContainer.innerHTML = '';
      classesListContainer.classList.remove('hidden');
      this.allTeacherStudents = null;
      return;
    }

    // Lazy-load all students on first search
    if (!this.allTeacherStudents) {
      try {
        const result = await this.callRpcDirect('search_teacher_students', {});
        this.allTeacherStudents = result.data || [];
      } catch (err) {
        // Fallback to the simpler RPC if the new one isn't deployed yet
        console.warn('search_teacher_students not available, falling back:', err);
        try {
          const fallback = await this.callRpcDirect('get_all_teacher_students', {});
          this.allTeacherStudents = (fallback.data || []).map(s => ({
            ...s,
            class_id: null,
            class_name: null,
            joined_at: null,
            is_pending: false
          }));
        } catch (fallbackErr) {
          console.error('Error loading students for search:', fallbackErr);
          this.allTeacherStudents = [];
        }
      }
    }

    // Filter by search term
    const filtered = this.allTeacherStudents.filter(s =>
      s.name.toLowerCase().includes(searchTerm) ||
      (s.email && s.email.toLowerCase().includes(searchTerm))
    );

    // Hide classes list and show results
    classesListContainer.classList.add('hidden');
    resultsContainer.classList.remove('hidden');

    if (filtered.length === 0) {
      resultsContainer.innerHTML = `
        <div style="text-align: center; padding: 3rem; color: var(--text-secondary);">
          <p style="font-size: 1.125rem; margin-bottom: 0.5rem;">No students found</p>
          <p>Try a different search term</p>
        </div>
      `;
      return;
    }

    // Group results by student (a student may appear in multiple classes)
    // Active students keyed by user_id, pending keyed by email
    const studentMap = new Map();
    const pendingMap = new Map();

    filtered.forEach(row => {
      if (row.is_pending) {
        const key = row.email.toLowerCase();
        if (!pendingMap.has(key)) {
          pendingMap.set(key, {
            name: row.name,
            email: row.email,
            classes: []
          });
        }
        if (row.class_name) {
          pendingMap.get(key).classes.push({
            id: row.class_id,
            name: row.class_name
          });
        }
      } else {
        if (!studentMap.has(row.user_id)) {
          studentMap.set(row.user_id, {
            user_id: row.user_id,
            name: row.name,
            email: row.email,
            classes: []
          });
        }
        if (row.class_name) {
          studentMap.get(row.user_id).classes.push({
            id: row.class_id,
            name: row.class_name,
            joined_at: row.joined_at
          });
        }
      }
    });

    const activeStudents = Array.from(studentMap.values()).sort((a, b) =>
      a.name.localeCompare(b.name, undefined, { sensitivity: 'base' })
    );

    const pendingStudents = Array.from(pendingMap.values()).sort((a, b) =>
      a.name.localeCompare(b.name, undefined, { sensitivity: 'base' })
    );

    const activeHtml = activeStudents.map(student => {
      const firstClassId = student.classes[0]?.id || '';
      const classBadges = student.classes.map(c =>
        `<span class="class-code-badge" style="font-size: 0.75rem; cursor: pointer;" onclick="event.stopPropagation(); app.viewClass('${c.id}')">${this.escapeHtml(c.name)}</span>`
      ).join(' ');

      return `
        <div class="roster-item" onclick="app.viewStudentFromSearch('${student.user_id}', '${firstClassId}')" style="cursor: pointer;">
          <div class="roster-student-info" style="flex: 1;">
            <div class="roster-student-name">${this.escapeHtml(student.name)}</div>
            <div class="roster-student-meta">
              ${this.escapeHtml(student.email || '')}
            </div>
          </div>
          <div style="display: flex; gap: 0.375rem; flex-wrap: wrap; align-items: center;">
            ${classBadges}
            <span style="font-size: 0.8rem; color: var(--primary-color); white-space: nowrap;">View progress →</span>
          </div>
        </div>
      `;
    }).join('');

    const pendingHtml = pendingStudents.map(student => {
      const classBadges = student.classes.map(c =>
        `<span class="class-code-badge" style="font-size: 0.75rem; cursor: pointer;" onclick="event.stopPropagation(); app.viewClass('${c.id}')">${this.escapeHtml(c.name)}</span>`
      ).join(' ');

      return `
        <div class="roster-item roster-item-pending">
          <div class="roster-student-info" style="flex: 1;">
            <div class="roster-student-name">
              ${this.escapeHtml(student.name)}
              <span class="roster-pending-badge">Pending</span>
            </div>
            <div class="roster-student-meta">
              ${this.escapeHtml(student.email)}
            </div>
          </div>
          <div style="display: flex; gap: 0.375rem; flex-wrap: wrap; align-items: center;">
            ${classBadges}
          </div>
        </div>
      `;
    }).join('');

    const totalCount = activeStudents.length + pendingStudents.length;

    resultsContainer.innerHTML = `
      <p style="color: var(--text-secondary); margin-bottom: 0.75rem; font-size: 0.875rem;">
        ${totalCount} student${totalCount !== 1 ? 's' : ''} found${pendingStudents.length > 0 ? ` (${pendingStudents.length} pending)` : ''}
      </p>
      ${activeHtml}${pendingHtml}
    `;
  }

  async renderProgressHeatmap() {
    // Close any open modals to prevent showing students from other classes
    const modal = document.getElementById('student-detail-modal');
    if (modal) modal.classList.add('hidden');

    const container = document.getElementById('progress-heatmap');
    if (!container || this.classStudents.length === 0) {
      container.innerHTML = '<p style="color: var(--text-secondary);">No student data available</p>';
      return;
    }

    // Create heatmap table
    let html = '<table class="heatmap-table"><thead><tr><th>Student</th>';

    // Add instrument columns
    this.instruments.forEach(inst => {
      html += `<th>${inst.icon} ${inst.name}</th>`;
    });
    html += '</tr></thead><tbody>';

    // Add student rows
    this.classStudents.forEach(member => {
      const student = member.users;
      html += `<tr><td style="cursor: pointer;" onclick="app.viewStudentDetail('${student.id}')">${student.name}</td>`;

      this.instruments.forEach(inst => {
        const progress = member.student_progress?.find(p => p.instrument_id === inst.id);
        if (progress) {
          const level = progress.current_level;
          html += `<td class="heatmap-cell level-${level}" style="cursor: pointer;" onclick="app.viewStudentDetail('${student.id}')">Level ${level}</td>`;
        } else {
          html += `<td class="heatmap-cell">-</td>`;
        }
      });

      html += '</tr>';
    });

    html += '</tbody></table>';
    container.innerHTML = html;
  }

  async renderClassTimeline() {
    // Close any open modals to prevent showing students from other classes
    const modal = document.getElementById('student-detail-modal');
    if (modal) modal.classList.add('hidden');

    const container = document.getElementById('class-timeline');
    if (!container) return;

    if (!this.currentClass) {
      container.innerHTML = '<p style="color: var(--text-secondary);">No class selected</p>';
      return;
    }

    // Use direct RPC call to bypass stale connections and RLS
    let data;
    try {
      const result = await this.callRpcDirect('get_class_timeline', {
        p_class_id: this.currentClass.id
      });
      data = result.data;
    } catch (error) {
      console.error('Error loading timeline:', error);
      container.innerHTML = '<p style="color: var(--text-secondary);">Error loading timeline</p>';
      return;
    }

    if (!data || data.length === 0) {
      container.innerHTML = '<p style="color: var(--text-secondary);">No recent activity</p>';
      return;
    }

    const html = data.map(item => {
      const timeAgo = this.getTimeAgo(item.date_started);
      const status = item.status === 'mastered' ? 'mastered' : 'started learning';

      return `
        <div class="timeline-item">
          <div class="timeline-header">
            <span class="timeline-student">${item.student_name}</span>
            <span class="timeline-time">${timeAgo}</span>
          </div>
          <div class="timeline-content">
            ${status} <span class="timeline-highlight">${item.song_title}</span>
            by ${item.song_artist} on ${item.instrument_icon} ${item.instrument_name}
          </div>
        </div>
      `;
    }).join('');

    container.innerHTML = html;
  }

  async viewStudentDetail(studentId, studentName) {
    // Find student info first from already-loaded data
    let student = this.classStudents.find(m => m.user_id === studentId)?.users;
    // Fallback: look up from cross-class search results cache
    if (!student && this.allTeacherStudents) {
      const match = this.allTeacherStudents.find(s => s.user_id === studentId);
      if (match) {
        student = { id: match.user_id, name: match.name, email: match.email };
      }
    }
    // Fallback: use the provided name (e.g. from song details modal)
    if (!student && studentName) {
      student = { id: studentId, name: studentName };
    }
    if (!student) return;

    // Show modal immediately with loading state
    document.getElementById('student-detail-name').textContent = student.name;
    document.getElementById('student-detail-content').innerHTML = '<p style="color: var(--text-secondary); text-align: center; padding: 2rem;">Loading student data...</p>';
    document.getElementById('student-detail-modal').classList.remove('hidden');

    // Use direct RPC call to bypass stale connections and RLS
    let data;
    try {
      const result = await this.callRpcDirect('get_student_detail', {
        p_student_id: studentId
      });
      data = result.data;
    } catch (error) {
      console.error('Error loading student detail:', error);
    }

    let progressData = [];
    let songsData = [];

    // Handle both RPC return formats:
    // - Current (migration 060): flat array of student_songs
    // - Legacy: { progress: [...], songs: [...] }
    if (Array.isArray(data)) {
      songsData = data;
    } else if (data) {
      progressData = data.progress || [];
      songsData = data.songs || [];
    }

    // Fallback: if RPC returned no progress, use data already loaded from classStudents
    const member = this.classStudents.find(m => m.user_id === studentId);
    if (progressData.length === 0) {
      const memberProgress = member?.student_progress || [];
      if (memberProgress.length > 0) {
        progressData = memberProgress.map(p => {
          const inst = this.instruments.find(i => i.id === p.instrument_id);
          return {
            instrument_id: p.instrument_id,
            current_level: p.current_level,
            current_branch: p.current_branch,
            instruments: inst ? { id: inst.id, name: inst.name, icon: inst.icon } : { id: p.instrument_id, name: 'Unknown', icon: '🎵' }
          };
        });
      }
    }

    // Fallback: if RPC returned no songs, use get_class_timeline (known working SECURITY DEFINER RPC)
    if (songsData.length === 0 && this.currentClass) {
      try {
        const { data: timelineData } = await this.callRpcDirect('get_class_timeline', {
          p_class_id: this.currentClass.id
        });
        if (timelineData && timelineData.length > 0) {
          // Filter for this student and reshape to match expected song format
          songsData = timelineData
            .filter(t => t.user_id === studentId)
            .map(t => ({
              id: t.id,
              song_id: t.song_id,
              instrument_id: t.instrument_id,
              status: t.status,
              date_started: t.date_started,
              date_completed: t.date_completed,
              songs: { id: t.song_id, title: t.song_title, artist: t.song_artist }
            }));
        }
      } catch (err) {
        console.error('Timeline songs fallback failed:', err);
      }
    }

    // Fallback: derive progressData from songsData when student_progress isn't available
    // (migration 060 RPC returns flat song array without separate progress data)
    if (progressData.length === 0 && songsData.length > 0) {
      const instrumentMap = {};
      songsData.forEach(s => {
        if (!instrumentMap[s.instrument_id]) {
          const inst = s.instruments || this.instruments?.find(i => i.id === s.instrument_id) || { id: s.instrument_id, name: 'Unknown', icon: '🎵' };
          instrumentMap[s.instrument_id] = {
            instrument_id: s.instrument_id,
            current_level: null,
            current_branch: null,
            instruments: { id: inst.id, name: inst.name, icon: inst.icon }
          };
        }
      });
      progressData = Object.values(instrumentMap);
    }

    // Build student detail modal content
    let html = '';

    if (progressData.length === 0) {
      html = '<p style="color: var(--text-secondary);">This student hasn\'t started any instruments yet.</p>';
    } else {
      html = '<div class="student-instruments-grid">';

      progressData.forEach(progress => {
        const inst = progress.instruments || { icon: '🎵', name: 'Unknown' };
        const studentSongs = songsData.filter(s => s.instrument_id === progress.instrument_id);
        const learning = studentSongs.filter(s => s.status === 'learning');
        const mastered = studentSongs.filter(s => s.status === 'mastered');

        html += `
          <div class="student-instrument-card">
            <div class="student-instrument-header">
              ${inst.icon} ${inst.name}
            </div>
            ${progress.current_level != null ? `<div class="student-progress-info">
              Level ${progress.current_level}${progress.current_branch ? ` - ${progress.current_branch}` : ''}
            </div>` : ''}
            <div class="student-progress-info">
              ${learning.length} learning • ${mastered.length} mastered
            </div>
            ${learning.length > 0 ? `
              <div class="student-songs-list">
                <strong style="font-size: 0.75rem; text-transform: uppercase; letter-spacing: 0.05em; color: var(--text-secondary);">Currently Learning:</strong>
                ${learning.map(s => `
                  <div class="student-song-item clickable-song" data-song-id="${s.song_id}" data-instrument-id="${s.instrument_id}" style="color: var(--primary-color);">
                    ${s.songs?.title || 'Unknown'} - ${s.songs?.artist || 'Unknown'}
                  </div>
                `).join('')}
              </div>
            ` : ''}
            ${mastered.length > 0 ? `
              <div class="student-songs-list" style="margin-top: ${learning.length > 0 ? '0.75rem' : '0'};">
                <strong style="font-size: 0.75rem; text-transform: uppercase; letter-spacing: 0.05em; color: var(--text-secondary);">Mastered:</strong>
                ${mastered.map(s => `
                  <div class="student-song-item clickable-song" data-song-id="${s.song_id}" data-instrument-id="${s.instrument_id}">${s.songs?.title || 'Unknown'} - ${s.songs?.artist || 'Unknown'}</div>
                `).join('')}
              </div>
            ` : ''}
          </div>
        `;
      });

      html += '</div>';
    }

    // Update modal content (modal is already visible from loading state above)
    document.getElementById('student-detail-content').innerHTML = html;

    // Attach click handlers to clickable song items
    document.querySelectorAll('#student-detail-content .clickable-song').forEach(el => {
      el.addEventListener('click', () => {
        const songId = el.dataset.songId;
        const instrumentId = el.dataset.instrumentId;
        if (songId) {
          this.openSongFromStudentDetail(songId, instrumentId);
        }
      });
    });

    // Add preview button if it doesn't exist
    let previewBtn = document.getElementById('preview-student-btn');
    if (!previewBtn) {
      previewBtn = document.createElement('button');
      previewBtn.id = 'preview-student-btn';
      previewBtn.className = 'btn btn-primary';
      previewBtn.textContent = 'Preview Student View';
      previewBtn.style.marginTop = '1rem';

      const modalBody = document.querySelector('#student-detail-modal .modal-body');
      if (modalBody) {
        modalBody.appendChild(previewBtn);
      }

      // Add event listener
      previewBtn.addEventListener('click', () => {
        this.enterStudentPreview(studentId, student.name);
      });
    } else {
      // Update the click handler with current student info
      const newPreviewBtn = previewBtn.cloneNode(true);
      previewBtn.parentNode.replaceChild(newPreviewBtn, previewBtn);
      newPreviewBtn.addEventListener('click', () => {
        this.enterStudentPreview(studentId, student.name);
      });
    }
  }

  async viewStudentFromSearch(studentId, classId) {
    if (classId) {
      await this.viewClass(classId);
    }
    await this.viewStudentDetail(studentId);
  }

  async openSongFromStudentDetail(songId, instrumentId) {
    // Ensure the song is in this.songs so showSongResourcesModal can find it
    if (!this.songs || !this.songs.find(s => s.id === songId)) {
      // Fetch the song directly from the database
      const { data, error } = await this.callSelectDirect(
        'songs',
        '*,instruments(id,name,icon),song_ratings(assessed_level,instrument_id,user_id)',
        { eq: { id: songId } }
      );

      if (error || !data || data.length === 0) {
        this.showToast('Could not load song details', 'error');
        return;
      }

      // Initialize songs array if needed and add the fetched song
      if (!this.songs) this.songs = [];
      this.songs.push(data[0]);
    }

    // Ensure instruments are loaded (needed by the resources modal filter)
    if (!this.instruments || this.instruments.length === 0) {
      await this.loadInstruments();
    }

    await this.showSongResourcesModal(songId, instrumentId);
  }

  async enterStudentPreview(studentId, studentName) {
    // Store current state AND teacher's data
    this.previewMode.active = true;
    this.previewMode.studentId = studentId;
    this.previewMode.studentName = studentName;
    this.previewMode.originalUser = auth.user;
    this.previewMode.originalView = this.currentView;

    // Save teacher's current data to restore later
    this.previewMode.originalStudentProgress = this.studentProgress ? [...this.studentProgress] : [];
    this.previewMode.originalInstruments = this.instruments ? [...this.instruments] : [];
    this.previewMode.originalCurrentInstrument = this.currentInstrument;
    this.previewMode.originalStudentSongs = this.studentSongs ? [...this.studentSongs] : [];
    this.previewMode.originalLevels = this.levels ? [...this.levels] : [];

    // Close the student detail modal
    document.getElementById('student-detail-modal').classList.add('hidden');

    // Show preview banner
    const banner = document.getElementById('preview-banner');
    if (banner) {
      banner.classList.remove('hidden');
      document.getElementById('preview-student-name').textContent = studentName;
    }

    // Hide teacher tabs and show student tabs
    document.querySelectorAll('.teacher-tab').forEach(tab => tab.classList.add('hidden'));
    document.querySelectorAll('.student-tab').forEach(tab => tab.classList.remove('hidden'));

    // Hide only export and join class buttons in preview mode
    // Keep instrument and song controls visible so teacher can make changes
    const actionButtons = [
      'export-progress-btn',
      'join-class-toggle-btn'
    ];
    actionButtons.forEach(btnId => {
      const btn = document.getElementById(btnId);
      if (btn) btn.classList.add('hidden');
    });

    // Clear data before loading so pathway view shows loading state (not stale teacher data)
    this.studentProgress = [];
    this.instruments = [];
    this.currentInstrument = null;
    this.levels = [];
    this.studentSongs = [];
    this.previewMode.dataLoaded = false;

    // Switch to pathway view immediately so user sees loading state
    this.switchView('pathway');

    // Load student's data
    try {
      await this.loadStudentPreviewData(studentId);
    } catch (error) {
      console.error('Error entering student preview:', error);
      this.showToast('Failed to load student data. Please try again.', 'error');
    }
    this.previewMode.dataLoaded = true;

    // Re-render pathway and instrument tabs now that data is loaded
    this.updatePathwayInstrument();
    this.renderPathway();
  }

  async loadStudentPreviewData(studentId) {
    // Use direct RPC call to bypass stale connections and RLS
    let data;
    try {
      const result = await this.callRpcDirect('get_student_detail', {
        p_student_id: studentId
      });
      data = result.data;
    } catch (error) {
      console.error('Error loading student preview data:', error);
    }

    let progressData = [];
    let songsData = [];

    // Handle both RPC return formats:
    // - Current (migration 060): flat array of student_songs
    // - Legacy: { progress: [...], songs: [...] }
    if (Array.isArray(data)) {
      songsData = data;
    } else if (data) {
      progressData = data.progress || [];
      songsData = data.songs || [];
    }

    // Fallback: if RPC returned no progress, use data already loaded from classStudents
    // Use saved original instruments since this.instruments was cleared for preview mode
    const savedInstruments = this.previewMode.originalInstruments || [];
    if (progressData.length === 0) {
      const member = this.classStudents.find(m => m.user_id === studentId);
      const memberProgress = member?.student_progress || [];
      if (memberProgress.length > 0) {
        progressData = memberProgress.map(p => {
          const inst = savedInstruments.find(i => i.id === p.instrument_id);
          return {
            instrument_id: p.instrument_id,
            current_level: p.current_level,
            current_branch: p.current_branch,
            instruments: inst ? { id: inst.id, name: inst.name, icon: inst.icon } : { id: p.instrument_id, name: 'Unknown', icon: '🎵' }
          };
        });
      }
    }

    // Fallback: if RPC returned no songs, try get_class_timeline
    if (songsData.length === 0 && this.currentClass) {
      try {
        const { data: timelineData } = await this.callRpcDirect('get_class_timeline', {
          p_class_id: this.currentClass.id
        });
        if (timelineData && timelineData.length > 0) {
          songsData = timelineData
            .filter(t => t.user_id === studentId)
            .map(t => ({
              id: t.id,
              song_id: t.song_id,
              instrument_id: t.instrument_id,
              status: t.status,
              date_started: t.date_started,
              date_completed: t.date_completed,
              songs: { id: t.song_id, title: t.song_title, artist: t.song_artist }
            }));
        }
      } catch (err) {
        console.error('Timeline songs fallback failed:', err);
      }
    }

    // Fallback: derive progressData from songsData when student_progress isn't available
    // (migration 060 RPC returns flat song array without separate progress data)
    if (progressData.length === 0 && songsData.length > 0) {
      const instrumentMap = {};
      songsData.forEach(s => {
        if (!instrumentMap[s.instrument_id]) {
          const inst = s.instruments || savedInstruments.find(i => i.id === s.instrument_id) || { id: s.instrument_id, name: 'Unknown', icon: '🎵' };
          instrumentMap[s.instrument_id] = {
            instrument_id: s.instrument_id,
            current_level: null,
            current_branch: null,
            instruments: { id: inst.id, name: inst.name, icon: inst.icon }
          };
        }
      });
      progressData = Object.values(instrumentMap);
    }

    this.studentProgress = progressData;

    // Load ALL available instruments so teacher can assign new ones to the student.
    // (Without this, this.instruments would only contain the student's current instruments,
    // causing showInstrumentSelection() to always report "already tracking all instruments".)
    await this.loadInstruments();

    // Set first instrument as current
    if (progressData.length > 0) {
      this.currentInstrument = progressData[0].instrument_id;

      // Load levels for the student's instrument
      await this.loadLevels(this.currentInstrument);
      await this.loadSongs();
    } else {
      this.currentInstrument = null;
    }

    this.studentSongs = songsData || [];
  }

  async exitStudentPreview() {
    // Save the original view before resetting
    const originalView = this.previewMode.originalView;

    // Restore teacher's original data
    this.studentProgress = this.previewMode.originalStudentProgress || [];
    this.instruments = this.previewMode.originalInstruments || [];
    this.currentInstrument = this.previewMode.originalCurrentInstrument;
    this.studentSongs = this.previewMode.originalStudentSongs || [];
    this.levels = this.previewMode.originalLevels || [];

    // Reset preview mode FIRST (before switchView)
    this.previewMode.active = false;
    this.previewMode.studentId = null;
    this.previewMode.studentName = null;
    this.previewMode.originalUser = null;
    this.previewMode.originalView = null;
    this.previewMode.originalStudentProgress = null;
    this.previewMode.originalInstruments = null;
    this.previewMode.originalCurrentInstrument = null;
    this.previewMode.originalStudentSongs = null;
    this.previewMode.originalLevels = null;
    this.previewMode.dataLoaded = false;

    // Hide preview banner
    const banner = document.getElementById('preview-banner');
    if (banner) {
      banner.classList.add('hidden');
    }

    // Reload teacher's classes to ensure fresh data
    const user = auth.getCurrentUser();
    if (user.role === 'teacher' || user.role === 'admin') {
      await this.loadTeacherData();
    }

    // Return to original view
    this.switchView(originalView || 'classes');

    // Show teacher tabs and hide student tabs AFTER switchView
    const currentUser = auth.getCurrentUser();
    const teacherTabs = document.querySelectorAll('.teacher-tab');

    if (currentUser && (currentUser.role === 'teacher' || currentUser.role === 'admin')) {
      // Hide student tabs first, then show teacher tabs — this order matters because
      // the Song Library tab has both classes; showing teacher tabs last ensures it stays visible.
      document.querySelectorAll('.student-tab').forEach(tab => tab.classList.add('hidden'));
      teacherTabs.forEach(tab => {
        tab.classList.remove('hidden');
      });
    }

    // Show action buttons again (only those we hid)
    const actionButtons = [
      'export-progress-btn'
    ];
    actionButtons.forEach(btnId => {
      const btn = document.getElementById(btnId);
      if (btn) btn.classList.remove('hidden');
    });
  }

  // ============================================
  // TEACHER: Student Songs
  // ============================================

  async loadStudentSongs() {
    const listEl = document.getElementById('student-songs-list');
    if (!listEl) return;

    listEl.innerHTML = '<div class="loading-state">Loading student songs...</div>';

    let result;
    try {
      result = await this.callRpcDirect('get_teacher_student_songs', {});
    } catch (err) {
      console.error('Error loading student songs:', err);
      listEl.innerHTML = '<div class="empty-state">Failed to load student songs. Please try again.</div>';
      return;
    }

    this.teacherStudentSongs = result.data || [];
    this.populateStudentSongsFilters();
    this.filterStudentSongs();
  }

  populateStudentSongsFilters() {
    const classFilter = document.getElementById('student-songs-class-filter');
    const instrumentFilter = document.getElementById('student-songs-instrument-filter');
    if (!classFilter || !instrumentFilter) return;

    const songs = this.teacherStudentSongs || [];

    // Unique classes
    const classMap = new Map();
    songs.forEach(s => { if (s.class_id) classMap.set(s.class_id, s.class_name); });
    const currentClass = classFilter.value;
    classFilter.innerHTML = '<option value="">All Classes</option>';
    [...classMap.entries()]
      .sort((a, b) => a[1].localeCompare(b[1]))
      .forEach(([id, name]) => {
        const opt = document.createElement('option');
        opt.value = id;
        opt.textContent = name;
        opt.selected = (id === currentClass);
        classFilter.appendChild(opt);
      });

    // Unique instruments
    const instrMap = new Map();
    songs.forEach(s => { if (s.instrument_id) instrMap.set(s.instrument_id, { name: s.instrument_name, icon: s.instrument_icon }); });
    const currentInstr = instrumentFilter.value;
    instrumentFilter.innerHTML = '<option value="">All Instruments</option>';
    [...instrMap.entries()]
      .sort((a, b) => a[1].name.localeCompare(b[1].name))
      .forEach(([id, { name, icon }]) => {
        const opt = document.createElement('option');
        opt.value = id;
        opt.textContent = `${icon} ${name}`;
        opt.selected = (id === currentInstr);
        instrumentFilter.appendChild(opt);
      });
  }

  filterStudentSongs() {
    const songs = this.teacherStudentSongs || [];
    const search = (document.getElementById('student-songs-search')?.value || '').toLowerCase();
    const classId = document.getElementById('student-songs-class-filter')?.value || '';
    const instrumentId = document.getElementById('student-songs-instrument-filter')?.value || '';

    const filtered = songs.filter(s => {
      if (classId && s.class_id !== classId) return false;
      if (instrumentId && s.instrument_id !== instrumentId) return false;
      if (search) {
        const matchesSong = s.title?.toLowerCase().includes(search) || s.artist?.toLowerCase().includes(search);
        const matchesStudent = s.student_name?.toLowerCase().includes(search);
        if (!matchesSong && !matchesStudent) return false;
      }
      return true;
    });

    this.renderStudentSongs(filtered);
  }

  renderStudentSongs(songs) {
    const listEl = document.getElementById('student-songs-list');
    if (!listEl) return;

    if (!songs || songs.length === 0) {
      listEl.innerHTML = `
        <div class="empty-state">
          <p>No songs found.</p>
          ${!this.teacherStudentSongs?.length ? '<p style="color:var(--text-secondary);font-size:0.875rem;">Your students haven\'t added any songs to learn yet.</p>' : ''}
        </div>`;
      return;
    }

    // Group by song, collecting all instruments and the students per instrument
    const grouped = new Map();
    songs.forEach(row => {
      if (!grouped.has(row.song_id)) {
        grouped.set(row.song_id, {
          song_id: row.song_id,
          title: row.title,
          artist: row.artist,
          youtube_url: row.youtube_url,
          chords_url: row.chords_url,
          bass_tab_url: row.bass_tab_url,
          drum_notation_url: row.drum_notation_url,
          instruments: new Map() // instrument_id → { name, icon, students[] }
        });
      }
      const entry = grouped.get(row.song_id);
      if (!entry.instruments.has(row.instrument_id)) {
        entry.instruments.set(row.instrument_id, {
          name: row.instrument_name,
          icon: row.instrument_icon,
          students: []
        });
      }
      entry.instruments.get(row.instrument_id).students.push({
        id: row.student_id,
        name: row.student_name,
        class_name: row.class_name
      });
    });

    const items = [...grouped.values()].sort((a, b) => a.title.localeCompare(b.title));

    listEl.innerHTML = items.map(item => {
      const totalStudents = new Set(
        [...item.instruments.values()].flatMap(i => i.students.map(s => s.id))
      ).size;

      const sortedInstrs = [...item.instruments.entries()]
        .map(([id, instr]) => ({ id, ...instr }))
        .sort((a, b) => a.name.localeCompare(b.name));
      const firstInstrumentId = sortedInstrs[0]?.id || '';
      const escapedTitle = (item.title || '').replace(/'/g, "\\'");
      const escapedArtist = (item.artist || '').replace(/'/g, "\\'");
      const escapedFirstInstrName = (sortedInstrs[0]?.name || '').replace(/'/g, "\\'");

      const instrumentRows = sortedInstrs.map(instr => {
          const tags = instr.students
            .sort((a, b) => a.name.localeCompare(b.name))
            .map(s => `<span class="student-tag" title="${this.escapeHtml(s.class_name || '')}">${this.escapeHtml(s.name)}</span>`)
            .join('');

          return `
            <div class="student-song-instrument-row">
              <span class="instrument-badge">${instr.icon} ${this.escapeHtml(instr.name)}</span>
              <div class="student-song-students">${tags}</div>
            </div>`;
        }).join('');

      return `
        <div class="student-song-item" data-song-id="${item.song_id}">
          <div class="student-song-header">
            <div class="student-song-info">
              <div class="student-song-title">${this.escapeHtml(item.title)}</div>
              <div class="student-song-artist">${this.escapeHtml(item.artist)}</div>
            </div>
            <div class="student-song-header-right">
              ${item.youtube_url
                ? `<a href="${this.escapeHtml(item.youtube_url)}" target="_blank" class="song-resource-link song-resource-link--youtube">▶ YouTube</a>`
                : `<button class="btn btn-secondary btn-add" onclick="app.editSongResource('${item.song_id}', 'youtube_url', '', '${escapedTitle}', '${escapedArtist}', '${escapedFirstInstrName}')" title="Add YouTube link">+ YouTube</button>`}
              <button class="btn btn-secondary btn-resources" onclick="app.openSongFromStudentDetail('${item.song_id}', '${firstInstrumentId}')">Learning Resources</button>
              <div class="student-song-count">${totalStudents} student${totalStudents !== 1 ? 's' : ''}</div>
            </div>
          </div>
          <div class="student-song-instruments">${instrumentRows}</div>
        </div>`;
    }).join('');
  }

  // ============================================
  // TEACHER: Flagged Ratings Review
  // ============================================

  async loadFlaggedRatings() {
    // Get all students from all the teacher's classes first, so we can filter everything
    let allStudents;
    let studentsError;
    try {
      const result = await this.callRpcDirect('get_all_teacher_students', {});
      allStudents = result.data;
    } catch (err) {
      studentsError = err;
    }

    if (studentsError) {
      console.error('Error loading teacher students:', studentsError);
      this.pendingLinks = [];
      this.pendingTutorials = [];
      this.pendingResources = [];
      this.flaggedRatings = [];
      this.newRatings = [];
      this.populateFlaggedFilters();
      this.filterFlaggedRatings();
      return;
    }

    if (!allStudents || allStudents.length === 0) {
      this.pendingLinks = [];
      this.pendingTutorials = [];
      this.pendingResources = [];
      this.flaggedRatings = [];
      this.newRatings = [];
      this.populateFlaggedFilters();
      this.filterFlaggedRatings();
      return;
    }

    const studentIds = allStudents.map(s => s.user_id);

    // Load pending links and resources (which now include tutorials) filtered to teacher's own students
    const [{ data: pendingLinks }, { data: pendingAllResources }] = await Promise.all([
      this.callSelectDirect(
        'pending_links',
        'id,song_id,link_type,url,submitted_at,submitted_by_user_id,songs!inner(title,artist),users!pending_links_submitted_by_user_id_fkey(name)',
        { in: { submitted_by_user_id: studentIds }, eq: { status: 'pending' } },
        { order: 'submitted_at.desc' }
      ),
      this.callSelectDirect(
        'student_resources',
        'id,song_id,title,file_url,file_type,created_at,user_id,instrument_id,songs!inner(title,artist),instruments(icon,name),users!student_resources_user_id_fkey(name)',
        { in: { user_id: studentIds }, eq: { status: 'pending' } },
        { order: 'created_at.desc' }
      )
    ]);

    // Split resources into tutorials and non-tutorials for separate display sections
    const allResources = pendingAllResources || [];
    this.pendingLinks = pendingLinks || [];
    this.pendingTutorials = allResources.filter(r => r.file_type === 'tutorial');
    this.pendingResources = allResources.filter(r => r.file_type !== 'tutorial');

    // Enrich pending links with instrument context from song_ratings
    if (this.pendingLinks.length > 0) {
      const linkSongIds = [...new Set(this.pendingLinks.map(l => l.song_id))];
      const linkUserIds = [...new Set(this.pendingLinks.map(l => l.submitted_by_user_id).filter(Boolean))];
      const { data: linkRatings } = await this.callSelectDirect(
        'song_ratings',
        'song_id,user_id,instrument_id,instruments(icon,name)',
        { in: { song_id: linkSongIds, user_id: linkUserIds } }
      );
      if (linkRatings) {
        const ratingInstrumentMap = {};
        linkRatings.forEach(r => {
          const key = `${r.song_id}-${r.user_id}`;
          if (!ratingInstrumentMap[key] && r.instruments) {
            ratingInstrumentMap[key] = r.instruments;
          }
        });
        this.pendingLinks.forEach(link => {
          const key = `${link.song_id}-${link.submitted_by_user_id}`;
          link.instrument = ratingInstrumentMap[key] || null;
        });
      }
    }

    // Create a user map for displaying names
    const userMap = {};
    allStudents.forEach(s => {
      userMap[s.user_id] = s.name;
    });

    // Add current teacher to the map
    const user = auth.getCurrentUser();
    userMap[user.id] = user.name || 'Teacher';

    // First, get all song IDs that have been rated by class students
    const { data: studentRatings, error: studentError } = await this.callSelectDirect(
      'song_ratings',
      'song_id',
      { in: { user_id: studentIds } }
    );

    if (studentError) {
      console.error('Error loading student ratings:', studentError);
      this.flaggedRatings = [];
      this.newRatings = [];
      this.populateFlaggedFilters();
      this.filterFlaggedRatings();
      return;
    }

    // Get unique song IDs
    const songIds = [...new Set((studentRatings || []).map(r => r.song_id))];

    // Initialize flagged and newRatings arrays
    let flagged = [];
    let newRatings = [];

    // Only load song ratings if there are songs to check
    if (songIds.length > 0) {
      // Now get ALL ratings for these songs (including teacher ratings)
      // Don't use inner join on users to avoid RLS issues
      const { data, error } = await this.callSelectDirect(
        'song_ratings',
        'song_id,instrument_id,assessed_level,user_id,songs!inner(title,artist,suggested_level),instruments(icon,name)',
        { in: { song_id: songIds } }
      );

      if (error) {
        console.error('Error loading ratings:', error);
      } else if (data) {
        // Group by song AND instrument to find discrepancies
        const songGroups = {};
        data.forEach(rating => {
          const key = `${rating.song_id}-${rating.instrument_id}`;
          if (!songGroups[key]) {
            songGroups[key] = {
              songId: rating.song_id,
              song: rating.songs,
              instrument: rating.instruments,
              ratings: [],
              hasBeenResolved: rating.songs.suggested_level !== null
            };
          }
          songGroups[key].ratings.push({
            student: userMap[rating.user_id] || 'Unknown',
            level: rating.assessed_level
          });
        });

        // Find songs with 2+ level discrepancies (excluding already resolved songs)
        Object.values(songGroups).forEach(group => {
          if (group.ratings.length >= 2 && !group.hasBeenResolved) {
            const levels = group.ratings.map(r => r.level);
            const min = Math.min(...levels);
            const max = Math.max(...levels);
            if (max - min >= 2) {
              flagged.push(group);
            }
          }
        });
      }

      // Also load new ratings that need teacher review
      const { data: unreviewedRatings, error: unreviewedError } = await this.callSelectDirect(
        'song_ratings',
        'id,song_id,instrument_id,assessed_level,user_id,date_graded,songs!inner(title,artist),instruments(icon,name)',
        { in: { user_id: studentIds }, eq: { teacher_reviewed: false } },
        { order: 'date_graded.desc' }
      );

      // Format unreviewed ratings for display
      newRatings = (unreviewedRatings || []).map(rating => ({
        id: rating.id,
        songId: rating.song_id,
        song: rating.songs,
        instrument: rating.instruments,
        rating: {
          student: userMap[rating.user_id] || 'Unknown',
          level: rating.assessed_level,
          dateGraded: rating.date_graded
        },
        isNew: true
      }));
    }

    // Store rating data and render
    this.flaggedRatings = flagged;
    this.newRatings = newRatings;
    this.populateFlaggedFilters();
    this.filterFlaggedRatings();
  }

  populateFlaggedFilters() {
    // Populate class filter
    const classFilter = document.getElementById('flagged-class-filter');
    if (classFilter && this.classes) {
      const classOptions = this.classes.map(c =>
        `<option value="${c.id}">${c.name}</option>`
      ).join('');
      classFilter.innerHTML = '<option value="">All Classes</option>' + classOptions;
    }

    // Populate instrument filter
    const instrumentFilter = document.getElementById('flagged-instrument-filter');
    if (instrumentFilter && this.instruments) {
      const instrumentOptions = this.instruments.map(i =>
        `<option value="${i.id}">${i.icon} ${i.name}</option>`
      ).join('');
      instrumentFilter.innerHTML = '<option value="">All Instruments</option>' + instrumentOptions;
    }
  }

  setupFlaggedFilters() {
    const classFilter = document.getElementById('flagged-class-filter');
    const instrumentFilter = document.getElementById('flagged-instrument-filter');

    if (classFilter) {
      classFilter.addEventListener('change', () => {
        this.filterFlaggedRatings();
      });
    }

    if (instrumentFilter) {
      instrumentFilter.addEventListener('change', () => {
        this.filterFlaggedRatings();
      });
    }
  }

  async filterFlaggedRatings() {
    if (!this.flaggedRatings) {
      this.renderFlaggedRatings([]);
      return;
    }

    let filtered = [...this.flaggedRatings];

    // Filter by instrument
    const instrumentFilter = document.getElementById('flagged-instrument-filter')?.value;
    if (instrumentFilter) {
      filtered = filtered.filter(item => item.instrument.id === instrumentFilter);
    }

    // Filter by class - need to check if any of the ratings are from students in that class
    const classFilter = document.getElementById('flagged-class-filter')?.value;
    if (classFilter) {
      // Get student IDs from this class
      const { data: classMembers } = await supabase
        .from('class_members')
        .select('user_id')
        .eq('class_id', classFilter);

      if (classMembers) {
        const classStudentIds = classMembers.map(m => m.user_id);
        // We need to re-fetch ratings with user_id to filter by class
        // For now, just skip class filtering
        // TODO: Store user_id in flagged ratings for class filtering
      }
    }

    this.renderFlaggedRatings(filtered);
  }

  renderFlaggedRatings(flaggedSongs) {
    const container = document.getElementById('flagged-ratings-list');
    if (!container) return;

    // Update notification badge - count all items needing review
    const totalCount = flaggedSongs.length + (this.newRatings?.length || 0) + (this.pendingLinks?.length || 0) + (this.pendingTutorials?.length || 0) + (this.pendingResources?.length || 0);
    const badge = document.getElementById('flagged-count-badge');
    if (badge) {
      if (totalCount > 0) {
        badge.textContent = totalCount;
        badge.classList.remove('hidden');
      } else {
        badge.classList.add('hidden');
      }
    }

    // Build HTML for pending links section
    let pendingLinksHtml = '';
    if (this.pendingLinks && this.pendingLinks.length > 0) {
      const linkTypeLabels = {
        'youtube_url': 'YouTube Video',
        'chords_url': 'Chords/Tabs',
        'bass_tab_url': 'Bass Tab',
        'drum_notation_url': 'Drum Notation',
        'tutorial_url': 'Tutorial Video'
      };

      pendingLinksHtml = `
        <div style="margin-bottom: 2rem;">
          <h3 style="margin-bottom: 1rem; color: var(--text-primary);">Pending Link Approvals (${this.pendingLinks.length})</h3>
          ${this.pendingLinks.map(link => {
            const linkLabel = linkTypeLabels[link.link_type] || link.link_type;
            const submittedDate = new Date(link.submitted_at).toLocaleDateString();
            const submitterName = link.users?.name || 'Unknown';
            const instrumentLabel = link.instrument ? `${link.instrument.icon} ${link.instrument.name}` : '';

            return `
              <div class="flagged-card" style="border-left: 4px solid #ffc107;">
                <div class="flagged-header">
                  <div>
                    <div class="flagged-song-title">${link.songs.title}</div>
                    <div class="flagged-song-meta">${link.songs.artist} • ${linkLabel}${instrumentLabel ? ` • ${instrumentLabel}` : ''}</div>
                  </div>
                  <div style="text-align: right; font-size: 0.875rem; color: var(--text-secondary);">
                    <div>Submitted by ${submitterName}</div>
                    <div>${submittedDate}</div>
                  </div>
                </div>
                <div id="pending-link-url-${link.id}" style="padding: 1rem; background: var(--bg-secondary); border-radius: 4px; margin: 1rem 0;">
                  <div style="font-weight: 500; margin-bottom: 0.5rem; color: var(--text-primary);">Submitted URL:</div>
                  <div id="pending-link-display-${link.id}">
                    <a href="${link.url}" target="_blank" rel="noopener noreferrer" style="color: var(--primary-color); word-break: break-all;">${link.url}</a>
                  </div>
                  <div id="pending-link-edit-${link.id}" class="hidden" style="margin-top: 0.5rem;">
                    <input type="url" id="pending-link-input-${link.id}" value="${link.url}" style="width: 100%; padding: 0.5rem; border: 1px solid var(--border-color); border-radius: 4px; font-size: 0.875rem; background: var(--bg-primary); color: var(--text-primary);" />
                    <div style="display: flex; gap: 0.5rem; margin-top: 0.5rem;">
                      <button class="btn btn-primary" style="font-size: 0.75rem;" onclick="app.savePendingLinkUrl('${link.id}')">Save URL</button>
                      <button class="btn btn-secondary" style="font-size: 0.75rem;" onclick="app.cancelEditPendingLink('${link.id}')">Cancel</button>
                    </div>
                  </div>
                </div>
                <div class="flagged-resolve">
                  <button class="btn btn-primary" onclick="app.approvePendingLink('${link.id}')">
                    <span style="margin-right: 0.5rem;">✓</span> Approve
                  </button>
                  <button class="btn btn-secondary" onclick="app.rejectPendingLink('${link.id}')" style="margin-left: 0.5rem;">
                    <span style="margin-right: 0.5rem;">✗</span> Reject
                  </button>
                  <button class="btn btn-secondary" onclick="app.editPendingLinkUrl('${link.id}')" style="margin-left: 0.5rem;">
                    <span style="margin-right: 0.5rem;">&#9998;</span> Edit URL
                  </button>
                </div>
              </div>
            `;
          }).join('')}
        </div>
      `;
    }

    // Build HTML for pending tutorials section (tutorials are resources with file_type='tutorial')
    let pendingTutorialsHtml = '';
    if (this.pendingTutorials && this.pendingTutorials.length > 0) {
      pendingTutorialsHtml = `
        <div style="margin-bottom: 2rem;">
          <h3 style="margin-bottom: 1rem; color: var(--text-primary);">Pending Tutorial Approvals (${this.pendingTutorials.length})</h3>
          ${this.pendingTutorials.map(tutorial => {
            const submittedDate = new Date(tutorial.created_at).toLocaleDateString();
            const tutorialInstrumentLabel = tutorial.instruments ? `${tutorial.instruments.icon} ${tutorial.instruments.name}` : '';
            const tutorialSubmitterName = tutorial.users?.name || 'Unknown';

            return `
              <div class="flagged-card" style="border-left: 4px solid #9c27b0;">
                <div class="flagged-header">
                  <div>
                    <div class="flagged-song-title">${tutorial.songs.title}</div>
                    <div class="flagged-song-meta">${tutorial.songs.artist} • Tutorial Video${tutorialInstrumentLabel ? ` • ${tutorialInstrumentLabel}` : ''}</div>
                  </div>
                  <div style="text-align: right; font-size: 0.875rem; color: var(--text-secondary);">
                    <div>Submitted by ${tutorialSubmitterName}</div>
                    <div>${submittedDate}</div>
                  </div>
                </div>
                <div id="pending-tutorial-url-${tutorial.id}" style="padding: 1rem; background: var(--bg-secondary); border-radius: 4px; margin: 1rem 0;">
                  ${tutorial.title ? `<div style="font-weight: 500; margin-bottom: 0.5rem; color: var(--text-primary);">${tutorial.title}</div>` : ''}
                  <div style="font-weight: 500; margin-bottom: 0.5rem; color: var(--text-primary);">Submitted URL:</div>
                  <div id="pending-tutorial-display-${tutorial.id}">
                    <a href="${tutorial.file_url}" target="_blank" rel="noopener noreferrer" style="color: var(--primary-color); word-break: break-all;">${tutorial.file_url}</a>
                  </div>
                  <div id="pending-tutorial-edit-${tutorial.id}" class="hidden" style="margin-top: 0.5rem;">
                    <input type="url" id="pending-tutorial-input-${tutorial.id}" value="${tutorial.file_url}" style="width: 100%; padding: 0.5rem; border: 1px solid var(--border-color); border-radius: 4px; font-size: 0.875rem; background: var(--bg-primary); color: var(--text-primary);" />
                    <div style="display: flex; gap: 0.5rem; margin-top: 0.5rem;">
                      <button class="btn btn-primary" style="font-size: 0.75rem;" onclick="app.savePendingTutorialUrl('${tutorial.id}')">Save URL</button>
                      <button class="btn btn-secondary" style="font-size: 0.75rem;" onclick="app.cancelEditPendingTutorial('${tutorial.id}')">Cancel</button>
                    </div>
                  </div>
                </div>
                <div class="flagged-resolve">
                  <button class="btn btn-primary" onclick="app.approvePendingTutorial('${tutorial.id}', '${tutorial.song_id}')">
                    <span style="margin-right: 0.5rem;">✓</span> Approve
                  </button>
                  <button class="btn btn-danger" onclick="app.deletePendingTutorial('${tutorial.id}')" style="margin-left: 0.5rem;">
                    <span style="margin-right: 0.5rem;">✗</span> Delete
                  </button>
                  <button class="btn btn-secondary" onclick="app.editPendingTutorialUrl('${tutorial.id}')" style="margin-left: 0.5rem;">
                    <span style="margin-right: 0.5rem;">&#9998;</span> Edit URL
                  </button>
                </div>
              </div>
            `;
          }).join('')}
        </div>
      `;
    }

    // Build HTML for pending student resources section
    let pendingResourcesHtml = '';
    if (this.pendingResources && this.pendingResources.length > 0) {
      const fileTypeLabels = {
        'image': 'Image',
        'pdf': 'PDF Document',
        'link': 'External Link'
      };

      pendingResourcesHtml = `
        <div style="margin-bottom: 2rem;">
          <h3 style="margin-bottom: 1rem; color: var(--text-primary);">Pending Student Resource Approvals (${this.pendingResources.length})</h3>
          ${this.pendingResources.map(resource => {
            const submittedDate = new Date(resource.created_at).toLocaleDateString();
            const typeLabel = fileTypeLabels[resource.file_type] || resource.file_type;
            const resourceInstrumentLabel = resource.instruments ? `${resource.instruments.icon} ${resource.instruments.name}` : '';
            const resourceSubmitterName = resource.users?.name || 'Unknown';

            return `
              <div class="flagged-card" style="border-left: 4px solid #ff9800;">
                <div class="flagged-header">
                  <div>
                    <div class="flagged-song-title">${resource.songs.title}</div>
                    <div class="flagged-song-meta">${resource.songs.artist} • ${typeLabel}${resourceInstrumentLabel ? ` • ${resourceInstrumentLabel}` : ''}</div>
                  </div>
                  <div style="text-align: right; font-size: 0.875rem; color: var(--text-secondary);">
                    <div>Submitted by ${resourceSubmitterName}</div>
                    <div>${submittedDate}</div>
                  </div>
                </div>
                <div style="padding: 1rem; background: var(--bg-secondary); border-radius: 4px; margin: 1rem 0;">
                  <div style="font-weight: 500; margin-bottom: 0.5rem; color: var(--text-primary);">${resource.title}</div>
                  <a href="${resource.file_url}" target="_blank" rel="noopener noreferrer" style="color: var(--primary-color); word-break: break-all;">${resource.file_url}</a>
                </div>
                <div class="flagged-resolve">
                  <button class="btn btn-primary" onclick="app.approvePendingResource('${resource.id}', '${resource.song_id}')">
                    <span style="margin-right: 0.5rem;">✓</span> Approve
                  </button>
                  <button class="btn btn-danger" onclick="app.deletePendingResource('${resource.id}')" style="margin-left: 0.5rem;">
                    <span style="margin-right: 0.5rem;">✗</span> Delete
                  </button>
                </div>
              </div>
            `;
          }).join('')}
        </div>
      `;
    }

    // Build HTML for new ratings section
    let newRatingsHtml = '';
    if (this.newRatings && this.newRatings.length > 0) {
      newRatingsHtml = `
        <div style="margin-bottom: 2rem;">
          <h3 style="margin-bottom: 1rem; color: var(--text-primary);">New Song Ratings for Review (${this.newRatings.length})</h3>
          ${this.newRatings.map((item, index) => {
            const gradedDate = new Date(item.rating.dateGraded).toLocaleDateString();

            return `
              <div class="flagged-card" style="border-left: 4px solid #2196f3;">
                <div class="flagged-header">
                  <div>
                    <div class="flagged-song-title">${item.song.title}</div>
                    <div class="flagged-song-meta">${item.song.artist} • ${item.instrument.icon} ${item.instrument.name}</div>
                  </div>
                  <div style="text-align: right; font-size: 0.875rem; color: var(--text-secondary);">
                    <div>Graded by ${item.rating.student}</div>
                    <div>${gradedDate}</div>
                  </div>
                </div>
                <div class="flagged-ratings">
                  <div class="flagged-rating-item">
                    <div class="flagged-student-name">Quiz Result:</div>
                    <div class="flagged-level">Level ${item.rating.level}</div>
                  </div>
                </div>
                <div class="flagged-resolve">
                  <label for="review-level-${index}">Confirm or override level:</label>
                  <select id="review-level-${index}" class="resolve-level-select">
                    <option value="${item.rating.level}" selected>Level ${item.rating.level} (Confirm)</option>
                    <option value="1" ${item.rating.level === 1 ? 'disabled' : ''}>Level 1 - Getting Started</option>
                    <option value="2" ${item.rating.level === 2 ? 'disabled' : ''}>Level 2 - Expanding Skills</option>
                    <option value="3" ${item.rating.level === 3 ? 'disabled' : ''}>Level 3 - Building Technique</option>
                    <option value="4" ${item.rating.level === 4 ? 'disabled' : ''}>Level 4 - Finding Your Style</option>
                    <option value="5" ${item.rating.level === 5 ? 'disabled' : ''}>Level 5 - Mastering It</option>
                  </select>
                  <button class="btn btn-secondary" onclick="event.stopPropagation(); app.editSongDetails('${item.songId}', '${item.song.title.replace(/'/g, "\\'")}', '${item.song.artist.replace(/'/g, "\\'")}', null)" title="Edit song details">Edit Details</button>
                  <button class="btn btn-primary" onclick="app.reviewNewRating('${item.id}', 'review-level-${index}')">Confirm</button>
                </div>
              </div>
            `;
          }).join('')}
        </div>
      `;
    }

    // Build HTML for flagged ratings section
    let flaggedRatingsHtml = '';
    if (flaggedSongs.length > 0) {
      flaggedRatingsHtml = `
        <div>
          <h3 style="margin-bottom: 1rem; color: var(--text-primary);">Rating Discrepancies (${flaggedSongs.length})</h3>
          ${flaggedSongs.map((item, index) => {
      const levels = item.ratings.map(r => r.level);
      const discrepancy = Math.max(...levels) - Math.min(...levels);

      return `
        <div class="flagged-card">
          <div class="flagged-header">
            <div>
              <div class="flagged-song-title">${item.song.title}</div>
              <div class="flagged-song-meta">${item.song.artist} • ${item.instrument.icon} ${item.instrument.name}</div>
            </div>
            <div class="flagged-warning">${discrepancy}-level discrepancy</div>
          </div>
          <div class="flagged-ratings">
            ${item.ratings.map(rating => `
              <div class="flagged-rating-item">
                <div class="flagged-student-name">${rating.student}</div>
                <div class="flagged-level">Level ${rating.level}</div>
              </div>
            `).join('')}
          </div>
          <div class="flagged-resolve">
            <label for="resolve-level-${index}">Set official level:</label>
            <select id="resolve-level-${index}" class="resolve-level-select">
              <option value="">Choose level...</option>
              <option value="1">Level 1 - Getting Started</option>
              <option value="2">Level 2 - Expanding Skills</option>
              <option value="3">Level 3 - Building Technique</option>
              <option value="4">Level 4 - Finding Your Style</option>
              <option value="5">Level 5 - Mastering It</option>
            </select>
            <button class="btn btn-primary" onclick="app.resolveFlaggedRating('${item.songId}', 'resolve-level-${index}')">Resolve</button>
          </div>
        </div>
      `;
    }).join('')}
        </div>
      `;
    }

    // Combine all sections
    if (pendingLinksHtml || pendingTutorialsHtml || pendingResourcesHtml || newRatingsHtml || flaggedRatingsHtml) {
      container.innerHTML = pendingLinksHtml + pendingTutorialsHtml + pendingResourcesHtml + newRatingsHtml + flaggedRatingsHtml;
    } else {
      container.innerHTML = '<p style="color: var(--text-secondary); text-align: center; padding: 3rem;">No items need review</p>';
    }
  }

  async resolveFlaggedRating(songId, selectId) {
    const selectElement = document.getElementById(selectId);
    const level = parseInt(selectElement.value);

    if (!level) {
      this.showToast('Please select a level', 'warning');
      return;
    }

    try {
      // Use direct RPC call to bypass stale Supabase client connections
      await this.callRpcDirect('update_song_suggested_level', {
        p_song_id: songId,
        p_level: level
      });

      this.showToast('Official level set successfully', 'success');

      // Reload flagged ratings to remove the resolved song
      await this.loadFlaggedRatings();

      // Also reload songs to update the song library display
      await this.loadSongs();
      if (this.currentView === 'songs') {
        this.filterSongs();
      }
    } catch (error) {
      console.error('Exception in resolveFlaggedRating:', error);
      this.showToast('Failed to resolve rating', 'error');
    }
  }

  async reviewNewRating(ratingId, selectId) {
    const selectElement = document.getElementById(selectId);
    const level = parseInt(selectElement.value);

    if (!level) {
      this.showToast('Please select a level', 'warning');
      return;
    }

    try {
      // Use direct RPC call to bypass stale Supabase client connections
      await this.callRpcDirect('approve_song_rating', {
        p_rating_id: ratingId,
        p_assessed_level: level
      });

      this.showToast('Rating reviewed successfully', 'success');

      // Reload flagged ratings to remove the reviewed rating
      await this.loadFlaggedRatings();

      // Also reload songs to update the song library display
      await this.loadSongs();

      if (this.currentView === 'songs') {
        this.filterSongs();
      }
    } catch (error) {
      console.error('Exception in reviewNewRating:', error);
      this.showToast('Failed to review rating', 'error');
    }
  }

  async approvePendingLink(linkId) {
    try {
      // Set flag to prevent real-time subscription from double-loading
      this.approvingLink = true;

      // Use direct RPC call to bypass stale Supabase client connections
      await this.callRpcDirect('approve_pending_link', {
        pending_link_id: linkId
      });

      this.showToast('Link approved successfully', 'success');

      // Reload flagged ratings to update the pending links list
      await this.loadFlaggedRatings();

      // Also reload songs to update the song library with the new link
      await this.loadSongs();

      if (this.currentView === 'songs') {
        this.filterSongs();
      }

      // Clear flag after a short delay to allow real-time subscription to catch up
      setTimeout(() => {
        this.approvingLink = false;
      }, 1000);
    } catch (error) {
      console.error('Exception in approvePendingLink:', error);
      this.showToast('Failed to approve link', 'error');
      this.approvingLink = false;
    }
  }

  async rejectPendingLink(linkId) {
    try {
      // Use direct RPC call to bypass stale Supabase client connections
      await this.callRpcDirect('reject_pending_link', {
        pending_link_id: linkId
      });

      this.showToast('Link rejected', 'success');

      // Reload flagged ratings to update the pending links list
      await this.loadFlaggedRatings();
    } catch (error) {
      console.error('Exception in rejectPendingLink:', error);
      this.showToast('Failed to reject link', 'error');
    }
  }

  editPendingLinkUrl(linkId) {
    const displayEl = document.getElementById(`pending-link-display-${linkId}`);
    const editEl = document.getElementById(`pending-link-edit-${linkId}`);
    if (displayEl) displayEl.classList.add('hidden');
    if (editEl) editEl.classList.remove('hidden');
  }

  cancelEditPendingLink(linkId) {
    const displayEl = document.getElementById(`pending-link-display-${linkId}`);
    const editEl = document.getElementById(`pending-link-edit-${linkId}`);
    if (displayEl) displayEl.classList.remove('hidden');
    if (editEl) editEl.classList.add('hidden');
    // Reset input value
    const link = this.pendingLinks?.find(l => l.id === linkId);
    const input = document.getElementById(`pending-link-input-${linkId}`);
    if (link && input) input.value = link.url;
  }

  async savePendingLinkUrl(linkId) {
    const input = document.getElementById(`pending-link-input-${linkId}`);
    if (!input) return;

    const newUrl = input.value.trim();
    if (!newUrl) {
      this.showToast('URL cannot be empty', 'error');
      return;
    }

    try {
      await this.rawUpdate('pending_links', linkId, { url: newUrl });

      // Update local data
      const link = this.pendingLinks?.find(l => l.id === linkId);
      if (link) link.url = newUrl;

      this.showToast('URL updated successfully', 'success');

      // Re-render to show updated URL
      await this.loadFlaggedRatings();
    } catch (error) {
      console.error('Exception in savePendingLinkUrl:', error);
      this.showToast('Failed to update URL', 'error');
    }
  }

  async approvePendingTutorial(tutorialId, songId) {
    try {
      await this.rawUpdate('student_resources', tutorialId, {
        status: 'approved',
        reviewed_by_user_id: auth.getCurrentUser().id,
        reviewed_at: new Date().toISOString()
      });

      // Update local song count
      const song = this.songs.find(s => s.id === songId);
      if (song) {
        song.resource_count = (song.resource_count || 0) + 1;
      }

      this.showToast('Tutorial approved', 'success');
      await this.loadFlaggedRatings();
      await this.loadSongs();
      if (this.currentView === 'songs') {
        this.filterSongs();
      }
    } catch (error) {
      console.error('Error approving tutorial:', error);
      this.showToast('Failed to approve tutorial', 'error');
    }
  }

  async deletePendingTutorial(tutorialId) {
    try {
      await this.rawDelete('student_resources', tutorialId);
      this.showToast('Tutorial deleted', 'success');
      await this.loadFlaggedRatings();
    } catch (error) {
      console.error('Error deleting tutorial:', error);
      this.showToast('Failed to delete tutorial', 'error');
    }
  }

  editPendingTutorialUrl(tutorialId) {
    const displayEl = document.getElementById(`pending-tutorial-display-${tutorialId}`);
    const editEl = document.getElementById(`pending-tutorial-edit-${tutorialId}`);
    if (displayEl) displayEl.classList.add('hidden');
    if (editEl) editEl.classList.remove('hidden');
  }

  cancelEditPendingTutorial(tutorialId) {
    const displayEl = document.getElementById(`pending-tutorial-display-${tutorialId}`);
    const editEl = document.getElementById(`pending-tutorial-edit-${tutorialId}`);
    if (displayEl) displayEl.classList.remove('hidden');
    if (editEl) editEl.classList.add('hidden');
    // Reset input value
    const tutorial = this.pendingTutorials?.find(t => t.id === tutorialId);
    const input = document.getElementById(`pending-tutorial-input-${tutorialId}`);
    if (tutorial && input) input.value = tutorial.file_url;
  }

  async savePendingTutorialUrl(tutorialId) {
    const input = document.getElementById(`pending-tutorial-input-${tutorialId}`);
    if (!input) return;

    const newUrl = input.value.trim();
    if (!newUrl) {
      this.showToast('URL cannot be empty', 'error');
      return;
    }

    try {
      await this.rawUpdate('student_resources', tutorialId, { file_url: newUrl });

      // Update local data
      const tutorial = this.pendingTutorials?.find(t => t.id === tutorialId);
      if (tutorial) tutorial.file_url = newUrl;

      this.showToast('URL updated successfully', 'success');

      // Re-render to show updated URL
      await this.loadFlaggedRatings();
    } catch (error) {
      console.error('Exception in savePendingTutorialUrl:', error);
      this.showToast('Failed to update URL', 'error');
    }
  }

  async approvePendingResource(resourceId, songId) {
    try {
      await this.rawUpdate('student_resources', resourceId, {
        status: 'approved',
        reviewed_by_user_id: auth.getCurrentUser().id,
        reviewed_at: new Date().toISOString()
      });

      // Update local song count
      const song = this.songs.find(s => s.id === songId);
      if (song) {
        song.resource_count = (song.resource_count || 0) + 1;
      }

      this.showToast('Resource approved', 'success');
      await this.loadFlaggedRatings();
      await this.loadSongs();
      if (this.currentView === 'songs') {
        this.filterSongs();
      }
    } catch (error) {
      console.error('Error approving resource:', error);
      this.showToast('Failed to approve resource', 'error');
    }
  }

  async deletePendingResource(resourceId) {
    try {
      await this.rawDelete('student_resources', resourceId);
      this.showToast('Resource deleted', 'success');
      await this.loadFlaggedRatings();
    } catch (error) {
      console.error('Error deleting resource:', error);
      this.showToast('Failed to delete resource', 'error');
    }
  }

  setupEditSongLevelForm() {
    const form = document.getElementById('edit-song-level-form');
    if (!form) return;

    form.addEventListener('submit', async (e) => {
      e.preventDefault();

      if (!this.editingRatingId) {
        console.error('No editing rating ID set');
        this.showToast('Error: No rating ID found', 'error');
        return;
      }

      const newLevel = parseInt(document.getElementById('edit-song-level').value);
      const notes = document.getElementById('edit-song-notes').value;

      try {
        // Use RPC function to update rating (bypasses RLS)
        const { data, error } = await supabase
          .rpc('update_song_rating', {
            p_rating_id: this.editingRatingId,
            p_assessed_level: newLevel,
            p_notes: notes || null
          });

        if (error) {
          console.error('Update error details:', {
            message: error.message,
            details: error.details,
            hint: error.hint,
            code: error.code
          });
          throw error;
        }

        document.getElementById('edit-song-level-modal').classList.add('hidden');
        this.showToast('Song level updated successfully', 'success');

        // Reload flagged ratings to show the updated level
        await this.loadFlaggedRatings();
      } catch (error) {
        console.error('Error updating song level:', error);
        this.showToast(`Failed to update song level: ${error.message}`, 'error');
      }
    });
  }

  editSongLevel(ratingId, songId, songTitle, currentLevel, currentNotes = '') {
    // Store the rating ID so the form handler can use it
    this.editingRatingId = ratingId;

    document.getElementById('edit-song-info').textContent = `Editing: ${songTitle}`;
    document.getElementById('edit-song-level').value = currentLevel;
    document.getElementById('edit-song-notes').value = currentNotes || '';
    document.getElementById('edit-song-level-modal').classList.remove('hidden');
  }

  // Edit song title and artist (teachers only)
  editSongDetails(songId, currentTitle, currentArtist, currentLevel) {
    // Store the song ID for the form handler
    this.editingSongId = songId;

    document.getElementById('edit-song-title').value = currentTitle;
    document.getElementById('edit-song-artist').value = currentArtist;
    document.getElementById('edit-song-details-level').value = currentLevel || '';
    document.getElementById('edit-song-details-modal').classList.remove('hidden');
  }

  setupEditSongDetailsForm() {
    const form = document.getElementById('edit-song-details-form');
    if (!form) return;

    form.addEventListener('submit', async (e) => {
      e.preventDefault();

      if (!this.editingSongId) {
        console.error('No editing song ID set');
        this.showToast('Error: No song ID found', 'error');
        return;
      }

      const newTitle = document.getElementById('edit-song-title').value.trim();
      const newArtist = document.getElementById('edit-song-artist').value.trim();
      const newLevelValue = document.getElementById('edit-song-details-level').value;
      const newLevel = newLevelValue ? parseInt(newLevelValue) : null;

      if (!newTitle || !newArtist) {
        this.showToast('Please fill in both title and artist', 'warning');
        return;
      }

      try {
        // Use RPC function to update song details
        const { data, error } = await supabase
          .rpc('update_song_details', {
            p_song_id: this.editingSongId,
            p_title: newTitle,
            p_artist: newArtist
          });

        if (error) {
          console.error('Update error details:', {
            message: error.message,
            details: error.details,
            hint: error.hint,
            code: error.code
          });
          throw error;
        }

        // Update level if changed
        if (newLevel !== null) {
          await this.callRpcDirect('update_song_suggested_level', {
            p_song_id: this.editingSongId,
            p_level: newLevel
          });
        }

        document.getElementById('edit-song-details-modal').classList.add('hidden');
        document.getElementById('song-details-modal').classList.add('hidden');
        this.showToast('Song details updated successfully', 'success');

        // Reload songs to show the updated details
        await this.loadSongs();
        this.renderSongs();

        // Also refresh content moderation list if visible
        if (this.adminContentList) {
          await this.loadContentModeration();
        }

        // Also refresh flagged/new ratings review if visible
        if (this.newRatings || this.flaggedRatings) {
          await this.loadFlaggedRatings();
        }
      } catch (error) {
        console.error('Error updating song details:', error);
        this.showToast(`Failed to update song details: ${error.message}`, 'error');
      }
    });
  }

  toggleJoinClassSection() {
    const modal = document.getElementById('join-class-modal');
    modal.classList.remove('hidden');
    this.loadStudentClasses();
  }

  // ============================================
  // STUDENT: Class Features (Join & View)
  // ============================================

  async loadStudentClasses() {
    const user = auth.getCurrentUser();
    const container = document.getElementById('student-classes-list');

    // Use direct fetch to bypass stale Supabase client connections
    const { data: memberships, error } = await this.callSelectDirect(
      'class_members',
      '*,classes(id,name,class_code,year_level,created_at)',
      { eq: { user_id: user.id } },
      { order: 'joined_at.desc' }
    );

    if (error) {
      console.error('Error loading student classes:', error);
      container.innerHTML = '<p style="color: var(--text-secondary); margin-top: 1rem;">Unable to load your classes</p>';
      return;
    }

    if (!memberships || memberships.length === 0) {
      container.innerHTML = '<p style="color: var(--text-secondary); margin-top: 1rem;">You haven\'t joined any classes yet</p>';
      return;
    }

    const html = `
      <div style="margin-top: 1.5rem;">
        <h4 style="margin-bottom: 0.75rem; font-size: 0.875rem; font-weight: 600; text-transform: uppercase; letter-spacing: 0.05em; color: var(--text-secondary);">Your Classes</h4>
        <div class="student-classes-grid">
          ${memberships.map(m => {
            const cls = m.classes;
            const joinDate = new Date(m.joined_at).toLocaleDateString('en-GB');
            return `
              <div class="student-class-card">
                <div class="class-card-header">
                  <strong>${cls.name}</strong>
                  ${cls.year_level ? `<span class="class-year-badge">${cls.year_level}</span>` : ''}
                </div>
                <div class="class-card-meta">
                  <span>Code: <strong>${cls.class_code}</strong></span>
                  <span>Joined: ${joinDate}</span>
                </div>
              </div>
            `;
          }).join('')}
        </div>
      </div>
    `;

    container.innerHTML = html;
  }

  async loadStudentClassesHeader() {
    const user = auth.getCurrentUser();
    const container = document.getElementById('student-classes-header');

    if (!container) return;

    // Don't show for teachers or in preview mode
    if (this.previewMode.active || (user.role === 'teacher' || user.role === 'admin')) {
      container.classList.add('hidden');
      return;
    }

    const userId = user.id;

    // Use direct fetch to bypass stale Supabase client connections
    const { data: memberships, error } = await this.callSelectDirect(
      'class_members',
      '*,classes(id,name,class_code,year_level)',
      { eq: { user_id: userId } },
      { order: 'joined_at.desc' }
    );

    if (error) {
      console.error('Error loading student classes for header:', error);
      container.classList.add('hidden');
      return;
    }

    if (!memberships || memberships.length === 0) {
      container.classList.add('hidden');
      return;
    }

    // Show class badges
    container.classList.remove('hidden');
    container.innerHTML = memberships.map(m => {
      const cls = m.classes;
      return `<span class="class-badge" title="${cls.name}${cls.year_level ? ' - ' + cls.year_level : ''}">${cls.name}</span>`;
    }).join('');
  }

  async joinClass() {
    const codeInput = document.getElementById('class-code-input');
    const joinBtn = document.getElementById('join-class-btn');
    const classCode = codeInput.value.trim().toUpperCase();

    if (!classCode || classCode.length !== 6) {
      this.showToast('Please enter a valid 6-character class code', 'error');
      return;
    }

    // Disable button during processing
    joinBtn.disabled = true;
    joinBtn.textContent = 'Joining...';

    try {
      const user = auth.getCurrentUser();

      // Use direct RPC call to bypass stale Supabase client connections
      let data;
      try {
        const result = await this.callRpcDirect('join_class_by_code', {
          p_user_id: user.id,
          p_class_code: classCode
        });
        data = result.data;
      } catch (rpcError) {
        console.error('Database error details:', {
          message: rpcError.message,
          details: rpcError.details,
          hint: rpcError.hint,
          code: rpcError.code
        });

        // Handle timeout
        if (rpcError.message?.includes('timeout') || rpcError.message?.includes('timed out')) {
          this.showToast('Request timed out. Please check your connection and try again.', 'error');
          return;
        }

        // Handle specific error cases
        if (rpcError.message?.includes('not found')) {
          this.showToast('Class not found. Please check the code.', 'error');
        } else if (rpcError.message?.includes('already') || rpcError.code === '23505') {
          this.showToast('You are already in this class', 'info');
        } else {
          this.showToast('Failed to join class. Please try again.', 'error');
        }
        return;
      }

      // Handle response
      if (!data || !data.success) {
        // Show appropriate message
        const messageType = data?.message?.includes('already') ? 'info' : 'error';
        this.showToast(data?.message || 'Class not found. Please check the code.', messageType);

        // Still load classes to show what they're in
        await this.loadStudentClasses();
        await this.loadStudentClassesHeader();
        return;
      }

      codeInput.value = '';
      this.showToast(`Joined ${data.class_name}!`, 'success');

      // Reload the student's classes list and header
      await this.loadStudentClasses();
      await this.loadStudentClassesHeader();
    } finally {
      // Re-enable button
      joinBtn.disabled = false;
      joinBtn.textContent = 'Join Class';
    }
  }

  async exportClassData() {
    if (!this.currentClass) return;

    // Gather all class data
    const rows = [['Student Name', 'Email', 'Instrument', 'Level', 'Branch', 'Songs Learning', 'Songs Mastered']];

    for (const member of this.classStudents) {
      const student = member.users;
      const progress = member.student_progress || [];

      if (progress.length === 0) {
        rows.push([student.name, student.email, '-', '-', '-', '0', '0']);
      } else {
        for (const p of progress) {
          const inst = this.instruments.find(i => i.id === p.instrument_id);

          // Count songs
          const { data: songs } = await supabase
            .from('student_songs')
            .select('status')
            .eq('user_id', student.id)
            .eq('instrument_id', p.instrument_id);

          const learning = songs?.filter(s => s.status === 'learning').length || 0;
          const mastered = songs?.filter(s => s.status === 'mastered').length || 0;

          rows.push([
            student.name,
            student.email,
            inst?.name || '-',
            p.current_level,
            p.current_branch || '-',
            learning,
            mastered
          ]);
        }
      }
    }

    // Create CSV
    const csv = rows.map(row => row.map(cell => `"${cell}"`).join(',')).join('\n');

    // Download
    const blob = new Blob([csv], { type: 'text/csv' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `${this.currentClass.name.replace(/\s+/g, '_')}_data.csv`;
    a.click();
    URL.revokeObjectURL(url);

    this.showToast('Class data exported', 'success');
  }

  // ============================================
  // ADMIN: Dashboard & System Overview
  // ============================================

  getTimeAgo(timestamp) {
    const now = new Date();
    const then = new Date(timestamp);
    const seconds = Math.floor((now - then) / 1000);

    if (seconds < 60) return 'just now';
    if (seconds < 3600) return `${Math.floor(seconds / 60)}m ago`;
    if (seconds < 86400) return `${Math.floor(seconds / 3600)}h ago`;
    if (seconds < 604800) return `${Math.floor(seconds / 86400)}d ago`;
    return then.toLocaleDateString();
  }

  /* ========== END TEACHER DASHBOARD METHODS ========== */

  /* ========== ADMIN DASHBOARD METHODS ========== */

  async loadAdminData() {
    await this.loadAdminStats();
    await this.loadAdminLevels();
  }

  async loadAdminStats() {
    // Get system-wide statistics using data length for reliability
    // Use callSelectDirect to bypass stale Supabase client connections
    const [usersRes, songsRes, ratingsRes, classesRes] = await Promise.all([
      this.callSelectDirect('users', 'id, role'),
      this.callSelectDirect('songs', 'id'),
      this.callSelectDirect('song_ratings', 'id'),
      this.callSelectDirect('classes', 'id')
    ]);

    const users = usersRes.data || [];
    const students = users.filter(u => u.role === 'student').length;
    const teachers = users.filter(u => u.role === 'teacher' || u.role === 'admin').length;

    this.adminStats = {
      students,
      teachers,
      songs: songsRes.data?.length ?? 0,
      ratings: ratingsRes.data?.length ?? 0,
      classes: classesRes.data?.length ?? 0
    };

    this.renderAdminStats(this.adminStats);
  }

  renderAdminStats(stats) {
    const container = document.getElementById('admin-stats');
    if (!container) return;

    const html = `
      <div class="admin-stat-card">
        <div class="admin-stat-value">${stats.students}</div>
        <div class="admin-stat-label">Students</div>
      </div>
      <div class="admin-stat-card">
        <div class="admin-stat-value">${stats.teachers}</div>
        <div class="admin-stat-label">Teachers</div>
      </div>
      <div class="admin-stat-card">
        <div class="admin-stat-value">${stats.songs}</div>
        <div class="admin-stat-label">Songs</div>
      </div>
      <div class="admin-stat-card">
        <div class="admin-stat-value">${stats.classes}</div>
        <div class="admin-stat-label">Classes</div>
      </div>
    `;

    container.innerHTML = html;
  }

  switchAdminSection(sectionName) {
    // Update section tabs
    document.querySelectorAll('.admin-section-tab').forEach(tab => {
      tab.classList.toggle('active', tab.dataset.section === sectionName);
    });

    // Update sections
    document.querySelectorAll('.admin-section').forEach(section => {
      section.classList.remove('active');
    });

    const targetSection = document.getElementById(`${sectionName}-section`);
    if (targetSection) {
      targetSection.classList.add('active');

      // Load data for the section
      if (sectionName === 'levels') {
        this.renderAdminLevels();
      } else if (sectionName === 'instruments') {
        this.renderAdminInstruments();
      } else if (sectionName === 'content') {
        this.loadContentModeration();
      } else if (sectionName === 'users') {
        this.loadUsersManagement();
      }
    }
  }

  // ============================================
  // ADMIN: Levels & Checklist Management
  // ============================================

  async loadAdminLevels() {
    const { data, error } = await this.callSelectDirect(
      'levels',
      '*, instruments(name, icon)',
      {},
      { order: 'instrument_id.asc,level_number.asc' }
    );

    if (error) {
      console.error('Error loading levels:', error);
      this.showToast('Failed to load levels', 'error');
      return;
    }

    this.adminLevels = data;

    // Only set default instrument if not already selected
    if (!this.currentAdminLevelInstrument) {
      this.currentAdminLevelInstrument = this.instruments[0]?.id;
    }

    // Populate instrument filter
    const select = document.getElementById('admin-level-instrument');
    if (select) {
      select.innerHTML = this.instruments.map(i =>
        `<option value="${i.id}">${i.icon} ${i.name}</option>`
      ).join('');
      select.value = this.currentAdminLevelInstrument;
    }
  }

  renderAdminLevels() {
    const container = document.getElementById('levels-list');
    if (!container || !this.adminLevels) return;

    const filteredLevels = this.adminLevels.filter(l =>
      l.instrument_id === this.currentAdminLevelInstrument
    );

    if (filteredLevels.length === 0) {
      container.innerHTML = '<p style="color: var(--text-secondary);">No levels found for this instrument</p>';
      return;
    }

    const html = filteredLevels.map(level => {
      const skills = level.skills_json || [];
      const examples = level.example_songs || [];

      return `
        <div class="level-admin-card">
          <div class="level-admin-header">
            <div>
              <div class="level-admin-title">
                Level ${level.level_number}${level.is_branch ? ` - ${level.branch_name}` : ''}: ${level.name}
              </div>
              <div class="level-admin-meta">
                ${level.instruments.icon} ${level.instruments.name}
              </div>
            </div>
            <div class="level-admin-actions">
              <button class="btn btn-secondary btn-sm" onclick="app.editLevel('${level.id}')">Edit Details</button>
            </div>
          </div>
          <div class="level-admin-description">${level.description}</div>
          ${skills.length > 0 ? `
            <div class="level-admin-skills">
              <h4>Skills</h4>
              <ul>
                ${skills.map(skill => `<li>${skill}</li>`).join('')}
              </ul>
            </div>
          ` : ''}
          ${examples.length > 0 ? `
            <div class="level-admin-meta">
              <strong>Example Songs:</strong> ${examples.join(', ')}
            </div>
          ` : ''}
        </div>
      `;
    }).join('');

    container.innerHTML = html;
  }

  async editLevel(levelId) {
    const level = this.adminLevels.find(l => l.id === levelId);
    if (!level) return;

    // Populate form
    document.getElementById('edit-level-name').value = level.name;
    document.getElementById('edit-level-description').value = level.description;
    document.getElementById('edit-level-skills').value = (level.skills_json || []).join('\n');
    document.getElementById('edit-level-examples').value = (level.example_songs || []).join(', ');

    // Store level ID for form submission
    document.getElementById('edit-level-form').dataset.levelId = levelId;

    document.getElementById('edit-level-modal').classList.remove('hidden');
  }

  // ============================================
  // ADMIN: Instruments Management
  // ============================================

  renderAdminInstruments() {
    const container = document.getElementById('instruments-admin-list');
    if (!container) return;

    const html = this.instruments.map(inst => {
      // Count levels for this instrument
      const levelCount = this.adminLevels?.filter(l => l.instrument_id === inst.id).length || 0;

      return `
        <div class="instrument-admin-card">
          <div class="instrument-admin-header">
            <div class="instrument-admin-info">
              <div class="instrument-admin-icon">${inst.icon}</div>
              <div>
                <div class="instrument-admin-name">${inst.name}</div>
                <div class="instrument-admin-order">Display Order: ${inst.display_order}</div>
              </div>
            </div>
            <div class="instrument-admin-actions">
              <button class="btn btn-secondary btn-sm" onclick="app.editInstrument('${inst.id}')">Edit</button>
            </div>
          </div>
          <div class="instrument-admin-description">${inst.description}</div>
          <div class="instrument-admin-stats">
            <span>${levelCount} levels configured</span>
          </div>
        </div>
      `;
    }).join('');

    container.innerHTML = html;
  }

  showAddInstrumentModal() {
    document.getElementById('instrument-modal-title').textContent = 'Add Instrument';
    document.getElementById('instrument-form').reset();
    document.getElementById('instrument-form').dataset.instrumentId = '';
    document.getElementById('instrument-modal').classList.remove('hidden');
  }

  async editInstrument(instrumentId) {
    const inst = this.instruments.find(i => i.id === instrumentId);
    if (!inst) return;

    document.getElementById('instrument-modal-title').textContent = 'Edit Instrument';
    document.getElementById('instrument-name').value = inst.name;
    document.getElementById('instrument-icon').value = inst.icon;
    document.getElementById('instrument-description').value = inst.description;
    document.getElementById('instrument-order').value = inst.display_order;
    document.getElementById('instrument-form').dataset.instrumentId = instrumentId;

    document.getElementById('instrument-modal').classList.remove('hidden');
  }

  // ============================================
  // ADMIN: Content Moderation (Songs)
  // ============================================

  async loadContentModeration() {
    const statusFilter = document.getElementById('content-filter-status')?.value || 'all';

    let query = supabase
      .from('songs')
      .select('*, users(name), instruments(icon, name)')
      .order('created_at', { ascending: false });

    if (statusFilter === 'approved') {
      query = query.eq('approved', true);
    } else if (statusFilter === 'pending') {
      query = query.eq('approved', false);
    }

    const { data, error } = await query.limit(100);

    if (error) {
      console.error('Error loading content moderation:', error);
      return;
    }

    this.adminContentList = data;
    this.renderContentModeration();
  }

  renderContentModeration() {
    const container = document.getElementById('content-moderation-list');
    if (!container) return;

    if (!this.adminContentList || this.adminContentList.length === 0) {
      container.innerHTML = '<p style="color: var(--text-secondary); text-align: center; padding: 3rem;">No songs found</p>';
      return;
    }

    // Filter by search term
    const searchTerm = document.getElementById('content-search')?.value?.toLowerCase() || '';
    const filteredList = this.adminContentList.filter(song => {
      if (!searchTerm) return true;
      return song.title?.toLowerCase().includes(searchTerm) ||
             song.artist?.toLowerCase().includes(searchTerm) ||
             song.users?.name?.toLowerCase().includes(searchTerm);
    });

    if (filteredList.length === 0) {
      container.innerHTML = '<p style="color: var(--text-secondary); text-align: center; padding: 3rem;">No songs match your search</p>';
      return;
    }

    const html = filteredList.map(song => {
      const statusClass = song.approved ? 'approved' : 'pending';
      const statusText = song.approved ? 'Approved' : 'Pending';

      return `
        <div class="content-mod-card ${statusClass}">
          <div class="content-mod-header">
            <div>
              <div class="content-mod-title">${song.title}</div>
              <div class="content-mod-meta">${song.artist} • Added by ${song.users?.name || 'Unknown'}</div>
            </div>
            <span class="content-mod-status ${statusClass}">${statusText}</span>
          </div>
          <div class="content-mod-details">
            <div class="content-mod-detail-item">
              <div class="content-mod-detail-label">Instrument</div>
              <div class="content-mod-detail-value">${song.instruments?.icon || ''} ${song.instruments?.name || 'N/A'}</div>
            </div>
            <div class="content-mod-detail-item">
              <div class="content-mod-detail-label">Resources</div>
              <div class="content-mod-detail-value">
                ${song.chords_url ? '✓ Chords ' : ''}
                ${song.bass_tab_url ? '✓ Bass Tab ' : ''}
                ${song.drum_notation_url ? '✓ Drum Notation ' : ''}
                ${song.tutorial_url ? '✓ Tutorial ' : ''}
                ${song.youtube_url ? '✓ YouTube' : ''}
              </div>
            </div>
            <div class="content-mod-detail-item">
              <div class="content-mod-detail-label">Added</div>
              <div class="content-mod-detail-value">${new Date(song.created_at).toLocaleDateString()}</div>
            </div>
          </div>
          <div class="content-mod-actions">
            <button class="btn btn-secondary btn-sm" onclick="event.stopPropagation(); app.editSongDetails('${song.id}', '${song.title.replace(/'/g, "\\'")}', '${song.artist.replace(/'/g, "\\'")}', ${song.suggested_level || 'null'})" title="Edit song details">Edit Details</button>
            <button class="btn btn-secondary btn-sm" onclick="app.moderateSong('${song.id}')">Moderate</button>
          </div>
        </div>
      `;
    }).join('');

    container.innerHTML = html;
  }

  async moderateSong(songId) {
    const song = this.adminContentList.find(s => s.id === songId);
    if (!song) return;

    this.currentModeratingSongId = songId;

    const details = `
      <div style="margin-bottom: 1rem;">
        <h3 style="margin-bottom: 0.5rem;">${song.title}</h3>
        <p style="color: var(--text-secondary);">${song.artist}</p>
      </div>
      <div style="display: grid; gap: 0.75rem; margin-bottom: 1rem;">
        <div><strong>Instrument:</strong> ${song.instruments?.icon || ''} ${song.instruments?.name || 'N/A'}</div>
        <div><strong>Added by:</strong> ${song.users?.name || 'Unknown'}</div>
        <div><strong>Status:</strong> ${song.approved ? 'Approved' : 'Pending'}</div>
        ${song.chords_url ? `<div><strong>Chords:</strong> <a href="${song.chords_url}" target="_blank">Link</a></div>` : ''}
        ${song.bass_tab_url ? `<div><strong>Bass Tab:</strong> <a href="${song.bass_tab_url}" target="_blank">Link</a></div>` : ''}
        ${song.drum_notation_url ? `<div><strong>Drum Notation:</strong> <a href="${song.drum_notation_url}" target="_blank">Link</a></div>` : ''}
        ${song.tutorial_url ? `<div><strong>Tutorial:</strong> <a href="${song.tutorial_url}" target="_blank">Link</a></div>` : ''}
        ${song.youtube_url ? `<div><strong>YouTube:</strong> <a href="${song.youtube_url}" target="_blank">Link</a></div>` : ''}
      </div>
    `;

    document.getElementById('admin-song-details').innerHTML = details;
    document.getElementById('admin-song-modal').classList.remove('hidden');
  }

  // ============================================
  // Merge Duplicate Songs
  // ============================================

  async scanForDuplicates() {
    const container = document.getElementById('duplicates-list');
    if (!container) return;

    const btn = document.getElementById('scan-duplicates-btn');
    const section = document.getElementById('duplicates-section');

    // Show the duplicates section and scroll to it
    if (section) {
      section.classList.remove('hidden');
      section.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }

    // Disable button while scanning
    if (btn) {
      btn.disabled = true;
      btn.textContent = 'Scanning...';
    }

    container.innerHTML = '<p style="color: var(--text-secondary); text-align: center; padding: 3rem;">Scanning for duplicates...</p>';

    try {
      // Ensure songs are loaded so titles can open the song detail modal
      if (!this.songs || this.songs.length === 0) {
        await this.loadSongs();
      }

      const { data, error } = await this.callRpcDirect('find_duplicate_song_groups', {
        p_threshold: 0.65,
        p_limit: 50
      });

      if (error) {
        console.error('Error scanning for duplicates:', error);
        container.innerHTML = '<p style="color: var(--error-color); text-align: center; padding: 3rem;">Failed to scan for duplicates. The database function may need to be created first.</p>';
        return;
      }

      this.duplicatePairs = data || [];
      this.renderDuplicates();
    } catch (err) {
      console.error('Error scanning for duplicates:', err);
      container.innerHTML = '<p style="color: var(--error-color); text-align: center; padding: 3rem;">Failed to scan for duplicates. The database function may need to be created first.</p>';
    } finally {
      if (btn) {
        btn.disabled = false;
        btn.textContent = 'Scan for Duplicates';
      }
    }
  }

  renderDuplicates() {
    const container = document.getElementById('duplicates-list');
    if (!container) return;

    if (!this.duplicatePairs || this.duplicatePairs.length === 0) {
      container.innerHTML = '<p style="color: var(--text-secondary); text-align: center; padding: 3rem;">No potential duplicates found. Your song library is clean!</p>' +
        '<div class="back-to-top-container"><button class="btn btn-secondary back-to-top-btn" onclick="window.scrollTo({ top: 0, behavior: \'smooth\' })">&#8593; Back to Top</button></div>';
      return;
    }

    const html = this.duplicatePairs.map((pair, index) => {
      const scorePercent = Math.round(pair.similarity_score * 100);
      const scoreClass = scorePercent >= 70 ? 'high' : '';

      return `
        <div class="duplicate-pair-card">
          <div class="duplicate-pair-header">
            <span style="font-weight: 600;">Potential Duplicate #${index + 1}</span>
            <span class="duplicate-pair-score ${scoreClass}">${scorePercent}% similar</span>
          </div>
          <div class="duplicate-pair-songs">
            <div class="duplicate-song-info">
              <div class="duplicate-song-title"><a href="#" onclick="event.preventDefault(); app.viewSongDetails('${pair.song_id}')">${this.escapeHtml(pair.title)}</a></div>
              <div class="duplicate-song-artist">${this.escapeHtml(pair.artist)}</div>
              <div class="duplicate-song-stats">
                <span>${pair.rating_count || 0} ratings</span>
                <span>${pair.student_count || 0} students</span>
                <span>${pair.approved ? 'Approved' : 'Pending'}</span>
                <span>${[pair.youtube_url ? 'YT' : '', pair.chords_url ? 'Chords' : '', pair.bass_tab_url ? 'Bass' : '', pair.drum_notation_url ? 'Drums' : ''].filter(Boolean).join(', ') || 'No links'}</span>
              </div>
            </div>
            <div class="duplicate-pair-vs">VS</div>
            <div class="duplicate-song-info">
              <div class="duplicate-song-title"><a href="#" onclick="event.preventDefault(); app.viewSongDetails('${pair.match_song_id}')">${this.escapeHtml(pair.match_title)}</a></div>
              <div class="duplicate-song-artist">${this.escapeHtml(pair.match_artist)}</div>
              <div class="duplicate-song-stats">
                <span>Song B</span>
              </div>
            </div>
          </div>
          <div class="duplicate-pair-actions">
            <button class="btn btn-secondary btn-sm" onclick="app.dismissDuplicatePair('${pair.song_id}', '${pair.match_song_id}', this)">Not Duplicates</button>
            <button class="btn btn-primary btn-sm" onclick="app.showMergeModal('${pair.song_id}', '${pair.match_song_id}')">Review & Merge</button>
          </div>
        </div>
      `;
    }).join('');

    container.innerHTML = html + `
      <div class="back-to-top-container">
        <button class="btn btn-secondary back-to-top-btn" onclick="window.scrollTo({ top: 0, behavior: 'smooth' })">&#8593; Back to Top</button>
      </div>
    `;
  }

  async dismissDuplicatePair(songIdA, songIdB, buttonEl) {
    const card = buttonEl.closest('.duplicate-pair-card');
    try {
      buttonEl.disabled = true;
      buttonEl.textContent = 'Dismissing...';

      const { data, error } = await this.callRpcDirect('dismiss_duplicate_pair', {
        p_song_id_a: songIdA,
        p_song_id_b: songIdB
      });

      if (error) {
        console.error('Error dismissing duplicate pair:', error);
        this.showToast('Failed to dismiss pair', 'error');
        buttonEl.disabled = false;
        buttonEl.textContent = 'Not Duplicates';
        return;
      }

      // Animate the card out and remove from list
      card.style.transition = 'opacity 0.3s, transform 0.3s';
      card.style.opacity = '0';
      card.style.transform = 'translateX(20px)';
      setTimeout(() => {
        card.remove();
        // Remove from in-memory list too
        this.duplicatePairs = this.duplicatePairs.filter(
          p => !(p.song_id === songIdA && p.match_song_id === songIdB)
        );
        // Show empty state if none left
        if (this.duplicatePairs.length === 0) {
          const container = document.getElementById('duplicates-list');
          if (container) {
            container.innerHTML = '<p style="color: var(--text-secondary); text-align: center; padding: 3rem;">No potential duplicates found. Your song library is clean!</p>';
          }
        }
      }, 300);

      this.showToast('Pair dismissed as separate songs', 'success');
    } catch (err) {
      console.error('Error dismissing duplicate pair:', err);
      this.showToast('Failed to dismiss pair', 'error');
      buttonEl.disabled = false;
      buttonEl.textContent = 'Not Duplicates';
    }
  }

  async showMergeModal(songIdA, songIdB) {
    // Fetch full details for both songs
    const [resultA, resultB] = await Promise.all([
      supabase.from('songs').select('*').eq('id', songIdA).single(),
      supabase.from('songs').select('*').eq('id', songIdB).single()
    ]);

    if (resultA.error || resultB.error) {
      this.showToast('Failed to load song details', 'error');
      return;
    }

    const songA = resultA.data;
    const songB = resultB.data;

    // Get counts for both songs
    const [ratingsA, ratingsB, studentsA, studentsB] = await Promise.all([
      supabase.from('song_ratings').select('id', { count: 'exact', head: true }).eq('song_id', songIdA),
      supabase.from('song_ratings').select('id', { count: 'exact', head: true }).eq('song_id', songIdB),
      supabase.from('student_songs').select('id', { count: 'exact', head: true }).eq('song_id', songIdA),
      supabase.from('student_songs').select('id', { count: 'exact', head: true }).eq('song_id', songIdB)
    ]);

    this.mergeCandidate = { songA, songB };
    this.mergeKeepId = songA.id; // Default to keeping song A

    const buildSongCard = (song, counts, label) => {
      const ratingCount = counts.ratings || 0;
      const studentCount = counts.students || 0;
      const links = [
        song.youtube_url ? 'YouTube' : '',
        song.chords_url ? 'Chords' : '',
        song.bass_tab_url ? 'Bass Tab' : '',
        song.drum_notation_url ? 'Drum Notation' : '',
        song.tutorial_url ? 'Tutorial' : ''
      ].filter(Boolean);

      return `
        <div class="merge-song-option ${song.id === this.mergeKeepId ? 'selected' : ''}"
             data-song-id="${song.id}" onclick="app.selectMergeKeep('${song.id}')">
          <div class="merge-keep-badge">KEEP THIS SONG</div>
          <div class="merge-delete-badge">WILL BE MERGED & DELETED</div>
          <div class="merge-song-name">${this.escapeHtml(song.title)}</div>
          <div class="merge-song-artist">${this.escapeHtml(song.artist)}</div>
          <div class="merge-song-detail">
            <span class="merge-song-detail-label">Status</span>
            <span class="merge-song-detail-value">${song.approved ? 'Approved' : 'Pending'}</span>
          </div>
          <div class="merge-song-detail">
            <span class="merge-song-detail-label">Ratings</span>
            <span class="merge-song-detail-value">${ratingCount}</span>
          </div>
          <div class="merge-song-detail">
            <span class="merge-song-detail-label">Students tracking</span>
            <span class="merge-song-detail-value">${studentCount}</span>
          </div>
          <div class="merge-song-detail">
            <span class="merge-song-detail-label">Resource links</span>
            <span class="merge-song-detail-value">${links.length > 0 ? links.join(', ') : 'None'}</span>
          </div>
          <div class="merge-song-detail">
            <span class="merge-song-detail-label">Added</span>
            <span class="merge-song-detail-value">${new Date(song.created_at).toLocaleDateString()}</span>
          </div>
        </div>
      `;
    };

    const comparison = document.getElementById('merge-songs-comparison');
    comparison.innerHTML =
      buildSongCard(songA, { ratings: ratingsA.count, students: studentsA.count }, 'Song A') +
      buildSongCard(songB, { ratings: ratingsB.count, students: studentsB.count }, 'Song B');

    document.getElementById('confirm-merge-btn').disabled = false;
    document.getElementById('merge-songs-modal').classList.remove('hidden');
  }

  selectMergeKeep(songId) {
    this.mergeKeepId = songId;

    // Update UI
    document.querySelectorAll('.merge-song-option').forEach(option => {
      option.classList.toggle('selected', option.dataset.songId === songId);
    });
  }

  async executeMerge() {
    if (!this.mergeCandidate || !this.mergeKeepId) return;

    const keepId = this.mergeKeepId;
    const deleteId = keepId === this.mergeCandidate.songA.id
      ? this.mergeCandidate.songB.id
      : this.mergeCandidate.songA.id;

    const keepSong = keepId === this.mergeCandidate.songA.id
      ? this.mergeCandidate.songA
      : this.mergeCandidate.songB;
    const deleteSong = deleteId === this.mergeCandidate.songA.id
      ? this.mergeCandidate.songA
      : this.mergeCandidate.songB;

    if (!confirm(`Are you sure you want to merge "${deleteSong.title}" by ${deleteSong.artist} into "${keepSong.title}" by ${keepSong.artist}? This cannot be undone.`)) {
      return;
    }

    document.getElementById('confirm-merge-btn').disabled = true;
    document.getElementById('confirm-merge-btn').textContent = 'Merging...';

    try {
      const { data, error } = await this.callRpcDirect('merge_songs', {
        p_keep_song_id: keepId,
        p_delete_song_id: deleteId
      });

      if (error) {
        console.error('Error merging songs:', error);
        this.showToast('Failed to merge songs: ' + (error.message || 'Unknown error'), 'error');
        return;
      }

      const result = typeof data === 'string' ? JSON.parse(data) : data;

      if (result?.success) {
        document.getElementById('merge-songs-modal').classList.add('hidden');
        this.showToast(result.message || 'Songs merged successfully', 'success');

        // Remove the merged pair from the list and re-render
        this.duplicatePairs = (this.duplicatePairs || []).filter(p =>
          p.song_id !== deleteId && p.match_song_id !== deleteId
        );
        this.renderDuplicates();
      } else {
        this.showToast(result?.message || 'Failed to merge songs', 'error');
      }
    } catch (err) {
      console.error('Error merging songs:', err);
      this.showToast('Failed to merge songs: ' + (err.message || 'Unknown error'), 'error');
    } finally {
      const btn = document.getElementById('confirm-merge-btn');
      if (btn) {
        btn.disabled = false;
        btn.textContent = 'Merge Songs';
      }
    }
  }

  // ============================================
  // ADMIN: User Management
  // ============================================

  async loadUsersManagement() {
    const roleFilter = document.getElementById('user-filter-role')?.value || '';

    let query = supabase
      .from('users')
      .select('*')
      .order('created_at', { ascending: false });

    if (roleFilter) {
      query = query.eq('role', roleFilter);
    }

    const { data, error } = await query.limit(200);

    if (error) {
      console.error('Error loading users:', error);
      return;
    }

    this.adminUsersList = data;
    this.renderUsersManagement();
  }

  renderUsersManagement() {
    const container = document.getElementById('users-list');
    if (!container) return;

    let users = this.adminUsersList || [];

    // Apply search filter
    const searchTerm = document.getElementById('user-search')?.value.toLowerCase();
    if (searchTerm) {
      users = users.filter(u =>
        u.name.toLowerCase().includes(searchTerm) ||
        u.email.toLowerCase().includes(searchTerm)
      );
    }

    if (users.length === 0) {
      container.innerHTML = '<p style="color: var(--text-secondary); text-align: center; padding: 3rem;">No users found</p>';
      return;
    }

    const html = users.map(user => {
      return `
        <div class="user-admin-card">
          <div class="user-admin-info">
            <div class="user-admin-name">${user.name}</div>
            <div class="user-admin-email">${user.email}</div>
          </div>
          <div class="user-admin-meta">
            <span class="user-role-badge ${user.role}">${user.role.charAt(0).toUpperCase() + user.role.slice(1)}</span>
            ${user.role === 'student' ? `<button class="btn btn-secondary btn-sm" onclick="app.showAdminAddToClassModal('${user.id}', '${user.name.replace(/'/g, "\\'")}')">Add to Class</button>` : ''}
            <button class="btn btn-secondary btn-sm" onclick="app.editUserRole('${user.id}', '${user.name}', '${user.role}')">Change Role</button>
          </div>
        </div>
      `;
    }).join('');

    container.innerHTML = html;
  }

  editUserRole(userId, userName, currentRole) {
    this.currentEditingUserId = userId;
    document.getElementById('edit-user-info').textContent = `Editing role for: ${userName}`;
    document.getElementById('user-role-select').value = currentRole;
    document.getElementById('edit-user-role-modal').classList.remove('hidden');
  }

  async showAdminAddToClassModal(userId, userName) {
    this.adminAddStudentId = userId;
    document.getElementById('admin-add-student-name').textContent = userName;

    const select = document.getElementById('admin-add-student-class-select');
    select.innerHTML = '<option value="">Loading classes...</option>';

    document.getElementById('admin-add-student-to-class-modal').classList.remove('hidden');

    try {
      const user = auth.getCurrentUser();
      const result = await this.callRpcDirect('get_teacher_classes', {
        p_teacher_id: user.id,
        p_include_archived: false
      });
      const classes = result.data || [];

      select.innerHTML = '<option value="">-- Select a class --</option>';
      classes
        .sort((a, b) => a.name.localeCompare(b.name, undefined, { sensitivity: 'base' }))
        .forEach(cls => {
          const option = document.createElement('option');
          option.value = cls.id;
          option.textContent = cls.teacher_name ? `${cls.name} (${cls.teacher_name})` : cls.name;
          select.appendChild(option);
        });

      if (classes.length === 0) {
        select.innerHTML = '<option value="">No classes available</option>';
      }
    } catch (error) {
      console.error('Error loading classes for admin add:', error);
      select.innerHTML = '<option value="">Error loading classes</option>';
    }
  }

  async executeAdminAddToClass() {
    const studentId = this.adminAddStudentId;
    const classId = document.getElementById('admin-add-student-class-select').value;

    if (!studentId || !classId) {
      this.showToast('Please select a class', 'error');
      return;
    }

    try {
      const { data } = await this.callRpcDirect('admin_add_student_to_class', {
        p_student_id: studentId,
        p_class_id: classId
      });

      if (data.success) {
        document.getElementById('admin-add-student-to-class-modal').classList.add('hidden');
        this.showToast(data.message, 'success');
      } else {
        this.showToast(data.message || 'Failed to add student to class', 'error');
      }
    } catch (error) {
      console.error('Error adding student to class:', error);
      this.showToast('An unexpected error occurred', 'error');
    }
  }

  setupAdminForms() {
    // Edit Level Form
    const editLevelForm = document.getElementById('edit-level-form');
    if (editLevelForm) {
      editLevelForm.addEventListener('submit', async (e) => {
        e.preventDefault();
        const levelId = editLevelForm.dataset.levelId;
        const name = document.getElementById('edit-level-name').value;
        const description = document.getElementById('edit-level-description').value;
        const skillsText = document.getElementById('edit-level-skills').value;
        const examplesText = document.getElementById('edit-level-examples').value;

        const skills = skillsText.split('\n').filter(s => s.trim());
        const examples = examplesText.split(',').map(s => s.trim()).filter(s => s);

        const { error } = await supabase
          .from('levels')
          .update({
            name,
            description,
            skills_json: skills,
            example_songs: examples
          })
          .eq('id', levelId);

        if (error) {
          console.error('Error updating level:', error);
          this.showToast('Failed to update level', 'error');
          return;
        }

        document.getElementById('edit-level-modal').classList.add('hidden');
        this.showToast('Level updated successfully', 'success');
        await this.loadAdminLevels();
        this.renderAdminLevels();
      });
    }

    // Instrument Form
    const instrumentForm = document.getElementById('instrument-form');
    if (instrumentForm) {
      instrumentForm.addEventListener('submit', async (e) => {
        e.preventDefault();

        const instrumentId = instrumentForm.dataset.instrumentId;
        const name = document.getElementById('instrument-name').value;
        const icon = document.getElementById('instrument-icon').value;
        const description = document.getElementById('instrument-description').value;
        const displayOrder = parseInt(document.getElementById('instrument-order').value);

        if (instrumentId) {
          // Update existing instrument
          const { error } = await supabase
            .from('instruments')
            .update({ name, icon, description, display_order: displayOrder })
            .eq('id', instrumentId);

          if (error) {
            console.error('Error updating instrument:', error);
            this.showToast('Failed to update instrument', 'error');
            return;
          }

          this.showToast('Instrument updated successfully', 'success');
        } else {
          // Add new instrument
          const { error } = await supabase
            .from('instruments')
            .insert([{ name, icon, description, display_order: displayOrder }]);

          if (error) {
            console.error('Error adding instrument:', error);
            this.showToast('Failed to add instrument', 'error');
            return;
          }

          this.showToast('Instrument added successfully', 'success');
        }

        document.getElementById('instrument-modal').classList.add('hidden');
        await this.loadInstruments();
        this.renderAdminInstruments();
      });
    }

    // Edit User Role Form
    const editUserRoleForm = document.getElementById('edit-user-role-form');
    if (editUserRoleForm) {
      editUserRoleForm.addEventListener('submit', async (e) => {
        e.preventDefault();

        const newRole = document.getElementById('user-role-select').value;

        // Use RPC function to bypass RLS restrictions
        let data;
        try {
          const result = await this.callRpcDirect('change_user_role', {
            p_user_id: this.currentEditingUserId,
            p_new_role: newRole
          });
          data = result.data;
        } catch (error) {
          console.error('Error updating user role:', error);
          this.showToast('Failed to update user role', 'error');
          return;
        }

        if (data && data.success) {
          document.getElementById('edit-user-role-modal').classList.add('hidden');
          this.showToast(`${data.name}'s role updated to ${data.new_role}`, 'success');
          await this.loadUsersManagement();
        } else {
          this.showToast(data?.message || 'Failed to update user role', 'error');
        }
      });
    }
  }

  // ============================================
  // ACCOUNT MANAGEMENT (Teachers & Admins)
  // ============================================

  async loadAccountsData() {
    await Promise.all([
      this.loadManageableUsers(),
      this.loadPendingTeacherAccounts()
    ]);
  }

  async loadManageableUsers() {
    // Use direct RPC call to bypass stale connections
    let data;
    try {
      const result = await this.callRpcDirect('get_manageable_users', {});
      data = result.data;
    } catch (error) {
      console.error('Error loading manageable users:', error);
      this.manageableUsers = [];
      return;
    }

    this.manageableUsers = data || [];
    this.renderAccountsList();
  }

  async loadPendingTeacherAccounts() {
    // Use direct fetch to bypass stale Supabase client connections
    const { data, error } = await this.callSelectDirect(
      'pre_registered_accounts',
      '*',
      {},
      { order: 'created_at.desc' }
    );

    if (error) {
      console.error('Error loading pending accounts:', error);
      this.pendingTeacherAccounts = [];
      return;
    }

    this.pendingTeacherAccounts = data || [];
    this.renderPendingAccounts();
  }

  renderPendingAccounts() {
    const container = document.getElementById('pending-accounts-list');
    if (!container) return;

    const section = document.getElementById('pending-accounts-section');

    if (!this.pendingTeacherAccounts || this.pendingTeacherAccounts.length === 0) {
      if (section) section.classList.add('hidden');
      return;
    }

    if (section) section.classList.remove('hidden');

    const html = this.pendingTeacherAccounts.map(account => `
      <div class="account-card">
        <div class="account-info">
          <div class="account-name">${account.name || 'Not specified'}</div>
          <div class="account-email">${account.email}</div>
        </div>
        <div class="account-meta">
          <span class="user-role-badge teacher">Teacher (Pending)</span>
          <button class="btn btn-text btn-sm" style="color: var(--error-color);" onclick="app.removePendingTeacherAccount('${account.id}')">Remove</button>
        </div>
      </div>
    `).join('');

    container.innerHTML = html;
  }

  renderAccountsList() {
    const container = document.getElementById('accounts-list');
    if (!container) return;

    let users = this.manageableUsers || [];
    const currentUserRole = auth.getCurrentUser()?.role;

    // Apply search filter
    const searchTerm = document.getElementById('accounts-search')?.value?.toLowerCase();
    if (searchTerm) {
      users = users.filter(u =>
        u.name.toLowerCase().includes(searchTerm) ||
        u.email.toLowerCase().includes(searchTerm)
      );
    }

    // Apply role filter
    const roleFilter = document.getElementById('accounts-role-filter')?.value;
    if (roleFilter) {
      users = users.filter(u => u.role === roleFilter);
    }

    // Update title based on role
    const title = document.getElementById('accounts-list-title');
    if (title) {
      title.textContent = currentUserRole === 'admin' ? 'All Accounts' : 'Student Accounts';
    }

    // Show/hide role filter based on whether there are multiple roles
    const roleFilterEl = document.getElementById('accounts-role-filter');
    if (roleFilterEl) {
      roleFilterEl.classList.toggle('hidden', currentUserRole !== 'admin');
    }

    if (users.length === 0) {
      container.innerHTML = '<p style="color: var(--text-secondary); text-align: center; padding: 3rem;">No accounts found</p>';
      return;
    }

    const html = users.map(user => {
      // Determine if current user can delete this account
      const canDelete = (user.role === 'student' && (currentUserRole === 'teacher' || currentUserRole === 'admin'))
        || (user.role === 'teacher' && currentUserRole === 'admin');

      // Admins can promote students to teachers
      const canPromote = currentUserRole === 'admin' && user.role === 'student';

      return `
        <div class="account-card">
          <div class="account-info">
            <div class="account-name">${user.name}</div>
            <div class="account-email">${user.email}</div>
          </div>
          <div class="account-meta">
            <span class="user-role-badge ${user.role}">${user.role.charAt(0).toUpperCase() + user.role.slice(1)}</span>
            ${canPromote ? `<button class="btn btn-secondary btn-sm" onclick="app.confirmPromoteToTeacher('${user.id}', '${user.name.replace(/'/g, "\\'")}')">Promote to Teacher</button>` : ''}
            ${canDelete ? `<button class="btn btn-danger btn-sm" onclick="app.confirmDeleteAccount('${user.id}', '${user.name.replace(/'/g, "\\'")}', '${user.role}')">Delete</button>` : ''}
          </div>
        </div>
      `;
    }).join('');

    container.innerHTML = html;
  }

  showCreateTeacherModal() {
    document.getElementById('new-teacher-email').value = '';
    document.getElementById('new-teacher-name').value = '';
    document.getElementById('create-teacher-modal').classList.remove('hidden');
  }

  async createTeacherAccount() {
    // Only admins can create teacher accounts
    if (auth.getCurrentUser()?.role !== 'admin') {
      this.showToast('Only admins can create teacher accounts', 'error');
      return;
    }

    const email = document.getElementById('new-teacher-email').value.trim().toLowerCase();
    const name = document.getElementById('new-teacher-name').value.trim();

    if (!email) {
      this.showToast('Please enter an email address', 'error');
      return;
    }

    // Check if user already exists
    const existingUser = this.manageableUsers?.find(u => u.email.toLowerCase() === email);
    if (existingUser) {
      this.showToast('A user with this email already exists', 'error');
      return;
    }

    // Check if already pre-registered
    const existingPending = this.pendingTeacherAccounts?.find(a => a.email.toLowerCase() === email);
    if (existingPending) {
      this.showToast('This email has already been pre-registered', 'error');
      return;
    }

    const { error } = await supabase
      .from('pre_registered_accounts')
      .insert([{
        email: email,
        role: 'teacher',
        name: name || null,
        created_by: auth.getCurrentUser().id
      }]);

    if (error) {
      console.error('Error creating teacher account:', error);
      if (error.code === '23505') {
        this.showToast('This email has already been pre-registered', 'error');
      } else {
        this.showToast('Failed to create teacher account', 'error');
      }
      return;
    }

    document.getElementById('create-teacher-modal').classList.add('hidden');
    this.showToast('Teacher account created. They will be assigned the teacher role when they sign in.', 'success');
    await this.loadPendingTeacherAccounts();
  }

  async removePendingTeacherAccount(accountId) {
    // Only admins can manage pending teacher accounts
    if (auth.getCurrentUser()?.role !== 'admin') {
      this.showToast('Only admins can manage pending teacher accounts', 'error');
      return;
    }

    const { error } = await supabase
      .from('pre_registered_accounts')
      .delete()
      .eq('id', accountId);

    if (error) {
      console.error('Error removing pending account:', error);
      this.showToast('Failed to remove pending account', 'error');
      return;
    }

    this.showToast('Pending account removed', 'success');
    await this.loadPendingTeacherAccounts();
  }

  confirmDeleteAccount(userId, userName, userRole) {
    document.getElementById('delete-account-id').value = userId;
    document.getElementById('delete-account-info').innerHTML =
      `<strong>${userName}</strong> (${userRole.charAt(0).toUpperCase() + userRole.slice(1)})`;
    document.getElementById('delete-account-modal').classList.remove('hidden');
  }

  async deleteUserAccount() {
    const userId = document.getElementById('delete-account-id').value;

    if (!userId) {
      this.showToast('No user selected', 'error');
      return;
    }

    // Use direct RPC call to bypass stale Supabase client connections
    let data;
    try {
      const result = await this.callRpcDirect('delete_user_account', {
        p_user_id: userId
      });
      data = result.data;
    } catch (error) {
      console.error('Error deleting user account:', error);
      this.showToast('Failed to delete account', 'error');
      return;
    }

    if (data && data.success) {
      document.getElementById('delete-account-modal').classList.add('hidden');
      this.showToast(`Account for ${data.name} deleted successfully`, 'success');
      await this.loadManageableUsers();
    } else {
      this.showToast(data?.message || 'Failed to delete account', 'error');
    }
  }

  confirmPromoteToTeacher(userId, userName) {
    document.getElementById('promote-account-id').value = userId;
    document.getElementById('promote-account-info').innerHTML =
      `<strong>${userName}</strong>`;
    document.getElementById('promote-teacher-modal').classList.remove('hidden');
  }

  async promoteToTeacher() {
    const userId = document.getElementById('promote-account-id').value;

    if (!userId) {
      this.showToast('No user selected', 'error');
      return;
    }

    // Use direct RPC call to promote user
    let data;
    try {
      const result = await this.callRpcDirect('promote_to_teacher', {
        p_user_id: userId
      });
      data = result.data;
    } catch (error) {
      console.error('Error promoting user to teacher:', error);
      this.showToast('Failed to promote user', 'error');
      return;
    }

    if (data && data.success) {
      document.getElementById('promote-teacher-modal').classList.add('hidden');
      this.showToast(`${data.name} has been promoted to teacher`, 'success');
      await this.loadManageableUsers();
    } else {
      this.showToast(data?.message || 'Failed to promote user', 'error');
    }
  }

  async approveSong(approved) {
    const { error } = await supabase
      .from('songs')
      .update({ approved })
      .eq('id', this.currentModeratingSongId);

    if (error) {
      console.error('Error updating song approval:', error);
      this.showToast('Failed to update song', 'error');
      return;
    }

    document.getElementById('admin-song-modal').classList.add('hidden');
    this.showToast(`Song ${approved ? 'approved' : 'unapproved'} successfully`, 'success');
    await this.loadContentModeration();
  }

  async deleteSong() {
    if (!confirm('Are you sure you want to delete this song? This action cannot be undone.')) {
      return;
    }

    const { error } = await supabase
      .from('songs')
      .delete()
      .eq('id', this.currentModeratingSongId);

    if (error) {
      console.error('Error deleting song:', error);
      this.showToast('Failed to delete song', 'error');
      return;
    }

    document.getElementById('admin-song-modal').classList.add('hidden');
    this.showToast('Song deleted successfully', 'success');
    await this.loadContentModeration();
  }

  // ============================================
  // STUDENT RESOURCES (tutorials, links, files)
  // ============================================

  setupResourceModals() {
    // Add Resource form
    const addResourceForm = document.getElementById('add-resource-form');
    if (addResourceForm) {
      addResourceForm.addEventListener('submit', async (e) => {
        e.preventDefault();
        await this.submitStudentResource();
      });
    }
  }

  async showSongResourcesModal(songId, instrumentId) {
    const song = this.songs.find(s => s.id === songId);
    if (!song) {
      console.error('Song not found:', songId);
      return;
    }

    // Store current song for adding resources
    this.currentResourceSong = song;

    // Update modal title and info
    document.getElementById('song-resources-title').textContent = `Resources for ${song.title}`;
    document.getElementById('song-resources-info').textContent = `${song.title} - ${song.artist}`;

    // Show "View Song Card" button for teachers/admins so they can navigate to the song in the library
    const viewSongCardBtn = document.getElementById('view-song-card-btn');
    if (viewSongCardBtn) {
      if (auth.hasRole('teacher') || auth.hasRole('admin')) {
        viewSongCardBtn.classList.remove('hidden');
        viewSongCardBtn.dataset.songId = song.id;
      } else {
        viewSongCardBtn.classList.add('hidden');
      }
    }

    // If no instrument passed, try to get selected instrument from the song card dropdown
    if (!instrumentId) {
      const card = document.querySelector(`.song-card[data-song-id="${songId}"]`);
      const select = card?.querySelector('.song-instrument-select');
      instrumentId = select?.value;
    }

    // Populate instrument filter dropdown
    const filterSelect = document.getElementById('resources-instrument-filter');
    if (filterSelect && this.instruments) {
      // Only show instruments that this song has been graded for
      const ratedInstrumentIds = [...new Set((song.song_ratings || []).map(r => r.instrument_id))];
      const gradedInstruments = this.instruments.filter(i => ratedInstrumentIds.includes(i.id));
      const instrumentsToShow = gradedInstruments.length > 0 ? gradedInstruments : this.instruments;

      filterSelect.innerHTML = instrumentsToShow.map(i =>
        `<option value="${i.id}">${i.icon} ${i.name}</option>`
      ).join('');

      // Default to passed instrument first, then current instrument, then first option
      const preferredInstrumentId = instrumentId || this.currentInstrument;
      if (preferredInstrumentId) {
        filterSelect.value = preferredInstrumentId;
      }
      // else: leave the select at its first option (first graded instrument)
    }

    // Load resources
    await this.loadStudentResources(songId);

    // Show modal
    document.getElementById('song-resources-modal').classList.remove('hidden');
  }

  // Navigate from the song-resources-modal to the song's card in the Song Library
  goToSongCard() {
    const btn = document.getElementById('view-song-card-btn');
    const songId = btn?.dataset.songId;
    if (!songId) return;

    // Close open modals
    document.getElementById('song-resources-modal').classList.add('hidden');
    document.getElementById('student-detail-modal')?.classList.add('hidden');

    // Store the song ID so filterSongs() can scroll to it after rendering
    this._highlightSongId = songId;

    this.switchView('songs');
  }

  // Handle instrument filter change in resources modal
  async onResourcesInstrumentChange() {
    if (!this.currentResourceSong) return;

    // Reload resources with new instrument filter
    await this.loadStudentResources(this.currentResourceSong.id);
  }

  async loadStudentResources(songId) {
    const container = document.getElementById('student-resources-list');
    container.innerHTML = '<p style="color: var(--text-secondary);">Loading resources...</p>';

    try {
      const isTeacher = auth.hasRole('teacher') || auth.hasRole('admin');

      // Fetch all resources (tutorials, links, files) for this song
      let query = `select=id,title,description,file_url,file_type,status,user_id,instrument_id,created_at&song_id=eq.${songId}&order=created_at.desc`;

      // Filter by selected instrument: show resources for this instrument OR universal (null instrument_id)
      const filterInstrumentId = document.getElementById('resources-instrument-filter')?.value || this.currentInstrument;
      const filterInstrument = this.instruments?.find(i => i.id === filterInstrumentId);
      const filterInstrumentName = filterInstrument?.name || '';
      if (filterInstrumentId) {
        query += `&or=(instrument_id.is.null,instrument_id.eq.${filterInstrumentId})`;
      }

      const { data, error } = await this.rawSelect('student_resources', query);

      if (error) {
        console.error('Error loading resources:', error);
        container.innerHTML = '<p class="empty-resources">Failed to load resources</p>';
        return;
      }

      // Also include the song's legacy tutorial_url if no tutorial resources exist yet
      const song = this.currentResourceSong;
      const allResources = [...(data || [])];
      const hasTutorialResources = allResources.some(r => r.file_type === 'tutorial');
      if (song?.tutorial_url && !hasTutorialResources) {
        allResources.unshift({
          id: 'main-tutorial',
          title: 'Tutorial Video',
          description: null,
          file_url: song.tutorial_url,
          file_type: 'tutorial',
          status: 'approved',
          instrument_id: null,
          is_legacy: true
        });
      }

      // Add song-level chords/tab/notation URL (instrument-specific)
      const chordsUrlField = this.getChordsUrlField(filterInstrumentName);
      const chordsLabel = this.getChordsLabelForInstrument(filterInstrumentName);
      if (song?.[chordsUrlField]) {
        allResources.unshift({
          id: `song-${chordsUrlField}`,
          title: chordsLabel,
          description: null,
          file_url: song[chordsUrlField],
          file_type: 'link',
          status: 'approved',
          instrument_id: filterInstrumentId || null,
          is_song_url: true
        });
      }


      if (allResources.length === 0) {
        container.innerHTML = '<p class="empty-resources">No resources yet. Be the first to add one!</p>';
        return;
      }

      // Sort: song URLs first, then tutorials, then others
      allResources.sort((a, b) => {
        if (a.is_song_url && !b.is_song_url) return -1;
        if (!a.is_song_url && b.is_song_url) return 1;
        const aIsTutorial = a.file_type === 'tutorial' ? 0 : 1;
        const bIsTutorial = b.file_type === 'tutorial' ? 0 : 1;
        return aIsTutorial - bIsTutorial;
      });

      container.innerHTML = allResources.map(resource => {
        const icon = resource.file_type === 'tutorial' ? '🎬'
          : resource.file_type === 'image' ? '🖼️'
          : resource.file_type === 'pdf' ? '📄'
          : '🔗';

        const typeBadge = resource.file_type === 'tutorial'
          ? '<span class="resource-badge type-tutorial">Tutorial</span>'
          : '';

        const songLinkBadge = resource.is_song_url
          ? '<span class="resource-badge song-link">Song Link</span>'
          : '';

        const statusBadge = resource.status === 'pending'
          ? '<span class="resource-badge pending">Pending Approval</span>'
          : '';

        const instrument = resource.instrument_id
          ? this.instruments.find(i => i.id === resource.instrument_id)
          : null;
        const instrumentBadge = instrument
          ? `<span class="resource-badge instrument">${instrument.icon} ${instrument.name}</span>`
          : '<span class="resource-badge universal">All Instruments</span>';

        const approveButton = isTeacher && resource.status === 'pending'
          ? `<button class="btn btn-sm btn-primary" onclick="app.approveResource('${resource.id}')">Approve</button>`
          : '';

        const deleteButton = isTeacher && !resource.is_legacy && !resource.is_song_url
          ? `<button class="btn btn-sm btn-danger" onclick="app.deleteResource('${resource.id}')" title="Delete resource">Delete</button>`
          : '';

        const metaText = resource.is_song_url || resource.is_legacy ? 'Added during grading' : 'Shared by a student';

        return `
          <div class="resource-item ${resource.status === 'pending' ? 'pending' : ''}">
            <div class="resource-icon">${icon}</div>
            <div class="resource-content">
              <div class="resource-title">
                <a href="${resource.file_url}" target="_blank">${resource.title}</a>
                ${typeBadge}
                ${songLinkBadge}
                ${instrumentBadge}
                ${statusBadge}
              </div>
              ${resource.description ? `<div class="resource-description">${resource.description}</div>` : ''}
              <div class="resource-meta">${metaText}</div>
            </div>
            <div class="resource-actions">
              ${approveButton}
              ${deleteButton}
            </div>
          </div>
        `;
      }).join('');
    } catch (error) {
      console.error('Error loading resources:', error);
      container.innerHTML = '<p class="empty-resources">An error occurred</p>';
    }
  }

  showAddResourceModal() {
    if (!this.currentResourceSong) {
      this.showToast('Please select a song first', 'error');
      return;
    }

    document.getElementById('add-resource-song-info').textContent =
      `${this.currentResourceSong.title} - ${this.currentResourceSong.artist}`;

    // Show pending notice for students
    const isStudent = auth.hasRole('student');
    const pendingNotice = document.getElementById('resource-pending-notice');
    if (pendingNotice) {
      if (isStudent) {
        pendingNotice.classList.remove('hidden');
      } else {
        pendingNotice.classList.add('hidden');
      }
    }

    // Reset form
    document.getElementById('add-resource-form').reset();

    // Populate instrument dropdown
    const instrumentSelect = document.getElementById('resource-instrument');
    if (instrumentSelect && this.instruments) {
      instrumentSelect.innerHTML = '<option value="">All Instruments (Universal)</option>' +
        this.instruments.map(i =>
          `<option value="${i.id}">${i.icon} ${i.name}</option>`
        ).join('');

      // Pre-select the instrument from the filter dropdown (what user is currently viewing)
      const filterInstrumentId = document.getElementById('resources-instrument-filter')?.value || this.currentInstrument;
      if (filterInstrumentId) {
        instrumentSelect.value = filterInstrumentId;
      }
    }

    // Wire up search button for tutorials
    const searchBtn = document.getElementById('search-resource-btn');
    if (searchBtn) {
      searchBtn.onclick = () => {
        const searchInstrumentId = document.getElementById('resource-instrument')?.value ||
          document.getElementById('resources-instrument-filter')?.value || this.currentInstrument;
        const instrumentName = this.instruments.find(i => i.id === searchInstrumentId)?.name || '';
        const searchQuery = instrumentName
          ? `${this.currentResourceSong.title} ${instrumentName} tutorial`
          : `${this.currentResourceSong.title} tutorial`;
        const searchUrl = `https://www.google.com/search?q=${encodeURIComponent(searchQuery)}`;
        window.open(searchUrl, '_blank');
      };
    }

    document.getElementById('add-resource-modal').classList.remove('hidden');
  }

  async submitStudentResource() {
    // Prevent double submission
    if (this.isSubmittingResource) return;
    this.isSubmittingResource = true;

    try {
      const title = document.getElementById('resource-title').value.trim();
      const url = document.getElementById('resource-link').value.trim();
      const description = document.getElementById('resource-description').value.trim();
      const fileInput = document.getElementById('resource-file');
      const file = fileInput?.files[0];
      const isStudent = auth.hasRole('student');

      let fileUrl = '';
      let fileType = 'link';

      if (file) {
        // File upload takes priority over URL
        if (file.size > 5 * 1024 * 1024) {
          this.showToast('File size must be under 5MB', 'error');
          return;
        }

        fileType = file.type.startsWith('image/') ? 'image' : 'pdf';

        const fileName = `${Date.now()}_${file.name.replace(/[^a-zA-Z0-9.-]/g, '_')}`;
        const filePath = `${this.currentResourceSong.id}/${fileName}`;

        const { data: uploadData, error: uploadError } = await supabase.storage
          .from('student-resources')
          .upload(filePath, file);

        if (uploadError) {
          console.error('Upload error:', uploadError);
          this.showToast('Failed to upload file. Please try again.', 'error');
          return;
        }

        const { data: urlData } = supabase.storage
          .from('student-resources')
          .getPublicUrl(filePath);

        fileUrl = urlData.publicUrl;
      } else if (url) {
        fileUrl = url;
        // Auto-detect tutorial videos by URL
        fileType = /youtube\.com|youtu\.be|vimeo\.com/i.test(url) ? 'tutorial' : 'link';
      } else {
        this.showToast('Please provide a URL or upload a file', 'error');
        return;
      }

      // Get selected instrument (empty string = universal/all instruments)
      const instrumentId = document.getElementById('resource-instrument')?.value || null;

      // Insert resource record
      await this.rawInsert('student_resources', {
        song_id: this.currentResourceSong.id,
        user_id: auth.getCurrentUser().id,
        title: title,
        description: description || null,
        file_url: fileUrl,
        file_type: fileType,
        instrument_id: instrumentId || null,
        status: isStudent ? 'pending' : 'approved'
      });

      // Close modal and refresh
      document.getElementById('add-resource-modal').classList.add('hidden');
      this.showToast(
        isStudent ? 'Resource submitted for teacher approval' : 'Resource added successfully',
        'success'
      );

      // Refresh the resources list
      await this.loadStudentResources(this.currentResourceSong.id);
    } catch (error) {
      console.error('Error submitting resource:', error);
      this.showToast('An error occurred. Please try again.', 'error');
    } finally {
      this.isSubmittingResource = false;
    }
  }

  // Helper for raw fetch inserts (workaround for Supabase JS client bug)
  async rawInsert(table, data, _isRetry = false) {
    const { data: { session } } = await supabase.auth.getSession();
    const token = session?.access_token;

    const response = await fetch(`https://dgwtihpiqgkhokkkxuzo.supabase.co/rest/v1/${table}`, {
      method: 'POST',
      headers: {
        'apikey': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRnd3RpaHBpcWdraG9ra2t4dXpvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc0OTQzNjcsImV4cCI6MjA4MzA3MDM2N30.xnD7lrvmBlvW-9XzL0VTabAq6wtwsepxb90Assu8bNo',
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
        'Prefer': 'return=minimal'
      },
      body: JSON.stringify(data)
    });

    // On 401, force-refresh the token and retry once
    if (response.status === 401 && !_isRetry) {
      const { data: { session: refreshed } } = await supabase.auth.refreshSession();
      if (refreshed?.access_token) {
        return this.rawInsert(table, data, true);
      }
    }

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`Insert failed: ${response.status} ${errorText}`);
    }

    return { error: null };
  }

  // Helper for raw fetch updates (workaround for Supabase JS client bug)
  async rawUpdate(table, id, data, _isRetry = false) {
    const session = await this.getSessionWithTimeout();
    const token = session?.access_token;

    const response = await fetch(`https://dgwtihpiqgkhokkkxuzo.supabase.co/rest/v1/${table}?id=eq.${id}`, {
      method: 'PATCH',
      headers: {
        'apikey': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRnd3RpaHBpcWdraG9ra2t4dXpvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc0OTQzNjcsImV4cCI6MjA4MzA3MDM2N30.xnD7lrvmBlvW-9XzL0VTabAq6wtwsepxb90Assu8bNo',
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
        'Prefer': 'return=minimal'
      },
      body: JSON.stringify(data)
    });

    // On 401, force-refresh the token and retry once
    if (response.status === 401 && !_isRetry) {
      const { data: { session: refreshed } } = await supabase.auth.refreshSession();
      if (refreshed?.access_token) {
        return this.rawUpdate(table, id, data, true);
      }
    }

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`Update failed: ${response.status} ${errorText}`);
    }

    return { error: null };
  }

  // Helper for raw fetch deletes (workaround for Supabase JS client bug)
  async rawDelete(table, id, _isRetry = false) {
    const { data: { session } } = await supabase.auth.getSession();
    const token = session?.access_token;

    const response = await fetch(`https://dgwtihpiqgkhokkkxuzo.supabase.co/rest/v1/${table}?id=eq.${id}`, {
      method: 'DELETE',
      headers: {
        'apikey': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRnd3RpaHBpcWdraG9ra2t4dXpvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc0OTQzNjcsImV4cCI6MjA4MzA3MDM2N30.xnD7lrvmBlvW-9XzL0VTabAq6wtwsepxb90Assu8bNo',
        'Authorization': `Bearer ${token}`,
        'Prefer': 'return=minimal'
      }
    });

    // On 401, force-refresh the token and retry once
    if (response.status === 401 && !_isRetry) {
      const { data: { session: refreshed } } = await supabase.auth.refreshSession();
      if (refreshed?.access_token) {
        return this.rawDelete(table, id, true);
      }
    }

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`Delete failed: ${response.status} ${errorText}`);
    }

    return { error: null };
  }

  // Helper for raw fetch selects (workaround for Supabase JS client issues after raw inserts)
  async rawSelect(table, query = '', _isRetry = false) {
    // Use Supabase client to get a fresh session (auto-refreshes expired tokens)
    const { data: { session } } = await supabase.auth.getSession();
    const token = session?.access_token;

    const response = await fetch(`https://dgwtihpiqgkhokkkxuzo.supabase.co/rest/v1/${table}?${query}`, {
      method: 'GET',
      headers: {
        'apikey': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRnd3RpaHBpcWdraG9ra2t4dXpvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc0OTQzNjcsImV4cCI6MjA4MzA3MDM2N30.xnD7lrvmBlvW-9XzL0VTabAq6wtwsepxb90Assu8bNo',
        'Authorization': `Bearer ${token}`,
        'Accept': 'application/json'
      }
    });

    // On 401, force-refresh the token and retry once
    if (response.status === 401 && !_isRetry) {
      const { data: { session: refreshed } } = await supabase.auth.refreshSession();
      if (refreshed?.access_token) {
        return this.rawSelect(table, query, true);
      }
    }

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`Select failed: ${response.status} ${errorText}`);
    }

    const data = await response.json();
    return { data, error: null };
  }

  async approveResource(resourceId) {
    try {
      await this.rawUpdate('student_resources', resourceId, {
        status: 'approved',
        reviewed_by_user_id: auth.getCurrentUser().id,
        reviewed_at: new Date().toISOString()
      });

      // Update local song count and re-render
      const song = this.songs.find(s => s.id === this.currentResourceSong.id);
      if (song) {
        song.resource_count = (song.resource_count || 0) + 1;
        this.filterSongs(); // Re-render song cards
      }

      this.showToast('Resource approved', 'success');
      await this.loadStudentResources(this.currentResourceSong.id);
    } catch (error) {
      console.error('Error approving resource:', error);
      this.showToast('Failed to approve resource', 'error');
    }
  }

  async rejectResource(resourceId) {
    try {
      await this.rawUpdate('student_resources', resourceId, {
        status: 'rejected',
        reviewed_by_user_id: auth.getCurrentUser().id,
        reviewed_at: new Date().toISOString()
      });

      this.showToast('Resource rejected', 'success');
      await this.loadStudentResources(this.currentResourceSong.id);
    } catch (error) {
      console.error('Error rejecting resource:', error);
      this.showToast('Failed to reject resource', 'error');
    }
  }

  async deleteResource(resourceId) {
    if (!confirm('Are you sure you want to delete this resource?')) {
      return;
    }

    try {
      await this.rawDelete('student_resources', resourceId);

      this.showToast('Resource deleted', 'success');
      await this.loadStudentResources(this.currentResourceSong.id);
    } catch (error) {
      console.error('Error deleting resource:', error);
      this.showToast('Failed to delete resource', 'error');
    }
  }

  // ============================================
  // BACK BUTTON: Browser/Device Back Navigation
  // ============================================

  setupBackButtonHandler() {
    // Tag the initial history entry with the current view so back always has a target
    const cleanUrl = window.location.pathname + window.location.search;
    history.replaceState({ cadenceView: this.currentView || 'pathway' }, '', cleanUrl);

    window.addEventListener('popstate', (e) => {
      // Close any overlays that are open (modals, class detail, preview, etc.)
      this.closeOverlays();

      // Navigate to the view stored in the history entry we landed on
      const state = e.state;
      if (state && state.cadenceView) {
        this.switchView(state.cadenceView, { addToHistory: false });
      }
    });
  }

  closeOverlays() {
    // Close any open modals
    document.querySelectorAll('.modal:not(.hidden)').forEach(m => m.classList.add('hidden'));

    // Hide instrument selection overlay
    const instrumentSelection = document.getElementById('instrument-selection');
    if (instrumentSelection) instrumentSelection.classList.add('hidden');

    // Exit preview mode
    if (this.previewMode.active) {
      this.exitStudentPreview();
    }

    // Close class detail back to classes list
    const classDetailView = document.getElementById('class-detail-view');
    if (classDetailView && !classDetailView.classList.contains('hidden')) {
      classDetailView.classList.add('hidden');
      const classesList = document.getElementById('classes-list');
      if (classesList) classesList.classList.remove('hidden');
    }
  }

  // ============================================
  // UTILITIES: Helpers & UI Components
  // ============================================

  escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  }

  showToast(message, type = 'info') {
    // Deduplicate identical error toasts within a cooldown window
    if (type === 'error') {
      if (!this._toastCooldowns) this._toastCooldowns = {};
      const now = Date.now();
      if (this._toastCooldowns[message] && now - this._toastCooldowns[message] < 10000) {
        return; // Suppress duplicate error toast within 10s
      }
      this._toastCooldowns[message] = now;
    }

    const container = document.getElementById('toast-container');
    const toast = document.createElement('div');
    toast.className = `toast ${type}`;
    toast.textContent = message;

    container.appendChild(toast);

    setTimeout(() => {
      toast.remove();
    }, 3000);
  }
}

// Initialize app
const app = new CadenceApp();
window.app = app; // Make available globally for inline event handlers
app.init();
