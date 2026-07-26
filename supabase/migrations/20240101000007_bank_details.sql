-- Add bank details columns to profiles table
alter table profiles add column if not exists bank_name text;
alter table profiles add column if not exists account_number text;
