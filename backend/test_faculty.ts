import { SRUClient } from './src/sru/sru-client';

async function test() {
  const client = new SRUClient();
  const list = await client.getFacultyList();
  
  if (list.length > 0) {
    const facultyId = list[0].id;
    console.log(`Testing with faculty: ${facultyId}`);
    
    const raw = await client.getFacultyTimetable(facultyId);
    console.log("RAW RESPONSE:");
    console.log(JSON.stringify(raw, null, 2));
    
    const normalized = client.normalize(raw);
    console.log("NORMALIZED RESPONSE:");
    console.log(JSON.stringify(normalized, null, 2));
  } else {
    console.log("No faculty found");
  }
}

test().catch(console.error);
