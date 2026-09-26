# Market Analysis - Supabase Backend Setup Guide

This guide walks you through connecting your **Market Analysis** Flutter app to **Supabase** in one shot.

---

## 1. What You Need from Supabase

To connect your Flutter frontend to Supabase, you need exactly **two items** from your Supabase Dashboard:

1. **Project URL** (e.g. `https://xyzabcdefghijklmnopq.supabase.co`)
2. **Anon / Public API Key** (a long string starting with `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...` or `sb_publishable_...`)

---

## 2. Where to Find Them in Supabase Dashboard

1. Open [https://supabase.com/dashboard](https://supabase.com/dashboard) and sign in.
2. Select your project (if you don't have one, click **"New project"**, give it a name like `market-analysis`, set a database password, and choose your nearest region).
3. In the left navigation menu, click the **Gear icon (Project Settings)** at the bottom left.
4. Under Project Settings, click **"API"** (or **"Data API"**).
5. In the API settings page:
   - Copy the **Project URL** (under "Project URL").
   - Copy the **anon / public key** (under "Project API keys" -> `anon` `public`).

---

## 3. Run the Database Schema (One Click)

1. In your Supabase Dashboard left menu, click **"SQL Editor"** (terminal icon).
2. Click **"+ New query"** at the top.
3. Open [`backend/schema.sql`](schema.sql) from this project.
4. Copy all lines and paste them into the SQL Editor in Supabase.
5. Click the green **"Run"** button.
   - You will see `"Success. No rows returned"`.
6. Your 5 database tables are now ready:
   - `purchases` (Crop purchases from farmers)
   - `sales` (Crop sales to factories)
   - `farmers` (Farmer contact directory)
   - `factories` (Factory & mill contact directory)
   - `workers` (Staff profiles, daily wages & attendance)

---

## 4. In Which File to Keep the Link in VS Code

Keep the credentials in your root `.env` file:

Open the file:
```
c:\myproject\market_analysis\.env
```

Add your Supabase credentials:

```properties
# Google Sheets Web App (Optional)
SHEETS_WEB_APP_URL=https://script.google.com/macros/s/AKfycbwXpcknfkdXoc-3Grnzf5iI4oZ614ys9t-HaT6lV4j3cDDdDtP4ygR2nKyM5IuIqjV_dQ/exec

# Supabase Backend Configuration
SUPABASE_URL=https://YOUR_PROJECT_ID.supabase.co
SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY_HERE
```

Replace `https://YOUR_PROJECT_ID.supabase.co` and `YOUR_SUPABASE_ANON_KEY_HERE` with your actual Supabase credentials.

---

## 5. How the Architecture Works in Production

- **Offline-First Resilience**: Even if the network drops in a rural mandi or farm field, transactions are stored locally immediately so zero data is ever lost.
- **Instant Supabase Sync**: When connected, transactions and updates are pushed to Supabase Postgres instantly.
- **Dual-Sync (Optional)**: If you also keep `SHEETS_WEB_APP_URL`, entries sync to both Supabase and Google Sheets simultaneously.
