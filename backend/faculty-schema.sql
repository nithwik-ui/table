-- Update device_tokens to support faculty
ALTER TABLE device_tokens ADD COLUMN IF NOT EXISTS user_mode TEXT DEFAULT 'student';
ALTER TABLE device_tokens ADD COLUMN IF NOT EXISTS faculty_id TEXT;
-- We need to drop the NOT NULL constraint on batch_id if it exists, since faculty mode might not have a batch
ALTER TABLE device_tokens ALTER COLUMN batch_id DROP NOT NULL;


-- 1. Faculty Timetable Entries
CREATE TABLE IF NOT EXISTS faculty_timetable_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    faculty_id TEXT NOT NULL,
    day TEXT NOT NULL,
    start_time TEXT NOT NULL,
    end_time TEXT NOT NULL,
    subject TEXT NOT NULL,
    faculty TEXT,
    room TEXT,
    semester TEXT,
    ltp TEXT,
    source_hash TEXT,
    UNIQUE (faculty_id, day, start_time, end_time, subject, room)
);

-- 2. Faculty Timetable Snapshots
CREATE TABLE IF NOT EXISTS faculty_snapshots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    faculty_id TEXT NOT NULL UNIQUE,
    hash TEXT NOT NULL,
    raw_json JSONB NOT NULL,
    synced_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. Faculty Timetable Changes
CREATE TABLE IF NOT EXISTS faculty_changes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    faculty_id TEXT NOT NULL,
    timetable_entry_id UUID REFERENCES faculty_timetable_entries(id) ON DELETE SET NULL,
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

-- Enable RLS and setup policies
ALTER TABLE faculty_timetable_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE faculty_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE faculty_changes ENABLE ROW LEVEL SECURITY;

-- Allow public read access
CREATE POLICY "Allow public read access on faculty_entries" ON faculty_timetable_entries FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "Allow public read access on faculty_snapshots" ON faculty_snapshots FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "Allow public read access on faculty_changes" ON faculty_changes FOR SELECT TO anon, authenticated USING (true);
