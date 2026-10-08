import axios from 'axios';
import * as cheerio from 'cheerio';

async function test() {
  try {
    const initRes = await axios.get('https://timetable.sruniv.com/room_free_slots');
    const $1 = cheerio.load(initRes.data);
    const token = $1('input[name="_token"]').val();
    
    const cookies = initRes.headers['set-cookie'];
    const cookieHeader = cookies ? cookies.map(c => c.split(';')[0]).join('; ') : '';

    const params = new URLSearchParams();
    params.append('_token', token as string);
    params.append('day', 'Thursday');
    params.append('time', '09:30');

    const res = await axios.post('https://timetable.sruniv.com/room_free_slots', params, {
      headers: {
        'Cookie': cookieHeader,
        'Content-Type': 'application/x-www-form-urlencoded',
        'Referer': 'https://timetable.sruniv.com/room_free_slots'
      }
    });

    console.log("RESPONSE HTML:");
    console.log(res.data.substring(0, 500) + '...');
    
    const $ = cheerio.load(res.data);
    const tableHtml = $('.table').html();
    console.log("TABLE HTML:");
    console.log(tableHtml);
    
    const rooms: any[] = [];
    $('.table tbody tr').each((_, el) => {
      const tds = $(el).find('td');
      if (tds.length >= 2) {
        const roomCell = $(tds[1]);
        const badge = roomCell.find('.badge');
        let type = badge.text().trim();
        let name = roomCell.text().replace(type, '').replace('-', '').trim();
        rooms.push({ name, type, original: roomCell.html() });
      } else {
         console.log("TD length < 2:", $(el).html());
      }
    });
    console.log("Parsed rooms:", rooms.length);
    console.dir(rooms.slice(0, 5), {depth: null});
  } catch (err) {
    console.error(err);
  }
}

test();
