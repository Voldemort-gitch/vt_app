-- ============================================================
-- Base Tables — must be created BEFORE migration SQL files
-- Run this first, then payroll_migrations.sql, then enhancement_migrations.sql
-- ============================================================

-- 1. profiles (linked to auth.users via trigger or manual insert)
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id),
  name TEXT NOT NULL,
  employee_code TEXT UNIQUE NOT NULL,
  phone TEXT,
  role TEXT NOT NULL DEFAULT 'employee',
  department_id TEXT,
  is_active BOOLEAN DEFAULT true,
  avatar_url TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 2. attendance
CREATE TABLE IF NOT EXISTS attendance (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id UUID REFERENCES profiles(id) NOT NULL,
  attendance_date DATE NOT NULL,
  check_in TIMESTAMPTZ,
  check_out TIMESTAMPTZ,
  check_in_latitude DOUBLE PRECISION,
  check_in_longitude DOUBLE PRECISION,
  check_out_latitude DOUBLE PRECISION,
  check_out_longitude DOUBLE PRECISION,
  working_minutes INTEGER DEFAULT 0,
  status TEXT DEFAULT 'present',
  UNIQUE(employee_id, attendance_date)
);

-- 3. company_settings (single-row table, id=1)
CREATE TABLE IF NOT EXISTS company_settings (
  id INTEGER PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  company_name TEXT DEFAULT 'My Company',
  office_latitude DOUBLE PRECISION DEFAULT 0,
  office_longitude DOUBLE PRECISION DEFAULT 0,
  allowed_radius DOUBLE PRECISION DEFAULT 100,
  office_start_time TEXT DEFAULT '09:00',
  office_end_time TEXT DEFAULT '18:00',
  late_after_minutes INTEGER DEFAULT 15,
  max_employees_on_leave INTEGER DEFAULT 2,
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Seed default company settings row
INSERT INTO company_settings (id) VALUES (1) ON CONFLICT (id) DO NOTHING;

-- 4. leave_requests
CREATE TABLE IF NOT EXISTS leave_requests (
  id INTEGER PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  employee_id UUID REFERENCES profiles(id) NOT NULL,
  from_date DATE NOT NULL,
  to_date DATE NOT NULL,
  reason TEXT NOT NULL,
  status TEXT DEFAULT 'pending',
  admin_id UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ DEFAULT now()
);
