-- ============================================================
-- Payroll & Features Enhancement - Database Migrations
-- Run this in Supabase SQL Editor
-- ============================================================

-- 1. Salary Components (customizable per employee)
create table if not exists salary_components (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid references profiles(id) not null unique,
  basic_pct numeric(5,2) not null default 45,
  hra_pct numeric(5,2) not null default 17,
  conveyance_pct numeric(5,2) not null default 3,
  medical_pct numeric(5,2) not null default 2,
  special_pct numeric(5,2) not null default 33,
  health_insurance numeric(10,2) not null default 0,
  professional_tax numeric(10,2) not null default 200,
  tds numeric(10,2) not null default 0,
  created_at timestamptz default now()
);

-- 2. Advance Salary Requests
create table if not exists advance_requests (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references profiles(id) on delete cascade,
  amount numeric(10,2) not null,
  reason text,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  admin_id uuid references profiles(id),
  month integer,
  year integer,
  created_at timestamptz default now()
);

-- 3. Add columns to payroll_records
alter table payroll_records add column if not exists advance_amount numeric(10,2) not null default 0;
alter table payroll_records add column if not exists gross_salary numeric(10,2) default 0;

-- 4. Add column to company_settings
alter table company_settings add column if not exists max_employees_on_leave integer not null default 2;

-- 5. Add advance_requests RLS
alter table advance_requests enable row level security;
create policy "Employees view own advances" on advance_requests for select using (auth.uid() = employee_id);
create policy "Admins view all advances" on advance_requests for select using (is_admin());
create policy "Employees insert advances" on advance_requests for insert with check (auth.uid() = employee_id);
create policy "Admins update advances" on advance_requests for update using (is_admin());

-- 6. Add salary_components RLS
alter table salary_components enable row level security;
create policy "Anyone can read components" on salary_components for select using (true);
create policy "Admins manage components" on salary_components for all using (is_admin());
