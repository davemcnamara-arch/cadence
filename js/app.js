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
    this.currentView = 'pathway';
    this.currentStep = 1;
    this.gradingData = {};
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

    // Logout
    const logoutBtn = document.getElementById('logout-btn');
    if (logoutBtn) {
      logoutBtn.addEventListener('click', () => auth.signOut());
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
  }

  async onUserSignedIn(user) {
    // Load user data
    await this.loadInstruments();
    await this.loadStudentProgress();

    // Update UI
    document.getElementById('user-name').textContent = user.name;
    this.showApp();

    // Check if user has selected instruments
    if (this.studentProgress.length === 0) {
      this.showInstrumentSelection();
    } else {
      // Select first instrument
      this.currentInstrument = this.studentProgress[0].instrument_id;
      await this.loadLevels(this.currentInstrument);
      await this.loadSongs();
      this.renderPathway();
      this.updateInstrumentDropdown();
    }
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
    const { data, error } = await supabase
      .from('student_progress')
      .select('*')
      .eq('user_id', user.id);

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

    const { data, error } = await supabase
      .from('student_progress')
      .insert([{
        user_id: user.id,
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
      this.renderPathway();
      this.updateInstrumentDropdown();
    } else {
      this.updateInstrumentDropdown();
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

    // Delete all student songs for this instrument
    const { error: songsError } = await supabase
      .from('student_songs')
      .delete()
      .eq('user_id', user.id)
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
      .eq('user_id', user.id)
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
    this.renderPathway();
  }

  updateInstrumentDropdown() {
    const dropdown = document.getElementById('current-instrument');
    const filterDropdown = document.getElementById('filter-instrument');
    const gradingDropdown = document.getElementById('grading-instrument');

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

    // Update grading dropdown with student's instruments
    if (gradingDropdown) {
      gradingDropdown.innerHTML = html;
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

    // Group levels
    const regularLevels = this.levels.filter(l => !l.is_branch && l.level_number <= 3);
    const level4Branches = this.levels.filter(l => l.is_branch && l.level_number === 4);
    const level5Branches = this.levels.filter(l => l.is_branch && l.level_number === 5);

    let html = '<div class="pathway-map">';

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
      this.currentView = viewName;

      // Load data for the view if needed
      if (viewName === 'pathway') {
        this.renderPathway();
      } else if (viewName === 'songs') {
        this.renderSongs();
      } else if (viewName === 'progress') {
        this.renderProgress();
      }
    }
  }

  async renderSongs() {
    await this.loadSongs();
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
    const ratings = song.song_ratings || [];
    let levelDisplay, levelLabel;

    if (ratings.length > 0) {
      const avgLevel = (ratings.reduce((sum, r) => sum + r.assessed_level, 0) / ratings.length).toFixed(1);
      levelDisplay = avgLevel;
      levelLabel = `Level ${avgLevel}`;
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

    return `
      <div class="song-card" data-song-id="${song.id}">
        <div class="song-header">
          <div>
            <h3 class="song-title">${song.title}</h3>
            <p class="song-artist">${song.artist}</p>
          </div>
          <button class="btn btn-primary" onclick="event.stopPropagation(); app.addSongToLearning('${song.id}')">Start Learning</button>
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
            <a href="${song.youtube_url}" target="_blank" class="btn btn-secondary" onclick="event.stopPropagation()">YouTube</a>
            <button class="btn-icon" onclick="event.stopPropagation(); app.editSongResource('${song.id}', 'youtube_url', '${song.youtube_url.replace(/'/g, "\\'")}', '${song.title.replace(/'/g, "\\'")}', '${song.artist.replace(/'/g, "\\'")}', '${instrumentName.replace(/'/g, "\\'")}')" title="Edit YouTube link">✎</button>
          ` : `
            <button class="btn btn-secondary btn-add" onclick="event.stopPropagation(); app.editSongResource('${song.id}', 'youtube_url', '', '${song.title.replace(/'/g, "\\'")}', '${song.artist.replace(/'/g, "\\'")}', '${instrumentName.replace(/'/g, "\\'")}')" title="Add YouTube link">+ YouTube</button>
          `}
        </div>
      </div>
    `;
  }

  async viewSongDetails(songId) {
    // Future enhancement: show detailed modal with all ratings
    console.log('View song details:', songId);
  }

  async addSongToLearning(songId) {
    const user = auth.getCurrentUser();

    // Validate that an instrument is selected
    if (!this.currentInstrument) {
      this.showToast('Please select an instrument first', 'warning');
      return;
    }

    // Check if already tracking
    const { data: existing } = await supabase
      .from('student_songs')
      .select('*')
      .eq('user_id', user.id)
      .eq('song_id', songId)
      .eq('instrument_id', this.currentInstrument)
      .single();

    if (existing) {
      this.showToast('Already tracking this song!', 'info');
      return;
    }

    const { error } = await supabase
      .from('student_songs')
      .insert([{
        user_id: user.id,
        song_id: songId,
        instrument_id: this.currentInstrument,
        status: 'learning'
      }]);

    if (error) {
      console.error('Error adding song:', error);
      this.showToast('Failed to add song', 'error');
      return;
    }

    this.showToast('Song added to Currently Learning!', 'success');
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
      this.gradingData.spotify_url = document.getElementById('song-spotify').value;
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

    try {
      // First, check if song exists
      let songId;
      const { data: existingSong } = await supabase
        .from('songs')
        .select('id')
        .eq('title', this.gradingData.title)
        .eq('artist', this.gradingData.artist)
        .single();

      if (existingSong) {
        songId = existingSong.id;
      } else {
        // Create new song
        const { data: newSong, error: songError } = await supabase
          .from('songs')
          .insert([{
            title: this.gradingData.title,
            artist: this.gradingData.artist,
            youtube_url: this.gradingData.youtube_url,
            spotify_url: this.gradingData.spotify_url,
            chords_url: this.gradingData.chords_url,
            tutorial_url: this.gradingData.tutorial_url,
            added_by_user_id: user.id,
            approved: true // Auto-approve for MVP
          }])
          .select()
          .single();

        if (songError) throw songError;
        songId = newSong.id;
      }

      // Add rating
      const { error: ratingError } = await supabase
        .from('song_ratings')
        .insert([{
          song_id: songId,
          instrument_id: this.gradingData.instrument,
          assessed_level: this.gradingData.level,
          user_id: user.id,
          checklist_responses_json: this.gradingData.checklistResponses
        }]);

      if (ratingError) throw ratingError;

      // Add to learning if checked
      if (document.getElementById('add-to-learning').checked) {
        await supabase
          .from('student_songs')
          .insert([{
            user_id: user.id,
            song_id: songId,
            instrument_id: this.gradingData.instrument,
            status: 'learning'
          }]);
      }

      // Close modal and refresh
      document.getElementById('song-grading-modal').classList.add('hidden');
      this.showToast('Song graded successfully!', 'success');
      await this.loadSongs();

      if (this.currentView === 'songs') {
        this.renderSongs();
      }
    } catch (error) {
      console.error('Error submitting grading:', error);
      this.showToast('Failed to submit grading', 'error');
    }
  }

  async renderProgress() {
    const user = auth.getCurrentUser();

    // Load student songs
    const { data: studentSongs } = await supabase
      .from('student_songs')
      .select(`
        *,
        songs (*)
      `)
      .eq('user_id', user.id)
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
    const studentSongsWithRatings = studentSongs?.map(s => ({
      ...s,
      resource_ratings: ratingsMap[s.id] || { chords: [], tutorial: [] }
    }));

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
              <a href="${song.chords_url}" target="_blank" style="font-size: 12px; color: var(--secondary-color);">Chords</a>
              ${chordsRating}
              <button class="btn-icon-small" onclick="app.editSongResource('${song.id}', 'chords_url', '${song.chords_url.replace(/'/g, "\\'")}', '${song.title.replace(/'/g, "\\'")}', '${song.artist.replace(/'/g, "\\'")}', '${instrumentName.replace(/'/g, "\\'")}')" title="Edit chords link">✎</button>
            ` : `
              <button class="btn-link-add" onclick="app.editSongResource('${song.id}', 'chords_url', '', '${song.title.replace(/'/g, "\\'")}', '${song.artist.replace(/'/g, "\\'")}', '${instrumentName.replace(/'/g, "\\'")}')" title="Add chords link">+ Chords</button>
            `}
            ${song.tutorial_url ? `
              <a href="${song.tutorial_url}" target="_blank" style="font-size: 12px; color: var(--secondary-color);">Tutorial</a>
              ${tutorialRating}
              <button class="btn-icon-small" onclick="app.editSongResource('${song.id}', 'tutorial_url', '${song.tutorial_url.replace(/'/g, "\\'")}', '${song.title.replace(/'/g, "\\'")}', '${song.artist.replace(/'/g, "\\'")}', '${instrumentName.replace(/'/g, "\\'")}')" title="Edit tutorial link">✎</button>
            ` : `
              <button class="btn-link-add" onclick="app.editSongResource('${song.id}', 'tutorial_url', '', '${song.title.replace(/'/g, "\\'")}', '${song.artist.replace(/'/g, "\\'")}', '${instrumentName.replace(/'/g, "\\'")}')" title="Add tutorial link">+ Tutorial</button>
            `}
            ${song.youtube_url ? `
              <a href="${song.youtube_url}" target="_blank" style="font-size: 12px; color: var(--secondary-color);">YouTube</a>
              <button class="btn-icon-small" onclick="app.editSongResource('${song.id}', 'youtube_url', '${song.youtube_url.replace(/'/g, "\\'")}', '${song.title.replace(/'/g, "\\'")}', '${song.artist.replace(/'/g, "\\'")}', '${instrumentName.replace(/'/g, "\\'")}')" title="Edit YouTube link">✎</button>
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
            <button class="btn btn-secondary" onclick="app.removeSong('${studentSong.id}')">
              Remove
            </button>
          ` : `
            <span style="color: var(--secondary-color); font-weight: 600; margin-right: 8px;">✓ Mastered</span>
            <button class="btn btn-secondary" onclick="app.unmasterSong('${studentSong.id}')">
              Unmaster
            </button>
            <button class="btn btn-secondary" onclick="app.removeSong('${studentSong.id}')">
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

    // Save ratings if provided
    if (chordsRating || tutorialRating) {
      const { error } = await supabase
        .from('resource_ratings')
        .insert({
          student_song_id: this.pendingMasteredSong.studentSongId,
          user_id: user.id,
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
      .eq('user_id', user.id)
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
        .eq('user_id', user.id)
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
    document.getElementById('app').classList.add('hidden');
  }

  showApp() {
    console.log('🎵 Cadence: Showing main app');
    document.getElementById('login-screen').classList.add('hidden');
    document.getElementById('app').classList.remove('hidden');
  }

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
