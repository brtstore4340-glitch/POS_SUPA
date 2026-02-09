import * as React from "react";
import { AuthGate } from "@/modules/auth/AuthGate";
import { AppRouter } from "@/router/AppRouter";
import SetupPage from "./pages/SetupPage";

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
    <AuthGate>
      <AppRouter />
    </AuthGate>
  );
}
