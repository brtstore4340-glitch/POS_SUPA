import { useState, useEffect, useRef } from 'react';
import { auth } from '../config/firebase';
import { 
  signInWithEmailAndPassword, 
  createUserWithEmailAndPassword 
} from 'firebase/auth';

const RECAPTCHA_SITE_KEY = import.meta.env.VITE_RECAPTCHA_SITE_KEY || "6Lc71z4sAAAAAMxG25t_oi47_986McgLXdfbTWh9";

export default function LoginPage() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [isSignUp, setIsSignUp] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [isFirstLogin, setIsFirstLogin] = useState(false);
  const [recaptchaToken, setRecaptchaToken] = useState(null);
  const [isRecaptchaLoaded, setIsRecaptchaLoaded] = useState(false);
  const recaptchaRef = useRef(null);

  // Load reCAPTCHA script
  useEffect(() => {
    if (document.querySelector('script[src*="recaptcha"]')) {
      setIsRecaptchaLoaded(true);
      return;
    }

    const script = document.createElement('script');
    script.src = `https://www.google.com/recaptcha/enterprise.js?render=${RECAPTCHA_SITE_KEY}`;
    script.async = true;
    script.defer = true;
    script.onload = () => setIsRecaptchaLoaded(true);
    document.head.appendChild(script);

    return () => {
      // Don't remove script on unmount to avoid reloading
    };
  }, []);

  // Check if this email has logged in before (first login detection)
  useEffect(() => {
    if (!email) {
      setIsFirstLogin(false);
      return;
    }

    const normalizedEmail = email.trim().toLowerCase();
    if (!normalizedEmail) return;

    try {
      const loggedInEmails = JSON.parse(localStorage.getItem('loggedInEmails') || '[]');
      const hasLoggedInBefore = loggedInEmails.includes(normalizedEmail);
      setIsFirstLogin(!hasLoggedInBefore);
    } catch (e) {
      setIsFirstLogin(true);
    }
  }, [email]);

  // Execute reCAPTCHA when needed
  const executeRecaptcha = async () => {
    if (!window.grecaptcha || !window.grecaptcha.enterprise) {
      throw new Error('reCAPTCHA not loaded yet');
    }

    const token = await window.grecaptcha.enterprise.execute(RECAPTCHA_SITE_KEY, {
      action: 'LOGIN'
    });
    
    return token;
  };

  const markEmailAsLoggedIn = (email) => {
    try {
      const normalizedEmail = email.trim().toLowerCase();
      const loggedInEmails = JSON.parse(localStorage.getItem('loggedInEmails') || '[]');
      if (!loggedInEmails.includes(normalizedEmail)) {
        loggedInEmails.push(normalizedEmail);
        localStorage.setItem('loggedInEmails', JSON.stringify(loggedInEmails));
      }
    } catch (e) {
      console.error('Failed to save login history:', e);
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError('');

    try {
      // Check if reCAPTCHA is required (first login or sign up)
      const needsRecaptcha = isSignUp || isFirstLogin;
      
      if (needsRecaptcha && !recaptchaToken) {
        // Execute reCAPTCHA
        const token = await executeRecaptcha();
        setRecaptchaToken(token);
        console.log('✅ reCAPTCHA verified');
      }

      if (isSignUp) {
        await createUserWithEmailAndPassword(auth, email, password);
        console.log('✅ Account created successfully');
      } else {
        await signInWithEmailAndPassword(auth, email, password);
        console.log('✅ Signed in successfully');
      }
      
      // Mark email as logged in (for future first-login detection)
      markEmailAsLoggedIn(email);
      
      window.location.href = '/setup';
    } catch (err) {
      console.error('Auth error:', err);
      setError(err.message);
      setRecaptchaToken(null); // Reset token on error
    } finally {
      setLoading(false);
    }
  };

  // Show reCAPTCHA badge info
  const showRecaptchaBadge = (isSignUp || isFirstLogin) && email;

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
          {isSignUp ? '📝 Sign Up' : '🔐 Sign In'}
        </h1>

        {/* First login notice */}
        {!isSignUp && isFirstLogin && email && (
          <div style={{
            padding: '12px',
            backgroundColor: '#dbeafe',
            color: '#1e40af',
            borderRadius: '6px',
            marginBottom: '16px',
            fontSize: '14px'
          }}>
            ℹ️ <strong>First time login detected</strong><br/>
            Please complete the security verification below.
          </div>
        )}

        {/* Returning user notice */}
        {!isSignUp && !isFirstLogin && email && (
          <div style={{
            padding: '12px',
            backgroundColor: '#d1fae5',
            color: '#065f46',
            borderRadius: '6px',
            marginBottom: '16px',
            fontSize: '14px'
          }}>
            👋 <strong>Welcome back!</strong><br/>
            No additional verification needed.
          </div>
        )}

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
              style={{
                width: '100%',
                padding: '10px',
                border: '1px solid #d1d5db',
                borderRadius: '6px',
                fontSize: '16px'
              }}
            />
          </div>

          <div style={{ marginBottom: '24px' }}>
            <label style={{ display: 'block', marginBottom: '8px', fontWeight: 500 }}>
              Password
            </label>
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
              minLength={6}
              style={{
                width: '100%',
                padding: '10px',
                border: '1px solid #d1d5db',
                borderRadius: '6px',
                fontSize: '16px'
              }}
            />
          </div>

          {/* reCAPTCHA container - visible only when needed */}
          {showRecaptchaBadge && (
            <div style={{
              marginBottom: '16px',
              padding: '12px',
              backgroundColor: '#f9fafb',
              borderRadius: '6px',
              textAlign: 'center'
            }}>
              <div 
                ref={recaptchaRef}
                className="g-recaptcha"
                data-sitekey={RECAPTCHA_SITE_KEY}
                data-action="LOGIN"
                style={{ display: 'inline-block' }}
              />
              {!isRecaptchaLoaded && (
                <p style={{ fontSize: '12px', color: '#6b7280', marginTop: '8px' }}>
                  Loading security verification...
                </p>
              )}
            </div>
          )}

          {error && (
            <div style={{
              padding: '12px',
              backgroundColor: '#fee2e2',
              color: '#dc2626',
              borderRadius: '6px',
              marginBottom: '16px',
              fontSize: '14px'
            }}>
              {error}
            </div>
          )}

          <button
            type="submit"
            disabled={loading || (showRecaptchaBadge && !isRecaptchaLoaded)}
            style={{
              width: '100%',
              padding: '12px',
              backgroundColor: loading ? '#9ca3af' : '#3b82f6',
              color: 'white',
              border: 'none',
              borderRadius: '6px',
              fontSize: '16px',
              fontWeight: 500,
              cursor: loading ? 'not-allowed' : 'pointer',
              marginBottom: '16px'
            }}
          >
            {loading ? 'Processing...' : (isSignUp ? 'Sign Up' : 'Sign In')}
          </button>

          <button
            type="button"
            onClick={() => {
              setIsSignUp(!isSignUp);
              setRecaptchaToken(null);
              setError('');
            }}
            style={{
              width: '100%',
              padding: '12px',
              backgroundColor: 'transparent',
              color: '#3b82f6',
              border: '1px solid #3b82f6',
              borderRadius: '6px',
              fontSize: '14px',
              cursor: 'pointer'
            }}
          >
            {isSignUp ? 'Already have an account? Sign In' : 'Need an account? Sign Up'}
          </button>
        </form>

        <div style={{
          marginTop: '24px',
          padding: '16px',
          backgroundColor: '#f3f4f6',
          borderRadius: '6px',
          fontSize: '13px',
          color: '#6b7280'
        }}>
          <strong>Security Note:</strong><br/>
          reCAPTCHA verification is required only for:<br/>
          • First-time logins on this device<br/>
          • New account registration
        </div>
      </div>
    </div>
  );
}
