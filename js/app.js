// Main Application Module
import { supabase } from './config.js';
import { auth } from './auth.js';

class CadenceApp {
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
    console.log('🎵 Cadence: Initializing app...');

    // Show loading screen
    this.showLoading(true);
    console.log('🎵 Cadence: Loading screen shown');

    // Initialize auth
    auth.onAuthStateChange = (user) => {
      console.log('🎵 Cadence: Auth state changed, user:', user ? 'logged in' : 'not logged in');
      if (user) {
        this.onUserSignedIn(user);
      } else {
        this.showLoginScreen();
      }
    };

    // Handle role selection for new users
    auth.onNeedRoleSelection = (authUser) => {
      console.log('🎵 Cadence: New user needs to select role');
      this.showRoleSelection();
    };

    console.log('🎵 Cadence: Initializing auth...');
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
        console.log('Logout button clicked');
        e.preventDefault();
        e.stopPropagation();
        try {
          const result = await auth.signOut();
          console.log('Sign out result:', result);
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
    console.log('🎵 Add Instrument Button:', addInstrumentBtn);
    if (addInstrumentBtn) {
      addInstrumentBtn.addEventListener('click', () => {
        console.log('🎵 Add Instrument button clicked!');
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

    const contentFilterInstrument = document.getElementById('content-filter-instrument');
    if (contentFilterInstrument) {
      contentFilterInstrument.addEventListener('change', () => this.loadContentModeration());
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

    // Update UI
    document.getElementById('user-name').textContent = user.name;
    this.showApp();

    // Show/hide tabs and features based on role
    if (user.role === 'student') {
      // Show student tabs and features
      document.querySelectorAll('.student-tab').forEach(tab => tab.classList.remove('hidden'));
      // Student tabs will be active by default
      await this.loadStudentClassesHeader();
    } else if (user.role === 'teacher' || user.role === 'admin') {
      // Hide student-only features for teachers and admins
      document.querySelectorAll('.student-tab').forEach(tab => tab.classList.add('hidden'));
      document.getElementById('join-class-toggle-btn')?.classList.add('hidden');
      document.getElementById('export-progress-btn')?.classList.add('hidden');

      // Keep song and instrument controls visible for Song Library access
      // Teachers/admins can now add/manage songs via Song Library tab

      // Show teacher tabs
      document.querySelectorAll('.teacher-tab').forEach(tab => tab.classList.remove('hidden'));
      await this.loadTeacherData();

      // Switch to teacher's default view
      this.switchView('classes');
    }

    // Show/hide admin tabs based on role
    if (user.role === 'admin') {
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
  }

  showInstrumentSelection() {
    console.log('🎵 showInstrumentSelection called');
    const container = document.getElementById('instrument-selection');
    const grid = document.getElementById('instrument-grid');
    console.log('🎵 Container:', container);
    console.log('🎵 Grid:', grid);

    // Filter out already selected instruments
    const selectedIds = this.studentProgress.map(p => p.instrument_id);
    const availableInstruments = this.instruments.filter(i => !selectedIds.includes(i.id));
    console.log('🎵 Selected IDs:', selectedIds);
    console.log('🎵 Available instruments:', availableInstruments);

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

    const html = this.studentProgress.map(progress => {
      const instrument = this.instruments.find(i => i.id === progress.instrument_id);
      return `<option value="${instrument.id}">${instrument.icon} ${instrument.name}</option>`;
    }).join('');

    if (dropdown) dropdown.innerHTML = html;

    // Update filter dropdown with all instruments
    if (filterDropdown) {
      const allInstrumentsHtml = '<option value="my-instruments">My Instruments</option>' +
        '<option value="">All Instruments</option>' +
        this.instruments.map(i => `<option value="${i.id}">${i.icon} ${i.name}</option>`).join('');
      filterDropdown.innerHTML = allInstrumentsHtml;
      // Set default to "My Instruments"
      filterDropdown.value = 'my-instruments';
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
        if (this.classes.length > 0 && this.classStudents.length > 0) {
          this.loadFlaggedRatings();
        }
      } else if (viewName === 'admin') {
        // Load admin data
        this.renderAdminStats(this.adminStats || {users: 0, songs: 0, ratings: 0, classes: 0});
        this.renderAdminLevels();
      }
    }
  }

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

    grid.innerHTML = filteredSongs.map(song => this.renderSongCard(song)).join('');

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
    // Filter ratings for current instrument only
    const ratings = allRatings.filter(r => r.instrument_id === this.currentInstrument);
    let levelDisplay, levelLabel;

    if (ratings.length > 0) {
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
    } else if (song.suggested_level) {
      levelDisplay = song.suggested_level;
      levelLabel = `Level ${song.suggested_level} (suggested)`;
    } else {
      levelDisplay = '?';
      levelLabel = 'Not rated';
    }

    // Get current instrument name for search queries
    const instrumentName = this.instruments.find(i => i.id === this.currentInstrument)?.name || '';

    // Get resource ratings
    const chordsRating = this.formatResourceRating(song.resource_ratings?.chords);
    const tutorialRating = this.formatResourceRating(song.resource_ratings?.tutorial);

    // Check if student is already tracking this song
    const studentSong = this.studentSongs.find(ss =>
      ss.song_id === song.id && ss.instrument_id === this.currentInstrument
    );

    let actionButton = '';
    if (studentSong) {
      if (studentSong.status === 'mastered') {
        actionButton = `<button class="btn btn-secondary" disabled style="opacity: 0.6; cursor: not-allowed;">Already Mastered</button>`;
      } else {
        actionButton = `<button class="btn btn-secondary" disabled style="opacity: 0.6; cursor: not-allowed;">Already Learning</button>`;
      }
    } else {
      actionButton = `<button class="btn btn-primary" onclick="event.stopPropagation(); app.addSongToLearning('${song.id}')">Start Learning</button>`;
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
          <span class="song-tag">${ratings.length} rating${ratings.length !== 1 ? 's' : ''}</span>
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

  setupSongGradingForm() {
    const form = document.getElementById('song-grading-form');
    const levelSelect = document.getElementById('grading-level');
    const nextBtn = document.getElementById('next-step-btn');
    const prevBtn = document.getElementById('prev-step-btn');
    const submitBtn = document.getElementById('submit-grade-btn');

    // Level selection triggers checklist generation
    if (levelSelect) {
      levelSelect.addEventListener('change', (e) => {
        const level = parseInt(e.target.value);
        if (level) {
          this.generateGradingChecklist(level);
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
    console.log('🎵 Setting up edit resource modal');

    const form = document.getElementById('edit-resource-form');
    const cancelBtn = document.getElementById('cancel-edit-resource');

    console.log('🎵 Form element:', form);

    // Cancel button
    if (cancelBtn) {
      cancelBtn.addEventListener('click', () => {
        console.log('🎵 Cancel clicked');
        document.getElementById('edit-resource-modal').classList.add('hidden');
      });
    }

    // Form submit handler
    if (form) {
      form.addEventListener('submit', async (e) => {
        console.log('🎵 Form submit event triggered');
        e.preventDefault();
        e.stopPropagation();
        await this.saveResourceUrl();
      });
      console.log('🎵 Form submit listener added');
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

    const modalTitle = currentValue ? 'Edit Resource Link' : 'Add Resource Link';
    const fieldLabel = fieldLabels[fieldName] || 'URL';

    document.getElementById('edit-resource-title').textContent = modalTitle;
    document.getElementById('edit-resource-song-info').textContent = `${title} - ${artist}`;
    document.getElementById('resource-url-label').textContent = fieldLabel;
    document.getElementById('resource-url').value = currentValue;

    // Show modal
    document.getElementById('edit-resource-modal').classList.remove('hidden');
    document.getElementById('resource-url').focus();
  }

  async saveResourceUrl() {
    console.log('🎵 saveResourceUrl called');

    try {
      const url = document.getElementById('resource-url').value.trim();
      const { songId, fieldName } = this.editingResource;

      console.log('🎵 Saving resource:', { songId, fieldName, url });

      // Get the current session token from localStorage (Supabase stores it there)
      console.log('🎵 Getting session from localStorage...');
      const sessionKey = `sb-dgwtihpiqgkhokkkxuzo-auth-token`;
      const sessionData = localStorage.getItem(sessionKey);
      console.log('🎵 Session data exists:', !!sessionData);

      if (!sessionData) {
        throw new Error('Not authenticated - no session found');
      }

      const session = JSON.parse(sessionData);
      const accessToken = session.access_token;
      console.log('🎵 Access token retrieved:', !!accessToken);

      if (!accessToken) {
        throw new Error('Not authenticated - no access token');
      }

      console.log('🎵 About to update database using REST API...');

      // Use REST API directly instead of Supabase client
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

      console.log('🎵 Response status:', response.status);
      console.log('🎵 Response ok:', response.ok);

      if (!response.ok) {
        const errorText = await response.text();
        console.error('🎵 Response error:', errorText);
        throw new Error(`Update failed: ${response.status} ${errorText}`);
      }

      console.log('🎵 Update successful!');

      // Update the local song object immediately so UI reflects the change
      const song = this.songs.find(s => s.id === songId);
      if (song) {
        song[fieldName] = url || null;
        console.log('🎵 Updated local song object:', song.title, fieldName, '=', url || null);
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
      const level = document.getElementById('grading-level').value;

      if (!title || !artist || !instrument || !level) {
        this.showToast('Please fill in all required fields', 'warning');
        return;
      }

      this.gradingData.title = title;
      this.gradingData.artist = artist;
      this.gradingData.instrument = instrument;
      this.gradingData.level = parseInt(level);
      this.gradingData.youtube_url = document.getElementById('song-youtube').value;
      this.gradingData.chords_url = document.getElementById('song-chords').value;
      this.gradingData.tutorial_url = document.getElementById('song-tutorial').value;
    }

    if (this.currentStep === 2) {
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

  showLevelSuggestion() {
    const suggested = this.gradingData.level;
    const container = document.getElementById('level-suggestion');

    container.innerHTML = `
      <div class="suggested-level">Level ${suggested}</div>
      <p>Based on your responses, this song appears to be at <strong>Level ${suggested}</strong></p>
      <p style="margin-top: 1rem; font-size: 0.875rem; color: var(--text-secondary);">
        You can adjust this if you think it should be different.
      </p>
    `;
  }

  async submitSongGrading() {
    const user = auth.getCurrentUser();
    // Use student ID if in preview mode, otherwise use current user
    const userId = this.previewMode.active ? this.previewMode.studentId : user.id;

    try {
      // Use RPC function to handle the entire grading workflow
      // This bypasses RLS and handles all validation internally
      const { data, error } = await supabase.rpc('grade_song', {
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

      if (error) throw error;

      // Close modal and refresh
      document.getElementById('song-grading-modal').classList.add('hidden');
      this.showToast('Song graded successfully!', 'success');
      await this.loadSongs();

      if (this.currentView === 'songs') {
        this.renderSongs();
      }
    } catch (error) {
      console.error('Error submitting grading:', error);
      console.error('Error details:', {
        message: error.message,
        details: error.details,
        hint: error.hint,
        code: error.code
      });
      const errorMsg = error.message || error.details || 'Failed to submit grading';
      this.showToast(`Failed to submit grading: ${errorMsg}`, 'error');
    }
  }

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

    // Check if in preview mode
    const isPreview = this.previewMode.active;

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
                ${!isPreview ? `<button class="btn-icon-small" onclick="app.editSongResource('${song.id}', 'chords_url', '${song.chords_url.replace(/'/g, "\\'")}', '${song.title.replace(/'/g, "\\'")}', '${song.artist.replace(/'/g, "\\'")}', '${instrumentName.replace(/'/g, "\\'")}')" title="Edit chords link">✎</button>` : ''}
              </span>
            ` : !isPreview ? `
              <button class="btn-link-add" onclick="app.editSongResource('${song.id}', 'chords_url', '', '${song.title.replace(/'/g, "\\'")}', '${song.artist.replace(/'/g, "\\'")}', '${instrumentName.replace(/'/g, "\\'")}')" title="Add chords link">+ Chords</button>
            ` : ''}
            ${song.tutorial_url ? `
              <span style="display: inline-flex; align-items: center; gap: 2px;">
                <a href="${song.tutorial_url}" target="_blank" style="font-size: 12px; color: var(--secondary-color);">Tutorial</a>
                ${tutorialRating}
                ${!isPreview ? `<button class="btn-icon-small" onclick="app.editSongResource('${song.id}', 'tutorial_url', '${song.tutorial_url.replace(/'/g, "\\'")}', '${song.title.replace(/'/g, "\\'")}', '${song.artist.replace(/'/g, "\\'")}', '${instrumentName.replace(/'/g, "\\'")}')" title="Edit tutorial link">✎</button>` : ''}
              </span>
            ` : !isPreview ? `
              <button class="btn-link-add" onclick="app.editSongResource('${song.id}', 'tutorial_url', '', '${song.title.replace(/'/g, "\\'")}', '${song.artist.replace(/'/g, "\\'")}', '${instrumentName.replace(/'/g, "\\'")}')" title="Add tutorial link">+ Tutorial</button>
            ` : ''}
            ${song.youtube_url ? `
              <span style="display: inline-flex; align-items: center; gap: 2px;">
                <a href="${song.youtube_url}" target="_blank" style="font-size: 12px; color: var(--secondary-color);">YouTube</a>
                ${!isPreview ? `<button class="btn-icon-small" onclick="app.editSongResource('${song.id}', 'youtube_url', '${song.youtube_url.replace(/'/g, "\\'")}', '${song.title.replace(/'/g, "\\'")}', '${song.artist.replace(/'/g, "\\'")}', '${instrumentName.replace(/'/g, "\\'")}')" title="Edit YouTube link">✎</button>` : ''}
              </span>
            ` : !isPreview ? `
              <button class="btn-link-add" onclick="app.editSongResource('${song.id}', 'youtube_url', '', '${song.title.replace(/'/g, "\\'")}', '${song.artist.replace(/'/g, "\\'")}', '${instrumentName.replace(/'/g, "\\'")}')" title="Add YouTube link">+ YouTube</button>
            ` : ''}
          </div>
        </div>
        <div class="actions">
          ${!isPreview ? (studentSong.status === 'learning' ? `
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
          `) : (studentSong.status === 'mastered' ? `
            <span style="color: var(--secondary-color); font-weight: 600;">✓ Mastered</span>
          ` : '')}
        </div>
      </div>
    `;
  }

  async markSongMastered(studentSongId) {
    const user = auth.getCurrentUser();

    // Get the student song to check which instrument it's for
    const { data: studentSong } = await supabase
      .from('student_songs')
      .select('*, songs(*)')
      .eq('id', studentSongId)
      .single();

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
    const user = auth.getCurrentUser();
    // Use student ID if in preview mode, otherwise use current user
    const userId = this.previewMode.active ? this.previewMode.studentId : user.id;

    // Save ratings if provided
    if (chordsRating || tutorialRating) {
      const { error } = await supabase
        .from('resource_ratings')
        .insert({
          student_song_id: this.pendingMasteredSong.studentSongId,
          user_id: userId,
          chords_rating: chordsRating ? parseInt(chordsRating) : null,
          tutorial_rating: tutorialRating ? parseInt(tutorialRating) : null
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

    const { error } = await supabase
      .from('student_songs')
      .update({
        status: 'mastered',
        date_completed: new Date().toISOString()
      })
      .eq('id', studentSongId);

    if (error) {
      console.error('Error marking song mastered:', error);
      this.showToast('Failed to update song', 'error');
      return;
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
    const { error } = await supabase
      .from('student_songs')
      .update({
        status: 'learning',
        date_completed: null
      })
      .eq('id', studentSongId);

    if (error) {
      console.error('Error unmarking song:', error);
      this.showToast('Failed to unmaster song', 'error');
      return;
    }

    this.showToast('Song moved back to learning', 'success');
    this.renderProgress();
  }

  async removeSong(studentSongId) {
    if (!confirm('Are you sure you want to remove this song from your progress?')) {
      return;
    }

    const { error } = await supabase
      .from('student_songs')
      .delete()
      .eq('id', studentSongId);

    if (error) {
      console.error('Error removing song:', error);
      this.showToast('Failed to remove song', 'error');
      return;
    }

    this.showToast('Song removed successfully', 'success');
    this.renderProgress();
  }

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

  showLoading(show) {
    console.log('🎵 Cadence: showLoading(' + show + ')');
    document.getElementById('loading-screen').classList.toggle('hidden', !show);
  }

  showLoginScreen() {
    console.log('🎵 Cadence: Showing login screen');
    document.getElementById('login-screen').classList.remove('hidden');
    document.getElementById('role-selection-screen').classList.add('hidden');
    document.getElementById('app').classList.add('hidden');
  }

  showRoleSelection() {
    console.log('🎵 Cadence: Showing role selection screen');
    document.getElementById('login-screen').classList.add('hidden');
    document.getElementById('role-selection-screen').classList.remove('hidden');
    document.getElementById('app').classList.add('hidden');
  }

  async selectRole(role) {
    console.log('🎵 Cadence: User selected role:', role);

    // Complete signup with selected role
    const result = await auth.completeSignupWithRole(role);

    if (result.success) {
      console.log('🎵 Cadence: Signup completed successfully');
      // The onAuthStateChange callback will be triggered automatically
      // which will call onUserSignedIn
    } else {
      console.error('🎵 Cadence: Failed to complete signup:', result.error);
      this.showToast('Failed to complete signup. Please try again.', 'error');
    }
  }

  showApp() {
    console.log('🎵 Cadence: Showing main app');
    document.getElementById('login-screen').classList.add('hidden');
    document.getElementById('role-selection-screen').classList.add('hidden');
    document.getElementById('app').classList.remove('hidden');
  }

  /* ========== TEACHER DASHBOARD METHODS ========== */

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

    console.log('Loaded classes from RPC:', data);

    this.classes = data || [];
    if (this.currentView === 'classes') {
      this.renderClassesList();
    }
  }

  showCreateClassModal() {
    document.getElementById('create-class-modal').classList.remove('hidden');
  }

  setupCreateClassForm() {
    const form = document.getElementById('create-class-form');
    if (!form) {
      console.warn('Create class form not found');
      return;
    }

    form.addEventListener('submit', async (e) => {
      e.preventDefault();
      console.log('Create class form submitted');

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

      console.log('Creating class:', className, yearLevel);

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
      console.warn('Edit class form not found');
      return;
    }

    form.addEventListener('submit', async (e) => {
      e.preventDefault();
      console.log('Edit class form submitted');

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

      console.log('Updating class:', className, yearLevel);

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
      console.log('Archiving class:', className);

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
      console.log('Unarchiving class:', classId);

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

  async loadClassStudents() {
    if (!this.currentClass) return;

    console.log('Loading students for class:', this.currentClass.id);

    try {
      // Use RPC function to bypass RLS recursion issues
      const { data, error } = await supabase.rpc('get_class_students', {
        p_class_id: this.currentClass.id
      });

      console.log('RPC response - data:', data, 'error:', error);

      if (error) {
        console.error('Error loading class students:', error);
        this.classStudents = [];
        document.getElementById('class-detail-count').textContent = '0 students';
        return;
      }

      console.log('Raw class members data:', data);
      console.log('Type of data:', typeof data);

      // Data is already in the right format from the function
      this.classStudents = data || [];

      console.log('Processed class students:', this.classStudents);
      console.log('Student count:', this.classStudents.length);

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
    console.log('viewStudentDetail called with studentId:', studentId);

    // Use RPC function to bypass RLS
    const { data, error } = await supabase.rpc('get_student_detail', {
      p_student_id: studentId
    });

    if (error) {
      console.error('Error loading student detail:', error);
      return;
    }

    console.log('Student detail data from RPC:', data);

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
    console.log('Loading preview data for student:', studentId);

    // Use RPC function to bypass RLS
    const { data, error } = await supabase.rpc('get_student_detail', {
      p_student_id: studentId
    });

    if (error) {
      console.error('Error loading student preview data:', error);
      return;
    }

    console.log('Student preview data from RPC:', data);

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

    console.log('Preview mode - studentProgress:', this.studentProgress);
    console.log('Preview mode - studentSongs:', this.studentSongs);
    console.log('Preview mode - instruments:', this.instruments);
    console.log('Preview mode - currentInstrument:', this.currentInstrument);
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
    console.log('Showing teacher tabs, user role:', currentUser?.role);
    const teacherTabs = document.querySelectorAll('.teacher-tab');
    console.log('Found teacher tabs:', teacherTabs.length);

    if (currentUser && (currentUser.role === 'teacher' || currentUser.role === 'admin')) {
      // Show teacher tabs
      teacherTabs.forEach(tab => {
        console.log('Removing hidden from tab:', tab.getAttribute('data-view'), tab);
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

    console.log('Exit preview complete');
  }

  async loadSubmissions() {
    const user = auth.getCurrentUser();
    console.log('loadSubmissions - current user:', user.id);

    // DEBUG: Check all song_ratings in the database
    const { data: allRatings } = await supabase
      .from('song_ratings')
      .select('id, user_id, assessed_level, date_graded, users(name), songs(title)')
      .order('date_graded', { ascending: false })
      .limit(10);
    console.log('DEBUG - All recent song_ratings:', allRatings);

    // Use RPC function to get all students from teacher's classes
    const { data: students, error: studentsError } = await supabase
      .rpc('get_all_teacher_students');

    console.log('loadSubmissions - students from RPC:', { students, studentsError });

    if (studentsError) {
      console.error('Error loading students:', studentsError);
      this.submissions = [];
      this.renderSubmissionsFeed();
      return;
    }

    if (!students || students.length === 0) {
      console.log('loadSubmissions - no students found');
      this.submissions = [];
      this.renderSubmissionsFeed();
      return;
    }

    const studentIds = students.map(s => s.user_id);
    console.log('loadSubmissions - studentIds:', studentIds);

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

    console.log('loadSubmissions - submissions query result:', { data, error });

    if (error) {
      console.error('Error loading submissions:', error);
      return;
    }

    // Attach student info from our map
    this.submissions = (data || []).map(submission => ({
      ...submission,
      users: studentMap[submission.user_id] || { name: 'Unknown Student' }
    }));
    console.log('loadSubmissions - final submissions:', this.submissions);

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
    const studentIds = this.classStudents.map(m => m.user_id);

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
    const { data, error } = await supabase
      .from('song_ratings')
      .select(`
        song_id,
        instrument_id,
        assessed_level,
        user_id,
        users!inner (name),
        songs!inner (title, artist),
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
          song: rating.songs,
          instrument: rating.instruments,
          ratings: []
        };
      }
      songGroups[key].ratings.push({
        student: rating.users.name,
        level: rating.assessed_level
      });
    });

    // Find songs with 2+ level discrepancies
    const flagged = [];
    Object.values(songGroups).forEach(group => {
      if (group.ratings.length >= 2) {
        const levels = group.ratings.map(r => r.level);
        const min = Math.min(...levels);
        const max = Math.max(...levels);
        if (max - min >= 2) {
          flagged.push(group);
        }
      }
    });

    this.renderFlaggedRatings(flagged);
  }

  renderFlaggedRatings(flaggedSongs) {
    const container = document.getElementById('flagged-ratings-list');
    if (!container) return;

    // Update notification badge
    const badge = document.getElementById('flagged-count-badge');
    if (badge) {
      if (flaggedSongs.length > 0) {
        badge.textContent = flaggedSongs.length;
        badge.classList.remove('hidden');
      } else {
        badge.classList.add('hidden');
      }
    }

    if (flaggedSongs.length === 0) {
      container.innerHTML = '<p style="color: var(--text-secondary); text-align: center; padding: 3rem;">No flagged ratings found</p>';
      return;
    }

    const html = flaggedSongs.map(item => {
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
        </div>
      `;
    }).join('');

    container.innerHTML = html;
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

      console.log('Updating song rating:', {
        ratingId: this.editingRatingId,
        newLevel: newLevel,
        notes: notes
      });

      try {
        // Use RPC function to update rating (bypasses RLS)
        const { data, error } = await supabase
          .rpc('update_song_rating', {
            p_rating_id: this.editingRatingId,
            p_assessed_level: newLevel,
            p_notes: notes || null
          });

        console.log('Update result:', { data, error });

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
    console.log('joinClass called');
    const codeInput = document.getElementById('class-code-input');
    const joinBtn = document.getElementById('join-class-btn');
    const classCode = codeInput.value.trim().toUpperCase();

    console.log('Class code entered:', classCode);

    if (!classCode || classCode.length !== 6) {
      this.showToast('Please enter a valid 6-character class code', 'error');
      return;
    }

    // Disable button during processing
    joinBtn.disabled = true;
    joinBtn.textContent = 'Joining...';

    try {
      const user = auth.getCurrentUser();

      console.log('Calling RPC with:', { userId: user.id, classCode });

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

      console.log('Join class RPC result:', { data, error });

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
    // Get system-wide statistics
    const [usersCount, songsCount, ratingsCount, classesCount] = await Promise.all([
      supabase.from('users').select('*', { count: 'exact', head: true }),
      supabase.from('songs').select('*', { count: 'exact', head: true }),
      supabase.from('song_ratings').select('*', { count: 'exact', head: true }),
      supabase.from('classes').select('*', { count: 'exact', head: true })
    ]);

    const stats = {
      users: usersCount.count || 0,
      songs: songsCount.count || 0,
      ratings: ratingsCount.count || 0,
      classes: classesCount.count || 0
    };

    this.renderAdminStats(stats);
  }

  renderAdminStats(stats) {
    const container = document.getElementById('admin-stats');
    if (!container) return;

    const html = `
      <div class="admin-stat-card">
        <div class="admin-stat-value">${stats.users}</div>
        <div class="admin-stat-label">Total Users</div>
      </div>
      <div class="admin-stat-card">
        <div class="admin-stat-value">${stats.songs}</div>
        <div class="admin-stat-label">Songs in Library</div>
      </div>
      <div class="admin-stat-card">
        <div class="admin-stat-value">${stats.ratings}</div>
        <div class="admin-stat-label">Total Ratings</div>
      </div>
      <div class="admin-stat-card">
        <div class="admin-stat-value">${stats.classes}</div>
        <div class="admin-stat-label">Active Classes</div>
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
    this.currentAdminLevelInstrument = this.instruments[0]?.id;

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
              <button class="btn btn-secondary btn-sm" onclick="app.editChecklist('${level.id}')">Edit Checklist</button>
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

  async editChecklist(levelId) {
    const level = this.adminLevels.find(l => l.id === levelId);
    if (!level) return;

    this.currentEditingChecklistId = levelId;
    this.currentChecklistData = level.grading_checklist_json || {};

    this.renderChecklistEditor();
    document.getElementById('edit-checklist-modal').classList.remove('hidden');
  }

  renderChecklistEditor() {
    const container = document.getElementById('checklist-criteria-container');
    if (!container) return;

    const criteria = Object.entries(this.currentChecklistData);

    let html = '';
    criteria.forEach(([criterionName, options], index) => {
      html += this.renderCriterionEditor(criterionName, options, index);
    });

    container.innerHTML = html;
  }

  renderCriterionEditor(criterionName, options, index) {
    const optionsArray = Array.isArray(options) ? options : [];

    return `
      <div class="criterion-editor" data-index="${index}">
        <div class="criterion-editor-header">
          <input type="text" class="criterion-name" value="${criterionName}" placeholder="Criterion name" />
          <button type="button" class="btn btn-danger btn-sm" onclick="app.removeCriterion(${index})">Remove</button>
        </div>
        <div class="criterion-options" data-criterion="${index}">
          ${optionsArray.map((opt, optIndex) => `
            <div class="criterion-option-tag">
              ${opt}
              <button type="button" onclick="app.removeOption(${index}, ${optIndex})">×</button>
            </div>
          `).join('')}
          <input type="text" class="add-option-input" placeholder="Add option..." onkeypress="if(event.key==='Enter'){event.preventDefault();app.addOption(${index}, this.value); this.value='';}" />
        </div>
      </div>
    `;
  }

  removeCriterion(index) {
    const criteria = Object.entries(this.currentChecklistData);
    criteria.splice(index, 1);
    this.currentChecklistData = Object.fromEntries(criteria);
    this.renderChecklistEditor();
  }

  addOption(criterionIndex, optionValue) {
    if (!optionValue.trim()) return;

    const criteria = Object.entries(this.currentChecklistData);
    const [criterionName, options] = criteria[criterionIndex];
    options.push(optionValue.trim());

    this.renderChecklistEditor();
  }

  removeOption(criterionIndex, optionIndex) {
    const criteria = Object.entries(this.currentChecklistData);
    const [criterionName, options] = criteria[criterionIndex];
    options.splice(optionIndex, 1);

    this.renderChecklistEditor();
  }

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

    const html = this.adminContentList.map(song => {
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

  async loadUsersManagement() {
    const roleFilter = document.getElementById('user-filter-role')?.value || '';

    let query = supabase
      .from('users')
      .select('*, student_progress(count)')
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
      const instrumentCount = user.student_progress?.[0]?.count || 0;

      return `
        <div class="user-admin-card">
          <div class="user-admin-info">
            <div class="user-admin-name">${user.name}</div>
            <div class="user-admin-email">${user.email}</div>
          </div>
          <div class="user-admin-meta">
            <span class="user-role-badge ${user.role}">${user.role.charAt(0).toUpperCase() + user.role.slice(1)}</span>
            <span class="user-admin-stats">${instrumentCount} instrument${instrumentCount !== 1 ? 's' : ''}</span>
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

    // Edit Checklist Form
    const editChecklistForm = document.getElementById('edit-checklist-form');
    if (editChecklistForm) {
      editChecklistForm.addEventListener('submit', async (e) => {
        e.preventDefault();

        // Collect all criteria
        const criteria = {};
        document.querySelectorAll('.criterion-editor').forEach(editor => {
          const nameInput = editor.querySelector('.criterion-name');
          const criterionName = nameInput.value.trim();
          if (!criterionName) return;

          const index = editor.dataset.index;
          const criteriaEntries = Object.entries(this.currentChecklistData);
          const [, options] = criteriaEntries[index];

          criteria[criterionName] = options;
        });

        const { error } = await supabase
          .from('levels')
          .update({ grading_checklist_json: criteria })
          .eq('id', this.currentEditingChecklistId);

        if (error) {
          console.error('Error updating checklist:', error);
          this.showToast('Failed to update checklist', 'error');
          return;
        }

        document.getElementById('edit-checklist-modal').classList.add('hidden');
        this.showToast('Checklist updated successfully', 'success');
        await this.loadAdminLevels();
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

  /* ========== END ADMIN DASHBOARD METHODS ========== */

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
