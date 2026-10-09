const http = require('http');
const proxyHandler = require('./api/proxy.js').default;

const server = http.createServer((req, res) => {
  // Mock req.query
  req.query = { target: 'sru', path: '' };
  proxyHandler(req, res);
});

server.listen(3000, async () => {
  console.log('Test proxy running on 3000');
  
  // Make a POST request
  const options = {
    hostname: 'localhost',
    port: 3000,
    path: '/',
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
      'Content-Length': '0' // Empty body for test, we just want to see the redirect
    }
  };

  const req = http.request(options, (res) => {
    console.log('STATUS:', res.statusCode);
    console.log('HEADERS:', res.headers);
    let data = '';
    res.on('data', chunk => data += chunk);
    res.on('end', () => {
      console.log('BODY:', data.substring(0, 100));
      process.exit(0);
    });
  });

  req.on('error', (e) => {
    console.error(`problem with request: ${e.message}`);
    process.exit(1);
  });

  req.end();
});
