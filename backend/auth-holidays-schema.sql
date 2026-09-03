-- 1. Faculty Accounts Table
CREATE TABLE IF NOT EXISTS faculty_accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    faculty_name TEXT NOT NULL UNIQUE,
    password_hash TEXT,
    activation_code_hash TEXT,
    activation_used BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. Calendar Overrides (Holidays) Table
CREATE TABLE IF NOT EXISTS calendar_overrides (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    override_date DATE NOT NULL,
    start_time TEXT,
    end_time TEXT,
    target_mode TEXT NOT NULL CHECK (target_mode IN ('student', 'faculty', 'both')),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE faculty_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE calendar_overrides ENABLE ROW LEVEL SECURITY;

-- Allow public read access to active faculty names (no hashes) for search
CREATE POLICY "Allow public read access to faculty names" 
ON faculty_accounts FOR SELECT 
TO anon, authenticated 
USING (is_active = true);

-- Allow public read access to active calendar overrides
CREATE POLICY "Allow public read access on calendar_overrides" 
ON calendar_overrides FOR SELECT 
TO anon, authenticated 
USING (is_active = true);
