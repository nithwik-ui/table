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

async function cleanupMockChanges() {
  console.log('--- Cleaning Up Mock Test Changes ---');

  const { error: err1 } = await supabase.from('timetable_changes').delete().like('field_name', 'TEST CLASS:%');
  if (err1) console.error("Error cleaning student changes:", err1);
  else console.log('✅ Cleaned up student mock changes.');

  const { error: err2 } = await supabase.from('faculty_changes').delete().like('field_name', 'TEST CLASS:%');
  if (err2) console.error("Error cleaning faculty changes:", err2);
  else console.log('✅ Cleaned up faculty mock changes.');

  console.log('\nCleanup complete! Your database is back to normal.');
}

cleanupMockChanges();
