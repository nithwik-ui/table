import { SRUClient, TimetableEntry } from '../sru/sru-client';
import { supabase } from '../db/supabase';
import * as crypto from 'crypto';
import { diffTimetables } from './diff';

// Politeness settings
const CONCURRENCY_LIMIT = 3;
const DELAY_BETWEEN_REQUESTS_MS = 200;

function sleep(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}

function computeHash(data: any): string {
  const contentStr = typeof data === 'string' ? data : JSON.stringify(data);
  return crypto.createHash('sha256').update(contentStr).digest('hex');
}

function sortEntries(entries: TimetableEntry[]): TimetableEntry[] {
  return [...entries].sort((a, b) => {
    if (a.day !== b.day) return a.day.localeCompare(b.day);
    if (a.start_time !== b.start_time) return a.start_time.localeCompare(b.start_time);
    if (a.subject !== b.subject) return a.subject.localeCompare(b.subject);
    if (a.faculty !== b.faculty) return a.faculty.localeCompare(b.faculty);
    return a.room.localeCompare(b.room);
  });
}

// Concurrency-limited worker pool implementation
async function executeInPool<T>(
  items: T[],
  workerCount: number,
  fn: (item: T) => Promise<void>
): Promise<void> {
  let index = 0;
  const workers = Array.from({ length: workerCount }, async () => {
    while (index < items.length) {
      const currentIndex = index++;
      const item = items[currentIndex];
      try {
        await fn(item);
      } catch (err) {
        console.error(`Error on item at index ${currentIndex}:`, err);
      }
    }
  });
  await Promise.all(workers);
}

async function sync() {
  console.log('=== Starting SRU Timetable Sync Worker ===');
  const startTime = Date.now();

  const client = new SRUClient();
  console.log('Initializing session with SRU Portal...');
  await client.initSession();

  // --- Step 1: Degrees Discovery ---
  console.log('\nDiscovering degrees...');
  const degrees = await client.getDegrees();
  console.log(`Discovered ${degrees.length} degrees from live portal.`);

  // Set all degrees to inactive first (for discovery stale detection)
  await supabase.from('degrees').update({ active: false }).neq('id', '00000000-0000-0000-0000-000000000000');

  const degreeMap: Record<string, string> = {}; // source_value -> id

  for (const degreeCode of degrees) {
    const { data, error } = await supabase
      .from('degrees')
      .upsert(
        { source_value: degreeCode, active: true, last_seen_at: new Date().toISOString() },
        { onConflict: 'source_value' }
      )
      .select('id, source_value');

    if (error) {
      console.error(`Error upserting degree ${degreeCode}:`, error.message);
    } else if (data && data.length > 0) {
      degreeMap[data[0].source_value] = data[0].id;
    }
  }

  // Fetch active degrees from DB
  const { data: dbDegrees, error: dbDegreesErr } = await supabase
    .from('degrees')
    .select('id, source_value')
    .eq('active', true);

  if (dbDegreesErr || !dbDegrees) {
    throw new Error(`Failed to retrieve degrees from database: ${dbDegreesErr?.message}`);
  }

  console.log(`Successfully upserted and activated ${dbDegrees.length} degrees in database.`);

  // --- Step 2: Years Discovery ---
  console.log('\nDiscovering years...');
  // Mark all years as inactive
  await supabase.from('years').update({ active: false }).neq('id', '00000000-0000-0000-0000-000000000000');

  const activeYearsList: { degree_id: string; degree_code: string; name: string }[] = [];

  await executeInPool(dbDegrees, CONCURRENCY_LIMIT, async (deg) => {
    await sleep(DELAY_BETWEEN_REQUESTS_MS);
    console.log(`Fetching years for ${deg.source_value}...`);
    try {
      const years = await client.getYears(deg.source_value);
      for (const yearName of years) {
        activeYearsList.push({
          degree_id: deg.id,
          degree_code: deg.source_value,
          name: yearName,
        });
      }
    } catch (err: any) {
      console.error(`Failed to fetch years for degree ${deg.source_value}:`, err.message || err);
    }
  });

  console.log(`Found ${activeYearsList.length} total degree-year combinations.`);

  const yearMap: Record<string, string> = {}; // degreeId_yearName -> yearId

  for (const yearItem of activeYearsList) {
    const { data, error } = await supabase
      .from('years')
      .upsert(
        {
          degree_id: yearItem.degree_id,
          name: yearItem.name,
          active: true,
          last_seen_at: new Date().toISOString(),
        },
        { onConflict: 'degree_id,name' }
      )
      .select('id, degree_id, name');

    if (error) {
      console.error(`Error upserting year ${yearItem.name} for degree ${yearItem.degree_code}:`, error.message);
    } else if (data && data.length > 0) {
      const key = `${data[0].degree_id}_${data[0].name}`;
      yearMap[key] = data[0].id;
    }
  }

  // --- Step 3: Batches Discovery ---
  console.log('\nDiscovering batches...');
  // Mark all batches as inactive
  await supabase.from('batches').update({ active: false }).neq('id', '00000000-0000-0000-0000-000000000000');

  // We need to fetch batches for each active degree-year combination
  const { data: dbYears, error: dbYearsErr } = await supabase
    .from('years')
    .select('id, name, degree_id, degrees(source_value)')
    .eq('active', true);

  if (dbYearsErr || !dbYears) {
    throw new Error(`Failed to retrieve years from database: ${dbYearsErr?.message}`);
  }

  const activeBatchesList: { degree_id: string; year_id: string; batch_code: string; degree_code: string; year_name: string }[] = [];

  await executeInPool(dbYears, CONCURRENCY_LIMIT, async (yr: any) => {
    await sleep(DELAY_BETWEEN_REQUESTS_MS);
    const degreeCode = yr.degrees.source_value;
    console.log(`Fetching batches for ${degreeCode} - ${yr.name}...`);
    try {
      const batches = await client.getBatches(degreeCode, yr.name);
      for (const batchCode of batches) {
        activeBatchesList.push({
          degree_id: yr.degree_id,
          year_id: yr.id,
          batch_code: batchCode,
          degree_code: degreeCode,
          year_name: yr.name,
        });
      }
    } catch (err: any) {
      console.error(`Failed to fetch batches for ${degreeCode} - ${yr.name}:`, err.message || err);
    }
  });

  console.log(`Found ${activeBatchesList.length} total batch candidates.`);

  for (const batchItem of activeBatchesList) {
    const { error } = await supabase
      .from('batches')
      .upsert(
        {
          degree_id: batchItem.degree_id,
          year_id: batchItem.year_id,
          batch_code: batchItem.batch_code,
          active: true,
          last_seen_at: new Date().toISOString(),
        },
        { onConflict: 'degree_id,year_id,batch_code' }
      );

    if (error) {
      console.error(
        `Error upserting batch ${batchItem.batch_code} for ${batchItem.degree_code} - ${batchItem.year_name}:`,
        error.message
      );
    }
  }

  // --- Step 4: Timetable Synchronization ---
  console.log('\nSynchronizing batch timetables...');
  
  // Get all active batches from database joined with their degree and year codes
  const { data: dbBatches, error: dbBatchesErr } = await supabase
    .from('batches')
    .select(`
      id,
      batch_code,
      degree_id,
      year_id,
      degrees (source_value),
      years (name)
    `)
    .eq('active', true);

  if (dbBatchesErr || !dbBatches) {
    throw new Error(`Failed to retrieve active batches for sync: ${dbBatchesErr?.message}`);
  }

  console.log(`Syncing timetables for ${dbBatches.length} active batches...`);

  let succeededCount = 0;
  let failedCount = 0;
  let unchangedCount = 0;
  let updatedCount = 0;

  await executeInPool(dbBatches, CONCURRENCY_LIMIT, async (batchRow: any) => {
    await sleep(DELAY_BETWEEN_REQUESTS_MS);
    const batchId = batchRow.id;
    const batchCode = batchRow.batch_code;
    const degreeCode = batchRow.degrees.source_value;
    const yearName = batchRow.years.name;

    try {
      // 1. Fetch raw timetable
      const raw = await client.getDetailedTimetable(yearName, batchCode);
      if (!raw || !raw.success) {
        throw new Error('Live portal returned unsuccessful status');
      }

      // 2. Normalize and sort
      const normalized = client.normalize(raw);
      const sorted = sortEntries(normalized);
      const serialized = JSON.stringify(sorted);
      const newHash = computeHash(serialized);

      // 3. Compare with database snapshot
      const { data: snapshot, error: snapshotErr } = await supabase
        .from('timetable_snapshots')
        .select('hash')
        .eq('batch_id', batchId)
        .maybeSingle();

      if (snapshotErr) {
        throw new Error(`Failed to check database snapshot: ${snapshotErr.message}`);
      }

      if (snapshot && snapshot.hash === newHash) {
        // No change detected
        unchangedCount++;
        succeededCount++;
        console.log(`[-] Batch ${batchCode} (${degreeCode} / ${yearName}): Timetable unchanged.`);
      } else {
        // Hash changed or is new
        console.log(`[+] Batch ${batchCode} (${degreeCode} / ${yearName}): Update detected! Syncing...`);

        // Diff with old entries if snapshot existed previously
        if (snapshot) {
          const { data: oldEntries, error: oldEntriesErr } = await supabase
            .from('timetable_entries')
            .select('id, day, start_time, end_time, subject, faculty, room, ltp, semester')
            .eq('batch_id', batchId);

          if (oldEntriesErr) {
            console.error(`Failed to fetch old entries for diff: ${oldEntriesErr.message}`);
          } else {
            const { changes } = diffTimetables(batchId, oldEntries || [], sorted);
            if (changes.length > 0) {
              const { error: insertChangesErr } = await supabase
                .from('timetable_changes')
                .insert(changes);

              if (insertChangesErr) {
                console.error(`Failed to write timetable changes: ${insertChangesErr.message}`);
              } else {
                console.log(`[+] Recorded ${changes.length} schedule updates in timetable_changes.`);
              }
            }
          }
        }

        // Update raw snapshot
        const { error: snapshotUpsertErr } = await supabase
          .from('timetable_snapshots')
          .upsert({
            batch_id: batchId,
            hash: newHash,
            raw_json: raw,
            synced_at: new Date().toISOString()
          }, { onConflict: 'batch_id' });

        if (snapshotUpsertErr) {
          throw new Error(`Failed to save raw snapshot: ${snapshotUpsertErr.message}`);
        }

        // Delete existing entries
        const { error: deleteErr } = await supabase
          .from('timetable_entries')
          .delete()
          .eq('batch_id', batchId);


        if (deleteErr) {
          throw new Error(`Failed to delete existing entries: ${deleteErr.message}`);
        }

        // Insert new normalized entries
        if (sorted.length > 0) {
          const insertPayload = sorted.map(item => ({
            batch_id: batchId,
            day: item.day,
            start_time: item.start_time,
            end_time: item.end_time,
            subject: item.subject,
            faculty: item.faculty,
            room: item.room,
            semester: item.semester,
            ltp: item.ltp,
            source_hash: computeHash(JSON.stringify(item))
          }));

          const { error: insertErr } = await supabase
            .from('timetable_entries')
            .insert(insertPayload);

          if (insertErr) {
            throw new Error(`Failed to insert timetable entries: ${insertErr.message}`);
          }
        }

        updatedCount++;
        succeededCount++;
        console.log(`[✓] Batch ${batchCode}: Synced ${sorted.length} classes.`);
      }
    } catch (err: any) {
      failedCount++;
      console.error(`[✗] Batch ${batchCode} (${degreeCode} / ${yearName}) failed:`, err.message || err);
    }
  });

  const durationSec = ((Date.now() - startTime) / 1000).toFixed(1);
  console.log('\n=== Synchronization Summary ===');
  console.log(`Duration: ${durationSec} seconds`);
  console.log(`Total active batches processed: ${dbBatches.length}`);
  console.log(`Succeeded: ${succeededCount} (Updated: ${updatedCount}, Unchanged: ${unchangedCount})`);
  console.log(`Failed: ${failedCount}`);
  console.log('=================================');
}

sync().catch(err => {
  console.error('Fatal sync error:', err);
  process.exit(1);
});
