-- ============================================================
-- admin_audit_log table
-- Run this after all other SQL files
-- ============================================================

CREATE TABLE IF NOT EXISTS admin_audit_log (
  id INTEGER PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  admin_id UUID REFERENCES profiles(id) NOT NULL,
  action TEXT NOT NULL,
  details TEXT,
  ip_address TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);
