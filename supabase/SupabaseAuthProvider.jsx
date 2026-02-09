import { createContext, useContext, useState, useEffect } from 'react';
import { supabase } from './client';

const AuthContext = createContext();

export const SupabaseAuthProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [selectedAccount, setSelectedAccount] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // 1. Fetch the initial Supabase user session
    supabase.auth.getSession().then(({ data: { session } }) => {
      setUser(session?.user ?? null);
      
      // 2. Check if an account was saved in the session storage
      try {
        const savedAccount = sessionStorage.getItem('selectedAccount');
        if (savedAccount) {
          const account = JSON.parse(savedAccount);
          // Ensure the saved account belongs to the current user
          if (session && account.email === session.user.email) {
            setSelectedAccount(account);
          } else {
            sessionStorage.removeItem('selectedAccount');
          }
        }
      } catch (e) {
        console.error('Failed to parse selectedAccount from sessionStorage', e);
        sessionStorage.removeItem('selectedAccount');
      }

      setLoading(false);
    });

    // 3. Listen for future auth state changes
    const { data: authListener } = supabase.auth.onAuthStateChange(
      (event, session) => {
        setUser(session?.user ?? null);
        // If user logs out, clear the selected account
        if (event === 'SIGNED_OUT') {
          setSelectedAccount(null);
          sessionStorage.removeItem('selectedAccount');
        }
        setLoading(false);
      }
    );

    return () => {
      authListener.subscription.unsubscribe();
    };
  }, []);

  // Securely verifies the user's PIN by calling a Supabase Edge Function.
  // YOU MUST CREATE THIS EDGE FUNCTION for PIN login to work.
  // The function should be named 'verify-pin'.
  // It should accept a POST request with { accountId, pin }.
  // It should return { isValid: true } on success or { isValid: false, message: '...' } on failure.
  const loginWithPin = async (account, pin) => {
    try {
      const { data, error } = await supabase.functions.invoke('verify-pin', {
        body: { accountId: account.account_ID, pin: pin },
      });

      if (error) throw error;

      if (data.isValid) {
        sessionStorage.setItem('selectedAccount', JSON.stringify(account));
        setSelectedAccount(account);
        return { success: true, error: null };
      } else {
        throw new Error(data.message || 'Invalid PIN.');
      }
    } catch (err) {
      console.error('Edge Function "verify-pin" error:', err);
      return { success: false, error: { message: err.message } };
    }
  };
  
  const signOut = async () => {
    await supabase.auth.signOut();
    setSelectedAccount(null);
    setUser(null);
    sessionStorage.removeItem('selectedAccount');
  };

  const value = {
    signUp: (data) => supabase.auth.signUp(data),
    signIn: (data) => supabase.auth.signInWithPassword(data),
    signOut,
    user,
    selectedAccount,
    loginWithPin,
  };

  return (
    <AuthContext.Provider value={value}>
      {!loading && children}
    </AuthContext.Provider>
  );
};

export const useSupabaseAuth = () => {
  return useContext(AuthContext);
};