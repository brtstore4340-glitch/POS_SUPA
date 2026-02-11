## Software Requirements Specification: Boots POS System (Combined & Phased)

### **URGENT / HIGH PRIORITY FEATURES:**
#### 🎯 1. Web Scraping – Core Functionality
*This section is considered URGENT for initial data acquisition.*

**Target Websites**
*   Public e-commerce / marketplaces
*   Supplier portals
*   Systems requiring real-time capture (Grab print–like use case)

**Scraping Frequency**
*   Daily batch: once per day
*   Real-time scraping: required (Only for specific critical sources, Not all sources require real-time)

**Site Type**
*   Mostly dynamic / JavaScript-heavy
*   Headless browser required

**Authentication for Scraping**
*   Gmail-based authentication for target websites (where applicable)

**Legal / Permission**
*   Company-owned or partner-approved data only
*   No ToS violations

**👉 Position**
*   APIs preferred whenever available.
*   Scraping (especially real-time) used selectively.

#### 🎯 2. Authentication & User Management (Google OAuth + Multiple PINs)
*This section is considered URGENT as it redefines the core authentication flow.*

**Authentication Rules**
*   **Gmail OAuth:** Primary authentication method for all non-Admin users.
*   **One Gmail → multiple non-admin accounts:** A single Gmail account can be associated with multiple unique system accounts, each with its own Employee ID and PIN.
*   **Admin uses separate credentials:** Admin login flow remains distinct (e.g., dedicated Employee ID/Password or another secure method, not Gmail OAuth with PINs).

**Login with PIN after Gmail OAuth:**
*   After successful Gmail OAuth, the user will be prompted to enter a specific PIN.
*   The system will validate this PIN to determine the active `Employee ID` and `Role` for the session.

**User Roles**
*   Admin
*   Manager
*   Analyst
*   Staff (Cashier equivalent for POS)

**Role-based Access Control (RBAC):**
*   **Admin:** Full access to all modules (POS, Reports, Settings, Admin Module).
*   **Staff (Cashier):** Access restricted to POS/Dashboard only. Other menus must be hidden or inaccessible.

**PIN Management:**
*   **Admin Module:** Admins must have an interface to create, update, and deactivate PINs, linking them to specific Gmail accounts, Employee IDs, and Roles.
*   **User Profile (Self-Service):** Non-admin users should be able to view/change their own associated PINs (if allowed by their role).

**Auto-Logout (Security):**
*   System must monitor inactivity (mouse/keyboard).
*   Automatic logout after a configurable duration (default 30 minutes).
*   Clear sensitive local storage data upon logout.

---

### **STANDARD / NON-URGENT FEATURES:**
#### 🎯 3. Data Ingestion – File Upload

**File Sources**
*   Admin panel (Master data, Reference data)
*   User panel (Daily data, Weekly data, Monthly data)

**Formats**
*   Excel (.xlsx), CSV

**Data Volume**
*   Hundreds to hundreds of thousands of rows (Pipeline must be scalable)

**Validation**
*   Mandatory column checks
*   Data type validation
*   Clear rejection reasons
*   Full batch logging

#### 🎯 4. Products & Reporting

**Product Scale**
*   Designed for 50,000+ SKUs (No fixed upper limit)

**Product Grouping**
*   Brand, Category, Supplier, Channel, Time-based (daily / weekly / monthly)

**Core Metrics**
*   Revenue, Units sold, Average price, Inventory (if available), Margin (optional)

**Reporting Output**
*   In-app dashboards
*   Excel export (required)
*   PDF export (future phase)

#### 🎯 5. Admin Module – Batch Operations

**Batch features include:**
*   Multiple file uploads 
*   Period-based batches (daily / weekly / monthly)
*   Batch reprocessing / rollback

**Status tracking:**
*   success, failed, partial

---

#### 🎯 6. User Experience & User Interface (UX/UI)
*This section applies across all features.*

**Design System Requirements:**

**Color Palette:**
*   Primary Color: Boots Blue (`#4285F4` or `text-blue-600`) for Header, primary action buttons, important numbers.
*   Background: White (`bg-white`) and light gray (`bg-slate-50`) for visual comfort.
*   Alert/Error: Red (`text-red-600`) for warning/deletion messages.

**Typography:**
*   Font Family: `"Outfit"`, `"Noto Sans Thai"` for modernity and Thai language support.

**Layout Structure:**
*   **Sidebar (Desktop):** Left-side menu with Boots logo, navigation, user profile.
*   **Header:** Top bar with branch name (`4340 Grand 5 Sukhumvit`) and real-time digital clock.
*   **Responsive:** Support Desktop and Mobile (hide Sidebar on Mobile).

**Feedback & Interactions:**
*   **Loading States:** `LoadingScreen` or Spinner for data processing.
*   **Input Validation:** Immediate alerts for incorrect input (e.g., empty Employee ID, short password).

**Theme Toggle (Note):**
*   Current React version (`src/`) lacks user-enabled Dark/Light Mode. System is locked to Light Theme (white/gray background, dark blue/navy text) per Boots CI.
*   *Reference:* Theme Toggle existed in `legacy_v1/js/ui/theme.js`, but new version prioritizes simplicity and formality via `tailwind.config.js` (`slate`, `blue`).

---

### 🏗️ Technical Constraints

**Budget**
*   ❗ Zero budget (free only)

**Infrastructure**
*   **Frontend:** Firebase Hosting or GitHub Pages
*   **Backend / DB:** Supabase (free tier)
*   **Auth:** Supabase Auth (Gmail OAuth)
*   **Jobs:** Limited automation due to free tier

**Expectation**
*   Limited real-time capacity
*   Focus on reliability over scale

### 🚨 Accepted Trade-offs

**Free Tier Limitations**
*   Selective real-time scraping only
*   Optimized DB & reporting required for 50k+ SKUs
