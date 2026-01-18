// Authentication Module
import { supabase } from './config.js';

export class AuthManager {
  constructor() {
    this.currentUser = null;
    this.onAuthStateChange = null;
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

    // Create user if doesn't exist
    if (!existingUser) {
      const { data: newUser, error: insertError } = await supabase
        .from('users')
        .insert([{
          id: authUser.id,
          email: authUser.email,
          name: authUser.user_metadata?.full_name || authUser.email.split('@')[0],
          google_id: authUser.user_metadata?.sub,
          role: 'student'
        }])
        .select()
        .single();

      if (insertError) {
        console.error('Error creating user:', insertError);
        return;
      }

      this.currentUser = newUser;
    } else {
      this.currentUser = existingUser;
    }

    // Notify listeners
    if (this.onAuthStateChange) {
      this.onAuthStateChange(this.currentUser);
    }
  }

  // Handle sign out
  handleSignOut() {
    this.currentUser = null;
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
