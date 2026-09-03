import { SRUClient } from './src/sru/sru-client';

async function main() {
  const client = new SRUClient();
  console.log('Fetching faculty list...');
  const faculty = await client.getFacultyList();
  console.log(faculty.slice(0, 3));
  if (faculty.length > 0) {
    console.log('Fetching timetable for', faculty[0].name);
    try {
      const timetable = await client.getFacultyTimetable(faculty[0].id);
      console.log(timetable);
    } catch(e) {
      console.error(e);
    }
  }

  console.log('Fetching free rooms for Monday 09:30...');
  try {
    const rooms = await client.getFreeRooms('Monday', '09:30');
    console.log(rooms);
  } catch(e) {
    console.error(e);
  }
}
main();
