import React from "react";
import ReactDOM from "react-dom/client";

import App from "./App.jsx";
import "./styles/globals.css";

import { ThemeProvider } from "@/providers/ThemeProvider";
import { AuthProvider } from "@/modules/auth";
import { Toaster } from "@/components/toaster";
import ErrorBoundary from "./components/ErrorBoundary";

import '../supabase/client.js';

ReactDOM.createRoot(document.getElementById("root")).render(
  <React.StrictMode>
    <ErrorBoundary>
      <ThemeProvider defaultTheme="system" storageKey="theme">
        <AuthProvider>
          <App />
        </AuthProvider>
        <Toaster />
      </ThemeProvider>
    </ErrorBoundary>
  </React.StrictMode>
);