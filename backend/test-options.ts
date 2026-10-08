import axios from 'axios';
import * as cheerio from 'cheerio';

async function test() {
  try {
    const initRes = await axios.get('https://timetable.sruniv.com/room_free_slots');
    const $1 = cheerio.load(initRes.data);
    
    console.log("Time options:");
    $1('#time option').each((i, el) => {
        console.log($1(el).val());
    });
  } catch (err) {
    console.error(err);
  }
}

test();
