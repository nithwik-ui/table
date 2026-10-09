import https from 'https';

export const config = {
  api: {
    bodyParser: false,
    externalResolver: true,
  },
};

// Read entire request body as a Buffer
function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on('data', (chunk) => chunks.push(chunk));
    req.on('end', () => resolve(Buffer.concat(chunks)));
    req.on('error', reject);
  });
}

function rewriteLocation(location, target) {
  if (!location) return location;
  if (target === 'sru') {
    if (/^https?:\/\/www\.sruniv\.com/i.test(location)) {
      return location.replace(/^https?:\/\/www\.sruniv\.com/i, '/api/sru');
    } else if (location.startsWith('/')) {
      return '/api/sru' + location;
    }
  } else if (target === 'sraap') {
    if (/^https?:\/\/sraap\.in/i.test(location)) {
      return location.replace(/^https?:\/\/sraap\.in/i, '/api/sraap');
    } else if (location.startsWith('/')) {
      return '/api/sraap' + location;
    }
  }
  return location;
}

function stripCookieDomain(cookie) {
  return cookie
    .replace(/;\s*domain=[^;]+/gi, '')
    .replace(/;\s*samesite=strict/gi, '; SameSite=Lax')
    .replace(/;\s*secure/gi, '');
}

export default async function handler(req, res) {
  const { target, path } = req.query;
  let hostname = '';

  if (target === 'sru') {
    hostname = 'www.sruniv.com';
  } else if (target === 'sraap') {
    hostname = 'sraap.in';
  } else {
    return res.status(400).send('Invalid target');
  }

  const urlPath = '/' + (path || '');

  // Read body first before doing anything else
  let bodyBuffer = Buffer.alloc(0);
  try {
    bodyBuffer = await readBody(req);
  } catch (e) {
    console.error('Body read error:', e.message);
  }

  // Build clean headers
  const forwardHeaders = {};
  const skipHeaders = new Set([
    'host', 'origin', 'referer',
    'x-forwarded-for', 'x-vercel-forwarded-for',
    'x-vercel-ip-country', 'x-forwarded-proto',
    'x-forwarded-host', 'x-real-ip',
    'connection', 'x-vercel-deployment-url',
    'x-vercel-id', 'x-vercel-cache',
    'accept-encoding', // Force backend to send plain text so proxy doesn't send raw gzip bytes
  ]);
  for (const [key, value] of Object.entries(req.headers)) {
    if (!skipHeaders.has(key.toLowerCase())) {
      forwardHeaders[key] = value;
    }
  }
  
  // Browsers block JS from setting "Cookie" headers. Dart sends it as "x-proxy-cookie".
  if (req.headers['x-proxy-cookie']) {
    forwardHeaders['cookie'] = req.headers['x-proxy-cookie'];
    delete forwardHeaders['x-proxy-cookie'];
  }
  forwardHeaders['host'] = hostname;
  // Set correct origin and referer so Laravel's CSRF middleware accepts the request
  forwardHeaders['origin'] = `https://${hostname}`;
  forwardHeaders['referer'] = `https://${hostname}/`;
  if (bodyBuffer.length > 0) {
    forwardHeaders['content-length'] = String(bodyBuffer.length);
  }

  const options = {
    hostname: hostname,
    port: 443,
    path: urlPath,
    method: req.method,
    headers: forwardHeaders,
  };

  return new Promise((resolve) => {
    const proxyReq = https.request(options, (proxyRes) => {
      res.status(proxyRes.statusCode);

      for (const [key, value] of Object.entries(proxyRes.headers)) {
        const lkey = key.toLowerCase();
        if (lkey === 'set-cookie') {
          const cookies = Array.isArray(value) ? value : [value];
          const fixed = cookies.map(stripCookieDomain);
          res.setHeader('set-cookie', fixed);
          // Browsers block JS from reading Set-Cookie. We expose it manually so Dart can capture it.
          res.setHeader('x-proxy-set-cookie', fixed.join(', '));
          res.setHeader('Access-Control-Expose-Headers', 'x-proxy-set-cookie');
        } else if (lkey === 'location') {
          res.setHeader('location', rewriteLocation(value, target));
        } else if (lkey === 'transfer-encoding' || lkey === 'content-encoding') {
          // Skip - Vercel handles encoding
        } else {
          try { res.setHeader(key, value); } catch (_) {}
        }
      }

      const chunks = [];
      proxyRes.on('data', (c) => chunks.push(c));
      proxyRes.on('end', () => {
        const body = Buffer.concat(chunks);
        res.end(body);
        resolve();
      });
      proxyRes.on('error', (err) => {
        res.status(502).end('Upstream error: ' + err.message);
        resolve();
      });
    });

    proxyReq.on('error', (err) => {
      console.error('Proxy request error:', err.message);
      res.status(500).json({ error: err.message });
      resolve();
    });

    if (bodyBuffer.length > 0) {
      proxyReq.write(bodyBuffer);
    }
    proxyReq.end();
  });
}
