import { supabase } from '../db/supabase';
import { diffTimetables } from './diff';
import * as crypto from 'crypto';

function computeHash(data: any): string {
  const contentStr = typeof data === 'string' ? data : JSON.stringify(data);
  return crypto.createHash('sha256').update(contentStr).digest('hex');
}

async function main() {
  console.log('--- SRU Timetable Change Detection Test ---');

  const degreeCode = 'TEST-DIFF-DEG';
  const yearName = 'First';
  const batchCode = 'TEST-DIFF-BATCH';

  try {
    // 1. Setup Mock Metadata
    console.log('\nStep 1: Setting up mock degree, year, and batch...');
    
    // Upsert Degree
    const { data: degData, error: degErr } = await supabase
      .from('degrees')
      .upsert({ source_value: degreeCode, name: 'Mock Test Degree', active: true })
      .select('id')
      .single();

    if (degErr) throw new Error(`Failed to create test degree: ${degErr.message}`);
    const degreeId = degData.id;

    // Upsert Year
    const { data: yrData, error: yrErr } = await supabase
      .from('years')
      .upsert({ degree_id: degreeId, name: yearName, active: true })
      .select('id')
      .single();

    if (yrErr) throw new Error(`Failed to create test year: ${yrErr.message}`);
    const yearId = yrData.id;

    // Upsert Batch
    const { data: bchData, error: bchErr } = await supabase
      .from('batches')
      .upsert({ degree_id: degreeId, year_id: yearId, batch_code: batchCode, active: true })
      .select('id')
      .single();

    if (bchErr) throw new Error(`Failed to create test batch: ${bchErr.message}`);
    const batchId = bchData.id;

    console.log(`Created Mock Batch! ID: ${batchId}`);

    // 2. Insert Initial schedule (Old Entry)
    console.log('\nStep 2: Inserting initial "old" schedule entry...');
    const oldEntryPayload = {
      batch_id: batchId,
      day: 'Monday',
      start_time: '08:30',
      end_time: '09:30',
      subject: 'Algorithms',
      faculty: 'Dr. Test',
      room: '1102-BL1-FF',
      ltp: 'Lecture',
      semester: 'I',
    };

    const { data: oldEntryData, error: oldEntryErr } = await supabase
      .from('timetable_entries')
      .insert([oldEntryPayload])
      .select('id, day, start_time, end_time, subject, faculty, room, ltp, semester')
      .single();

    if (oldEntryErr) throw new Error(`Failed to insert old entry: ${oldEntryErr.message}`);
    const oldEntryId = oldEntryData.id;
    console.log(`Inserted Old Entry ID: ${oldEntryId}`);

    // Create Initial Snapshot
    const oldHash = computeHash(JSON.stringify([oldEntryPayload]));
    const { error: oldSnapErr } = await supabase
      .from('timetable_snapshots')
      .insert({
        batch_id: batchId,
        hash: oldHash,
        raw_json: { success: true, data: { Monday: { '08:30': [ { facultyName: 'Dr. Test', room_name: '1102-BL1-FF', batch: batchCode, semester: 'I', subject: 'Algorithms', ltp: 'Lecture' } ] } } }
      });

    if (oldSnapErr) throw new Error(`Failed to insert old snapshot: ${oldSnapErr.message}`);

    // 3. Define new schedule (with Room Changed: '1102-BL1-FF' -> '1202-BL1-SF')
    console.log('\nStep 3: Simulating schedule modification (Room change)...');
    const newEntries = [
      {
        day: 'Monday',
        start_time: '08:30',
        end_time: '09:30',
        subject: 'Algorithms',
        faculty: 'Dr. Test',
        room: '1202-BL1-SF', // Room modified
        ltp: 'Lecture',
        semester: 'I',
      }
    ];

    // 4. Run Diffing
    console.log('Running diffing module...');
    const dbOldEntry = {
      ...oldEntryData,
      day: oldEntryData.day,
      start_time: oldEntryData.start_time,
      end_time: oldEntryData.end_time,
      subject: oldEntryData.subject,
      faculty: oldEntryData.faculty || '',
      room: oldEntryData.room || '',
      ltp: oldEntryData.ltp || '',
      semester: oldEntryData.semester || ''
    };
    
    const { changes } = diffTimetables(batchId, [dbOldEntry], newEntries);
    console.log('Detected changes:', JSON.stringify(changes, null, 2));

    if (changes.length === 0) {
      throw new Error('Verification failed: No changes were detected!');
    }

    // 5. Insert changes to database
    console.log('\nStep 5: Writing change log to "timetable_changes" table...');
    const { error: insertChangesErr } = await supabase
      .from('timetable_changes')
      .insert(changes);

    if (insertChangesErr) throw new Error(`Failed to insert changes: ${insertChangesErr.message}`);

    // 6. Verify written changes in database
    console.log('\nStep 6: Fetching change log from database for validation...');
    const { data: dbChanges, error: fetchChangesErr } = await supabase
      .from('timetable_changes')
      .select('change_type, field_name, old_value, new_value')
      .eq('batch_id', batchId);

    if (fetchChangesErr) throw new Error(`Failed to fetch changes: ${fetchChangesErr.message}`);

    console.log('Database Change Log:', dbChanges);

    const roomChange = dbChanges.find(c => c.change_type === 'ROOM_CHANGED');
    if (
      roomChange &&
      roomChange.field_name === 'room' &&
      roomChange.old_value === '1102-BL1-FF' &&
      roomChange.new_value === '1202-BL1-SF'
    ) {
      console.log('\n>>> SUCCESS! ROOM_CHANGED delta correctly captured and verified! <<<');
    } else {
      throw new Error('Verification failed: Change record contents do not match expected values.');
    }

  } catch (err: any) {
    console.error('\n>>> Test Failed! <<<');
    console.error(err.message || err);
  } finally {
    // 7. Cleanup Mock Metadata
    console.log('\nStep 7: Cleaning up mock test records from database...');
    const { error: delDegreeErr } = await supabase
      .from('degrees')
      .delete()
      .eq('source_value', degreeCode);

    if (delDegreeErr) {
      console.error(`Warning: Failed to clean up mock degree: ${delDegreeErr.message}`);
    } else {
      console.log('Cleanup completed successfully.');
    }
  }

  console.log('\n--- Change Detection Test Complete ---');
}

main();
