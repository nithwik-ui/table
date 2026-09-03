import axios from 'axios';
import * as cheerio from 'cheerio';

async function test() {
  const res = await axios.get('https://timetable.sruniv.com/room_free_slots');
  const $ = cheerio.load(res.data);
  $('select[name="time"] option').each((_, el) => {
    console.log(`Option: '${$(el).val()}' - Text: '${$(el).text()}'`);
  });
}
test();
