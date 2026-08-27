import { SRUClient } from './sru-client';

async function main() {
  console.log('--- SRU Timetable Client Test ---');
  const client = new SRUClient();

  console.log('\nStep 1: Initializing session (fetching CSRF and cookies)...');
  const session = await client.initSession();
  console.log(`Success! CSRF Token: ${session.csrfToken}`);
  console.log(`Cookies: ${session.cookies}`);

  console.log('\nStep 2: Fetching available degrees...');
  const degrees = await client.getDegrees();
  console.log(`Found ${degrees.length} degrees.`);
  console.log('Sample degrees:', degrees.slice(0, 10));

  const targetDegree = 'BTECH-CSE';
  if (!degrees.includes(targetDegree)) {
    console.error(`Error: Target degree "${targetDegree}" not found in list!`);
    process.exit(1);
  }
  console.log(`Target degree "${targetDegree}" exists in list.`);

  console.log(`\nStep 3: Fetching years for degree "${targetDegree}"...`);
  const years = await client.getYears(targetDegree);
  console.log(`Years found:`, years);

  const targetYear = 'Third';
  if (!years.includes(targetYear)) {
    console.error(`Error: Target year "${targetYear}" not found in list!`);
    process.exit(1);
  }
  console.log(`Target year "${targetYear}" exists in list.`);

  console.log(`\nStep 4: Fetching batches for degree "${targetDegree}" and year "${targetYear}"...`);
  const batches = await client.getBatches(targetDegree, targetYear);
  console.log(`Found ${batches.length} batches.`);
  console.log('Sample batches:', batches.slice(0, 10));

  const targetBatch = '24BTCAICYB02';
  if (!batches.includes(targetBatch)) {
    console.error(`Error: Target batch "${targetBatch}" not found in list!`);
    process.exit(1);
  }
  console.log(`Target batch "${targetBatch}" exists in list.`);

  console.log(`\nStep 5: Fetching detailed timetable for Year: "${targetYear}", Batch: "${targetBatch}"...`);
  const rawTimetable = await client.getDetailedTimetable(targetYear, targetBatch);
  console.log(`Detailed timetable response success: ${rawTimetable.success}`);

  console.log('\nStep 6: Normalizing timetable data...');
  const normalized = client.normalize(rawTimetable);
  console.log(`Successfully normalized! Total classes: ${normalized.length}`);
  
  if (normalized.length === 0) {
    console.log('Warning: Normalized schedule is empty!');
  } else {
    console.log('\nFirst 5 normalized entries:');
    console.log(JSON.stringify(normalized.slice(0, 5), null, 2));
  }

  console.log('\n--- Test Completed ---');
}

main().catch(err => {
  console.error('Test execution failed:', err);
  process.exit(1);
});
