import https from 'https';
import { URL } from 'url';

export const config = {
  api: {
    bodyParser: false,
    externalResolver: true,
  },
};

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

  const urlPath = '/' + (path || '');

  // Forward all headers except host/origin/referer to avoid CORS rejection
  const forwardHeaders = { ...req.headers };
  forwardHeaders['host'] = hostname;
  delete forwardHeaders['origin'];
  delete forwardHeaders['referer'];
  delete forwardHeaders['x-forwarded-for'];
  delete forwardHeaders['x-vercel-forwarded-for'];
  delete forwardHeaders['x-vercel-ip-country'];
  delete forwardHeaders['x-forwarded-proto'];
  delete forwardHeaders['x-forwarded-host'];

  const options = {
    hostname: hostname,
    port: 443,
    path: urlPath,
    method: req.method,
    headers: forwardHeaders,
  };

  const proxyReq = https.request(options, (proxyRes) => {
    // Pass through status
    res.status(proxyRes.statusCode);

    // Process response headers
    for (const [key, value] of Object.entries(proxyRes.headers)) {
      const lkey = key.toLowerCase();
      if (lkey === 'set-cookie') {
        const cookies = Array.isArray(value) ? value : [value];
        const fixed = cookies.map(stripCookieDomain);
        res.setHeader('set-cookie', fixed);
      } else if (lkey === 'location') {
        const newLoc = rewriteLocation(value, target);
        res.setHeader('location', newLoc);
      } else if (lkey === 'transfer-encoding' || lkey === 'content-encoding') {
        // Don't forward encoding headers as Vercel handles this
        continue;
      } else {
        try { res.setHeader(key, value); } catch (_) {}
      }
    }

    proxyRes.pipe(res);
  });

  proxyReq.on('error', (err) => {
    console.error('Proxy error:', err.message);
    res.status(500).json({ error: err.message });
  });

  if (req.method === 'GET' || req.method === 'HEAD' || req.method === 'OPTIONS') {
    proxyReq.end();
  } else {
    req.pipe(proxyReq);
  }
}
