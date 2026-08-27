-- Enable UUID extension if not enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Degrees Table
CREATE TABLE IF NOT EXISTS degrees (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT,
    source_value TEXT NOT NULL UNIQUE,
    active BOOLEAN NOT NULL DEFAULT true,
    first_seen_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. Years Table
CREATE TABLE IF NOT EXISTS years (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    degree_id UUID NOT NULL REFERENCES degrees(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    active BOOLEAN NOT NULL DEFAULT true,
    first_seen_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (degree_id, name)
);

-- 3. Batches Table
CREATE TABLE IF NOT EXISTS batches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    degree_id UUID NOT NULL REFERENCES degrees(id) ON DELETE CASCADE,
    year_id UUID NOT NULL REFERENCES years(id) ON DELETE CASCADE,
    batch_code TEXT NOT NULL,
    active BOOLEAN NOT NULL DEFAULT true,
    first_seen_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (degree_id, year_id, batch_code)
);

-- 4. Timetable Entries Table
CREATE TABLE IF NOT EXISTS timetable_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    batch_id UUID NOT NULL REFERENCES batches(id) ON DELETE CASCADE,
    day TEXT NOT NULL,
    start_time TEXT NOT NULL,
    end_time TEXT NOT NULL,
    subject TEXT NOT NULL,
    faculty TEXT,
    room TEXT,
    semester TEXT,
    ltp TEXT,
    source_hash TEXT,
    UNIQUE (batch_id, day, start_time, end_time, subject, faculty, room, ltp, semester)
);

-- 5. Timetable Snapshots Table
CREATE TABLE IF NOT EXISTS timetable_snapshots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    batch_id UUID NOT NULL REFERENCES batches(id) ON DELETE CASCADE UNIQUE,
    hash TEXT NOT NULL,
    raw_json JSONB NOT NULL,
    synced_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 6. Timetable Changes Table
CREATE TABLE IF NOT EXISTS timetable_changes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    batch_id UUID NOT NULL REFERENCES batches(id) ON DELETE CASCADE,
    timetable_entry_id UUID REFERENCES timetable_entries(id) ON DELETE SET NULL,
    change_type TEXT NOT NULL CHECK (
        change_type IN (
            'CLASS_ADDED',
            'CLASS_REMOVED',
            'SUBJECT_CHANGED',
            'FACULTY_CHANGED',
            'ROOM_CHANGED',
            'TIME_CHANGED',
            'LTP_CHANGED'
        )
    ),
    field_name TEXT,
    old_value TEXT,
    new_value TEXT,
    detected_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 7. Device Tokens Table
CREATE TABLE IF NOT EXISTS device_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fcm_token TEXT NOT NULL UNIQUE,
    batch_id UUID NOT NULL REFERENCES batches(id) ON DELETE CASCADE,
    notifications_enabled BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Enable Row Level Security (RLS) on all tables
ALTER TABLE degrees ENABLE ROW LEVEL SECURITY;
ALTER TABLE years ENABLE ROW LEVEL SECURITY;
ALTER TABLE batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE timetable_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE timetable_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE timetable_changes ENABLE ROW LEVEL SECURITY;
ALTER TABLE device_tokens ENABLE ROW LEVEL SECURITY;

-- Drop existing policies to prevent conflict on rerun
DROP POLICY IF EXISTS "Allow public read access on degrees" ON degrees;
DROP POLICY IF EXISTS "Allow public read access on years" ON years;
DROP POLICY IF EXISTS "Allow public read access on batches" ON batches;
DROP POLICY IF EXISTS "Allow public read access on timetable_entries" ON timetable_entries;
DROP POLICY IF EXISTS "Allow public read access on timetable_snapshots" ON timetable_snapshots;
DROP POLICY IF EXISTS "Allow public read access on timetable_changes" ON timetable_changes;
DROP POLICY IF EXISTS "Allow public read access on device_tokens" ON device_tokens;

-- Create public SELECT (read-only) policies for all relevant tables
CREATE POLICY "Allow public read access on degrees" ON degrees FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "Allow public read access on years" ON years FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "Allow public read access on batches" ON batches FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "Allow public read access on timetable_entries" ON timetable_entries FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "Allow public read access on timetable_snapshots" ON timetable_snapshots FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "Allow public read access on timetable_changes" ON timetable_changes FOR SELECT TO anon, authenticated USING (true);

-- For device_tokens, allow SELECT/INSERT/UPDATE for public (so anonymous clients can manage their tokens)
-- Note: Alternatively, device registration can be mediated via API only. But if we allow direct read, we can add it here.
-- The specification states Render REST API is the ONLY backend mediator, so direct public writes are blocked.
-- Anonymous database clients cannot insert/modify device_tokens directly. All device registrations flow through the REST API.
-- So we only define SELECT policies (no INSERT/UPDATE/DELETE policies for anon role).
