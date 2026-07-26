-- Fix salary_components RLS policy: add with check for insert/update
drop policy if exists "Admins manage components" on salary_components;
create policy "Admins manage components" on salary_components
  for all using (is_admin()) with check (is_admin());
