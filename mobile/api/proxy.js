import https from 'https';

export const config = {
  api: {
    bodyParser: false,
    externalResolver: true,
  },
};

export default function handler(req, res) {
  const { target, path } = req.query;
  let hostname = '';
  
  if (target === 'sru') {
    hostname = 'www.sruniv.com';
  } else if (target === 'sraap') {
    hostname = 'sraap.in';
  } else {
    return res.status(400).send('Invalid target');
  }

  const options = {
    hostname: hostname,
    path: '/' + (path || ''),
    method: req.method,
    headers: { ...req.headers },
  };

  delete options.headers.host;
  delete options.headers.origin;
  delete options.headers.referer;

  const proxyReq = https.request(options, (proxyRes) => {
    res.status(proxyRes.statusCode);
    
    for (const [key, value] of Object.entries(proxyRes.headers)) {
      if (key.toLowerCase() === 'set-cookie') {
        if (Array.isArray(value)) {
          const fixed = value.map(c => c.replace(/domain=[^;]+;?/gi, ''));
          res.setHeader(key, fixed);
        } else {
          res.setHeader(key, value.replace(/domain=[^;]+;?/gi, ''));
        }
      } else if (key.toLowerCase() === 'location') {
        let newLoc = value;
        if (target === 'sru') {
          if (newLoc.startsWith('http://www.sruniv.com') || newLoc.startsWith('https://www.sruniv.com')) {
            newLoc = newLoc.replace(/^https?:\/\/www\.sruniv\.com/i, '/api/sru');
          } else if (newLoc.startsWith('/')) {
            newLoc = '/api/sru' + newLoc;
          }
        } else if (target === 'sraap') {
          if (newLoc.startsWith('http://sraap.in') || newLoc.startsWith('https://sraap.in')) {
            newLoc = newLoc.replace(/^https?:\/\/sraap\.in/i, '/api/sraap');
          } else if (newLoc.startsWith('/')) {
            newLoc = '/api/sraap' + newLoc;
          }
        }
        res.setHeader(key, newLoc);
      } else {
        res.setHeader(key, value);
      }
    }
    
    proxyRes.pipe(res);
  });

  proxyReq.on('error', (err) => {
    res.status(500).send(err.message);
  });

  if (req.method === 'GET' || req.method === 'HEAD' || req.method === 'OPTIONS') {
    proxyReq.end();
  } else {
    req.pipe(proxyReq);
  }
}
