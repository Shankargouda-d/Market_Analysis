# 🌾 Market Analysis - Agricultural Commodity & Mandi Trading System

A Flutter web and mobile platform for managing agricultural crop purchases from farmers, sales to factories and mills, worker wages and attendance, real-time analytics, and seamless database synchronization.

---

## 🔐 Strict Multi-Environment & Zero-Overlap Isolation

The system strictly requires a User ID login before accessing any data:

| User ID | Environment | Purpose | Supabase Prefix | Local Storage Partition |
| :--- | :--- | :--- | :--- | :--- |
| **`MarketP`** | **Production** | Real business trades, active mandi purchases, factory sales | `p_` (e.g. `p_purchases`, `p_sales`) | `_MarketP` |
| **`MarketT`** | **Testing / Sandbox** | Feature testing, bug fixes, experiments | `t_` (e.g. `t_purchases`, `t_sales`) | `_MarketT` |

> **100% Physical Separation Guarantee:**
> - Neither database queries nor local device cache will ever mix between `MarketP` and `MarketT`.
> - Even on network loss, offline data is stored into independent disk keys per environment.

---

## 🚀 Key Features

1. **Buy (From Farmer)**:
   - Crop selection, quantity, suits/deductions (in kg), price per unit, and advance paid tracking.
   - Farmer directory with contact number, village address, and cascade update/delete.
2. **Sell (To Factory)**:
   - Factory directory with manager contacts, location, and rate per unit calculations.
3. **Other Expenditure (Mandi Expenses & Labor)**:
   - Track freight, hamali, packaging, diesel, office expenses, and labor/daily wages.
   - Record worker/payee name, phone number, and address directly on each payment.
4. **Daily Cash Settlement & Float Management**:
   - Record cash float deposits, track daily outflows (farmer payouts + mandi expenses), and compute exact remaining balances.
5. **Date-wise Daily Analysis & Analytics**:
   - Volume, gross turnover, net margins, top traded crops, and transaction history.
6. **Directories (Farmers & Factories)**:
   - Full CRUD: Add, Edit, Delete with cascade options for linked transactions.

---

## 🛠️ Database Setup (Supabase)

1. Open your [Supabase Dashboard](https://supabase.com/dashboard).
2. Go to **SQL Editor** -> Click **+ New Query**.
3. Paste the contents of `backend/schema.sql` and click **Run**.
4. Both `p_*` (Production) and `t_*` (Testing) tables, indexes, RLS policies, and realtime publications will be created instantly.

---

## 🌐 Deploy to Vercel (Web App)

1. Install the Vercel CLI (or connect this GitHub repository in [vercel.com](https://vercel.com)).
2. Build command:
   ```bash
   flutter build web --release
   ```
3. Output Directory:
   ```
   build/web
   ```
4. `vercel.json` is pre-configured with SPA route rewriting.

---

## 📱 Build Android APK

To generate the standalone release APK for Android devices:
```bash
flutter build apk --release
```
The APK will be generated at `build/app/outputs/flutter-apk/app-release.apk`.
