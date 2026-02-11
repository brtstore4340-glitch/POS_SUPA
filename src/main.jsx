import React from 'react';
import ReactDOM from 'react-dom/client';
import { BrowserRouter } from 'react-router-dom';
import App from './App';
import { AuthProvider } from './modules/auth/AuthContext'; // Correct path to the new provider
import { isSupabaseConfigured, supabaseConfigError } from '../supabase/client';
import './styles/globals.css';

function MissingSupabaseConfig() {
  return (
    <div className="min-h-screen bg-background text-foreground flex items-center justify-center p-6">
      <div className="max-w-xl w-full rounded-lg border bg-card text-card-foreground p-6 shadow-sm space-y-3">
        <h1 className="text-xl font-semibold">Supabase env vars missing</h1>
        <p className="text-sm text-muted-foreground">
          {supabaseConfigError}
        </p>
        <div className="text-sm space-y-1">
          <div>Required:</div>
          <ul className="list-disc pl-5 text-muted-foreground">
            <li><code>VITE_SUPABASE_URL</code></li>
            <li><code>VITE_SUPABASE_ANON_KEY</code></li>
          </ul>
        </div>
        <p className="text-xs text-muted-foreground">
          Set these in Vercel → Project → Settings → Environment Variables and redeploy.
        </p>
      </div>
    </div>
  );
}

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
