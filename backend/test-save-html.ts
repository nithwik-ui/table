import axios from 'axios';
import fs from 'fs';

async function test() {
  try {
    const sru = require('./src/sru/sru-client').SRUClient;
    const client = new sru();
    await client.initRoomSession();
    const params = new URLSearchParams();
    params.append('_token', client.csrfToken);
    params.append('day', 'Wednesday');
    params.append('time', '10:30');

    const res = await axios.post('https://timetable.sruniv.com/room_free_slots', params, {
      headers: {
        'Cookie': client.cookieHeader,
        'Content-Type': 'application/x-www-form-urlencoded',
        'Referer': 'https://timetable.sruniv.com/room_free_slots',
        'User-Agent': 'Mozilla/5.0'
      }
    });
    fs.writeFileSync('free_rooms.html', res.data);
    console.log('Saved to free_rooms.html');
  } catch (e) {
    console.log(e.message);
  }
}
test();
