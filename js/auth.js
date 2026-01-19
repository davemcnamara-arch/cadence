// Authentication Module
import { supabase } from './config.js';

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

    if (session) {
      await this.handleAuthSuccess(session.user);
    } else {
      // No session - trigger callback to show login screen
      if (this.onAuthStateChange) {
        this.onAuthStateChange(null);
      }
    }

    // Listen for auth state changes
    supabase.auth.onAuthStateChange(async (event, session) => {
      if (event === 'SIGNED_IN' && session) {
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
          redirectTo: window.location.origin
        }
      });

      if (error) throw error;
      return { success: true };
    } catch (error) {
      console.error('Error signing in with Google:', error);
      return { success: false, error: error.message };
    }
  }

  // Sign out
  async signOut() {
    try {
      const { error } = await supabase.auth.signOut();
      if (error) throw error;
      // handleSignOut() will be called automatically by the auth state change listener
      return { success: true };
    } catch (error) {
      console.error('Error signing out:', error);
      return { success: false, error: error.message };
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

    // If user doesn't exist, trigger role selection flow
    if (!existingUser) {
      this.pendingAuthUser = authUser;
      if (this.onNeedRoleSelection) {
        this.onNeedRoleSelection(authUser);
      }
      return;
    }

    // Existing user - proceed normally
    this.currentUser = existingUser;

    // Notify listeners
    if (this.onAuthStateChange) {
      this.onAuthStateChange(this.currentUser);
    }
  }

  // Complete signup with selected role
  async completeSignupWithRole(role) {
    if (!this.pendingAuthUser) {
      console.error('No pending auth user');
      return { success: false, error: 'No pending authentication' };
    }

    const authUser = this.pendingAuthUser;

    try {
      // Create user with selected role
      const { data: newUser, error: insertError } = await supabase
        .from('users')
        .insert([{
          id: authUser.id,
          email: authUser.email,
          name: authUser.user_metadata?.full_name || authUser.email.split('@')[0],
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
