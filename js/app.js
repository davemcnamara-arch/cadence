// Main Application Module
import { supabase } from './config.js';
import { auth } from './auth.js';

class CadenceApp {
  // ============================================
  // CORE: Initialization & Setup
  // ============================================

  constructor() {
    this.currentInstrument = null;
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
    this.submissions = [];
    this.flaggedRatings = [];

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
        }
      } else {
        this.showLoginScreen();
      }
    };

    // Handle role selection for new users
    auth.onNeedRoleSelection = (authUser) => {
      this.showRoleSelection();
    };

    await auth.init();

    // Set up event listeners
    this.setupEventListeners();

    this.showLoading(false);
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
              // Add timeout to prevent hanging on unsubscribe
              await Promise.race([
                this.songUpdatesSubscription.unsubscribe(),
                new Promise((resolve) => setTimeout(resolve, 1000))
              ]);
            } catch (unsubError) {
              // Ignore unsubscribe errors during logout
            }
          }

          await auth.signOut();
          // Force reload to clear all state and show login screen
          // This ensures logout works even if auth state change listener doesn't fire
          window.location.reload();
        } catch (error) {
          console.error('Error during sign out:', error);
          // Still reload on error to ensure user sees login screen
          window.location.reload();
        }
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

    // Class search
    const classSearchInput = document.getElementById('class-search');
    if (classSearchInput) {
      classSearchInput.addEventListener('input', () => this.filterClasses());
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
    this.setupEditSongLevelForm();
    this.setupSubmissionsFilters();
    this.setupFlaggedFilters();

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

    const deleteSongBtn = document.getElementById('delete-song-btn');
    if (deleteSongBtn) {
      deleteSongBtn.addEventListener('click', () => this.deleteSong());
    }

    // Setup admin forms
    this.setupAdminForms();
  }

  async onUserSignedIn(user) {
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
      await this.loadTeacherData();

      // Switch to teacher's default view
      this.switchView('classes');
    } else if (user.role === 'admin') {
      // Hide student-only features for admins
      document.querySelectorAll('.student-tab').forEach(tab => tab.classList.add('hidden'));
      document.getElementById('join-class-toggle-btn')?.classList.add('hidden');
      document.getElementById('export-progress-btn')?.classList.add('hidden');

      // Show admin tabs only (not teacher tabs)
      document.querySelectorAll('.admin-tab').forEach(tab => tab.classList.remove('hidden'));
      await this.loadAdminData();

      // Switch to admin view as default for admins
      this.switchView('admin');
    }

    // Check if user has selected instruments (students only)
    if (user.role === 'student') {
      if (this.studentProgress.length === 0) {
        this.showInstrumentSelection();
      } else {
        // Select first instrument
        this.currentInstrument = this.studentProgress[0].instrument_id;
        await this.loadLevels(this.currentInstrument);
        await this.loadSongs();
        this.updatePathwayInstrument();
        this.renderPathway();
        this.updateInstrumentDropdown();
      }
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
    const { data, error } = await supabase
      .from('instruments')
      .select('*')
      .order('display_order');

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

    const { data, error } = await supabase
      .from('student_progress')
      .select('*')
      .eq('user_id', userId);

    if (error) {
      console.error('Error loading progress:', error);
      return;
    }

    this.studentProgress = data || [];
  }

  async loadLevels(instrumentId) {
    const { data, error } = await supabase
      .from('levels')
      .select('*')
      .eq('instrument_id', instrumentId)
      .order('level_number');

    if (error) {
      console.error('Error loading levels:', error);
      this.showToast('Failed to load levels', 'error');
      return;
    }

    this.levels = data;
  }

  async loadSongs() {
    // Prevent concurrent calls
    if (this.loadingSongs) {
      return;
    }
    this.loadingSongs = true;

    try {
      const { data, error } = await supabase
        .from('songs')
        .select(`
          *,
          song_ratings (
            assessed_level,
            instrument_id,
            user_id
          )
        `)
        .eq('approved', true)
        .order('date_added', { ascending: false });

      if (error) {
        console.error('Error loading songs:', error);
        this.loadingSongs = false;
        return;
      }

    // Load resource ratings separately and attach to songs
    const { data: resourceRatings } = await supabase
      .from('resource_ratings')
      .select('*, student_songs!inner(song_id)');

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

    // Attach resource ratings to songs
    this.songs = (data || []).map(song => ({
      ...song,
      resource_ratings: ratingsMap[song.id] || { chords: [], tutorial: [] }
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
    } finally {
      this.loadingSongs = false;
    }
  }

  setupSongUpdatesSubscription() {
    // Subscribe to changes in the songs table
    const subscription = supabase
      .channel('song-updates')
      .on(
        'postgres_changes',
        {
          event: 'UPDATE',
          schema: 'public',
          table: 'songs'
        },
        (payload) => {
          // Skip if we're already handling this update via approvePendingLink
          if (this.approvingLink) {
            return;
          }

          // Only reload if user is viewing the songs tab
          if (this.currentView === 'songs') {
            this.loadSongs().then(() => {
              this.filterSongs();
              this.showToast('Song updated with new link!', 'info');
            });
          } else if (this.currentView === 'progress') {
            // Also update progress view if it shows songs
            this.loadSongs().then(() => {
              this.renderProgress();
            });
          } else {
            // Still update the data in background so it's fresh when they switch views
            this.loadSongs();
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

    const { data, error } = await supabase
      .from('student_progress')
      .insert([{
        user_id: userId,
        instrument_id: instrumentId,
        current_level: 1
      }])
      .select()
      .single();

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

    // Delete all student songs for this instrument
    const { error: songsError } = await supabase
      .from('student_songs')
      .delete()
      .eq('user_id', userId)
      .eq('instrument_id', this.currentInstrument);

    if (songsError) {
      console.error('Error deleting student songs:', songsError);
      this.showToast('Failed to remove instrument', 'error');
      return;
    }

    // Delete the student progress record
    const { error: progressError } = await supabase
      .from('student_progress')
      .delete()
      .eq('user_id', userId)
      .eq('instrument_id', this.currentInstrument);

    if (progressError) {
      console.error('Error deleting student progress:', progressError);
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

    if (dropdown) dropdown.innerHTML = html;

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
      if (user.role === 'teacher' || user.role === 'admin') {
        const allInstrumentsHtml = this.instruments.map(i =>
          `<option value="${i.id}">${i.icon} ${i.name}</option>`
        ).join('');
        gradingDropdown.innerHTML = allInstrumentsHtml;
      } else {
        gradingDropdown.innerHTML = html;
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
      container.innerHTML = '<p style="color: var(--text-secondary);">Loading pathway...</p>';
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
        const levelNumber = parseInt(node.dataset.level);
        if (levelNumber) {
          this.navigateToLevelSongs(levelNumber);
        }
      });
    });
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

    return `
      <div class="level-node ${statusClass}" data-level="${level.level_number}">
        <div class="level-header">
          <span class="level-number">Level ${level.level_number}</span>
          ${isComplete ? '<span>✓</span>' : ''}
        </div>
        <h3 class="level-name">${level.name}</h3>
        <p class="level-description">${level.description}</p>
        <ul class="level-skills">
          ${skills.map(skill => `<li>${skill}</li>`).join('')}
        </ul>
        ${level.example_songs && level.example_songs.length > 0 ? `
          <div class="example-songs">
            <strong>Example songs:</strong> ${level.example_songs.join(', ')}
          </div>
        ` : ''}
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

  switchView(viewName) {
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

      // Load data for the view if needed
      if (viewName === 'pathway') {
        this.renderPathway();
      } else if (viewName === 'songs') {
        // Update instrument dropdown before rendering songs
        this.updateInstrumentDropdown();
        this.renderSongs();
      } else if (viewName === 'progress') {
        this.renderProgress();
      } else if (viewName === 'classes') {
        this.renderClassesList();
      } else if (viewName === 'submissions') {
        // Load submissions when first opened
        if (this.classes.length > 0) {
          this.loadSubmissions();
        }
      } else if (viewName === 'flagged') {
        // Load flagged ratings
        if (this.classes.length > 0) {
          this.loadFlaggedRatings();
        }
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

  async renderSongs() {
    await this.loadSongs();

    // Load student songs if not in preview mode
    if (!this.previewMode.active) {
      const user = auth.getCurrentUser();
      if (user) {
        const { data: studentSongs } = await supabase
          .from('student_songs')
          .select('*')
          .eq('user_id', user.id);
        this.studentSongs = studentSongs || [];
      }
    }

    this.filterSongs();
  }

  filterSongs() {
    const searchTerm = document.getElementById('song-search')?.value.toLowerCase() || '';
    const instrumentFilter = document.getElementById('filter-instrument')?.value || '';
    const levelFilter = document.getElementById('filter-level')?.value || '';

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
        // Check suggested level OR average rated level
        const levelNum = parseInt(levelFilter);
        if (song.suggested_level === levelNum) return true;
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
    } else if (this.currentInstrument) {
      // Student with current instrument selected
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

    // Get current instrument name for search queries
    const instrumentName = this.instruments.find(i => i.id === this.currentInstrument)?.name || '';

    // Get resource ratings
    const chordsRating = this.formatResourceRating(song.resource_ratings?.chords);
    const tutorialRating = this.formatResourceRating(song.resource_ratings?.tutorial);

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
      // Teachers/admins get a delete button
      actionButton = `<button class="btn btn-danger" onclick="event.stopPropagation(); app.deleteSongFromLibrary('${song.id}', '${song.title.replace(/'/g, "\\'")}', '${song.artist.replace(/'/g, "\\'")}')" title="Delete this song from the library">Delete Song</button>`;
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
          <span class="song-tag level">${levelLabel}</span>
        </div>
        <div class="song-actions">
          ${song.chords_url ? `
            <div class="resource-link-group">
              <a href="${song.chords_url}" target="_blank" class="btn btn-secondary" onclick="event.stopPropagation()">Chords</a>
              ${chordsRating}
              <button class="btn-icon" onclick="event.stopPropagation(); app.editSongResource('${song.id}', 'chords_url', '${song.chords_url.replace(/'/g, "\\'")}', '${song.title.replace(/'/g, "\\'")}', '${song.artist.replace(/'/g, "\\'")}', '${instrumentName.replace(/'/g, "\\'")}')" title="Edit chords link">✎</button>
            </div>
          ` : `
            <button class="btn btn-secondary btn-add" onclick="event.stopPropagation(); app.editSongResource('${song.id}', 'chords_url', '', '${song.title.replace(/'/g, "\\'")}', '${song.artist.replace(/'/g, "\\'")}', '${instrumentName.replace(/'/g, "\\'")}')" title="Add chords link">+ Chords</button>
          `}
          ${song.tutorial_url ? `
            <div class="resource-link-group">
              <a href="${song.tutorial_url}" target="_blank" class="btn btn-secondary" onclick="event.stopPropagation()">Tutorial</a>
              ${tutorialRating}
              <button class="btn-icon" onclick="event.stopPropagation(); app.editSongResource('${song.id}', 'tutorial_url', '${song.tutorial_url.replace(/'/g, "\\'")}', '${song.title.replace(/'/g, "\\'")}', '${song.artist.replace(/'/g, "\\'")}', '${instrumentName.replace(/'/g, "\\'")}')" title="Edit tutorial link">✎</button>
            </div>
          ` : `
            <button class="btn btn-secondary btn-add" onclick="event.stopPropagation(); app.editSongResource('${song.id}', 'tutorial_url', '', '${song.title.replace(/'/g, "\\'")}', '${song.artist.replace(/'/g, "\\'")}', '${instrumentName.replace(/'/g, "\\'")}')" title="Add tutorial link">+ Tutorial</button>
          `}
          ${song.youtube_url ? `
            <div class="resource-link-group">
              <a href="${song.youtube_url}" target="_blank" class="btn btn-secondary" onclick="event.stopPropagation()">YouTube</a>
              <button class="btn-icon" onclick="event.stopPropagation(); app.editSongResource('${song.id}', 'youtube_url', '${song.youtube_url.replace(/'/g, "\\'")}', '${song.title.replace(/'/g, "\\'")}', '${song.artist.replace(/'/g, "\\'")}', '${instrumentName.replace(/'/g, "\\'")}')" title="Edit YouTube link">✎</button>
            </div>
          ` : `
            <button class="btn btn-secondary btn-add" onclick="event.stopPropagation(); app.editSongResource('${song.id}', 'youtube_url', '', '${song.title.replace(/'/g, "\\'")}', '${song.artist.replace(/'/g, "\\'")}', '${instrumentName.replace(/'/g, "\\'")}')" title="Add YouTube link">+ YouTube</button>
          `}
        </div>
      </div>
    `;
  }

  async viewSongDetails(songId) {
    const song = this.songs.find(s => s.id === songId);
    if (!song) {
      console.error('Song not found:', songId);
      return;
    }

    const user = auth.getCurrentUser();

    // Get list of students if user is a teacher (to show their names)
    let studentMap = {};
    if (user.role === 'teacher') {
      const { data: students } = await supabase.rpc('get_all_teacher_students');
      if (students) {
        students.forEach(s => {
          studentMap[s.user_id] = s.name;
        });
      }
    }

    // Fetch all ratings for this song (without user join due to RLS)
    const { data: ratings, error } = await supabase
      .from('song_ratings')
      .select(`
        *,
        instruments (icon, name)
      `)
      .eq('song_id', songId)
      .order('date_graded', { ascending: false });

    if (error) {
      console.error('Error loading song ratings:', error);
      return;
    }

    // Update modal title
    document.getElementById('song-details-title').textContent = `${song.title} - ${song.artist}`;

    // Render content
    const content = document.getElementById('song-details-content');

    if (!ratings || ratings.length === 0) {
      content.innerHTML = `
        <p style="color: var(--text-secondary); text-align: center; padding: 2rem;">
          No ratings yet for this song.
        </p>
      `;
    } else {
      const avgLevel = (ratings.reduce((sum, r) => sum + r.assessed_level, 0) / ratings.length).toFixed(1);

      content.innerHTML = `
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

    // Use RPC function to bypass RLS issues
    const { data, error } = await supabase.rpc('add_student_song', {
      p_student_id: userId,
      p_song_id: songId,
      p_instrument_id: this.currentInstrument,
      p_status: 'learning'
    });

    if (error) {
      console.error('Error adding song:', error);
      if (error.message.includes('Already tracking')) {
        this.showToast('Already tracking this song!', 'info');
      } else if (error.message.includes('Permission denied')) {
        this.showToast('Permission denied', 'error');
      } else {
        this.showToast('Failed to add song', 'error');
      }
      return;
    }

    this.showToast('Song added to Currently Learning!', 'success');

    // Reload student data to show the new song
    if (this.previewMode.active) {
      await this.loadStudentPreviewData(this.previewMode.studentId);
    } else {
      // Reload own songs if not in preview mode
      await this.loadSongs();
    }

    // Re-render current view to update button states
    if (this.currentView === 'songs') {
      this.renderSongs();
    } else if (this.currentView === 'progress') {
      this.renderProgress();
    }
  }

  async deleteSongFromLibrary(songId, title, artist) {
    // Confirm deletion with song details
    if (!confirm(`Are you sure you want to delete "${title}" by ${artist} from the library?\n\nThis will permanently remove the song and all associated ratings and student progress. This action cannot be undone.`)) {
      return;
    }

    const { error } = await supabase
      .from('songs')
      .delete()
      .eq('id', songId);

    if (error) {
      console.error('Error deleting song:', error);
      this.showToast('Failed to delete song', 'error');
      return;
    }

    this.showToast('Song deleted successfully', 'success');

    // Reload the song library to reflect the deletion
    await this.loadSongs();
    this.renderSongs();
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
          const searchQuery = `${title} ${artist} chords`;
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

    // If adding a new link (not editing), open a search to help user find it
    if (!currentValue) {
      let searchQuery = '';
      if (fieldName === 'chords_url') {
        searchQuery = `${title} ultimate guitar`;
      } else if (fieldName === 'tutorial_url') {
        searchQuery = instrumentName ? `${title} ${instrumentName} tutorial` : `${title} tutorial`;
      } else if (fieldName === 'youtube_url') {
        searchQuery = `${title} youtube`;
      }

      if (searchQuery) {
        const searchUrl = `https://www.google.com/search?q=${encodeURIComponent(searchQuery)}`;
        window.open(searchUrl, '_blank');
      }
    }

    // Update modal UI
    const fieldLabels = {
      'chords_url': 'Chords URL',
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

        // Close modal
        document.getElementById('edit-resource-modal').classList.add('hidden');

        // Show success message
        this.showToast('Link submitted for teacher approval', 'success');
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
    this.updateInstrumentDropdown(); // Populate instrument dropdown
    document.getElementById('song-grading-modal').classList.remove('hidden');
    document.getElementById('song-grading-form').reset();
    this.updateGradingStep();
  }

  generateComprehensiveChecklist() {
    const instrumentId = document.getElementById('grading-instrument').value;

    // Get the instrument name for display
    const instrument = this.instruments.find(i => i.id === instrumentId);
    const instrumentName = instrument ? instrument.name : 'this instrument';

    // Create a comprehensive questionnaire that works across all levels and instruments
    const comprehensiveQuestions = {
      "Harmonic complexity": [
        "1-3 basic chords/notes",
        "4-5 simple chords/progressions",
        "6-8 chords with some variety",
        "8-10 chords with extensions or more complex harmony",
        "10+ chords or very advanced harmony"
      ],
      "Chord/harmony types": [
        "basic major/minor only",
        "includes 7ths or sus chords",
        "includes extensions (9ths, 11ths, 13ths)",
        "includes alterations or jazz voicings",
        "n/a - melody/rhythm instrument only"
      ],
      "Playing patterns and articulation": [
        "single simple pattern throughout",
        "2-3 different patterns or techniques",
        "varied patterns with some complexity",
        "complex patterns with advanced articulation",
        "very advanced - multiple techniques integrated"
      ],
      "Technique examples (select what applies)": [
        "Basic: strumming, block chords, basic rhythms, straight tone",
        "Intermediate: fingerpicking/arpeggios, ghost notes, basic fills, dynamics",
        "Advanced: slap/pop, syncopation, polyrhythms, vibrato, runs/riffs",
        "Expert: tapping, double bass, advanced coordination, melisma, improvisation"
      ],
      "Song structure": [
        "single section or simple repeat",
        "verse/chorus (2 sections)",
        "verse/chorus/bridge (3 sections)",
        "multiple sections (4+) or complex form"
      ],
      "Coordination/independence": [
        "single element (one rhythm, one melodic line)",
        "two elements - simple (basic hands/limbs together)",
        "moderate coordination (independent parts)",
        "high independence (complex polyrhythmic or contrapuntal)",
        "mastered independence (full control of all elements)"
      ],
      "Overall technical difficulty": [
        "beginner friendly",
        "some challenges for beginners",
        "intermediate - moderately challenging",
        "advanced - quite challenging",
        "expert - very challenging"
      ],
      "Rhythm complexity": [
        "simple steady rhythm (4/4, straight)",
        "some variation or off-beats",
        "syncopated or swing feel",
        "complex rhythms or time signature changes",
        "polyrhythmic or very advanced timing"
      ],
      "Dynamics and expression": [
        "minimal - mostly one dynamic level",
        "basic dynamic changes (loud/soft)",
        "moderate expression and phrasing",
        "highly expressive with nuanced control",
        "exceptional artistry and interpretation"
      ],
      "Note reading requirement": [
        "chord symbols/charts only",
        "simple notation or tab",
        "standard notation - moderate",
        "complex notation or score reading",
        "can play by ear or memory"
      ],
      "Improvisation/embellishment": [
        "none - play exactly as written",
        "minimal decoration or simple fills",
        "some structured improvisation",
        "significant improvised sections",
        "free improvisation or extensive soloing"
      ]
    };

    const container = document.getElementById('grading-checklist');

    container.innerHTML = `
      <p style="margin-bottom: 1.5rem; color: var(--text-secondary);">
        Answer these questions about the song for <strong>${instrumentName}</strong>. Choose the option that best describes what's required.
      </p>
      ${Object.entries(comprehensiveQuestions).map(([question, options], index) => `
        <div class="checklist-item">
          <div class="checklist-question">${question}</div>
          <div class="checklist-options">
            ${options.map((option, optIndex) => `
              <label>
                <input type="radio" name="question-${index}" value="${option}" required>
                ${option}
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
      this.gradingData.youtube_url = document.getElementById('song-youtube').value;
      this.gradingData.chords_url = document.getElementById('song-chords').value;
      this.gradingData.tutorial_url = document.getElementById('song-tutorial').value;

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
      return 1; // Default to Level 1 if no responses
    }

    // Get the current instrument
    const instrument = this.instruments.find(i => i.id === this.gradingData.instrument);
    if (!instrument) return 1;

    // Initialize scores for each level (1-5)
    const levelScores = { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 };
    let totalQuestions = 0;

    // Process each response with the universal comprehensive questions
    Object.entries(responses).forEach(([question, answer]) => {
      totalQuestions++;
      const answerLower = answer.toLowerCase();
      const questionLower = question.toLowerCase();

      // Map answers to levels based on new universal questionnaire

      // Harmonic complexity (chords/notes)
      if (answerLower.includes('1-3 basic')) {
        levelScores[1] += 5;
      } else if (answerLower.includes('4-5 simple')) {
        levelScores[1] += 2; levelScores[2] += 5;
      } else if (answerLower.includes('6-8 chords')) {
        levelScores[2] += 2; levelScores[3] += 5;
      } else if (answerLower.includes('8-10 chords') || answerLower.includes('extensions')) {
        levelScores[3] += 2; levelScores[4] += 5;
      } else if (answerLower.includes('10+') || answerLower.includes('very advanced')) {
        levelScores[4] += 2; levelScores[5] += 5;
      }

      // Chord/harmony types
      else if (answerLower.includes('basic major/minor')) {
        levelScores[1] += 5;
      } else if (answerLower.includes('includes 7ths') || answerLower.includes('sus chords')) {
        levelScores[2] += 2; levelScores[3] += 5;
      } else if (answerLower.includes('extensions') || answerLower.includes('9ths')) {
        levelScores[4] += 2; levelScores[5] += 5;
      } else if (answerLower.includes('alterations') || answerLower.includes('jazz voicings')) {
        levelScores[5] += 5;
      } else if (answerLower.includes('n/a')) {
        // Neutral - doesn't affect score much
        levelScores[1] += 1; levelScores[2] += 1; levelScores[3] += 1;
      }

      // Playing patterns and articulation
      else if (answerLower.includes('single simple pattern')) {
        levelScores[1] += 5;
      } else if (answerLower.includes('2-3 different')) {
        levelScores[2] += 5;
      } else if (answerLower.includes('varied patterns')) {
        levelScores[3] += 5;
      } else if (answerLower.includes('complex patterns')) {
        levelScores[4] += 5;
      } else if (answerLower.includes('very advanced') && answerLower.includes('integrated')) {
        levelScores[5] += 5;
      }

      // Technique examples
      else if (answerLower.includes('basic:')) {
        levelScores[1] += 5;
      } else if (answerLower.includes('intermediate:')) {
        levelScores[2] += 2; levelScores[3] += 5;
      } else if (answerLower.includes('advanced:')) {
        levelScores[3] += 1; levelScores[4] += 5;
      } else if (answerLower.includes('expert:')) {
        levelScores[5] += 5;
      }

      // Song structure
      else if (answerLower.includes('single section') || answerLower.includes('simple repeat')) {
        levelScores[1] += 5;
      } else if (answerLower.includes('verse/chorus (2')) {
        levelScores[2] += 5;
      } else if (answerLower.includes('verse/chorus/bridge (3')) {
        levelScores[3] += 5;
      } else if (answerLower.includes('multiple sections (4+)') || answerLower.includes('complex form')) {
        levelScores[4] += 2; levelScores[5] += 5;
      }

      // Coordination/independence
      else if (answerLower.includes('single element')) {
        levelScores[1] += 5;
      } else if (answerLower.includes('two elements - simple')) {
        levelScores[1] += 2; levelScores[2] += 5;
      } else if (answerLower.includes('moderate coordination')) {
        levelScores[2] += 1; levelScores[3] += 5;
      } else if (answerLower.includes('high independence')) {
        levelScores[3] += 1; levelScores[4] += 5;
      } else if (answerLower.includes('mastered independence')) {
        levelScores[5] += 5;
      }

      // Overall technical difficulty
      else if (answerLower.includes('beginner friendly')) {
        levelScores[1] += 5;
      } else if (answerLower.includes('some challenges for beginners')) {
        levelScores[2] += 5;
      } else if (answerLower.includes('intermediate')) {
        levelScores[3] += 5;
      } else if (answerLower.includes('advanced -')) {
        levelScores[4] += 5;
      } else if (answerLower.includes('expert -')) {
        levelScores[5] += 5;
      }

      // Rhythm complexity
      else if (answerLower.includes('simple steady')) {
        levelScores[1] += 5;
      } else if (answerLower.includes('some variation') || answerLower.includes('off-beats')) {
        levelScores[2] += 5;
      } else if (answerLower.includes('syncopated') || answerLower.includes('swing')) {
        levelScores[3] += 2; levelScores[4] += 5;
      } else if (answerLower.includes('complex rhythms') || answerLower.includes('time signature')) {
        levelScores[4] += 1; levelScores[5] += 5;
      } else if (answerLower.includes('polyrhythmic')) {
        levelScores[5] += 5;
      }

      // Dynamics and expression
      else if (answerLower.includes('minimal')) {
        levelScores[1] += 5;
      } else if (answerLower.includes('basic dynamic')) {
        levelScores[2] += 5;
      } else if (answerLower.includes('moderate expression')) {
        levelScores[3] += 5;
      } else if (answerLower.includes('highly expressive')) {
        levelScores[4] += 2; levelScores[5] += 5;
      } else if (answerLower.includes('exceptional artistry')) {
        levelScores[5] += 5;
      }

      // Note reading requirement
      else if (answerLower.includes('chord symbols')) {
        levelScores[1] += 3; levelScores[2] += 3;
      } else if (answerLower.includes('simple notation') || answerLower.includes('tab')) {
        levelScores[2] += 3;
      } else if (answerLower.includes('standard notation - moderate')) {
        levelScores[3] += 3;
      } else if (answerLower.includes('complex notation') || answerLower.includes('score reading')) {
        levelScores[4] += 3; levelScores[5] += 3;
      } else if (answerLower.includes('play by ear')) {
        levelScores[2] += 2; levelScores[3] += 3; levelScores[4] += 3;
      }

      // Improvisation/embellishment
      else if (answerLower.includes('none') && answerLower.includes('exactly')) {
        levelScores[1] += 3; levelScores[2] += 3;
      } else if (answerLower.includes('minimal decoration')) {
        levelScores[2] += 2; levelScores[3] += 5;
      } else if (answerLower.includes('some structured')) {
        levelScores[3] += 2; levelScores[4] += 5;
      } else if (answerLower.includes('significant improvised')) {
        levelScores[4] += 3; levelScores[5] += 5;
      } else if (answerLower.includes('free improvisation') || answerLower.includes('extensive soloing')) {
        levelScores[5] += 5;
      }
    });

    // Find the level with the highest score
    let maxScore = 0;
    let suggestedLevel = 1;

    for (let level = 1; level <= 5; level++) {
      if (levelScores[level] > maxScore) {
        maxScore = levelScores[level];
        suggestedLevel = level;
      }
    }

    return suggestedLevel;
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
          <option value="1" ${suggested === 1 ? 'selected' : ''}>Level 1 - Foundation</option>
          <option value="2" ${suggested === 2 ? 'selected' : ''}>Level 2 - Expanding Vocabulary</option>
          <option value="3" ${suggested === 3 ? 'selected' : ''}>Level 3 - Technical Development</option>
          <option value="4" ${suggested === 4 ? 'selected' : ''}>Level 4 - Style Integration</option>
          <option value="5" ${suggested === 5 ? 'selected' : ''}>Level 5 - Advanced Techniques</option>
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
      // Add a timeout to detect hangs
      const timeoutPromise = new Promise((_, reject) =>
        setTimeout(() => reject(new Error('Request timed out after 15 seconds')), 15000)
      );

      const rpcPromise = supabase.rpc('grade_song', {
        p_student_id: userId,
        p_title: this.gradingData.title,
        p_artist: this.gradingData.artist,
        p_instrument_id: this.gradingData.instrument,
        p_assessed_level: this.gradingData.level,
        p_checklist_responses_json: this.gradingData.checklistResponses,
        p_youtube_url: this.gradingData.youtube_url || null,
        p_chords_url: this.gradingData.chords_url || null,
        p_tutorial_url: this.gradingData.tutorial_url || null,
        p_add_to_learning: document.getElementById('add-to-learning').checked
      });

      const { data, error } = await Promise.race([rpcPromise, timeoutPromise]);

      if (error) throw error;

      // Close modal and refresh
      document.getElementById('song-grading-modal').classList.add('hidden');
      this.showToast('Song graded successfully!', 'success');
      await this.loadSongs();

      if (this.currentView === 'songs') {
        this.renderSongs();
      }
    } catch (error) {
      console.error('🎯 Error submitting grading:', error);
      console.error('🎯 Error details:', {
        message: error.message,
        details: error.details,
        hint: error.hint,
        code: error.code
      });
      const errorMsg = error.message || error.details || 'Failed to submit grading';
      this.showToast(`Failed to submit grading: ${errorMsg}`, 'error');
    }
  }

  // ============================================
  // STUDENT: Progress Tracking & Mastery
  // ============================================

  async renderProgress() {
    const user = auth.getCurrentUser();
    let studentSongsWithRatings;

    // If in preview mode, use already-loaded data
    if (this.previewMode.active) {
      // Data already has resource_ratings from RPC function
      studentSongsWithRatings = this.studentSongs || [];
    } else {
      // Load fresh data for current user
      const userId = user.id;

      // Load student songs
      const { data: studentSongs } = await supabase
        .from('student_songs')
        .select(`
          *,
          songs (*)
        `)
        .eq('user_id', userId)
        .order('date_started', { ascending: false });

      // Load resource ratings for these student songs
      const studentSongIds = studentSongs?.map(s => s.id) || [];
      const { data: resourceRatings } = await supabase
        .from('resource_ratings')
        .select('*')
        .in('student_song_id', studentSongIds);

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

      // Attach ratings to student songs
      studentSongsWithRatings = studentSongs?.map(s => ({
        ...s,
        resource_ratings: ratingsMap[s.id] || { chords: [], tutorial: [] }
      }));
    }

    // Calculate stats
    const learning = studentSongsWithRatings?.filter(s => s.status === 'learning') || [];
    const mastered = studentSongsWithRatings?.filter(s => s.status === 'mastered') || [];

    // Render stats
    const statsContainer = document.getElementById('progress-stats');
    statsContainer.innerHTML = `
      <div class="stat-card">
        <div class="stat-value">${this.studentProgress.length}</div>
        <div class="stat-label">Instruments</div>
      </div>
      <div class="stat-card">
        <div class="stat-value">${learning.length}</div>
        <div class="stat-label">Currently Learning</div>
      </div>
      <div class="stat-card">
        <div class="stat-value">${mastered.length}</div>
        <div class="stat-label">Songs Mastered</div>
      </div>
    `;

    // Render song lists
    document.getElementById('learning-songs').innerHTML = learning.length > 0
      ? learning.map(s => this.renderStudentSongItem(s)).join('')
      : '<p style="color: var(--text-secondary);">No songs in progress</p>';

    document.getElementById('mastered-songs').innerHTML = mastered.length > 0
      ? mastered.map(s => this.renderStudentSongItem(s)).join('')
      : '<p style="color: var(--text-secondary);">No mastered songs yet</p>';
  }

  renderStudentSongItem(studentSong) {
    const song = studentSong.songs;
    // Get instrument name for search queries
    const instrumentName = this.instruments.find(i => i.id === studentSong.instrument_id)?.name || '';

    // Get resource ratings
    const chordsRating = this.formatResourceRating(studentSong.resource_ratings?.chords);
    const tutorialRating = this.formatResourceRating(studentSong.resource_ratings?.tutorial);

    return `
      <div class="song-list-item">
        <div class="info">
          <div class="title">${song.title}</div>
          <div class="artist">${song.artist}</div>
          <div class="song-links" style="margin-top: 4px; display: flex; gap: 8px; flex-wrap: wrap; align-items: center;">
            ${song.chords_url ? `
              <span style="display: inline-flex; align-items: center; gap: 2px;">
                <a href="${song.chords_url}" target="_blank" style="font-size: 12px; color: var(--secondary-color);">Chords</a>
                ${chordsRating}
                <button class="btn-icon-small" onclick="app.editSongResource('${song.id}', 'chords_url', '${song.chords_url.replace(/'/g, "\\'")}', '${song.title.replace(/'/g, "\\'")}', '${song.artist.replace(/'/g, "\\'")}', '${instrumentName.replace(/'/g, "\\'")}')" title="Edit chords link">✎</button>
              </span>
            ` : `
              <button class="btn-link-add" onclick="app.editSongResource('${song.id}', 'chords_url', '', '${song.title.replace(/'/g, "\\'")}', '${song.artist.replace(/'/g, "\\'")}', '${instrumentName.replace(/'/g, "\\'")}')" title="Add chords link">+ Chords</button>
            `}
            ${song.tutorial_url ? `
              <span style="display: inline-flex; align-items: center; gap: 2px;">
                <a href="${song.tutorial_url}" target="_blank" style="font-size: 12px; color: var(--secondary-color);">Tutorial</a>
                ${tutorialRating}
                <button class="btn-icon-small" onclick="app.editSongResource('${song.id}', 'tutorial_url', '${song.tutorial_url.replace(/'/g, "\\'")}', '${song.title.replace(/'/g, "\\'")}', '${song.artist.replace(/'/g, "\\'")}', '${instrumentName.replace(/'/g, "\\'")}')" title="Edit tutorial link">✎</button>
              </span>
            ` : `
              <button class="btn-link-add" onclick="app.editSongResource('${song.id}', 'tutorial_url', '', '${song.title.replace(/'/g, "\\'")}', '${song.artist.replace(/'/g, "\\'")}', '${instrumentName.replace(/'/g, "\\'")}')" title="Add tutorial link">+ Tutorial</button>
            `}
            ${song.youtube_url ? `
              <span style="display: inline-flex; align-items: center; gap: 2px;">
                <a href="${song.youtube_url}" target="_blank" style="font-size: 12px; color: var(--secondary-color);">YouTube</a>
                <button class="btn-icon-small" onclick="app.editSongResource('${song.id}', 'youtube_url', '${song.youtube_url.replace(/'/g, "\\'")}', '${song.title.replace(/'/g, "\\'")}', '${song.artist.replace(/'/g, "\\'")}', '${instrumentName.replace(/'/g, "\\'")}')" title="Edit YouTube link">✎</button>
              </span>
            ` : `
              <button class="btn-link-add" onclick="app.editSongResource('${song.id}', 'youtube_url', '', '${song.title.replace(/'/g, "\\'")}', '${song.artist.replace(/'/g, "\\'")}', '${instrumentName.replace(/'/g, "\\'")}')" title="Add YouTube link">+ YouTube</button>
            `}
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
    // Use RPC function to bypass RLS when in preview mode
    const { data: studentSong, error } = await supabase.rpc('get_student_song_detail', {
      p_student_song_id: studentSongId
    });

    if (error) {
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

    // Check if song has chords or tutorial links
    const hasChords = studentSong.songs.chords_url;
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
    // Update modal content
    document.getElementById('rate-resources-song-info').textContent =
      `${song.title} - ${song.artist}`;

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

    // Save ratings if provided - use RPC function to bypass RLS
    if (chordsRating || tutorialRating) {
      const { error } = await supabase.rpc('submit_resource_ratings', {
        p_student_song_id: this.pendingMasteredSong.studentSongId,
        p_chords_rating: chordsRating ? parseInt(chordsRating) : null,
        p_tutorial_rating: tutorialRating ? parseInt(tutorialRating) : null
      });

      if (error) {
        console.error('Error saving ratings:', error);
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

    // Use RPC function to bypass RLS when in preview mode
    const { error } = await supabase.rpc('update_student_song_status', {
      p_student_song_id: studentSongId,
      p_status: 'mastered',
      p_date_completed: new Date().toISOString()
    });

    if (error) {
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

    this.renderProgress();

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
    const { data: masteredSongs, error: queryError } = await supabase
      .from('student_songs')
      .select('*, songs!inner(*)')
      .eq('user_id', userId)
      .eq('instrument_id', instrumentId)
      .eq('status', 'mastered');

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

      const { error } = await supabase
        .from('student_progress')
        .update({ current_level: newLevel })
        .eq('user_id', userId)
        .eq('instrument_id', instrumentId);

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
    // Use RPC function to bypass RLS when in preview mode
    const { error } = await supabase.rpc('update_student_song_status', {
      p_student_song_id: studentSongId,
      p_status: 'learning',
      p_date_completed: null
    });

    if (error) {
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
    this.renderProgress();
  }

  async removeSong(studentSongId) {
    if (!confirm('Are you sure you want to remove this song from your progress?')) {
      return;
    }

    // Use RPC function to bypass RLS when in preview mode
    const { error } = await supabase.rpc('remove_student_song', {
      p_student_song_id: studentSongId
    });

    if (error) {
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
    this.renderProgress();
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

    if (instrumentNames.length > 0) {
      reflection += `I am currently developing my skills on ${instrumentNames.join(', ')}. `;
    }

    reflection += `Throughout this term, I have been working on ${learning.length + mastered.length} songs total.\n\n`;

    if (mastered.length > 0) {
      reflection += `I have successfully mastered ${mastered.length} song${mastered.length !== 1 ? 's' : ''}, including:\n`;
      mastered.forEach(ss => {
        const instrumentName = instrumentMap[ss.instrument_id] || 'Unknown';
        reflection += `- "${ss.songs.title}" by ${ss.songs.artist} on ${instrumentName}\n`;
      });
      reflection += '\n';
    }

    if (learning.length > 0) {
      reflection += `I am currently learning ${learning.length} song${learning.length !== 1 ? 's' : ''}:\n`;
      learning.forEach(ss => {
        const instrumentName = instrumentMap[ss.instrument_id] || 'Unknown';
        reflection += `- "${ss.songs.title}" by ${ss.songs.artist} on ${instrumentName}\n`;
      });
      reflection += '\n';
    }

    if (this.studentProgress && this.studentProgress.length > 0) {
      this.studentProgress.forEach(progress => {
        const inst = this.instruments.find(i => i.id === progress.instrument_id);
        if (inst) {
          reflection += `On ${inst.name}, I am working at Level ${progress.current_level}`;
          if (progress.current_branch) {
            reflection += ` (${progress.current_branch})`;
          }
          reflection += '.\n';
        }
      });
    }

    reflection += `\nI am committed to continuing my musical development and look forward to progressing to higher levels.`;

    return reflection;
  }

  // ============================================
  // UI STATE: Login, Role Selection & App Display
  // ============================================

  showLoading(show) {
    document.getElementById('loading-screen').classList.toggle('hidden', !show);
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

    // Use RPC function to bypass RLS and get accurate student counts
    const { data, error } = await supabase.rpc('get_teacher_classes', {
      p_teacher_id: user.id,
      p_include_archived: showArchived
    });

    if (error) {
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

  showCreateClassModal() {
    document.getElementById('create-class-modal').classList.remove('hidden');
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

      if (!className || className.trim() === '') {
        this.showToast('Please enter a class name', 'error');
        return;
      }

      await this.createClass(className, yearLevel);
    });
  }

  async createClass(className, yearLevel) {
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

      // Create the class
      const { data, error } = await supabase
        .from('classes')
        .insert([{
          class_code: classCode,
          name: className,
          teacher_id: user.id,
          year_level: yearLevel || null
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

  filterClasses() {
    const searchTerm = document.getElementById('class-search')?.value.toLowerCase() || '';

    let filteredClasses = this.classes;

    if (searchTerm) {
      filteredClasses = filteredClasses.filter(cls =>
        cls.name.toLowerCase().includes(searchTerm) ||
        cls.class_code.toLowerCase().includes(searchTerm) ||
        (cls.year_level && cls.year_level.toLowerCase().includes(searchTerm))
      );
    }

    this.renderClassesList(filteredClasses);
  }

  renderClassesList(classesToRender = null) {
    const container = document.getElementById('classes-list');
    if (!container) return;

    const classes = classesToRender || this.classes;

    if (this.classes.length === 0) {
      container.innerHTML = `
        <div style="text-align: center; padding: 4rem; color: var(--text-secondary);">
          <p style="font-size: 1.125rem; margin-bottom: 1rem;">No classes yet</p>
          <p>Create your first class to get started</p>
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
      const isArchived = cls.archived;

      if (isArchived) {
        // Archived class card with unarchive button
        return `
          <div class="class-card" style="opacity: 0.7; position: relative;">
            <div class="class-card-header">
              <div>
                <h3>${cls.name} <span style="background-color: var(--text-secondary); color: white; padding: 0.125rem 0.5rem; border-radius: 4px; font-size: 0.75rem; font-weight: normal;">ARCHIVED</span></h3>
                ${cls.year_level ? `<p style="color: var(--text-secondary); font-size: 0.875rem;">${cls.year_level}</p>` : ''}
              </div>
              <span class="class-code-badge">${cls.class_code}</span>
            </div>
            <div class="class-card-meta">
              <span>${memberCount} student${memberCount !== 1 ? 's' : ''}</span>
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
              </div>
              <span class="class-code-badge">${cls.class_code}</span>
            </div>
            <div class="class-card-meta">
              <span>${memberCount} student${memberCount !== 1 ? 's' : ''}</span>
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

    // Hide classes list, show class detail
    document.getElementById('classes-list').classList.add('hidden');
    document.getElementById('class-detail-view').classList.remove('hidden');

    // Update header
    document.getElementById('class-detail-name').textContent = this.currentClass.name;
    const yearLevelEl = document.getElementById('class-detail-year-level');
    if (yearLevelEl) {
      yearLevelEl.textContent = this.currentClass.year_level || '';
    }
    document.getElementById('class-detail-code').textContent = this.currentClass.class_code;

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
      // Use RPC function to bypass RLS recursion issues
      const { data, error } = await supabase.rpc('get_class_students', {
        p_class_id: this.currentClass.id
      });

      if (error) {
        console.error('Error loading class students:', error);
        this.classStudents = [];
        document.getElementById('class-detail-count').textContent = '0 students';
        return;
      }

      // Data is already in the right format from the function
      this.classStudents = data || [];

      // Update student count
      document.getElementById('class-detail-count').textContent =
        `${this.classStudents.length} student${this.classStudents.length !== 1 ? 's' : ''}`;
    } catch (err) {
      console.error('Exception in loadClassStudents:', err);
      this.classStudents = [];
      document.getElementById('class-detail-count').textContent = '0 students';
    }
  }

  renderClassRoster() {
    // Close any open modals to prevent showing students from other classes
    const modal = document.getElementById('student-detail-modal');
    if (modal) modal.classList.add('hidden');

    const container = document.getElementById('class-roster');
    if (!container) return;

    if (this.classStudents.length === 0) {
      container.innerHTML = `
        <div style="text-align: center; padding: 3rem; color: var(--text-secondary);">
          <p style="font-size: 1.125rem; margin-bottom: 0.5rem;">No students yet</p>
          <p>Share your class code <strong>${this.currentClass.class_code}</strong> with students to join</p>
        </div>
      `;
      return;
    }

    const html = this.classStudents.map(member => {
      const student = member.users;
      const progress = member.student_progress || [];
      const instruments = progress.map(p => {
        const inst = this.instruments.find(i => i.id === p.instrument_id);
        return inst ? inst.icon : '';
      }).join(' ');

      return `
        <div class="roster-item" onclick="app.viewStudentDetail('${student.id}')">
          <div class="roster-student-info">
            <div class="roster-student-name">${student.name}</div>
            <div class="roster-student-meta">
              ${progress.length} instrument${progress.length !== 1 ? 's' : ''}
              • Joined ${new Date(member.joined_at).toLocaleDateString()}
            </div>
          </div>
          <div class="roster-student-instruments">${instruments}</div>
        </div>
      `;
    }).join('');

    container.innerHTML = html;
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
      html += `<tr><td>${student.name}</td>`;

      this.instruments.forEach(inst => {
        const progress = member.student_progress?.find(p => p.instrument_id === inst.id);
        if (progress) {
          const level = progress.current_level;
          html += `<td class="heatmap-cell level-${level}">Level ${level}</td>`;
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

    // Use RPC function to bypass RLS
    const { data, error } = await supabase.rpc('get_class_timeline', {
      p_class_id: this.currentClass.id
    });

    if (error) {
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

  async viewStudentDetail(studentId) {
    // Use RPC function to bypass RLS
    const { data, error } = await supabase.rpc('get_student_detail', {
      p_student_id: studentId
    });

    if (error) {
      console.error('Error loading student detail:', error);
      return;
    }

    const progressData = data.progress || [];
    const songsData = data.songs || [];

    const student = this.classStudents.find(m => m.user_id === studentId)?.users;
    if (!student) return;

    // Build student detail modal content
    let html = '';

    if (progressData.length === 0) {
      html = '<p style="color: var(--text-secondary);">This student hasn\'t started any instruments yet.</p>';
    } else {
      html = '<div class="student-instruments-grid">';

      progressData.forEach(progress => {
        const inst = progress.instruments;
        const studentSongs = songsData.filter(s => s.instrument_id === progress.instrument_id);
        const learning = studentSongs.filter(s => s.status === 'learning');
        const mastered = studentSongs.filter(s => s.status === 'mastered');

        html += `
          <div class="student-instrument-card">
            <div class="student-instrument-header">
              ${inst.icon} ${inst.name}
            </div>
            <div class="student-progress-info">
              Level ${progress.current_level}${progress.current_branch ? ` - ${progress.current_branch}` : ''}
            </div>
            <div class="student-progress-info">
              ${learning.length} learning • ${mastered.length} mastered
            </div>
            ${mastered.length > 0 ? `
              <div class="student-songs-list">
                <strong style="font-size: 0.75rem; text-transform: uppercase; letter-spacing: 0.05em; color: var(--text-secondary);">Recently Mastered:</strong>
                ${mastered.slice(0, 5).map(s => `
                  <div class="student-song-item">${s.songs.title} - ${s.songs.artist}</div>
                `).join('')}
              </div>
            ` : ''}
          </div>
        `;
      });

      html += '</div>';
    }

    document.getElementById('student-detail-name').textContent = student.name;
    document.getElementById('student-detail-content').innerHTML = html;

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

    document.getElementById('student-detail-modal').classList.remove('hidden');
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

    // Load student's data
    await this.loadStudentPreviewData(studentId);

    // Switch to pathway view to show student's perspective
    this.switchView('pathway');
  }

  async loadStudentPreviewData(studentId) {
    // Use RPC function to bypass RLS
    const { data, error } = await supabase.rpc('get_student_detail', {
      p_student_id: studentId
    });

    if (error) {
      console.error('Error loading student preview data:', error);
      return;
    }

    const progressData = data.progress || [];
    const songsData = data.songs || [];

    this.studentProgress = progressData;

    // Load instruments and set first as current
    if (progressData.length > 0) {
      this.instruments = progressData.map(p => p.instruments);
      this.currentInstrument = progressData[0].instrument_id; // Use ID, not object!

      // Load levels for the student's instrument
      await this.loadLevels(this.currentInstrument);
      await this.loadSongs();
    } else {
      this.instruments = [];
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
      // Show teacher tabs
      teacherTabs.forEach(tab => {
        tab.classList.remove('hidden');
      });
      // Hide student tabs
      document.querySelectorAll('.student-tab').forEach(tab => tab.classList.add('hidden'));
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
  // TEACHER: Submissions & Flagged Ratings Review
  // ============================================

  async loadSubmissions() {
    const user = auth.getCurrentUser();

    // Use RPC function to get all students from teacher's classes
    const { data: students, error: studentsError } = await supabase
      .rpc('get_all_teacher_students');

    if (studentsError) {
      console.error('Error loading students:', studentsError);
      this.submissions = [];
      this.renderSubmissionsFeed();
      return;
    }

    if (!students || students.length === 0) {
      this.submissions = [];
      this.renderSubmissionsFeed();
      return;
    }

    const studentIds = students.map(s => s.user_id);

    // Create a lookup map for student info (since RLS might block the users join)
    const studentMap = {};
    students.forEach(s => {
      studentMap[s.user_id] = { name: s.name, email: s.email };
    });

    // Get submissions from those students
    const { data, error } = await supabase
      .from('song_ratings')
      .select(`
        *,
        songs!inner (title, artist),
        instruments (icon, name)
      `)
      .in('user_id', studentIds)
      .order('date_graded', { ascending: false })
      .limit(50);

    if (error) {
      console.error('Error loading submissions:', error);
      return;
    }

    // Attach student info from our map
    this.submissions = (data || []).map(submission => ({
      ...submission,
      users: studentMap[submission.user_id] || { name: 'Unknown Student' }
    }));

    // Populate filter dropdowns
    this.populateSubmissionsFilters();
    this.renderSubmissionsFeed();
  }

  renderSubmissionsFeed() {
    const container = document.getElementById('submissions-feed');
    if (!container) return;

    if (!this.submissions || this.submissions.length === 0) {
      container.innerHTML = '<p style="color: var(--text-secondary); text-align: center; padding: 3rem;">No recent submissions</p>';
      return;
    }

    // Apply filters
    const classFilter = document.getElementById('submissions-class-filter')?.value || '';
    const instrumentFilter = document.getElementById('submissions-instrument-filter')?.value || '';

    let filteredSubmissions = this.submissions;

    // Filter by instrument
    if (instrumentFilter) {
      filteredSubmissions = filteredSubmissions.filter(s => s.instrument_id === instrumentFilter);
    }

    // Filter by class - need to check if student is in the selected class
    if (classFilter && this.submissionsClassMemberships) {
      const studentIdsInClass = this.submissionsClassMemberships
        .filter(m => m.class_id === classFilter)
        .map(m => m.user_id);
      filteredSubmissions = filteredSubmissions.filter(s => studentIdsInClass.includes(s.user_id));
    }

    if (filteredSubmissions.length === 0) {
      container.innerHTML = '<p style="color: var(--text-secondary); text-align: center; padding: 3rem;">No submissions match the selected filters</p>';
      return;
    }

    const html = filteredSubmissions.map(submission => {
      const timeAgo = this.getTimeAgo(submission.date_graded);

      return `
        <div class="submission-card">
          <div class="submission-header">
            <div>
              <div class="submission-student">${submission.users.name}</div>
              <div class="submission-song">${submission.songs.title} - ${submission.songs.artist}</div>
            </div>
            <div class="submission-time">${timeAgo}</div>
          </div>
          <div class="submission-details">
            <div class="submission-detail-item">
              <div class="submission-detail-label">Instrument</div>
              <div class="submission-detail-value">${submission.instruments.icon} ${submission.instruments.name}</div>
            </div>
            <div class="submission-detail-item">
              <div class="submission-detail-label">Assessed Level</div>
              <div class="submission-detail-value">Level ${submission.assessed_level}</div>
            </div>
          </div>
          ${submission.notes ? `
            <div class="submission-notes">
              <div class="submission-notes-label">Notes:</div>
              <div class="submission-notes-text">${submission.notes}</div>
            </div>
          ` : ''}
          <div class="submission-actions">
            <button class="btn btn-secondary btn-sm" onclick="app.editSongLevel('${submission.id}', '${submission.song_id}', '${submission.songs.title}', ${submission.assessed_level}, '${(submission.notes || '').replace(/'/g, "\\'")}')">Edit Level</button>
          </div>
        </div>
      `;
    }).join('');

    container.innerHTML = html;
  }

  async populateSubmissionsFilters() {
    // Populate class filter
    const classFilter = document.getElementById('submissions-class-filter');
    if (classFilter && this.classes) {
      const classOptions = this.classes.map(c =>
        `<option value="${c.id}">${c.name}</option>`
      ).join('');
      classFilter.innerHTML = '<option value="">All Classes</option>' + classOptions;
    }

    // Populate instrument filter
    const instrumentFilter = document.getElementById('submissions-instrument-filter');
    if (instrumentFilter && this.instruments) {
      const instrumentOptions = this.instruments.map(i =>
        `<option value="${i.id}">${i.icon} ${i.name}</option>`
      ).join('');
      instrumentFilter.innerHTML = '<option value="">All Instruments</option>' + instrumentOptions;
    }

    // Fetch class memberships for filtering
    const user = auth.getCurrentUser();
    const { data: memberships } = await supabase
      .from('class_members')
      .select('user_id, class_id')
      .in('class_id', this.classes.map(c => c.id));

    this.submissionsClassMemberships = memberships || [];
  }

  setupSubmissionsFilters() {
    const classFilter = document.getElementById('submissions-class-filter');
    const instrumentFilter = document.getElementById('submissions-instrument-filter');

    if (classFilter) {
      classFilter.addEventListener('change', () => {
        this.renderSubmissionsFeed();
      });
    }

    if (instrumentFilter) {
      instrumentFilter.addEventListener('change', () => {
        this.renderSubmissionsFeed();
      });
    }
  }

  async loadFlaggedRatings() {
    // Get all students from all the teacher's classes
    const { data: allStudents, error: studentsError } = await supabase.rpc('get_all_teacher_students');

    if (studentsError) {
      console.error('Error loading teacher students:', studentsError);
      this.renderFlaggedRatings([]);
      return;
    }

    if (!allStudents || allStudents.length === 0) {
      this.renderFlaggedRatings([]);
      return;
    }

    // Create a user map for displaying names
    const userMap = {};
    allStudents.forEach(s => {
      userMap[s.user_id] = s.name;
    });

    // Add current teacher to the map
    const user = auth.getCurrentUser();
    userMap[user.id] = user.name || 'Teacher';

    const studentIds = allStudents.map(s => s.user_id);

    // First, get all song IDs that have been rated by class students
    const { data: studentRatings, error: studentError } = await supabase
      .from('song_ratings')
      .select('song_id')
      .in('user_id', studentIds);

    if (studentError) {
      console.error('Error loading student ratings:', studentError);
      return;
    }

    // Get unique song IDs
    const songIds = [...new Set(studentRatings.map(r => r.song_id))];

    if (songIds.length === 0) {
      this.renderFlaggedRatings([]);
      return;
    }

    // Now get ALL ratings for these songs (including teacher ratings)
    // Don't use inner join on users to avoid RLS issues
    const { data, error } = await supabase
      .from('song_ratings')
      .select(`
        song_id,
        instrument_id,
        assessed_level,
        user_id,
        songs!inner (title, artist, suggested_level),
        instruments (icon, name)
      `)
      .in('song_id', songIds);

    if (error) {
      console.error('Error loading ratings:', error);
      return;
    }

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
    const flagged = [];
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

    // Also load new ratings that need teacher review
    const { data: unreviewedRatings, error: unreviewedError } = await supabase
      .from('song_ratings')
      .select(`
        id,
        song_id,
        instrument_id,
        assessed_level,
        user_id,
        date_graded,
        songs!inner (title, artist),
        instruments (icon, name)
      `)
      .in('user_id', studentIds)
      .eq('teacher_reviewed', false)
      .order('date_graded', { ascending: false });

    // Format unreviewed ratings for display
    const newRatings = (unreviewedRatings || []).map(rating => ({
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

    // Also load pending links for teacher approval
    const { data: pendingLinks, error: pendingError } = await supabase
      .from('pending_links')
      .select(`
        id,
        song_id,
        link_type,
        url,
        submitted_at,
        submitted_by_user_id,
        songs!inner (title, artist),
        users!pending_links_submitted_by_user_id_fkey (name)
      `)
      .eq('status', 'pending')
      .order('submitted_at', { ascending: false });

    this.flaggedRatings = flagged;
    this.newRatings = newRatings;
    this.pendingLinks = pendingLinks || [];
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
    const totalCount = flaggedSongs.length + (this.newRatings?.length || 0) + (this.pendingLinks?.length || 0);
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
        'tutorial_url': 'Tutorial Video'
      };

      pendingLinksHtml = `
        <div style="margin-bottom: 2rem;">
          <h3 style="margin-bottom: 1rem; color: var(--text-primary);">Pending Link Approvals (${this.pendingLinks.length})</h3>
          ${this.pendingLinks.map(link => {
            const linkLabel = linkTypeLabels[link.link_type] || link.link_type;
            const submittedDate = new Date(link.submitted_at).toLocaleDateString();
            const submitterName = link.users?.name || 'Unknown';

            return `
              <div class="flagged-card" style="border-left: 4px solid #ffc107;">
                <div class="flagged-header">
                  <div>
                    <div class="flagged-song-title">${link.songs.title}</div>
                    <div class="flagged-song-meta">${link.songs.artist} • ${linkLabel}</div>
                  </div>
                  <div style="text-align: right; font-size: 0.875rem; color: var(--text-secondary);">
                    <div>Submitted by ${submitterName}</div>
                    <div>${submittedDate}</div>
                  </div>
                </div>
                <div style="padding: 1rem; background: var(--bg-secondary); border-radius: 4px; margin: 1rem 0;">
                  <div style="font-weight: 500; margin-bottom: 0.5rem; color: var(--text-primary);">Submitted URL:</div>
                  <a href="${link.url}" target="_blank" rel="noopener noreferrer" style="color: var(--primary-color); word-break: break-all;">${link.url}</a>
                </div>
                <div class="flagged-resolve">
                  <button class="btn btn-primary" onclick="app.approvePendingLink('${link.id}')">
                    <span style="margin-right: 0.5rem;">✓</span> Approve
                  </button>
                  <button class="btn btn-secondary" onclick="app.rejectPendingLink('${link.id}')" style="margin-left: 0.5rem;">
                    <span style="margin-right: 0.5rem;">✗</span> Reject
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
                    <option value="1" ${item.rating.level === 1 ? 'disabled' : ''}>Level 1 - Foundation</option>
                    <option value="2" ${item.rating.level === 2 ? 'disabled' : ''}>Level 2 - Expanding Vocabulary</option>
                    <option value="3" ${item.rating.level === 3 ? 'disabled' : ''}>Level 3 - Technical Development</option>
                    <option value="4" ${item.rating.level === 4 ? 'disabled' : ''}>Level 4 - Style Integration</option>
                    <option value="5" ${item.rating.level === 5 ? 'disabled' : ''}>Level 5 - Advanced Techniques</option>
                  </select>
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
              <option value="1">Level 1 - Foundation</option>
              <option value="2">Level 2 - Expanding Vocabulary</option>
              <option value="3">Level 3 - Technical Development</option>
              <option value="4">Level 4 - Style Integration</option>
              <option value="5">Level 5 - Advanced Techniques</option>
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
    if (pendingLinksHtml || newRatingsHtml || flaggedRatingsHtml) {
      container.innerHTML = pendingLinksHtml + newRatingsHtml + flaggedRatingsHtml;
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
      // Update the song's suggested_level using RPC to bypass RLS
      const { error } = await supabase.rpc('update_song_suggested_level', {
        p_song_id: songId,
        p_level: level
      });

      if (error) {
        console.error('Error resolving flagged rating:', error);
        this.showToast('Failed to resolve rating: ' + error.message, 'error');
        return;
      }

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
      // Update the rating level (if overridden) and mark as teacher_reviewed
      const { data, error } = await supabase.rpc('approve_song_rating', {
        p_rating_id: ratingId,
        p_assessed_level: level
      });

      if (error) {
        console.error('Error reviewing rating:', error);
        this.showToast('Failed to review rating: ' + error.message, 'error');
        return;
      }

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

      // Call the RPC function to approve the link
      const { error } = await supabase.rpc('approve_pending_link', {
        pending_link_id: linkId
      });

      if (error) {
        console.error('Error approving link:', error);
        this.showToast('Failed to approve link: ' + error.message, 'error');
        this.approvingLink = false;
        return;
      }

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
      // Call the RPC function to reject the link
      const { error } = await supabase.rpc('reject_pending_link', {
        pending_link_id: linkId
      });

      if (error) {
        console.error('Error rejecting link:', error);
        this.showToast('Failed to reject link: ' + error.message, 'error');
        return;
      }

      this.showToast('Link rejected', 'success');

      // Reload flagged ratings to update the pending links list
      await this.loadFlaggedRatings();
    } catch (error) {
      console.error('Exception in rejectPendingLink:', error);
      this.showToast('Failed to reject link', 'error');
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

        // Reload submissions to show the updated level
        await this.loadSubmissions();
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

    // Load classes the student has joined
    const { data: memberships, error } = await supabase
      .from('class_members')
      .select(`
        *,
        classes (
          id,
          name,
          class_code,
          year_level,
          created_at
        )
      `)
      .eq('user_id', user.id)
      .order('joined_at', { ascending: false });

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

    // Load classes the student has joined
    const { data: memberships, error } = await supabase
      .from('class_members')
      .select(`
        *,
        classes (
          id,
          name,
          class_code,
          year_level
        )
      `)
      .eq('user_id', userId)
      .order('joined_at', { ascending: false });

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

      // Add timeout to RPC call
      const timeoutPromise = new Promise((_, reject) =>
        setTimeout(() => reject(new Error('Request timeout after 10 seconds')), 10000)
      );

      const rpcPromise = supabase.rpc('join_class_by_code', {
        p_user_id: user.id,
        p_class_code: classCode
      });

      const { data, error } = await Promise.race([rpcPromise, timeoutPromise])
        .catch(err => {
          console.error('RPC call failed or timed out:', err);
          return { data: null, error: err };
        });

      if (error) {
        console.error('Database error details:', {
          message: error.message,
          details: error.details,
          hint: error.hint,
          code: error.code
        });

        // Handle timeout
        if (error.message?.includes('timeout')) {
          this.showToast('Request timed out. Please check your connection and try again.', 'error');
          return;
        }

        // Handle specific error cases
        if (error.message?.includes('not found')) {
          this.showToast('Class not found. Please check the code.', 'error');
        } else if (error.message?.includes('already') || error.code === '23505') {
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
    const [usersRes, songsRes, ratingsRes, classesRes] = await Promise.all([
      supabase.from('users').select('id, role'),
      supabase.from('songs').select('id'),
      supabase.from('song_ratings').select('id'),
      supabase.from('classes').select('id')
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
    const { data, error } = await supabase
      .from('levels')
      .select('*, instruments(name, icon)')
      .order('instrument_id')
      .order('level_number');

    if (error) {
      console.error('Error loading levels:', error);
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
        ${song.tutorial_url ? `<div><strong>Tutorial:</strong> <a href="${song.tutorial_url}" target="_blank">Link</a></div>` : ''}
        ${song.youtube_url ? `<div><strong>YouTube:</strong> <a href="${song.youtube_url}" target="_blank">Link</a></div>` : ''}
      </div>
    `;

    document.getElementById('admin-song-details').innerHTML = details;
    document.getElementById('admin-song-modal').classList.remove('hidden');
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

        const { error } = await supabase
          .from('users')
          .update({ role: newRole })
          .eq('id', this.currentEditingUserId);

        if (error) {
          console.error('Error updating user role:', error);
          this.showToast('Failed to update user role', 'error');
          return;
        }

        document.getElementById('edit-user-role-modal').classList.add('hidden');
        this.showToast('User role updated successfully', 'success');
        await this.loadUsersManagement();
      });
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
  // UTILITIES: Helpers & UI Components
  // ============================================

  showToast(message, type = 'info') {
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
