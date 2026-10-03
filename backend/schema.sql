-- ====================================================================
-- Market Analysis App - Production & Test Supabase Schema
-- ====================================================================
-- 100% Physical Database Separation for:
--   1. MarketP: Production Environment (Real Business Operations)
--      Tables: p_purchases, p_sales, p_farmers, p_factories, p_workers, p_expenditures
--   2. MarketT: Test / Staging Environment (Bug fixing, experiments)
--      Tables: t_purchases, t_sales, t_farmers, t_factories, t_workers, t_expenditures
--
-- INSTRUCTIONS:
-- 1. Log in to your Supabase Dashboard: https://supabase.com/dashboard
-- 2. Open your project -> click "SQL Editor" in the left sidebar.
-- 3. Click "+ New query", paste this entire script, and click "Run" (green button).
-- 4. All tables, indexes, RLS policies, and realtime streams will be created!
-- ====================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ====================================================================
-- SECTION A: PRODUCTION TABLES (MarketP - prefix: p_)
-- ====================================================================

-- 1. Production Purchases
CREATE TABLE IF NOT EXISTS public.p_purchases (
    id TEXT PRIMARY KEY,
    crop_name TEXT NOT NULL,
    farmer_name TEXT NOT NULL,
    farmer_phone TEXT DEFAULT '',
    farmer_address TEXT DEFAULT '',
    farmer_details TEXT DEFAULT '',
    quantity NUMERIC NOT NULL DEFAULT 0,
    suits_kg NUMERIC NOT NULL DEFAULT 0,
    net_quantity NUMERIC NOT NULL DEFAULT 0,
    unit TEXT NOT NULL DEFAULT 'Quintal',
    price_per_unit NUMERIC NOT NULL DEFAULT 0,
    total_amount NUMERIC NOT NULL DEFAULT 0,
    advance_paid NUMERIC NOT NULL DEFAULT 0,
    net_payable NUMERIC NOT NULL DEFAULT 0,
    date TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_p_purchases_date ON public.p_purchases (date DESC);
CREATE INDEX IF NOT EXISTS idx_p_purchases_crop ON public.p_purchases (crop_name);
CREATE INDEX IF NOT EXISTS idx_p_purchases_farmer ON public.p_purchases (farmer_name);

-- 2. Production Sales
CREATE TABLE IF NOT EXISTS public.p_sales (
    id TEXT PRIMARY KEY,
    crop_name TEXT NOT NULL,
    factory_name TEXT NOT NULL,
    factory_contact TEXT DEFAULT '',
    factory_address TEXT DEFAULT '',
    quantity NUMERIC NOT NULL DEFAULT 0,
    unit TEXT NOT NULL DEFAULT 'Quintal',
    sold_amount NUMERIC NOT NULL DEFAULT 0,
    price_per_unit NUMERIC NOT NULL DEFAULT 0,
    date TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_p_sales_date ON public.p_sales (date DESC);
CREATE INDEX IF NOT EXISTS idx_p_sales_crop ON public.p_sales (crop_name);
CREATE INDEX IF NOT EXISTS idx_p_sales_factory ON public.p_sales (factory_name);

-- 3. Production Farmers
CREATE TABLE IF NOT EXISTS public.p_farmers (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    phone TEXT DEFAULT '',
    address TEXT DEFAULT '',
    notes TEXT DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_p_farmers_name ON public.p_farmers (name);
CREATE INDEX IF NOT EXISTS idx_p_farmers_phone ON public.p_farmers (phone);

-- 4. Production Factories
CREATE TABLE IF NOT EXISTS public.p_factories (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    contact TEXT DEFAULT '',
    address TEXT DEFAULT '',
    notes TEXT DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_p_factories_name ON public.p_factories (name);
CREATE INDEX IF NOT EXISTS idx_p_factories_contact ON public.p_factories (contact);

-- 5. Production Workers
CREATE TABLE IF NOT EXISTS public.p_workers (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    phone TEXT DEFAULT '',
    role TEXT NOT NULL DEFAULT 'General Labor',
    address TEXT DEFAULT '',
    daily_wage NUMERIC NOT NULL DEFAULT 0,
    is_present_today BOOLEAN NOT NULL DEFAULT false,
    joined_date TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    notes TEXT DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_p_workers_name ON public.p_workers (name);
CREATE INDEX IF NOT EXISTS idx_p_workers_role ON public.p_workers (role);

-- 6. Production Other Expenditures
CREATE TABLE IF NOT EXISTS public.p_expenditures (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'Other / Miscellaneous',
    amount NUMERIC NOT NULL DEFAULT 0,
    paid_to TEXT DEFAULT '',
    payment_mode TEXT NOT NULL DEFAULT 'Cash',
    notes TEXT DEFAULT '',
    date TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_p_expenditures_date ON public.p_expenditures (date DESC);
CREATE INDEX IF NOT EXISTS idx_p_expenditures_category ON public.p_expenditures (category);


-- ====================================================================
-- SECTION B: TESTING / SANDBOX TABLES (MarketT - prefix: t_)
-- ====================================================================

-- 1. Test Purchases
CREATE TABLE IF NOT EXISTS public.t_purchases (
    id TEXT PRIMARY KEY,
    crop_name TEXT NOT NULL,
    farmer_name TEXT NOT NULL,
    farmer_phone TEXT DEFAULT '',
    farmer_address TEXT DEFAULT '',
    farmer_details TEXT DEFAULT '',
    quantity NUMERIC NOT NULL DEFAULT 0,
    suits_kg NUMERIC NOT NULL DEFAULT 0,
    net_quantity NUMERIC NOT NULL DEFAULT 0,
    unit TEXT NOT NULL DEFAULT 'Quintal',
    price_per_unit NUMERIC NOT NULL DEFAULT 0,
    total_amount NUMERIC NOT NULL DEFAULT 0,
    advance_paid NUMERIC NOT NULL DEFAULT 0,
    net_payable NUMERIC NOT NULL DEFAULT 0,
    date TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_t_purchases_date ON public.t_purchases (date DESC);
CREATE INDEX IF NOT EXISTS idx_t_purchases_crop ON public.t_purchases (crop_name);
CREATE INDEX IF NOT EXISTS idx_t_purchases_farmer ON public.t_purchases (farmer_name);

-- 2. Test Sales
CREATE TABLE IF NOT EXISTS public.t_sales (
    id TEXT PRIMARY KEY,
    crop_name TEXT NOT NULL,
    factory_name TEXT NOT NULL,
    factory_contact TEXT DEFAULT '',
    factory_address TEXT DEFAULT '',
    quantity NUMERIC NOT NULL DEFAULT 0,
    unit TEXT NOT NULL DEFAULT 'Quintal',
    sold_amount NUMERIC NOT NULL DEFAULT 0,
    price_per_unit NUMERIC NOT NULL DEFAULT 0,
    date TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_t_sales_date ON public.t_sales (date DESC);
CREATE INDEX IF NOT EXISTS idx_t_sales_crop ON public.t_sales (crop_name);
CREATE INDEX IF NOT EXISTS idx_t_sales_factory ON public.t_sales (factory_name);

-- 3. Test Farmers
CREATE TABLE IF NOT EXISTS public.t_farmers (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    phone TEXT DEFAULT '',
    address TEXT DEFAULT '',
    notes TEXT DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_t_farmers_name ON public.t_farmers (name);
CREATE INDEX IF NOT EXISTS idx_t_farmers_phone ON public.t_farmers (phone);

-- 4. Test Factories
CREATE TABLE IF NOT EXISTS public.t_factories (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    contact TEXT DEFAULT '',
    address TEXT DEFAULT '',
    notes TEXT DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_t_factories_name ON public.t_factories (name);
CREATE INDEX IF NOT EXISTS idx_t_factories_contact ON public.t_factories (contact);

-- 5. Test Workers
CREATE TABLE IF NOT EXISTS public.t_workers (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    phone TEXT DEFAULT '',
    role TEXT NOT NULL DEFAULT 'General Labor',
    address TEXT DEFAULT '',
    daily_wage NUMERIC NOT NULL DEFAULT 0,
    is_present_today BOOLEAN NOT NULL DEFAULT false,
    joined_date TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    notes TEXT DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_t_workers_name ON public.t_workers (name);
CREATE INDEX IF NOT EXISTS idx_t_workers_role ON public.t_workers (role);

-- 6. Test Other Expenditures
CREATE TABLE IF NOT EXISTS public.t_expenditures (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'Other / Miscellaneous',
    amount NUMERIC NOT NULL DEFAULT 0,
    paid_to TEXT DEFAULT '',
    payment_mode TEXT NOT NULL DEFAULT 'Cash',
    notes TEXT DEFAULT '',
    date TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_t_expenditures_date ON public.t_expenditures (date DESC);
CREATE INDEX IF NOT EXISTS idx_t_expenditures_category ON public.t_expenditures (category);


-- ====================================================================
-- SECTION C: ROW LEVEL SECURITY (RLS) POLICIES
-- ====================================================================

-- Enable RLS on all tables
ALTER TABLE public.p_purchases ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.p_sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.p_farmers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.p_factories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.p_workers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.p_expenditures ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.t_purchases ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.t_sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.t_farmers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.t_factories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.t_workers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.t_expenditures ENABLE ROW LEVEL SECURITY;

-- Production policies
DROP POLICY IF EXISTS "Allow anon all on p_purchases" ON public.p_purchases;
CREATE POLICY "Allow anon all on p_purchases" ON public.p_purchases FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow anon all on p_sales" ON public.p_sales;
CREATE POLICY "Allow anon all on p_sales" ON public.p_sales FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow anon all on p_farmers" ON public.p_farmers;
CREATE POLICY "Allow anon all on p_farmers" ON public.p_farmers FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow anon all on p_factories" ON public.p_factories;
CREATE POLICY "Allow anon all on p_factories" ON public.p_factories FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow anon all on p_workers" ON public.p_workers;
CREATE POLICY "Allow anon all on p_workers" ON public.p_workers FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow anon all on p_expenditures" ON public.p_expenditures;
CREATE POLICY "Allow anon all on p_expenditures" ON public.p_expenditures FOR ALL USING (true) WITH CHECK (true);

-- Test policies
DROP POLICY IF EXISTS "Allow anon all on t_purchases" ON public.t_purchases;
CREATE POLICY "Allow anon all on t_purchases" ON public.t_purchases FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow anon all on t_sales" ON public.t_sales;
CREATE POLICY "Allow anon all on t_sales" ON public.t_sales FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow anon all on t_farmers" ON public.t_farmers;
CREATE POLICY "Allow anon all on t_farmers" ON public.t_farmers FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow anon all on t_factories" ON public.t_factories;
CREATE POLICY "Allow anon all on t_factories" ON public.t_factories FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow anon all on t_workers" ON public.t_workers;
CREATE POLICY "Allow anon all on t_workers" ON public.t_workers FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow anon all on t_expenditures" ON public.t_expenditures;
CREATE POLICY "Allow anon all on t_expenditures" ON public.t_expenditures FOR ALL USING (true) WITH CHECK (true);


-- ====================================================================
-- SECTION D: SUPABASE REALTIME (Live Sync for both Production & Test)
-- ====================================================================

DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.p_purchases;
    ALTER PUBLICATION supabase_realtime ADD TABLE public.p_sales;
    ALTER PUBLICATION supabase_realtime ADD TABLE public.p_farmers;
    ALTER PUBLICATION supabase_realtime ADD TABLE public.p_factories;
    ALTER PUBLICATION supabase_realtime ADD TABLE public.p_workers;
    ALTER PUBLICATION supabase_realtime ADD TABLE public.p_expenditures;
    ALTER PUBLICATION supabase_realtime ADD TABLE public.t_purchases;
    ALTER PUBLICATION supabase_realtime ADD TABLE public.t_sales;
    ALTER PUBLICATION supabase_realtime ADD TABLE public.t_farmers;
    ALTER PUBLICATION supabase_realtime ADD TABLE public.t_factories;
    ALTER PUBLICATION supabase_realtime ADD TABLE public.t_workers;
    ALTER PUBLICATION supabase_realtime ADD TABLE public.t_expenditures;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- Safe column migrations for existing databases
ALTER TABLE public.p_purchases ADD COLUMN IF NOT EXISTS suits_kg NUMERIC DEFAULT 0;
ALTER TABLE public.p_purchases ADD COLUMN IF NOT EXISTS net_quantity NUMERIC DEFAULT 0;
ALTER TABLE public.p_purchases ADD COLUMN IF NOT EXISTS advance_paid NUMERIC DEFAULT 0;
ALTER TABLE public.p_purchases ADD COLUMN IF NOT EXISTS net_payable NUMERIC DEFAULT 0;

ALTER TABLE public.t_purchases ADD COLUMN IF NOT EXISTS suits_kg NUMERIC DEFAULT 0;
ALTER TABLE public.t_purchases ADD COLUMN IF NOT EXISTS net_quantity NUMERIC DEFAULT 0;
ALTER TABLE public.t_purchases ADD COLUMN IF NOT EXISTS advance_paid NUMERIC DEFAULT 0;
ALTER TABLE public.t_purchases ADD COLUMN IF NOT EXISTS net_payable NUMERIC DEFAULT 0;

