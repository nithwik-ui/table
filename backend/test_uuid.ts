import { supabase } from './src/db/supabase';
import fetch from 'node-fetch';

async function test() {
  const { data, error } = await supabase.from('faculty_accounts').select('id, faculty_name').limit(1);
  if (error || !data || data.length === 0) {
    console.error("No faculty found", error);
    return;
  }
  
  const faculty = data[0];
  console.log(`Testing with faculty: ${faculty.faculty_name} (ID: ${faculty.id})`);
  
  try {
    const res = await fetch(`http://localhost:3000/api/faculty-scraping/timetable?faculty=${faculty.id}`);
    const json = await res.json();
    console.log("RESPONSE from localhost:3000:");
    console.log(JSON.stringify(json, null, 2));
  } catch (e) {
    console.error("Could not fetch from localhost:3000", e);
  }
}

test().catch(console.error);
