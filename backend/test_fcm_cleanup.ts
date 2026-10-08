import * as dotenv from 'dotenv';
import * as path from 'path';
import { createClient } from '@supabase/supabase-js';

dotenv.config({ path: path.join(__dirname, '.env') });

const supabaseUrl = process.env.SUPABASE_URL!;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY!;

const supabase = createClient(supabaseUrl, supabaseKey);

async function cleanup() {
  console.log('Cleaning up test timetable entries and changes...');
  const batchCode = '26CAIBTAIB21';
  
  const { data: batch } = await supabase
    .from('batches')
    .select('id')
    .eq('batch_code', batchCode)
    .single();

  if (batch) {
    // Delete test entry
    await supabase
      .from('timetable_entries')
      .delete()
      .eq('batch_id', batch.id)
      .eq('subject', 'TEST: Cloud Computing & DevOps');

    // Delete test changes
    await supabase
      .from('timetable_changes')
      .delete()
      .eq('batch_id', batch.id)
      .like('field_name', '%TEST%');

    await supabase
      .from('timetable_changes')
      .delete()
      .eq('batch_id', batch.id)
      .eq('old_value', '8105-BL8-FF');

    console.log('✅ Cleaned up test entries and changes successfully.');
  }
}

cleanup();
