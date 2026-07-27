-- Fix company_settings RLS: restrict read to admins only
-- GPS coordinates and office radius are now read server-side by Edge Functions

drop policy if exists "Anyone read settings" on company_settings;
create policy "Admins read settings" on company_settings
  for select using (is_admin());
