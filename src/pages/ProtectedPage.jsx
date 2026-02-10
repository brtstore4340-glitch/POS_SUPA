import React, { useState, useEffect } from 'react';
import { supabase } from '../supabaseClient';

export default function ProtectedPage({ session }) {
  const [profile, setProfile] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchProfile = async () => {
      setLoading(true);
      const { user } = session;

      const { data, error } = await supabase
        .from('profiles')
        .select(`username, website, avatar_url`)
        .eq('id', user.id)
        .single();

      if (error) {
        console.warn(error);
      } else if (data) {
        setProfile(data);
      }
      setLoading(false);
    };

    fetchProfile();
  }, [session]);

  const handleSignOut = async () => {
    await supabase.auth.signOut();
  };

  return (
    <div>
      <h1>Protected Page</h1>
      <p>Welcome, {session.user.email}!</p>
      {loading ? (
        <p>Loading profile...</p>
      ) : (
        <div>
          <p>Username: {profile?.username || 'Not set'}</p>
          <button onClick={() => alert('Update profile functionality to be added.')}>Update Profile</button>
        </div>
      )}
      <button onClick={handleSignOut}>Sign Out</button>
    </div>
  );
}
