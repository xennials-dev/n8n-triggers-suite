/**
 * auto-auth-proxy.js
 * Zero-dependency transparent authentication proxy for n8n.
 * Listens on port 5678 (user-facing) and proxies to n8n on port 5679.
 * Automatically provisions/logs in the local owner and injects the session cookie
 * so the user lands straight on the workflow canvas without entering credentials.
 */

const http = require('http');
const net = require('net');

const PROXY_PORT = parseInt(process.env.PROXY_PORT || '5678', 10);
const TARGET_PORT = parseInt(process.env.N8N_PORT || '5679', 10);
const TARGET_HOST = process.env.N8N_HOST || '127.0.0.1';

const DEFAULT_USER = {
  email: process.env.N8N_LOCAL_ADMIN_EMAIL || 'admin@local.dev',
  password: process.env.N8N_LOCAL_ADMIN_PASSWORD || 'LocalDevPassword123!',
  firstName: 'Local',
  lastName: 'Admin'
};

let cachedAuthCookie = null;
let isSettingUp = false;

// Helper to make internal JSON HTTP requests to n8n
function makeInternalRequest(options, postData = null) {
  return new Promise((resolve, reject) => {
    const req = http.request({
      hostname: TARGET_HOST,
      port: TARGET_PORT,
      ...options,
      headers: {
        'Content-Type': 'application/json',
        ...(postData ? { 'Content-Length': Buffer.byteLength(postData) } : {}),
        ...(options.headers || {})
      }
    }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        resolve({
          statusCode: res.statusCode,
          headers: res.headers,
          body: data
        });
      });
    });

    req.on('error', reject);
    req.setTimeout(5000, () => {
      req.destroy();
      reject(new Error('Internal request timeout'));
    });

    if (postData) req.write(postData);
    req.end();
  });
}

// Automatically authenticate or set up the owner account
async function getOrFetchSessionCookie() {
  if (cachedAuthCookie) {
    return cachedAuthCookie;
  }

  if (isSettingUp) {
    // Wait briefly if another request is in-flight
    await new Promise(r => setTimeout(r, 800));
    if (cachedAuthCookie) return cachedAuthCookie;
  }

  isSettingUp = true;
  try {
    // 1. Try logging in first
    const loginPayload = JSON.stringify({
      emailOrLdapLoginId: DEFAULT_USER.email,
      password: DEFAULT_USER.password
    });

    const loginRes = await makeInternalRequest({
      path: '/rest/login',
      method: 'POST'
    }, loginPayload);

    if (loginRes.statusCode === 200 && loginRes.headers['set-cookie']) {
      cachedAuthCookie = loginRes.headers['set-cookie'];
      console.log('[Auto-Auth Proxy] Successfully authenticated local admin session.');
      return cachedAuthCookie;
    }

    // 2. If login failed or uninitialized, try owner setup
    console.log('[Auto-Auth Proxy] Attempting initial owner setup...');
    const setupPayload = JSON.stringify({
      email: DEFAULT_USER.email,
      firstName: DEFAULT_USER.firstName,
      lastName: DEFAULT_USER.lastName,
      password: DEFAULT_USER.password
    });

    const setupRes = await makeInternalRequest({
      path: '/rest/owner/setup',
      method: 'POST'
    }, setupPayload);

    if (setupRes.headers['set-cookie']) {
      cachedAuthCookie = setupRes.headers['set-cookie'];
      console.log('[Auto-Auth Proxy] Owner account created and session established.');
      return cachedAuthCookie;
    }

    // 3. Fallback: retry login once after setup attempt
    const retryLogin = await makeInternalRequest({
      path: '/rest/login',
      method: 'POST'
    }, loginPayload);

    if (retryLogin.headers['set-cookie']) {
      cachedAuthCookie = retryLogin.headers['set-cookie'];
      return cachedAuthCookie;
    }

  } catch (err) {
    console.error('[Auto-Auth Proxy] Auth helper error (n8n may still be starting):', err.message);
  } finally {
    isSettingUp = false;
  }

  return null;
}

// Create Main Proxy Server
const server = http.createServer(async (req, res) => {
  const url = req.url || '/';
  const cookieHeader = req.headers['cookie'] || '';
  const acceptHeader = req.headers['accept'] || '';

  const isWebhook = url.startsWith('/webhook') || url.startsWith('/webhook-test');
  const isStatic = url.startsWith('/assets/') || url.endsWith('.js') || url.endsWith('.css') || url.endsWith('.svg') || url.endsWith('.ico');
  const isRest = url.startsWith('/rest/');
  const isHtmlNavigation = acceptHeader.includes('text/html') || url === '/' || url.startsWith('/login') || url.startsWith('/signin') || url.startsWith('/home') || url.startsWith('/workflow');

  // Check if browser already has an auth cookie
  const hasAuthCookie = cookieHeader.includes('n8n-auth=') || cookieHeader.includes('n8n_auth=');

  // Intercept unauthenticated HTML browser navigation to auto-login
  if (!hasAuthCookie && isHtmlNavigation && !isWebhook && !isStatic) {
    const rawCookies = await getOrFetchSessionCookie();
    if (rawCookies) {
      console.log(`[Auto-Auth Proxy] Bypassing login screen for navigation to: ${url}`);
      // Remove Secure flag for plain HTTP localhost compatibility
      const sanitizedCookies = rawCookies.map(c => c.replace(/;\s*Secure/gi, ''));
      res.writeHead(302, {
        'Location': '/home/workflows',
        'Set-Cookie': sanitizedCookies,
        'Cache-Control': 'no-cache, no-store, must-revalidate'
      });
      res.end();
      return;
    }
  }

  // Standard proxying to n8n core
  const proxyReq = http.request({
    hostname: TARGET_HOST,
    port: TARGET_PORT,
    path: req.url,
    method: req.method,
    headers: {
      ...req.headers,
      host: `localhost:${PROXY_PORT}`
    }
  }, (proxyRes) => {
    // If n8n sets an auth cookie, cache it
    if (proxyRes.headers['set-cookie']) {
      cachedAuthCookie = proxyRes.headers['set-cookie'];
    }

    res.writeHead(proxyRes.statusCode, proxyRes.headers);
    proxyRes.pipe(res, { end: true });
  });

  proxyReq.on('error', (err) => {
    if (!res.headersSent) {
      res.writeHead(502, { 'Content-Type': 'text/html' });
      res.end(`
        <div style="font-family: sans-serif; padding: 40px; text-align: center;">
          <h2>n8n Starting Up...</h2>
          <p>The local n8n service on port ${TARGET_PORT} is not ready yet.</p>
          <p>Please refresh this page in a few seconds.</p>
        </div>
      `);
    }
  });

  req.pipe(proxyReq, { end: true });
});

// Handle WebSocket / Upgrade requests (used by n8n for live UI execution events)
server.on('upgrade', (req, clientSocket, head) => {
  const targetSocket = net.connect(TARGET_PORT, TARGET_HOST, () => {
    targetSocket.write(`${req.method} ${req.url} HTTP/${req.httpVersion}\r\n`);
    for (let i = 0; i < req.rawHeaders.length; i += 2) {
      const headerName = req.rawHeaders[i];
      let headerValue = req.rawHeaders[i + 1];
      if (headerName.toLowerCase() === 'host') {
        headerValue = `localhost:${TARGET_PORT}`;
      }
      targetSocket.write(`${headerName}: ${headerValue}\r\n`);
    }
    targetSocket.write('\r\n');
    if (head && head.length > 0) {
      targetSocket.write(head);
    }
    targetSocket.pipe(clientSocket);
    clientSocket.pipe(targetSocket);
  });

  targetSocket.on('error', (err) => {
    clientSocket.destroy();
  });
  clientSocket.on('error', (err) => {
    targetSocket.destroy();
  });
});

server.listen(PROXY_PORT, () => {
  console.log(`=======================================================`);
  console.log(`  n8n Zero-Click Auto-Auth Proxy Active`);
  console.log(`  User-Facing Endpoint: http://localhost:${PROXY_PORT}`);
  console.log(`  Forwarding to n8n:    http://${TARGET_HOST}:${TARGET_PORT}`);
  console.log(`  Auto-Login Account:   ${DEFAULT_USER.email}`);
  console.log(`=======================================================`);
});
