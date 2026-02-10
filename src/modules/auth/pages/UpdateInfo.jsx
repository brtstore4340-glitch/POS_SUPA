import React from 'react';
import { useAuth } from '../AuthContext';
import { useNavigate } from 'react-router-dom';

export default function UpdateInfo() {
  const { user, selectedProfile, logout } = useAuth();
  const navigate = useNavigate();

  const handleLogout = async () => {
    await logout();
    navigate('/signin');
  };

  if (!user || !selectedProfile) return null;

  return (
    <div style={{ maxWidth: 760, margin: "24px auto", padding: 16 }}>
      <h2>User Profile</h2>

      <div style={{ marginTop: 16, padding: 12, border: "1px solid #ddd", borderRadius: 8 }}>
        <p>This page is a placeholder for updating user information.</p>
        <div style={{ opacity: 0.8, marginTop: 8 }}>
          User: <b>{selectedProfile.displayName || selectedProfile.idCode}</b> | Role: <b>{selectedProfile.role}</b>
        </div>
      </div>

      <div style={{ display: "flex", gap: 10, flexWrap: "wrap", marginTop: 16 }}>
        <button onClick={handleLogout} style={{ padding: 10 }}>
          Logout
        </button>
      </div>
    </div>
  );
}
