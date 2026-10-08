import { createClient } from '@supabase/supabase-js';
import * as dotenv from 'dotenv';
import * as path from 'path';
import fetch from 'node-fetch';

dotenv.config({ path: path.join(__dirname, '.env') });

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseKey) {
  console.error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

async function testFetch() {
  const { data: batches } = await supabase.from('batches').select('id, batch_code').eq('active', true).limit(1);
  if (batches && batches.length > 0) {
    const batchId = batches[0].id;
    console.log(`Testing fetch for batchId: ${batchId}`);
    
    // First directly from DB
    const { data: changesDb } = await supabase.from('timetable_changes').select('*').eq('batch_id', batchId);
    console.log(`DB returned ${changesDb?.length} changes for this batch.`);
    
    // Then via API endpoint (assuming it's running locally on port 3000)
    try {
      const res = await fetch(`http://localhost:3000/api/batches/${batchId}/changes`);
      const apiChanges = await res.json();
      console.log(`API returned ${apiChanges.length} changes for this batch.`);
      if (apiChanges.length > 0) {
        console.log(apiChanges[0]);
      }
    } catch (e: any) {
      console.log('Failed to fetch from API:', e.message);
    }
  }
}

testFetch();
