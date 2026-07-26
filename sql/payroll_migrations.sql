-- ============================================================
-- Payroll Module - Database Migrations
-- Run this in Supabase SQL Editor
-- ============================================================

-- 1. Employee Salary History
create table if not exists employee_salary_history (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references profiles(id) on delete cascade,
  monthly_salary numeric(10,2) not null,
  working_days integer not null default 30,
  allowed_leaves integer not null default 4,
  effective_from date not null default current_date,
  created_at timestamptz default now()
);

-- 2. Monthly Attendance Summary
create table if not exists monthly_attendance_summary (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references profiles(id) on delete cascade,
  month integer not null,
  year integer not null,
  total_days integer not null,
  present_days integer not null,
  late_days integer not null default 0,
  leave_days integer not null default 0,
  absent_days integer not null default 0,
  created_at timestamptz default now(),
  unique(employee_id, month, year)
);

-- 3. Payroll Records
create table if not exists payroll_records (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references profiles(id) on delete cascade,
  month integer not null,
  year integer not null,
  basic_salary numeric(10,2) not null,
  daily_salary numeric(10,2) not null,
  allowed_leave integer not null,
  used_leave integer not null,
  extra_leave integer not null default 0,
  deduction_amount numeric(10,2) not null default 0,
  final_salary numeric(10,2) not null,
  status text not null default 'draft' check (status in ('draft','reviewed','approved','paid')),
  generated_by uuid references profiles(id),
  created_at timestamptz default now(),
  unique(employee_id, month, year)
);

-- RLS Policies
alter table employee_salary_history enable row level security;
alter table monthly_attendance_summary enable row level security;
alter table payroll_records enable row level security;

-- Helper: check if current user is admin
create or replace function is_admin()
returns boolean language sql security definer as $$
  select exists (select 1 from profiles where id = auth.uid() and role = 'admin');
$$;

-- employee_salary_history policies
create policy "Employees view own salary" on employee_salary_history for select using (auth.uid() = employee_id);
create policy "Admins view all salaries" on employee_salary_history for select using (is_admin());
create policy "Admins insert salaries" on employee_salary_history for insert with check (is_admin());
create policy "Admins update salaries" on employee_salary_history for update using (is_admin());

-- monthly_attendance_summary policies
create policy "Employees view own summary" on monthly_attendance_summary for select using (auth.uid() = employee_id);
create policy "Admins view all summaries" on monthly_attendance_summary for select using (is_admin());
create policy "Admins insert summaries" on monthly_attendance_summary for insert with check (is_admin());

-- payroll_records policies
create policy "Employees view own payroll" on payroll_records for select using (auth.uid() = employee_id);
create policy "Admins view all payroll" on payroll_records for select using (is_admin());
create policy "Admins insert payroll" on payroll_records for insert with check (is_admin());
create policy "Admins update payroll" on payroll_records for update using (is_admin());
