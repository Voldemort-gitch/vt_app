-- Fix security issues identified in third-party review
-- Run this migration to address critical and high-severity findings

-- ============================================================
-- FINDING #2 (CRITICAL): salary_components readable by any employee
-- Fix: restrict to own row (employees) or all (admins)
-- ============================================================
drop policy if exists "Anyone can read components" on salary_components;
create policy "Employees read own components" on salary_components
  for select using (auth.uid() = employee_id);
create policy "Admins read all components" on salary_components
  for select using (is_admin());

-- ============================================================
-- FINDING #7 (MEDIUM): No constraint prevents negative final_salary
-- Fix: add CHECK constraint
-- ============================================================
alter table payroll_records add constraint final_salary_non_negative
  check (final_salary >= 0);

-- ============================================================
-- FINDING #14 (CRITICAL, via #1): salary_components percentages should sum to 100
-- Fix: add CHECK constraint (allows small rounding tolerance)
-- ============================================================
alter table salary_components add constraint components_sum_to_100
  check (abs(basic_pct + hra_pct + conveyance_pct + medical_pct + special_pct - 100) < 0.01);

-- ============================================================
-- FINDING #13 (MEDIUM): Add indexes for common query patterns
-- ============================================================
create index if not exists idx_attendance_date on attendance(attendance_date);
create index if not exists idx_leave_requests_status on leave_requests(status);
create index if not exists idx_payroll_records_month_year on payroll_records(month, year);
create index if not exists idx_advance_requests_status on advance_requests(status);
create index if not exists idx_admin_audit_log_created on admin_audit_log(created_at);
