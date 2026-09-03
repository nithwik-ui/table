import axios from 'axios';
import * as cheerio from 'cheerio';

async function test() {
  const sru = require('./src/sru/sru-client').SRUClient;
  const client = new sru();
  const rooms = await client.getFreeRooms('Wednesday', '10:30');
  console.log(rooms);
}
test();
