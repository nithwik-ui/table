import { createClient } from '@supabase/supabase-js';
import * as dotenv from 'dotenv';
import * as path from 'path';

dotenv.config({ path: path.join(__dirname, '.env') });

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseKey) {
  console.error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

async function injectMockChanges() {
  console.log('--- Injecting Mock Changes for Manual Testing ---');

  // 1. Inject for Students (timetable_changes)
  // Get all active batches
  const { data: batches, error: batchErr } = await supabase.from('batches').select('id').eq('active', true);
  if (batchErr) {
    console.error("Error fetching batches:", batchErr);
  } else if (batches && batches.length > 0) {
    const changes = batches.map(b => ({
      batch_id: b.id,
      change_type: 'ROOM_CHANGED',
      field_name: 'TEST CLASS: Intro to Manual Testing|Monday|09:00 - 09:50',
      old_value: 'Old Room A',
      new_value: 'New Room B',
      detected_at: new Date().toISOString()
    }));
    const { error: insertErr } = await supabase.from('timetable_changes').insert(changes);
    if (insertErr) console.error("Error inserting student changes:", insertErr);
    else console.log(`✅ Injected mock change into ${batches.length} student batches.`);
  }

  // 2. Inject for Faculty (faculty_changes)
  // We MUST use the SRU portal ID (which is used in faculty_snapshots), NOT the UUID from faculty_accounts.
  const { data: faculties, error: facErr } = await supabase.from('faculty_snapshots').select('faculty_id');
  if (facErr) {
    console.error("Error fetching faculties from snapshots:", facErr);
  } else if (faculties && faculties.length > 0) {
    const fChanges = faculties.map(f => ({
      faculty_id: f.faculty_id,
      change_type: 'ROOM_CHANGED',
      field_name: 'TEST CLASS: Intro to Manual Testing|Monday|09:00 - 09:50',
      old_value: 'Old Room A',
      new_value: 'New Room B',
      detected_at: new Date().toISOString()
    }));
    const { error: insertErr } = await supabase.from('faculty_changes').insert(fChanges);
    if (insertErr) console.error("Error inserting faculty changes:", insertErr);
    else console.log(`✅ Injected mock change into ${faculties.length} faculty accounts (SRU Portal IDs).`);
  }

  console.log('\nDone! You can now pull-to-refresh the mobile app and check the "Changes" tab.');
  console.log('To clean up these test changes later, run: npx ts-node test_mock_cleanup.ts');
}

injectMockChanges();
