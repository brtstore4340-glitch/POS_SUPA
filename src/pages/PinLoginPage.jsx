import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../modules/auth/AuthContext';

export default function PinLoginPage() {
  const { user, profiles, verifyPin, logout, selectedProfile } = useAuth();
  const navigate = useNavigate();

  const [selectedProfileId, setSelectedProfileId] = useState('');
  const [pin, setPin] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    // If a profile is already selected, the user belongs on the main page.
    if (selectedProfile) {
      navigate('/');
    }
  }, [selectedProfile, navigate]);
  
  useEffect(() => {
    // If the user logs out or the session is lost, go to signin page.
    if (!user) {
      navigate('/signin');
    }
  }, [user, navigate]);

  useEffect(() => {
    // Default the selection to the first available profile.
    if (profiles && profiles.length > 0 && !selectedProfileId) {
      setSelectedProfileId(profiles[0].idCode);
    }
  }, [profiles, selectedProfileId]);

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!selectedProfileId) {
      setError('Please select a profile.');
      return;
    }
    setLoading(true);
    setError('');

    try {
      const success = await verifyPin(selectedProfileId, pin);
      if (!success) {
        throw new Error("Invalid PIN. Please try again.");
      }
      // On success, the AuthContext `selectedProfile` state will be set,
      // and the useEffect above will navigate the user to the homepage.
    } catch (err) {
      setError(err.message);
      setPin(''); // Clear PIN input on error
    } finally {
      setLoading(false);
    }
  };

  const handleSignOut = async () => {
    await logout();
    navigate('/signin');
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
        maxWidth: '90%',
        position: 'relative'
      }}>
        <button 
          onClick={handleSignOut}
          style={{
            position: 'absolute',
            top: '15px',
            right: '15px',
            background: 'none',
            border: 'none',
            color: '#6b7280',
            cursor: 'pointer',
            fontSize: '14px'
          }}
        >
          Sign Out
        </button>

        <h1 style={{ marginBottom: '8px', textAlign: 'center' }}>Enter PIN</h1>
        <p style={{ marginBottom: '24px', textAlign: 'center', color: '#4b5563' }}>
          Welcome, {user?.email}!
        </p>

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
        
        <form onSubmit={handleSubmit}>
          <div style={{ marginBottom: '16px' }}>
            <label style={{ display: 'block', marginBottom: '8px', fontWeight: 500 }}>
              Select Profile
            </label>
            <select
              value={selectedProfileId}
              onChange={(e) => setSelectedProfileId(e.target.value)}
              required
              style={{
                width: '100%',
                padding: '10px',
                border: '1px solid #d1d5db',
                borderRadius: '6px',
                fontSize: '16px',
                backgroundColor: 'white'
              }}
            >
              {profiles.map(profile => (
                <option key={profile.idCode} value={profile.idCode}>
                  {profile.name || profile.idCode} ({profile.role})
                </option>
              ))}
            </select>
          </div>

          <div style={{ marginBottom: '24px' }}>
            <label style={{ display: 'block', marginBottom: '8px', fontWeight: 500 }}>
              PIN
            </label>
            <input
              type="password"
              value={pin}
              onChange={(e) => setPin(e.target.value)}
              required
              maxLength="6"
              pattern="\d*"
              inputMode="numeric"
              autoComplete="one-time-code"
              style={{
                width: '100%',
                padding: '10px',
                border: '1px solid #d1d5db',
                borderRadius: '6px',
                fontSize: '24px',
                textAlign: 'center',
                letterSpacing: '0.5em'
              }}
            />
          </div>

          <button
            type="submit"
            disabled={loading || !profiles.length}
            style={{
              width: '100%',
              padding: '12px',
              border: 'none',
              borderRadius: '6px',
              backgroundColor: loading ? '#9ca3af' : '#2563eb',
              color: 'white',
              fontSize: '16px',
              fontWeight: 'bold',
              cursor: loading || !profiles.length ? 'not-allowed' : 'pointer'
            }}
          >
            {loading ? 'Verifying...' : 'Continue'}
          </button>
        </form>
      </div>
    </div>
  );
}