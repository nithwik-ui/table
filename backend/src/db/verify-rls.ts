import { createClient } from '@supabase/supabase-js';
import * as dotenv from 'dotenv';
import * as path from 'path';
import * as fs from 'fs';

const envPath = path.resolve(__dirname, '../../.env');
console.log('Resolved env path:', envPath);
if (fs.existsSync(envPath)) {
  console.log('File exists. Contents first 100 chars:', fs.readFileSync(envPath, 'utf8').substring(0, 100));
} else {
  console.log('File does NOT exist at resolved path!');
}

// Load environmental variables from .env
dotenv.config({ path: envPath, override: true });

const supabaseUrl = process.env.SUPABASE_URL || '';
const supabaseAnonKey = process.env.SUPABASE_ANON_KEY || '';
const supabaseServiceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY || '';

async function main() {
  console.log('SUPABASE_URL loaded:', JSON.stringify(supabaseUrl));
  console.log('SUPABASE_ANON_KEY loaded length:', supabaseAnonKey.length);
  console.log('SUPABASE_SERVICE_ROLE_KEY loaded length:', supabaseServiceRoleKey.length);

  if (!supabaseUrl || !supabaseAnonKey || !supabaseServiceRoleKey) {
    console.error('Error: SUPABASE_URL, SUPABASE_ANON_KEY, and SUPABASE_SERVICE_ROLE_KEY must be defined in your backend/.env file.');
    console.error('Please create/update backend/.env with your Supabase credentials.');
    process.exit(1);
  }

  console.log('Initializing Supabase Clients...');
  const anonClient = createClient(supabaseUrl, supabaseAnonKey);
  const serviceClient = createClient(supabaseUrl, supabaseServiceRoleKey);

  const testSourceValue = 'TEST-RLS-TEMP';

  console.log('\nStep 1: Attempting to insert a degree with ANONYMOUS client...');
  try {
    const { data, error } = await anonClient
      .from('degrees')
      .insert([{ name: 'Test Degree', source_value: testSourceValue }]);

    if (error) {
      console.log('Success! Anonymous write was BLOCKED by RLS.');
      console.log('Blocked response message:', error.message);
    } else {
      console.error('Failure! Anonymous write was ALLOWED. Verify your RLS policies on the "degrees" table.');
      await serviceClient.from('degrees').delete().eq('source_value', testSourceValue);
      process.exit(1);
    }
  } catch (e: any) {
    console.log('Success! Anonymous write threw an exception (blocked by RLS):', e.message);
  }

  console.log('\nStep 2: Attempting to insert a degree with SERVICE ROLE client...');
  try {
    const { data, error } = await serviceClient
      .from('degrees')
      .insert([{ name: 'Test Degree', source_value: testSourceValue }])
      .select();

    if (error) {
      console.error('Failure! Service role write failed:', error.message);
      process.exit(1);
    } else {
      console.log('Success! Service role write was ALLOWED.');
      console.log('Inserted record:', data);
    }
  } catch (e: any) {
    console.error('Failure! Service role write threw an exception:', e.message);
    process.exit(1);
  }

  console.log('\nStep 3: Cleaning up test record...');
  try {
    const { error } = await serviceClient
      .from('degrees')
      .delete()
      .eq('source_value', testSourceValue);

    if (error) {
      console.error('Warning: Cleanup failed:', error.message);
    } else {
      console.log('Success! Cleaned up the test record.');
    }
  } catch (e: any) {
    console.error('Warning: Cleanup threw an exception:', e.message);
  }

  console.log('\n--- RLS Verification Complete ---');
}

main();
