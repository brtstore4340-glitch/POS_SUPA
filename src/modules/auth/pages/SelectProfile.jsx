import React from 'react';
import { useAuth } from '../AuthContext';
import { useNavigate } from 'react-router-dom';

export default function SelectProfile() {
  const { profiles, setSelectedProfile } = useAuth();
  const navigate = useNavigate();

  const handleSelectProfile = (profile) => {
    setSelectedProfile(profile);
    navigate('/pin-login');
  };

  return (
    <div style={{ maxWidth: 520, margin: "40px auto", padding: 16 }}>
      <h2>Select Profile</h2>
      <p>This page is a placeholder. A UI to select between multiple user profiles would go here.</p>
      
      <div style={{ display: "grid", gap: 10, marginTop: 12 }}>
        {profiles.map(p => (
          <button
            key={p.idCode}
            onClick={() => handleSelectProfile(p)}
            style={{ padding: 12, textAlign: "left" }}
          >
            <div style={{ fontWeight: 700 }}>{p.name || p.idCode}</div>
            <div style={{ opacity: 0.8 }}>Role: {p.role}</div>
          </button>
        ))}
      </div>
    </div>
  );
}
