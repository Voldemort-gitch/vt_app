-- Block direct INSERT/UPDATE on attendance (must go through Edge Function)
-- The process-attendance Edge Function uses the service role key which bypasses RLS

drop policy if exists "Employees insert own checkin" on attendance;
drop policy if exists "Employees update own checkout" on attendance;

-- SELECT policies remain unchanged: employees read own, admins read all
