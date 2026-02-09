import * as React from "react";
import { AuthGate } from "@/modules/auth/AuthGate";
import { AppRouter } from "@/router/AppRouter";
import SetupPage from "./pages/SetupPage";
import { SupabaseAuthProvider } from '../supabase/SupabaseAuthProvider.jsx';

export default function App() {
  // Handle the setup route explicitly if it exists outside the main AppRouter
  if (window.location.pathname === "/setup") {
    return (
      <AuthGate>
        <SetupPage />
      </AuthGate>
    );
  }

  // Default application flow
  return (
    <SupabaseAuthProvider>
      <AuthGate>
        <AppRouter />
      </AuthGate>
    </SupabaseAuthProvider>
  );
}
