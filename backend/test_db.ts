import { supabase } from './src/lib/supabase';

async function run() {
  const { data } = await supabase.from('years').select('name, degrees(source_value), batches(id)');
  const missing = data?.filter((x: any) => x.batches.length === 0);
  console.log('Total years with 0 batches:', missing?.length);
  if (missing && missing.length > 0) {
    console.log(missing.slice(0, 10));
  }
}
run();
