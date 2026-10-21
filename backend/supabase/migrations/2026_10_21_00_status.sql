-- Run this FIRST, before either migration.
--
-- Two migrations were attempted yesterday and one failed. Rather than guess how
-- far it got, this tells you exactly what state the database is in: which
-- columns exist, which types they have, and which policies are installed.
--
-- It changes nothing. Safe to run as often as you like, and safe to run with the
-- publishable key from the SQL editor.

-- 1. Which tables exist at all
select table_name
from information_schema.tables
where table_schema = 'public'
order by table_name;

-- 2. Types of the money columns. 'text' means migration 02 has not converted them.
select table_name, column_name, data_type
from information_schema.columns
where table_schema = 'public'
  and column_name in ('price', 'amount', 'sales', 'sales_today', 'deposit',
                      'weekly_installment', 'cost_price', 'loan_price')
order by table_name, column_name;

-- 3. Do sales / loan_payments exist yet?
select table_name
from information_schema.tables
where table_schema = 'public'
  and table_name in ('sales', 'loan_payments');

-- 4. Policies currently installed. Empty for a table means RLS denies everyone.
select tablename, policyname, cmd
from pg_policies
where schemaname = 'public'
order by tablename, policyname;

-- 5. Helper functions from migration 01
select routine_name
from information_schema.routines
where routine_schema = 'public'
  and routine_name in ('current_staff_role', 'has_any_role');
