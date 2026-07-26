-- RLS policies for unprotected tables
-- Run this last after all other migrations

-- 1. profiles
alter table profiles enable row level security;

drop policy if exists "Employees read own profile" on profiles;
drop policy if exists "Admins read all profiles" on profiles;
drop policy if exists "Employees update own profile" on profiles;
drop policy if exists "Admins update all profiles" on profiles;

create policy "Employees read own profile" on profiles
  for select using (auth.uid() = id);
create policy "Admins read all profiles" on profiles
  for select using (is_admin());
create policy "Employees update own profile" on profiles
  for update using (auth.uid() = id) with check (auth.uid() = id);
create policy "Admins update all profiles" on profiles
  for update using (is_admin());

-- 2. attendance
alter table attendance enable row level security;

drop policy if exists "Employees read own attendance" on attendance;
drop policy if exists "Admins read all attendance" on attendance;
drop policy if exists "Employees insert own checkin" on attendance;
drop policy if exists "Employees update own checkout" on attendance;

create policy "Employees read own attendance" on attendance
  for select using (auth.uid() = employee_id);
create policy "Admins read all attendance" on attendance
  for select using (is_admin());
create policy "Employees insert own checkin" on attendance
  for insert with check (auth.uid() = employee_id);
create policy "Employees update own checkout" on attendance
  for update using (auth.uid() = employee_id);

-- 3. company_settings
alter table company_settings enable row level security;

drop policy if exists "Anyone read settings" on company_settings;
drop policy if exists "Admins update settings" on company_settings;

create policy "Anyone read settings" on company_settings
  for select using (true);
create policy "Admins update settings" on company_settings
  for update using (is_admin());

-- 4. leave_requests
alter table leave_requests enable row level security;

drop policy if exists "Employees read own leaves" on leave_requests;
drop policy if exists "Admins read all leaves" on leave_requests;
drop policy if exists "Employees insert own leaves" on leave_requests;
drop policy if exists "Admins update leaves" on leave_requests;

create policy "Employees read own leaves" on leave_requests
  for select using (auth.uid() = employee_id);
create policy "Admins read all leaves" on leave_requests
  for select using (is_admin());
create policy "Employees insert own leaves" on leave_requests
  for insert with check (auth.uid() = employee_id);
create policy "Admins update leaves" on leave_requests
  for update using (is_admin());

-- 5. admin_audit_log
alter table admin_audit_log enable row level security;

drop policy if exists "Admins insert audit" on admin_audit_log;
drop policy if exists "Admins read audit" on admin_audit_log;

create policy "Admins insert audit" on admin_audit_log
  for insert with check (is_admin());
create policy "Admins read audit" on admin_audit_log
  for select using (is_admin());
