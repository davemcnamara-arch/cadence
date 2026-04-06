// Authentication Module
import { supabase, SUPABASE_URL, SUPABASE_ANON_KEY } from './config.js';

const AUTH_TIMEOUT_MS = 8000;

export class AuthManager {
  constructor() {
    this.currentUser = null;
    this.onAuthStateChange = null;
    this.onNeedRoleSelection = null; // Callback for when new user needs to select role
    this.pendingAuthUser = null; // Stores auth user data while waiting for role selection
  }

  // Timeout-wrapped Supabase auth call to prevent hanging on stale connections
  async withTimeout(promise, timeoutMs = AUTH_TIMEOUT_MS, context = 'auth') {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), timeoutMs);
    try {
      const result = await Promise.race([
        promise,
        new Promise((_, reject) =>
          setTimeout(() => reject(new Error(`${context} timed out after ${timeoutMs}ms`)), timeoutMs)
        )
      ]);
      clearTimeout(timeoutId);
      return result;
    } catch (err) {
      clearTimeout(timeoutId);
      throw err;
    }
  }

  // Direct fetch wrapper for Supabase select queries (bypasses stale client)
  async fetchDirect(table, select = '*', filters = {}, options = {}) {
    const params = new URLSearchParams();
    params.set('select', select);
    for (const [op, conditions] of Object.entries(filters)) {
      for (const [column, value] of Object.entries(conditions)) {
        params.append(column, `${op}.${value}`);
      }
    }

    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), AUTH_TIMEOUT_MS);

    try {
      // Get access token from localStorage
      const storageKey = Object.keys(localStorage).find(key =>
        key.startsWith('sb-') && key.endsWith('-auth-token')
      );
      const tokenData = storageKey ? JSON.parse(localStorage.getItem(storageKey)) : null;
      const headers = {
        'Content-Type': 'application/json',
        'apikey': SUPABASE_ANON_KEY
      };
      if (tokenData?.access_token) {
        headers['Authorization'] = `Bearer ${tokenData.access_token}`;
      }

      const response = await fetch(
        `${SUPABASE_URL}/rest/v1/${table}?${params.toString()}`,
        { method: 'GET', headers, signal: controller.signal }
      );
      clearTimeout(timeoutId);

      if (!response.ok) {
        const errorData = await response.json().catch(() => ({}));
        return { data: null, error: { message: errorData.message || `HTTP ${response.status}`, code: errorData.code } };
      }

      const data = await response.json();
      return { data, error: null };
    } catch (err) {
      clearTimeout(timeoutId);
      if (err.name === 'AbortError') {
        return { data: null, error: { message: 'Connection timeout' } };
      }
      return { data: null, error: { message: err.message } };
    }
  }

  // Direct fetch wrapper for Supabase RPC calls (bypasses stale client)
  async rpcDirect(functionName, params) {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), AUTH_TIMEOUT_MS);

    try {
      const storageKey = Object.keys(localStorage).find(key =>
        key.startsWith('sb-') && key.endsWith('-auth-token')
      );
      const tokenData = storageKey ? JSON.parse(localStorage.getItem(storageKey)) : null;
      const headers = {
        'Content-Type': 'application/json',
        'apikey': SUPABASE_ANON_KEY
      };
      if (tokenData?.access_token) {
        headers['Authorization'] = `Bearer ${tokenData.access_token}`;
      }

      const response = await fetch(
        `${SUPABASE_URL}/rest/v1/rpc/${functionName}`,
        {
          method: 'POST',
          headers,
          body: JSON.stringify(params),
          signal: controller.signal
        }
      );
      clearTimeout(timeoutId);

      if (!response.ok) {
        const errorData = await response.json().catch(() => ({}));
        return { data: null, error: { message: errorData.message || `HTTP ${response.status}` } };
      }

      const text = await response.text();
      const data = text ? JSON.parse(text) : null;
      return { data, error: null };
    } catch (err) {
      clearTimeout(timeoutId);
      if (err.name === 'AbortError') {
        return { data: null, error: { message: 'Connection timeout' } };
      }
      return { data: null, error: { message: err.message } };
    }
  }

  // Direct fetch wrapper for Supabase INSERT (bypasses stale client)
  async insertDirect(table, rows) {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), AUTH_TIMEOUT_MS);

    try {
      const storageKey = Object.keys(localStorage).find(key =>
        key.startsWith('sb-') && key.endsWith('-auth-token')
      );
      const tokenData = storageKey ? JSON.parse(localStorage.getItem(storageKey)) : null;
      const headers = {
        'Content-Type': 'application/json',
        'apikey': SUPABASE_ANON_KEY,
        'Prefer': 'return=representation'
      };
      if (tokenData?.access_token) {
        headers['Authorization'] = `Bearer ${tokenData.access_token}`;
      }

      const response = await fetch(
        `${SUPABASE_URL}/rest/v1/${table}`,
        {
          method: 'POST',
          headers,
          body: JSON.stringify(rows),
          signal: controller.signal
        }
      );
      clearTimeout(timeoutId);

      if (!response.ok) {
        const errorData = await response.json().catch(() => ({}));
        return { data: null, error: { message: errorData.message || `HTTP ${response.status}` } };
      }

      const data = await response.json();
      // Return first item to match .single() behavior
      return { data: Array.isArray(data) ? data[0] : data, error: null };
    } catch (err) {
      clearTimeout(timeoutId);
      if (err.name === 'AbortError') {
        return { data: null, error: { message: 'Connection timeout' } };
      }
      return { data: null, error: { message: err.message } };
    }
  }

  // Direct fetch wrapper for Supabase PATCH (bypasses stale client)
  async patchDirect(table, updates, filters = {}) {
    const params = new URLSearchParams();
    for (const [op, conditions] of Object.entries(filters)) {
      for (const [column, value] of Object.entries(conditions)) {
        params.append(column, `${op}.${value}`);
      }
    }

    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), AUTH_TIMEOUT_MS);

    try {
      const storageKey = Object.keys(localStorage).find(key =>
        key.startsWith('sb-') && key.endsWith('-auth-token')
      );
      const tokenData = storageKey ? JSON.parse(localStorage.getItem(storageKey)) : null;
      const headers = {
        'Content-Type': 'application/json',
        'apikey': SUPABASE_ANON_KEY,
        'Prefer': 'return=representation'
      };
      if (tokenData?.access_token) {
        headers['Authorization'] = `Bearer ${tokenData.access_token}`;
      }

      const response = await fetch(
        `${SUPABASE_URL}/rest/v1/${table}?${params.toString()}`,
        {
          method: 'PATCH',
          headers,
          body: JSON.stringify(updates),
          signal: controller.signal
        }
      );
      clearTimeout(timeoutId);

      if (!response.ok) {
        const errorData = await response.json().catch(() => ({}));
        return { data: null, error: { message: errorData.message || `HTTP ${response.status}` } };
      }

      const data = await response.json();
      return { data: Array.isArray(data) ? data[0] : data, error: null };
    } catch (err) {
      clearTimeout(timeoutId);
      if (err.name === 'AbortError') {
        return { data: null, error: { message: 'Connection timeout' } };
      }
      return { data: null, error: { message: err.message } };
    }
  }

  // Initialize auth and check session
  async init() {
    const { data: { session } } = await this.withTimeout(
      supabase.auth.getSession(),
      AUTH_TIMEOUT_MS,
      'getSession'
    );

    // Clean up OAuth hash fragment from URL after Supabase has read it.
    // Without this, the #access_token=... URL stays in browser history
    // and the device back button navigates to it instead of going back in-app.
    if (window.location.hash && window.location.hash.includes('access_token')) {
      const cleanUrl = window.location.pathname + window.location.search;
      history.replaceState(null, '', cleanUrl);
    }

    let handledSession = false;
    if (session) {
      await this.handleAuthSuccess(session.user);
      handledSession = true;
    } else {
      // No session - trigger callback to show login screen
      if (this.onAuthStateChange) {
        this.onAuthStateChange(null);
      }
    }

    // Listen for auth state changes
    supabase.auth.onAuthStateChange(async (event, session) => {
      if (event === 'SIGNED_IN' && session) {
        // Skip if we already handled this session during init
        if (handledSession) {
          handledSession = false;
          return;
        }
        await this.handleAuthSuccess(session.user);
      } else if (event === 'SIGNED_OUT') {
        this.handleSignOut();
      }
    });

    return this.currentUser;
  }

  // Sign in with Google
  async signInWithGoogle() {
    try {
      const { data, error } = await supabase.auth.signInWithOAuth({
        provider: 'google',
        options: {
          redirectTo: window.location.origin + '/app.html',
          queryParams: {
            prompt: 'select_account'
          }
        }
      });

      if (error) throw error;
      return { success: true };
    } catch (error) {
      console.error('Error signing in with Google:', error);
      return { success: false, error: error.message };
    }
  }

  // Sign out using direct fetch to bypass potentially stale Supabase client
  // This mirrors the approach used for grading RPC calls
  async signOut() {
    const SIGNOUT_TIMEOUT_MS = 5000;

    try {
      // Get access token from localStorage
      const storageKey = Object.keys(localStorage).find(key =>
        key.startsWith('sb-') && key.endsWith('-auth-token')
      );

      if (storageKey) {
        const tokenData = JSON.parse(localStorage.getItem(storageKey));
        const accessToken = tokenData?.access_token;

        if (accessToken) {
          // Use AbortController for clean timeout handling
          const controller = new AbortController();
          const timeoutId = setTimeout(() => controller.abort(), SIGNOUT_TIMEOUT_MS);

          try {
            // Call Supabase logout endpoint directly, bypassing the stale client
            await fetch(`${SUPABASE_URL}/auth/v1/logout`, {
              method: 'POST',
              headers: {
                'Authorization': `Bearer ${accessToken}`,
                'Content-Type': 'application/json'
              },
              signal: controller.signal
            });
          } finally {
            clearTimeout(timeoutId);
          }
        }

        // Clear local session data
        localStorage.removeItem(storageKey);
      }

      this.handleSignOut();
      return { success: true };
    } catch (error) {
      // AbortError means timeout - not a real failure, just slow connection
      if (error.name === 'AbortError') {
        console.log('Sign out request timed out, clearing local session');
      } else {
        console.error('Error during sign out:', error);
      }

      // Clear local session regardless of server response
      this.clearLocalSession();
      this.handleSignOut();
      return { success: true };
    }
  }

  // Clear session data from localStorage
  clearLocalSession() {
    const storageKey = Object.keys(localStorage).find(key =>
      key.startsWith('sb-') && key.endsWith('-auth-token')
    );
    if (storageKey) {
      localStorage.removeItem(storageKey);
    }
  }

  // Handle successful authentication
  async handleAuthSuccess(authUser) {
    // Check if user exists in our users table (using direct fetch to avoid stale connections)
    const { data: usersArray, error: fetchError } = await this.fetchDirect(
      'users',
      '*',
      { eq: { id: authUser.id } }
    );

    // fetchDirect returns an array; .single() equivalent
    const existingUser = usersArray && usersArray.length > 0 ? usersArray[0] : null;

    if (fetchError && fetchError.code !== 'PGRST116') {
      console.error('Error fetching user:', fetchError);
      // CRITICAL: Don't silently return - notify callback so UI shows login screen instead of loading forever
      if (this.onAuthStateChange) {
        this.onAuthStateChange(null);
      }
      return;
    }

    // If user doesn't exist, check for pre-registration before showing role selection
    if (!existingUser) {
      try {
        const { data: preReg, error: preRegError } = await this.rpcDirect('check_pre_registration', {
          p_email: authUser.email
        });

        if (!preRegError && preReg && preReg.found) {
          // Auto-create account with pre-registered role
          const result = await this.completeSignupWithRole(
            preReg.role,
            authUser,
            preReg.name || authUser.user_metadata?.full_name || authUser.email.split('@')[0]
          );
          if (result.success) {
            // If invited via the School tab, auto-join that school (no join code needed)
            if (preReg.school_id) {
              await this.rpcDirect('auto_join_school_by_id', { p_school_id: preReg.school_id });
            }
            return;
          }
          // If auto-creation failed, fall through to manual role selection
        }
      } catch (preRegCheckError) {
        console.error('Error checking pre-registration:', preRegCheckError);
        // Fall through to manual role selection
      }

      // Use role from login.html selector if present, otherwise default to student
      const signupRole = localStorage.getItem('cadence_signup_role') || 'student';
      const result = await this.completeSignupWithRole(signupRole, authUser);
      if (result.success) return;

      // If auto-creation failed, store pending user and notify
      this.pendingAuthUser = authUser;
      if (this.onNeedRoleSelection) {
        this.onNeedRoleSelection(authUser);
      }
      return;
    }

    // Existing user — check if they selected a different role on the login page.
    // Handles two cases:
    //   student → teacher: existing student clicking "I'm a teacher" to upgrade;
    //                      the teacher subscription gate in app.js will then fire.
    //   teacher → student: teacher accidentally clicked "I'm a student"; clicking
    //                      "I'm a teacher" next time will upgrade them back.
    const selectedRole = localStorage.getItem('cadence_signup_role');
    const roleSwitch =
      (selectedRole === 'teacher' && existingUser.role === 'student') ||
      (selectedRole === 'student' && existingUser.role === 'teacher');
    if (roleSwitch) {
      const { error: patchError } = await this.patchDirect(
        'users',
        { role: selectedRole },
        { eq: { id: existingUser.id } }
      );
      if (patchError) {
        console.error('Error updating user role:', patchError);
      }
      // Always apply the selected role in memory, even if the DB patch failed
      // (e.g. blocked by RLS). This ensures the subscription gate in app.js
      // fires for a student who selects "teacher" — they'll be redirected to
      // subscribe rather than silently admitted as a student.
      existingUser.role = selectedRole;
    }

    this.currentUser = existingUser;

    // Process any pending enrollments for this user
    await this.processPendingEnrollments(existingUser.id);

    // Notify listeners
    if (this.onAuthStateChange) {
      this.onAuthStateChange(this.currentUser);
    }
  }

  // Complete signup with selected role
  // authUserOverride and nameOverride are used by pre-registration flow
  async completeSignupWithRole(role, authUserOverride, nameOverride) {
    const authUser = authUserOverride || this.pendingAuthUser;
    if (!authUser) {
      console.error('No pending auth user');
      return { success: false, error: 'No pending authentication' };
    }

    try {
      // Create user with selected role (using direct fetch to avoid stale connections)
      const { data: newUser, error: insertError } = await this.insertDirect('users', [{
        id: authUser.id,
        email: authUser.email,
        name: nameOverride || authUser.user_metadata?.full_name || authUser.email.split('@')[0],
        google_id: authUser.user_metadata?.sub,
        role: role
      }]);

      if (insertError) {
        console.error('Error creating user:', insertError);
        return { success: false, error: insertError.message };
      }

      this.currentUser = newUser;
      this.pendingAuthUser = null;

      // Process any pending enrollments for this new user
      await this.processPendingEnrollments(newUser.id);

      // For teachers/admins, transfer any classes that were pre-assigned to them
      if (role === 'teacher' || role === 'admin') {
        await this.transferPendingClasses(newUser.email);
      }

      // Notify listeners
      if (this.onAuthStateChange) {
        this.onAuthStateChange(this.currentUser);
      }

      return { success: true, user: newUser };
    } catch (error) {
      console.error('Error completing signup:', error);
      return { success: false, error: error.message };
    }
  }

  // Process pending enrollments for a user (called on login/signup)
  async processPendingEnrollments(userId) {
    try {
      const { data, error } = await this.rpcDirect('process_pending_enrollments', {
        p_user_id: userId
      });

      if (error) {
        console.error('Error processing pending enrollments:', error);
        return;
      }

      // If user was auto-enrolled in classes, we might want to notify them
      // The app.js will handle showing toasts if needed
      if (data && data.enrolled_count > 0) {
        // Store the enrollment result so the app can display it
        this.lastEnrollmentResult = data;
      }
    } catch (error) {
      console.error('Unexpected error processing pending enrollments:', error);
    }
  }

  // Transfer classes that were pre-assigned to a pending teacher
  async transferPendingClasses(email) {
    try {
      const { data, error } = await this.rpcDirect('complete_pending_teacher_setup', {
        p_email: email
      });

      if (error) {
        console.error('Error transferring pending classes:', error);
        return;
      }

      if (data && data.transferred_classes > 0) {
        console.log(`Transferred ${data.transferred_classes} class(es) to new teacher`);
        this.lastClassTransferResult = data;
      }
    } catch (error) {
      console.error('Unexpected error transferring pending classes:', error);
    }
  }

  // Handle sign out
  handleSignOut() {
    this.currentUser = null;
    this.pendingAuthUser = null;
    if (this.onAuthStateChange) {
      this.onAuthStateChange(null);
    }
  }

  // Get current user
  getCurrentUser() {
    return this.currentUser;
  }

  // Check if user is authenticated
  isAuthenticated() {
    return this.currentUser !== null;
  }

  // Check user role
  hasRole(role) {
    return this.currentUser?.role === role;
  }
}

// Create singleton instance
export const auth = new AuthManager();
