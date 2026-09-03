import axios from 'axios';
import * as cheerio from 'cheerio';

async function test() {
  const res = await axios.get('https://timetable.sruniv.com/room_free_slots');
  const $ = cheerio.load(res.data);
  $('form').find('input, select').each((_, el) => {
    console.log($(el).attr('name'));
  });
}
test();
