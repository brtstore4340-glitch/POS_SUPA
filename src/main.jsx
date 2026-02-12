import React from 'react';
import ReactDOM from 'react-dom/client';
import { BrowserRouter } from 'react-router-dom';
import App from './App';
import { AuthProvider } from './modules/auth/AuthContext'; // Correct path to the new provider
import { isSupabaseConfigured } from '../supabase/client';
import { MissingSupabaseConfig } from './components/MissingSupabaseConfig';
import './styles/globals.css';

const root = ReactDOM.createRoot(document.getElementById('root'));

root.render(
  <React.StrictMode>
    {isSupabaseConfigured ? (
      <BrowserRouter>
        <AuthProvider>
          <App />
        </AuthProvider>
      </BrowserRouter>
    ) : (
      <MissingSupabaseConfig />
    )}
  </React.StrictMode>
);
