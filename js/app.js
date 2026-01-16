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
    if (addInstrumentBtn) {
      addInstrumentBtn.addEventListener('click', () => this.showInstrumentSelection());
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

    this.songs = data || [];
  }

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
      const allInstrumentsHtml = '<option value="">All Instruments</option>' +
        this.instruments.map(i => `<option value="${i.id}">${i.icon} ${i.name}</option>`).join('');
      filterDropdown.innerHTML = allInstrumentsHtml;
    }

    // Update grading dropdown with student's instruments
    if (gradingDropdown) {
      gradingDropdown.innerHTML = html;
    }
  }

  renderPathway() {
    const container = document.getElementById('pathway-container');
    const progress = this.studentProgress.find(p => p.instrument_id === this.currentInstrument);

    if (!progress) return;

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

    // Render Level 4 branches
    if (currentLevel >= 4) {
      html += '<div class="branch-container">';
      level4Branches.forEach(branch => {
        const isSelected = currentBranch === branch.branch_name && currentLevel === 4;
        const isComplete = currentLevel > 4 && currentBranch === branch.branch_name;
        html += this.renderBranchNode(branch, isSelected, isComplete);
      });
      html += '</div>';
    }

    // Render Level 5 branches if Level 4 is complete
    if (currentLevel >= 5 && currentBranch) {
      const level5ForBranch = level5Branches.filter(b =>
        b.branch_name && currentBranch && b.branch_name.split(' ')[0] === currentBranch.split(' ')[0]
      );

      if (level5ForBranch.length > 0) {
        html += '<div class="branch-container">';
        level5ForBranch.forEach(branch => {
          const isSelected = currentBranch === branch.branch_name && currentLevel === 5;
          html += this.renderBranchNode(branch, isSelected, false);
        });
        html += '</div>';
      }
    }

    html += '</div>';
    container.innerHTML = html;
  }

  renderLevelNode(level, isComplete, isCurrent) {
    const skills = typeof level.skills_json === 'string' ? JSON.parse(level.skills_json) : (level.skills_json || []);
    const statusClass = isComplete ? 'completed' : (isCurrent ? 'current' : '');

    return `
      <div class="level-node ${statusClass}">
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
      <div class="branch-node ${statusClass}" data-branch="${branch.branch_name}">
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
      if (viewName === 'songs') {
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

    if (instrumentFilter) {
      filteredSongs = filteredSongs.filter(song =>
        song.song_ratings?.some(r => r.instrument_id === instrumentFilter)
      );
    }

    if (levelFilter) {
      filteredSongs = filteredSongs.filter(song =>
        song.song_ratings?.some(r => r.assessed_level === parseInt(levelFilter))
      );
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

  renderSongCard(song) {
    const ratings = song.song_ratings || [];
    const avgLevel = ratings.length > 0
      ? (ratings.reduce((sum, r) => sum + r.assessed_level, 0) / ratings.length).toFixed(1)
      : 'Not rated';

    return `
      <div class="song-card" data-song-id="${song.id}">
        <div class="song-header">
          <div>
            <h3 class="song-title">${song.title}</h3>
            <p class="song-artist">${song.artist}</p>
          </div>
        </div>
        <div class="song-meta">
          <span class="song-tag level">Level ${avgLevel}</span>
          <span class="song-tag">${ratings.length} rating${ratings.length !== 1 ? 's' : ''}</span>
        </div>
        <div class="song-actions">
          ${song.youtube_url ? `<a href="${song.youtube_url}" target="_blank" class="btn btn-secondary" onclick="event.stopPropagation()">YouTube</a>` : ''}
          ${song.spotify_url ? `<a href="${song.spotify_url}" target="_blank" class="btn btn-secondary" onclick="event.stopPropagation()">Spotify</a>` : ''}
          <button class="btn btn-primary" onclick="event.stopPropagation(); app.addSongToLearning('${song.id}')">Start Learning</button>
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

    // Calculate stats
    const learning = studentSongs?.filter(s => s.status === 'learning') || [];
    const mastered = studentSongs?.filter(s => s.status === 'mastered') || [];

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
    return `
      <div class="song-list-item">
        <div class="info">
          <div class="title">${song.title}</div>
          <div class="artist">${song.artist}</div>
        </div>
        <div class="actions">
          ${studentSong.status === 'learning' ? `
            <button class="btn btn-primary" onclick="app.markSongMastered('${studentSong.id}')">
              Mark Mastered
            </button>
          ` : `
            <span style="color: var(--secondary-color); font-weight: 600;">✓ Mastered</span>
          `}
        </div>
      </div>
    `;
  }

  async markSongMastered(studentSongId) {
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
      const text = await this.generateReflection();
      reflectionText.value = text;
      reflectionText.classList.remove('hidden');
      copyReflectionBtn.classList.remove('hidden');
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
    const { data: studentSongs } = await supabase
      .from('student_songs')
      .select(`
        *,
        songs (*),
        instruments (name)
      `)
      .eq('user_id', user.id);

    // Create CSV
    let csv = 'Song Title,Artist,Instrument,Status,Date Started,Date Completed\n';

    studentSongs.forEach(ss => {
      csv += `"${ss.songs.title}","${ss.songs.artist}","${ss.instruments.name}","${ss.status}","${new Date(ss.date_started).toLocaleDateString()}","${ss.date_completed ? new Date(ss.date_completed).toLocaleDateString() : ''}"\n`;
    });

    // Download
    const blob = new Blob([csv], { type: 'text/csv' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `cadence-progress-${new Date().toISOString().split('T')[0]}.csv`;
    a.click();

    this.showToast('CSV exported successfully!', 'success');
  }

  async generateReflection() {
    const user = auth.getCurrentUser();

    const { data: studentSongs } = await supabase
      .from('student_songs')
      .select(`
        *,
        songs (*),
        instruments (name)
      `)
      .eq('user_id', user.id);

    const learning = studentSongs.filter(s => s.status === 'learning');
    const mastered = studentSongs.filter(s => s.status === 'mastered');

    const instrumentNames = [...new Set(this.studentProgress.map(p => {
      const inst = this.instruments.find(i => i.id === p.instrument_id);
      return inst?.name;
    }))];

    let reflection = `Music Skill Progression Reflection\n\n`;
    reflection += `I am currently developing my skills on ${instrumentNames.join(', ')}. `;
    reflection += `Throughout this term, I have been working on ${learning.length + mastered.length} songs total.\n\n`;

    if (mastered.length > 0) {
      reflection += `I have successfully mastered ${mastered.length} song${mastered.length !== 1 ? 's' : ''}, including:\n`;
      mastered.forEach(ss => {
        reflection += `- "${ss.songs.title}" by ${ss.songs.artist} on ${ss.instruments.name}\n`;
      });
      reflection += '\n';
    }

    if (learning.length > 0) {
      reflection += `I am currently learning ${learning.length} song${learning.length !== 1 ? 's' : ''}:\n`;
      learning.forEach(ss => {
        reflection += `- "${ss.songs.title}" by ${ss.songs.artist} on ${ss.instruments.name}\n`;
      });
      reflection += '\n';
    }

    this.studentProgress.forEach(progress => {
      const inst = this.instruments.find(i => i.id === progress.instrument_id);
      reflection += `On ${inst.name}, I am working at Level ${progress.current_level}`;
      if (progress.current_branch) {
        reflection += ` (${progress.current_branch})`;
      }
      reflection += '.\n';
    });

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
