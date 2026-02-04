// Authentication Module
import { supabase, SUPABASE_URL } from './config.js';

export class AuthManager {
  constructor() {
    this.currentUser = null;
    this.onAuthStateChange = null;
    this.onNeedRoleSelection = null; // Callback for when new user needs to select role
    this.pendingAuthUser = null; // Stores auth user data while waiting for role selection
  }

  // Initialize auth and check session
  async init() {
    const { data: { session } } = await supabase.auth.getSession();

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
          redirectTo: window.location.origin,
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
    // Check if user exists in our users table
    const { data: existingUser, error: fetchError } = await supabase
      .from('users')
      .select('*')
      .eq('id', authUser.id)
      .single();

    if (fetchError && fetchError.code !== 'PGRST116') {
      console.error('Error fetching user:', fetchError);
      return;
    }

    // If user doesn't exist, check for pre-registration before showing role selection
    if (!existingUser) {
      try {
        const { data: preReg, error: preRegError } = await supabase.rpc('check_pre_registration', {
          p_email: authUser.email
        });

        if (!preRegError && preReg && preReg.found) {
          // Auto-create account with pre-registered role
          const result = await this.completeSignupWithRole(
            preReg.role,
            authUser,
            preReg.name || authUser.user_metadata?.full_name || authUser.email.split('@')[0]
          );
          if (result.success) return;
          // If auto-creation failed, fall through to manual role selection
        }
      } catch (preRegCheckError) {
        console.error('Error checking pre-registration:', preRegCheckError);
        // Fall through to manual role selection
      }

      // Auto-assign student role for all new users (teachers are promoted by admin)
      const result = await this.completeSignupWithRole('student', authUser);
      if (result.success) return;

      // If auto-creation failed, store pending user and notify
      this.pendingAuthUser = authUser;
      if (this.onNeedRoleSelection) {
        this.onNeedRoleSelection(authUser);
      }
      return;
    }

    // Existing user - proceed normally
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
      // Create user with selected role
      const { data: newUser, error: insertError } = await supabase
        .from('users')
        .insert([{
          id: authUser.id,
          email: authUser.email,
          name: nameOverride || authUser.user_metadata?.full_name || authUser.email.split('@')[0],
          google_id: authUser.user_metadata?.sub,
          role: role
        }])
        .select()
        .single();

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
      const { data, error } = await supabase.rpc('process_pending_enrollments', {
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
      const { data, error } = await supabase.rpc('complete_pending_teacher_setup', {
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
