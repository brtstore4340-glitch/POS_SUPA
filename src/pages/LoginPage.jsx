import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useSupabaseAuth } from '../../supabase/SupabaseAuthProvider';

export default function LoginPage() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [rememberMe, setRememberMe] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [showSignupInfo, setShowSignupInfo] = useState(false);

  const { signIn } = useSupabaseAuth();
  const navigate = useNavigate();

  // On component mount, check for saved credentials
  useEffect(() => {
    try {
      const savedEmail = localStorage.getItem('rememberedEmail');
      // NOTE: Storing passwords in localStorage is not secure. This is implemented as requested.
      const savedPassword = localStorage.getItem('rememberedPassword');
      if (savedEmail && savedPassword) {
        setEmail(savedEmail);
        setPassword(savedPassword);
        setRememberMe(true);
      }
    } catch (e) {
      console.error('Failed to read from localStorage:', e);
    }
  }, []);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError('');
    setShowSignupInfo(false);

    try {
      const { error } = await signIn({ email, password });
      if (error) throw error;

      // Handle "Remember Me" logic
      if (rememberMe) {
        localStorage.setItem('rememberedEmail', email);
        localStorage.setItem('rememberedPassword', password);
      } else {
        localStorage.removeItem('rememberedEmail');
        localStorage.removeItem('rememberedPassword');
      }

      console.log('✅ Step 1/2: Email login successful');
      navigate('/pin-login'); // Proceed to PIN login
    } catch (err) {
      console.error('Sign-in error:', err);
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={{
      display: 'flex',
      justifyContent: 'center',
      alignItems: 'center',
      minHeight: '100vh',
      backgroundColor: '#f3f4f6',
      fontFamily: 'system-ui'
    }}>
      <div style={{
        backgroundColor: 'white',
        padding: '40px',
        borderRadius: '12px',
        boxShadow: '0 4px 6px rgba(0,0,0,0.1)',
        width: '400px',
        maxWidth: '90%'
      }}>
        <h1 style={{ marginBottom: '24px', textAlign: 'center' }}>
          🔐 Sign In
        </h1>

        {error && (
          <div style={{
            padding: '12px',
            backgroundColor: '#fee2e2',
            color: '#b91c1c',
            borderRadius: '6px',
            marginBottom: '16px',
            fontSize: '14px'
          }}>
            <strong>Error:</strong> {error}
          </div>
        )}

        {showSignupInfo ? (
          <div style={{
            padding: '20px',
            backgroundColor: '#dbeafe',
            color: '#1e40af',
            borderRadius: '6px',
            textAlign: 'center'
          }}>
            <h2 style={{ marginTop: 0 }}>Create an Account</h2>
            <p>To create a new account, please contact your system administrator.</p>
            <button
              onClick={() => setShowSignupInfo(false)}
              style={{
                marginTop: '16px',
                padding: '10px 16px',
                border: '1px solid #1e40af',
                backgroundColor: 'transparent',
                color: '#1e40af',
                borderRadius: '6px',
                cursor: 'pointer'
              }}
            >
              &larr; Back to Sign In
            </button>
          </div>
        ) : (
          <form onSubmit={handleSubmit}>
            <div style={{ marginBottom: '16px' }}>
              <label style={{ display: 'block', marginBottom: '8px', fontWeight: 500 }}>
                Email
              </label>
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                required
                autoComplete="email"
                style={{
                  width: '100%',
                  padding: '10px',
                  border: '1px solid #d1d5db',
                  borderRadius: '6px',
                  fontSize: '16px'
                }}
              />
            </div>

            <div style={{ marginBottom: '16px' }}>
              <label style={{ display: 'block', marginBottom: '8px', fontWeight: 500 }}>
                Password
              </label>
              <input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
                autoComplete="current-password"
                style={{
                  width: '100%',
                  padding: '10px',
                  border: '1px solid #d1d5db',
                  borderRadius: '6px',
                  fontSize: '16px'
                }}
              />
            </div>
            
            <div style={{ marginBottom: '24px', display: 'flex', alignItems: 'center' }}>
              <input
                type="checkbox"
                id="rememberMe"
                checked={rememberMe}
                onChange={(e) => setRememberMe(e.target.checked)}
                style={{ marginRight: '8px', height: '16px', width: '16px' }}
              />
              <label htmlFor="rememberMe" style={{ fontSize: '14px', userSelect: 'none' }}>
                Remember me
              </label>
            </div>

            <button
              type="submit"
              disabled={loading}
              style={{
                width: '100%',
                padding: '12px',
                border: 'none',
                borderRadius: '6px',
                backgroundColor: loading ? '#9ca3af' : '#2563eb',
                color: 'white',
                fontSize: '16px',
                fontWeight: 'bold',
                cursor: loading ? 'not-allowed' : 'pointer'
              }}
            >
              {loading ? 'Signing In...' : 'Sign In'}
            </button>

            <div style={{ marginTop: '24px', textAlign: 'center', fontSize: '14px' }}>
              Don't have an account?{' '}
              <button
                type="button"
                onClick={() => setShowSignupInfo(true)}
                style={{
                  background: 'none',
                  border: 'none',
                  color: '#2563eb',
                  textDecoration: 'underline',
                  cursor: 'pointer',
                  padding: 0
                }}
              >
                Get Access
              </button>
            </div>
          </form>
        )}
      </div>
    </div>
  );
}

