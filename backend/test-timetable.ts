import axios from 'axios';

async function test() {
  try {
    const res = await axios.get('https://table-ij9g.onrender.com/api/batches/1255/timetable');
    console.log(JSON.stringify(res.data.slice(0, 5), null, 2));
  } catch (err) {
    console.error(err);
  }
}

test();
