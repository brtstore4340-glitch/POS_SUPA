import * as React from "react";
import { createBrowserRouter, RouterProvider } from "react-router-dom";
import { AppShell } from "@/components/layout/AppShell";
import ProtectedRoute from "@/modules/auth/ProtectedRoute";
import { HomePage } from "@/pages/HomePage";
import { PosPage } from "@/pages/PosPage";
import { ProductsPage } from "@/pages/ProductsPage";
import { OrdersPage } from "@/pages/OrdersPage";
import { ReportsPage } from "@/pages/ReportsPage";
import DailyReportPage from "@/pages/DailyReportPage";
import { SettingsPage } from "@/pages/SettingsPage";
import { ItemSearchPage } from "@/pages/ItemSearchPage";
import { NotFoundPage } from "@/pages/NotFoundPage";
import SetupPage from "@/pages/SetupPage";
import PinLoginPage from "@/pages/PinLoginPage";
import SignInPage from "@/pages/SignInPage";
import SelectProfile from "@/modules/auth/pages/SelectProfile";

const router = createBrowserRouter([
  // Public routes
  { path: "/signin", element: <SignInPage /> },
  { path: "/pin-login", element: <PinLoginPage /> },
  { path: "/select-profile", element: <SelectProfile /> }, // A page to select a user profile after login
  { path: "/setup", element: <SetupPage /> }, // Placeholder setup page

  // Main application layout, protected by the auth wrapper
  {
    path: "/",
    element: (
      <ProtectedRoute>
        <AppShell />
      </ProtectedRoute>
    ),
    // All children of AppShell are now implicitly protected
    children: [
      { index: true, element: <HomePage /> },
      { path: "pos", element: <PosPage /> },
      { path: "products", element: <ProductsPage /> },
      { path: "orders", element: <OrdersPage /> },
      { path: "reports", element: <ReportsPage /> },
      { path: "reports/daily-sales", element: <DailyReportPage /> },
      { path: "settings", element: <SettingsPage /> },
      { path: "item-search", element: <ItemSearchPage /> },
      { path: "*", element: <NotFoundPage /> }
    ]
  }
]);

export function AppRouter() {
  return <RouterProvider router={router} />;
}


