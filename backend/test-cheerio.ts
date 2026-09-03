import * as cheerio from 'cheerio';
import fs from 'fs';

const html = fs.readFileSync('free_rooms.html', 'utf-8');
const $ = cheerio.load(html);
const rooms: any[] = [];
$('.table tbody tr').each((_, el) => {
  const tds = $(el).find('td');
  if (tds.length >= 2) {
    const roomCell = $(tds[1]);
    const badge = roomCell.find('.badge');
    let type = badge.text().trim();
    let name = roomCell.text().replace(type, '').replace('-', '').trim();
    if (name) {
      rooms.push({ name, type });
    }
  }
});
console.log('Found rooms:', rooms.length);
console.log(rooms[0]);
