-- Migration: Petty Cash Table
-- Renamed from Krish to Petty Cash in the UI, mapping to 'petty_cash' table.

CREATE TABLE IF NOT EXISTS public.petty_cash (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now(),
    amount BIGINT NOT NULL,
    category TEXT NOT NULL,
    description TEXT,
    branch_id TEXT,
    staff_id TEXT
);

-- Enable RLS
ALTER TABLE public.petty_cash ENABLE ROW LEVEL SECURITY;

-- Allow anonymous inserts (for demo/preview mode)
CREATE POLICY "Allow anon insert to petty_cash" ON public.petty_cash
    FOR INSERT WITH CHECK (true);

-- Allow public read for now
CREATE POLICY "Allow public select from petty_cash" ON public.petty_cash
    FOR SELECT USING (true);
