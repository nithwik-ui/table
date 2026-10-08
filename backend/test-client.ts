import { SRUClient } from './src/sru/sru-client';

async function test() {
  const client = new SRUClient();
  const rooms = await client.getFreeRooms('Thursday', '09:30');
  console.dir(rooms, { maxArrayLength: null });
}

test().catch(console.error);
