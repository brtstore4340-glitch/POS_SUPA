import React from 'react';
import { Navigate, useLocation } from 'react-router-dom';
import { useAuth } from './AuthContext'; // Switched to the new AuthContext

export default function ProtectedRoute({ allowRoles, children }) {
  const { user, selectedProfile, loading } = useAuth();
  const location = useLocation();

  if (loading) {
    // Render a loading indicator while the auth state is being determined
    return <div className="flex items-center justify-center h-screen">Loading...</div>; 
  }

  // Step 1: Check if user is logged in with email/password
  if (!user) {
    return <Navigate to="/signin" state={{ from: location }} replace />;
  }

  // Step 2: Check if an account has been selected via PIN login
  if (!selectedProfile) {
    // Redirect to a profile selection or PIN entry page
    return <Navigate to="/pin-login" state={{ from: location }} replace />;
  }

  // Step 3: Check for role-based access
  if (Array.isArray(allowRoles) && allowRoles.length > 0) {
    if (!allowRoles.includes(selectedProfile.role)) {
      // Redirect to a default page if the role is not authorized
      // You might want an "Access Denied" page here in the future
      return <Navigate to="/" replace />;
    }
  }

  // If all checks pass, render the requested component
  return children;
}