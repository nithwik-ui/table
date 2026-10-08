import axios from 'axios';

async function test() {
  try {
    const initRes = await axios.get('https://timetable.sruniv.com/room_free_slots');
    console.log(initRes.data);
  } catch (err) {
    console.error(err);
  }
}

test();
