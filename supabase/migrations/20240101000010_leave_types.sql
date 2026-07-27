-- Leave types + balance tracking
-- Run this migration to add leave types and balance tracking

-- 1. Add leave_type column to leave_requests
ALTER TABLE leave_requests ADD COLUMN IF NOT EXISTS leave_type TEXT NOT NULL DEFAULT 'casual';

-- 2. Create leave_balance table
CREATE TABLE IF NOT EXISTS leave_balance (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  year INTEGER NOT NULL,
  leave_type TEXT NOT NULL CHECK (leave_type IN ('sick', 'casual', 'annual')),
  total_days INTEGER NOT NULL DEFAULT 0,
  used_days INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(employee_id, year, leave_type)
);

-- 3. Enable RLS on leave_balance
ALTER TABLE leave_balance ENABLE ROW LEVEL SECURITY;

-- 4. RLS policies for leave_balance
DROP POLICY IF EXISTS "Employees read own balance" ON leave_balance;
DROP POLICY IF EXISTS "Admins read all balances" ON leave_balance;
DROP POLICY IF EXISTS "Admins manage balances" ON leave_balance;

CREATE POLICY "Employees read own balance" ON leave_balance
  FOR SELECT USING (auth.uid() = employee_id);
CREATE POLICY "Admins read all balances" ON leave_balance
  FOR SELECT USING (is_admin());
CREATE POLICY "Admins manage balances" ON leave_balance
  FOR ALL USING (is_admin());
