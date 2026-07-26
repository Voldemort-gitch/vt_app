-- Fix RLS policies for advance_requests and salary_components
-- Run this in psql or Supabase SQL Editor

-- Drop existing policies first (safe if they don't exist)
drop policy if exists "Employees view own advances" on advance_requests;
drop policy if exists "Admins view all advances" on advance_requests;
drop policy if exists "Employees insert advances" on advance_requests;
drop policy if exists "Admins update advances" on advance_requests;

-- Create advance_requests policies
create policy "Employees view own advances" on advance_requests
  for select using (auth.uid() = employee_id);
create policy "Admins view all advances" on advance_requests
  for select using (is_admin());
create policy "Employees insert advances" on advance_requests
  for insert with check (auth.uid() = employee_id);
create policy "Admins update advances" on advance_requests
  for update using (is_admin());

-- Drop existing salary_components policies
drop policy if exists "Anyone can read components" on salary_components;
drop policy if exists "Admins manage components" on salary_components;

-- Create salary_components policies
create policy "Anyone can read components" on salary_components
  for select using (true);
create policy "Admins manage components" on salary_components
  for all using (is_admin());
