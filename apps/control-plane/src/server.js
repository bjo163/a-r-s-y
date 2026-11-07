import Fastify from 'fastify';
import pg from 'pg';
import { readFile } from 'node:fs/promises';
import { resolve4, resolve6 } from 'node:dns/promises';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import {
  constantTimeEqual,
  digestSessionToken,
  escapeHtml,
  hashPassword,
  makeRandomToken,
  normalizeEmail,
  validateSetupInput,
  verifyPassword
} from './security.js';

const __dirname = dirname(fileURLToPath(import.meta.url));
const publicDir = join(__dirname, '..', 'public');
const schemaPath = join(__dirname, '..', 'schema.sql');
const { Pool } = pg;

const env = process.env;
const requiredEnv = ['DB_HOST', 'DB_NAME', 'DB_USER', 'DB_PASSWORD', 'ARSY_SETUP_TOKEN', 'ARSY_SESSION_SECRET'];
for (const key of requiredEnv) {
  if (!env[key]) throw new Error('Missing required environment variable: ' + key);
}

const pool = new Pool({
  host: env.DB_HOST,
  port: Number(env.DB_PORT || 5432),
  database: env.DB_NAME,
  user: env.DB_USER,
  password: env.DB_PASSWORD,
  max: 8,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 8000,
  statement_timeout: 10000
});

const app = Fastify({
  logger: { level: env.LOG_LEVEL || 'info' },
  trustProxy: 1,
  bodyLimit: 16384,
  requestTimeout: 30000
});

const SESSION_COOKIE = 'arsy_session';
const SESSION_HOURS = 8;
const secureCookie = env.ARSY_COOKIE_SECURE === 'true';
const rateBuckets = new Map();
let updateCache = { checkedAt: 0, value: null };

function page(title, body, csrf = '') {
  const safeTitle = escapeHtml(title);
  const csrfMeta = csrf ? '<meta name="csrf-token" content="' + escapeHtml(csrf) + '">' : '';
  return '<!doctype html><html lang="id"><head><meta charset="utf-8">' +
    '<meta name="viewport" content="width=device-width, initial-scale=1">' +
    '<meta name="theme-color" content="#090d12">' + csrfMeta +
    '<title>' + safeTitle + ' · A-R-S-Y</title>' +
    '<link rel="icon" href="/assets/arsy-mark.svg" type="image/svg+xml">' +
    '<link rel="stylesheet" href="/assets/app.css">' +
    '<script src="/assets/app.js" defer></script></head><body>' +
    '<div class="ambient ambient-a"></div><div class="ambient ambient-b"></div>' +
    '<div class="app-shell">' +
    '<header class="topbar"><a class="brand" href="/"><img src="/assets/arsy-mark.svg" alt=""><span>A-R-S-Y</span></a>' +
    '<span class="topbar-note">OPEN INFRASTRUCTURE / CORE NODE</span></header>' +
    body +
    '<footer class="footer"><span>ONE COMMAND PLANE. OPEN BY DESIGN.</span><span>FOUNDATION / PRE-ALPHA</span></footer>' +
    '</div></body></html>';
}

function authPage(kind) {
  if (kind === 'setup') {
    return page('Initial superadmin setup',
      '<main class="auth-grid"><section class="auth-copy"><div class="eyebrow">FIRST BOOT / ONE-TIME SETUP</div>' +
      '<h1>Set the<br><em>first key.</em></h1><p class="lead">Buat akun Superadmin pertama untuk mengunci akses A-R-S-Y. Pendaftaran awal hanya tersedia sekali.</p>' +
      '<div class="note"><strong>Bootstrap key</strong><span>Ambil dari terminal VPS: <code>sudo grep ARSY_SETUP_TOKEN /opt/arsy/.env</code></span></div>' +
      '<div class="signal-line"><span></span> LOCAL NODE · PRIVATE SETUP</div></section>' +
      '<section class="panel auth-panel"><div class="panel-kicker">INITIALIZATION / 01</div><h2>Superadmin identity</h2>' +
      '<p class="muted">Akun ini menjadi pemilik awal control plane.</p>' +
      '<form data-api-form="/api/setup" class="stack-form">' +
      '<label>Bootstrap key<input name="setupToken" type="password" autocomplete="off" required minlength="32" placeholder="Paste one-time key"></label>' +
      '<label>Nama lengkap<input name="displayName" autocomplete="name" required minlength="2" maxlength="100" placeholder="Nama superadmin"></label>' +
      '<label>Email<input name="email" type="email" autocomplete="email" required maxlength="254" placeholder="admin@example.com"></label>' +
      '<label>Password<input name="password" type="password" autocomplete="new-password" required minlength="14" maxlength="128" placeholder="Minimal 14 karakter"></label>' +
      '<label>Ulangi password<input name="passwordConfirm" type="password" autocomplete="new-password" required minlength="14" maxlength="128" placeholder="Ulangi password"></label>' +
      '<div class="form-message" role="status" aria-live="polite"></div>' +
      '<button class="button button-primary" type="submit">Create superadmin <span>↗</span></button>' +
      '</form><div class="panel-foot">NO OPEN REGISTRATION · ONE-TIME ENROLLMENT</div></section></main>'
    );
  }

  return page('Superadmin login',
    '<main class="auth-grid"><section class="auth-copy"><div class="eyebrow">IDENTITY / ACCESS GATE</div>' +
    '<h1>Enter the<br><em>command plane.</em></h1><p class="lead">Satu kendali untuk mengelola layanan, node, kebijakan, dan operasi infrastruktur terbuka.</p>' +
    '<div class="signal-line"><span></span> AUTHENTICATED ACCESS ONLY</div></section>' +
    '<section class="panel auth-panel"><div class="panel-kicker">ARSY CORE / LOGIN</div><h2>Welcome back.</h2>' +
    '<p class="muted">Masuk menggunakan akun Superadmin.</p>' +
    '<form data-api-form="/api/login" class="stack-form">' +
    '<label>Email<input name="email" type="email" autocomplete="username" required maxlength="254" placeholder="admin@example.com"></label>' +
    '<label>Password<input name="password" type="password" autocomplete="current-password" required maxlength="128" placeholder="Password"></label>' +
    '<div class="form-message" role="status" aria-live="polite"></div>' +
    '<button class="button button-primary" type="submit">Sign in <span>↗</span></button>' +
    '</form><div class="panel-foot">SESSION PROTECTED · 8 HOUR EXPIRY</div></section></main>'
  );
}

function dashboardPage(user, csrf) {
  const safeName = escapeHtml(user.display_name);
  const safeEmail = escapeHtml(user.email);
  const initials = escapeHtml(user.display_name.split(/\s+/).slice(0, 2).map((part) => part[0] || '').join('').toUpperCase());
  const body =
    '<main class="dashboard">' +
    '<aside class="sidebar"><div class="side-label">COMMAND</div><a class="nav-item active" href="/dashboard"><span>◈</span> Overview</a>' +
    '<div class="side-label">INFRASTRUCTURE</div><div class="nav-item disabled"><span>⌘</span> Projects <small>soon</small></div>' +
    '<div class="nav-item disabled"><span>◎</span> Nodes <small>soon</small></div>' +
    '<div class="nav-item disabled"><span>⌁</span> Network <small>soon</small></div>' +
    '<div class="nav-item disabled"><span>▣</span> Storage <small>soon</small></div>' +
    '<div class="side-spacer"></div><div class="side-label">IDENTITY</div><div class="identity-mini"><span class="avatar">' + initials + '</span><span><strong>' + safeName + '</strong><small>SUPERADMIN</small></span></div>' +
    '</aside>' +
    '<section class="dashboard-main"><div class="dashboard-head"><div><div class="eyebrow">SYSTEM OVERVIEW / NODE 01</div><h1>Welcome, ' + safeName + '.</h1><p class="lead">A-R-S-Y Core Node is ready for its first configuration.</p></div>' +
    '<div class="profile"><span class="avatar">' + initials + '</span><span><strong>' + safeName + '</strong><small>' + safeEmail + '</small></span><form data-logout><button class="button button-quiet" type="submit">Sign out</button></form></div></div>' +
    '<div class="stats-grid"><article class="stat-card"><span class="stat-label">CONTROL PLANE</span><strong class="stat-value">ONLINE</strong><span class="stat-meta"><i class="live-dot"></i> Core web + database</span></article>' +
    '<article class="stat-card"><span class="stat-label">ACTIVE IDENTITY</span><strong class="stat-value">01</strong><span class="stat-meta">Superadmin account</span></article>' +
    '<article class="stat-card"><span class="stat-label">DEPLOYMENT MODE</span><strong class="stat-value">SINGLE VPS</strong><span class="stat-meta">Optional nodes later</span></article></div>' +
    '<div class="section-head"><div><div class="eyebrow">SERVICE MAP</div><h2>Infrastructure modules</h2></div><span class="pill pill-live">FOUNDATION</span></div>' +
    '<div class="service-grid">' +
    '<article class="service-card"><div class="service-icon">◈</div><div><h3>ARSY Core</h3><p>Identity, access, control API foundation.</p></div><span class="service-state live">ONLINE</span></article>' +
    '<article class="service-card"><div class="service-icon">⌁</div><div><h3>ARSY Name</h3><p>DNS zones and domain lifecycle.</p></div><span class="service-state planned">PLANNED</span></article>' +
    '<article class="service-card"><div class="service-icon">⟡</div><div><h3>ARSY Edge</h3><p>Routing, cache and edge delivery.</p></div><span class="service-state planned">PLANNED</span></article>' +
    '<article class="service-card"><div class="service-icon">⬡</div><div><h3>ARSY Shield</h3><p>WAF, access rules and protection.</p></div><span class="service-state planned">PLANNED</span></article>' +
    '<article class="service-card"><div class="service-icon">⤳</div><div><h3>ARSY Passage</h3><p>Secure tunnel and private origin.</p></div><span class="service-state planned">PLANNED</span></article>' +
    '<article class="service-card"><div class="service-icon">▤</div><div><h3>ARSY Vault</h3><p>Object storage and buckets.</p></div><span class="service-state planned">PLANNED</span></article></div>' +
    '<section class="update-card" id="update-card" hidden><div><div class="eyebrow">VERSION CONTROL</div><h2>Update available</h2><p id="update-copy">A newer A-R-S-Y version is ready. Nothing changes without your approval.</p><p class="command-line" id="update-command" hidden></p></div><div class="update-actions"><button id="update-now" class="button button-primary" type="button">Review update</button><button id="update-later" class="button button-quiet" type="button">Later</button><button id="copy-update" class="button button-quiet" type="button" hidden>Copy command</button></div></section>' +
    '<div class="bottom-grid"><article class="info-card"><div class="eyebrow">OPERATOR IDENTITY</div><h3>Superadmin protected</h3><p>' + safeEmail + '</p><span class="pill pill-live">PLATFORM OWNER</span></article>' +
    '<article class="info-card"><div class="eyebrow">NEXT STEP</div><h3>Configure your first services</h3><p>Core foundation is running. DNS, edge, tunnel, storage and compute will be enabled in later milestones.</p></article></div>' +
    '<p class="dashboard-version">A-R-S-Y FOUNDATION · ONE COMMAND PLANE. OPEN BY DESIGN.</p></section></main>';
  return page('Command center', body, csrf);
}


function onboardingPage(user, csrf, profile = {}) {
  const val = (key, fallback = '') => escapeHtml(profile[key] || fallback);
  const mode = profile.accessMode || 'private';
  return page('Installation onboarding',
    '<main class="wizard-wrap"><div class="eyebrow">FIRST RUN / INSTALLATION WIZARD</div>' +
    '<h1>Make this node<br><em>yours.</em></h1><p class="lead">Lengkapi identitas instalasi dan akses panel. Progress tersimpan dan bisa dilanjutkan kapan saja.</p>' +
    '<div class="wizard-steps"><span>01 Identity</span><span>02 Node</span><span>03 Network</span><span>04 Review</span></div>' +
    '<form id="onboarding-form" class="panel wizard-form">' +
    '<div class="wizard-section"><div class="panel-kicker">01 / WORKSPACE</div><h2>Who owns this installation?</h2>' +
    '<label>Workspace / organization<input name="workspaceName" required minlength="2" maxlength="100" value="' + val('workspaceName','My Workspace') + '"></label>' +
    '<label>Operational contact email<input name="contactEmail" type="email" maxlength="254" value="' + val('contactEmail', user.email) + '"></label>' +
    '<label>Installation name<input name="installationName" required minlength="2" maxlength="100" value="' + val('installationName','A-R-S-Y Primary') + '"></label>' +
    '<div class="form-grid"><label>Environment<select name="environment"><option value="personal">Personal</option><option value="lab">Lab</option><option value="staging">Staging</option><option value="production">Production</option></select></label>' +
    '<label>Timezone<input name="timezone" maxlength="64" value="' + val('timezone','Asia/Jakarta') + '"></label>' +
    '<label>Panel language<select name="language"><option value="id">Bahasa Indonesia</option><option value="en">English</option></select></label></div></div>' +
    '<div class="wizard-section"><div class="panel-kicker">02 / CORE NODE</div><h2>Identify this server.</h2>' +
    '<label>Node display name<input name="nodeName" required minlength="2" maxlength="100" value="' + val('nodeName','Core Node 01') + '"></label>' +
    '<p class="muted">OS, CPU, RAM, disk, Docker, dan hostname host akan ditampilkan dari pemeriksaan installer/doctor. Belum ada data host yang dikirim otomatis oleh browser.</p></div>' +
    '<div class="wizard-section"><div class="panel-kicker">03 / NETWORK & DOMAIN</div><h2>How will you access A-R-S-Y?</h2>' +
    '<label>Access mode<select name="accessMode" id="access-mode"><option value="private"' + (mode==='private'?' selected':'') + '>Private — SSH tunnel (recommended)</option><option value="public"' + (mode==='public'?' selected':'') + '>Public domain — A-R-S-Y managed gateway</option><option value="proxy"' + (mode==='proxy'?' selected':'') + '>Existing reverse proxy</option></select></label>' +
    '<div id="domain-fields"><label>Control panel hostname<input name="hostname" placeholder="panel.example.com" value="' + val('hostname') + '"></label>' +
    '<div class="form-grid"><label>VPS public IPv4 (A record target)<input name="targetIpv4" placeholder="203.0.113.10" value="' + val('targetIpv4') + '"></label>' +
    '<label>Existing proxy type<select name="proxyType"><option value="">Select if applicable</option><option>Nginx</option><option>Caddy</option><option>Traefik</option><option>Other</option></select></label></div>' +
    '<label class="check-label"><input type="checkbox" name="proxyTls" value="true"' + (profile.proxyTls?' checked':'') + '> Existing proxy already terminates valid HTTPS</label>' +
    '<p class="muted">Public mode requires DNS pointing to this VPS and inbound TCP 80/443. Existing-proxy mode keeps A-R-S-Y on loopback. No firewall, DNS, or proxy changes are made by saving this form.</p>' +
    '<button class="button button-quiet" id="dns-check" type="button">Check DNS records</button><div id="dns-result" class="form-message" role="status"></div></div></div>' +
    '<div class="wizard-section"><div class="panel-kicker">04 / REVIEW</div><h2>Save your installation profile.</h2>' +
    '<p class="muted">Saving records your choices only. Applying a public domain, opening ports, and requesting TLS will require a separate reviewed host operation. Private SSH access remains the recovery path.</p>' +
    '<div class="form-message" id="wizard-message" role="status"></div><button class="button button-primary" type="submit">Save & finish setup <span>↗</span></button></div>' +
    '</form></main>', csrf);
}

function cookieValue(header, name) {
  for (const part of String(header || '').split(';')) {
    const item = part.trim();
    const index = item.indexOf('=');
    if (index > 0 && item.slice(0, index) === name) {
      try { return decodeURIComponent(item.slice(index + 1)); } catch { return ''; }
    }
  }
  return '';
}

function setSessionCookie(reply, token) {
  const parts = [
    SESSION_COOKIE + '=' + encodeURIComponent(token),
    'Path=/',
    'HttpOnly',
    'SameSite=Strict',
    'Max-Age=' + (SESSION_HOURS * 60 * 60)
  ];
  if (secureCookie) parts.push('Secure');
  reply.header('Set-Cookie', parts.join('; '));
}

function clearSessionCookie(reply) {
  const parts = [SESSION_COOKIE + '=', 'Path=/', 'HttpOnly', 'SameSite=Strict', 'Max-Age=0'];
  if (secureCookie) parts.push('Secure');
  reply.header('Set-Cookie', parts.join('; '));
}

function sameOrigin(request) {
  const origin = request.headers.origin;
  if (!origin || !request.headers.host) return false;
  try {
    const parsed = new URL(origin);
    return parsed.host === request.headers.host && parsed.protocol === request.protocol + ':';
  } catch {
    return false;
  }
}

function allowRate(key, maximum, windowMs) {
  const now = Date.now();
  const current = rateBuckets.get(key);
  if (!current || current.resetAt <= now) {
    rateBuckets.set(key, { count: 1, resetAt: now + windowMs });
    return true;
  }
  current.count += 1;
  return current.count <= maximum;
}

setInterval(() => {
  const now = Date.now();
  for (const [key, value] of rateBuckets.entries()) {
    if (value.resetAt <= now) rateBuckets.delete(key);
  }
}, 60000).unref();

async function isSetupComplete() {
  const result = await pool.query("SELECT value FROM arsy_settings WHERE key = 'setup_completed'");
  return result.rows[0]?.value === 'true';
}

async function recordAudit(userId, eventType, request, metadata = {}) {
  await pool.query(
    'INSERT INTO arsy_audit_events (actor_user_id, event_type, source_ip, metadata) VALUES ($1, $2, $3, $4::jsonb)',
    [userId || null, eventType, request.ip || null, JSON.stringify(metadata)]
  );
}

async function createSession(userId) {
  const token = makeRandomToken(32);
  const csrfToken = makeRandomToken(32);
  const tokenHash = digestSessionToken(token, env.ARSY_SESSION_SECRET);
  await pool.query(
    'INSERT INTO arsy_sessions (token_hash, user_id, csrf_token, expires_at) VALUES ($1, $2, $3, NOW() + INTERVAL \'8 hours\')',
    [tokenHash, userId, csrfToken]
  );
  return { token, csrfToken };
}

async function getSession(request) {
  const token = cookieValue(request.headers.cookie, SESSION_COOKIE);
  if (!token || token.length > 128) return null;
  const tokenHash = digestSessionToken(token, env.ARSY_SESSION_SECRET);
  const result = await pool.query(
    'SELECT s.token_hash, s.csrf_token, u.id, u.display_name, u.email, u.role, u.status FROM arsy_sessions s JOIN arsy_users u ON u.id = s.user_id WHERE s.token_hash = $1 AND s.revoked_at IS NULL AND s.expires_at > NOW() AND u.status = \'active\' LIMIT 1',
    [tokenHash]
  );
  if (!result.rowCount) return null;
  const row = result.rows[0];
  return {
    tokenHash: row.token_hash,
    csrfToken: row.csrf_token,
    user: { id: row.id, display_name: row.display_name, email: row.email, role: row.role }
  };
}

async function requirePageAuth(request, reply) {
  const session = await getSession(request);
  if (!session) return reply.redirect('/login');
  request.arsySession = session;
}

async function requireApiAuth(request, reply) {
  const session = await getSession(request);
  if (!session) {
    return reply.code(401).send({ ok: false, error: 'Sesi berakhir. Silakan login kembali.' });
  }
  request.arsySession = session;
}

function requireCsrf(request, reply) {
  const supplied = request.headers['x-arsy-csrf'];
  if (!supplied || !constantTimeEqual(supplied, request.arsySession.csrfToken)) {
    reply.code(403).send({ ok: false, error: 'Permintaan tidak valid. Muat ulang halaman.' });
    return false;
  }
  return true;
}

async function currentVersion() {
  try {
    return (await readFile('/var/lib/arsy/deployed-sha', 'utf8')).trim();
  } catch {
    return 'unversioned';
  }
}

async function checkUpdate(force = false) {
  if (!force && updateCache.value && Date.now() - updateCache.checkedAt < 5 * 60 * 1000) {
    return updateCache.value;
  }

  const installedSha = await currentVersion();
  try {
    const response = await fetch('https://api.github.com/repos/bjo163/a-r-s-y/commits/main', {
      headers: { Accept: 'application/vnd.github+json', 'User-Agent': 'A-R-S-Y-Update-Check' },
      signal: AbortSignal.timeout(8000)
    });
    if (!response.ok) throw new Error('GitHub update check returned HTTP ' + response.status);
    const commit = await response.json();
    const availableSha = String(commit.sha || '').toLowerCase();
    const available = /^[0-9a-f]{40}$/.test(availableSha) && installedSha !== 'unversioned' && availableSha !== installedSha;
    const value = {
      ok: true,
      installedSha,
      availableSha,
      available,
      message: commit.commit?.message?.split('\n')[0] || 'New A-R-S-Y update',
      url: commit.html_url || 'https://github.com/bjo163/a-r-s-y/commits/main'
    };
    updateCache = { checkedAt: Date.now(), value };
    return value;
  } catch (error) {
    return { ok: false, installedSha, available: false, error: 'Update check is temporarily unavailable.' };
  }
}

app.addHook('onRequest', async (request, reply) => {
  reply.header('X-Content-Type-Options', 'nosniff');
  reply.header('X-Frame-Options', 'DENY');
  reply.header('Referrer-Policy', 'no-referrer');
  reply.header('Permissions-Policy', 'camera=(), microphone=(), geolocation=()');
  reply.header('Content-Security-Policy', "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; connect-src 'self'; object-src 'none'; base-uri 'none'; form-action 'self'; frame-ancestors 'none'");
  if (request.url.startsWith('/api/')) reply.header('Cache-Control', 'no-store');
  if (request.method === 'POST' && request.url.startsWith('/api/') && !sameOrigin(request)) {
    return reply.code(403).send({ ok: false, error: 'Origin tidak diizinkan.' });
  }
});

app.get('/assets/:asset', async (request, reply) => {
  const allowed = new Map([
    ['app.css', ['app.css', 'text/css; charset=utf-8']],
    ['app.js', ['app.js', 'text/javascript; charset=utf-8']],
    ['arsy-mark.svg', ['arsy-mark.svg', 'image/svg+xml']]
  ]);
  const item = allowed.get(request.params.asset);
  if (!item) return reply.code(404).send('Not found');
  try {
    const content = await readFile(join(publicDir, item[0]));
    reply.header('Cache-Control', 'public, max-age=300, must-revalidate');
    return reply.type(item[1]).send(content);
  } catch {
    return reply.code(404).send('Not found');
  }
});

app.get('/healthz', async (_request, reply) => {
  try {
    await pool.query('SELECT 1');
    return { status: 'ok', service: 'arsy-control-plane', database: 'ok' };
  } catch {
    return reply.code(503).send({ status: 'degraded', database: 'unavailable' });
  }
});

app.get('/', async (request, reply) => {
  if (!(await isSetupComplete())) return reply.redirect('/setup');
  const session = await getSession(request);
  return reply.redirect(session ? '/dashboard' : '/login');
});

app.get('/setup', async (_request, reply) => {
  if (await isSetupComplete()) return reply.redirect('/login');
  return reply.type('text/html; charset=utf-8').send(authPage('setup'));
});

app.get('/login', async (_request, reply) => {
  if (!(await isSetupComplete())) return reply.redirect('/setup');
  return reply.type('text/html; charset=utf-8').send(authPage('login'));
});

app.get('/dashboard', { preHandler: requirePageAuth }, async (request, reply) => {
  return reply.type('text/html; charset=utf-8').send(
    dashboardPage(request.arsySession.user, request.arsySession.csrfToken)
  );
});

app.post('/api/setup', async (request, reply) => {
  if (!allowRate('setup:' + request.ip, 5, 15 * 60 * 1000)) {
    return reply.code(429).send({ ok: false, error: 'Terlalu banyak percobaan. Coba lagi 15 menit.' });
  }
  if (await isSetupComplete()) return reply.code(409).send({ ok: false, error: 'Setup sudah selesai. Silakan login.' });

  const input = validateSetupInput(request.body);
  if (!input.ok) return reply.code(400).send({ ok: false, error: input.error });
  if (!constantTimeEqual(request.body?.setupToken, env.ARSY_SETUP_TOKEN)) {
    return reply.code(403).send({ ok: false, error: 'Bootstrap key tidak cocok.' });
  }

  const passwordHash = await hashPassword(input.password);
  const client = await pool.connect();
  let user;
  try {
    await client.query('BEGIN');
    const state = await client.query("SELECT value FROM arsy_settings WHERE key = 'setup_completed' FOR UPDATE");
    if (state.rows[0]?.value === 'true') {
      await client.query('ROLLBACK');
      return reply.code(409).send({ ok: false, error: 'Setup sudah diselesaikan oleh administrator lain.' });
    }
    const result = await client.query(
      "INSERT INTO arsy_users (display_name, email, password_hash, role) VALUES ($1, $2, $3, 'superadmin') RETURNING id, display_name, email, role",
      [input.displayName, input.email, passwordHash]
    );
    user = result.rows[0];
    await client.query("UPDATE arsy_settings SET value = 'true', updated_at = NOW() WHERE key = 'setup_completed'");
    await client.query(
      'INSERT INTO arsy_audit_events (actor_user_id, event_type, source_ip, metadata) VALUES ($1, $2, $3, $4::jsonb)',
      [user.id, 'superadmin.initialized', request.ip || null, JSON.stringify({ email: user.email })]
    );
    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK');
    if (error.code === '23505') return reply.code(409).send({ ok: false, error: 'Email atau akun Superadmin sudah digunakan.' });
    throw error;
  } finally {
    client.release();
  }

  const session = await createSession(user.id);
  setSessionCookie(reply, session.token);
  return reply.send({ ok: true, redirect: '/onboarding', message: 'Superadmin berhasil dibuat.' });
});


app.get('/onboarding', { preHandler: requirePageAuth }, async (request, reply) => {
  const result = await pool.query('SELECT profile FROM arsy_installation_profile WHERE id = 1');
  return reply.type('text/html; charset=utf-8').send(onboardingPage(request.arsySession.user, request.arsySession.csrfToken, result.rows[0]?.profile || {}));
});

app.get('/api/onboarding/profile', { preHandler: requireApiAuth }, async (_request, reply) => {
  const result = await pool.query('SELECT profile, onboarding_complete FROM arsy_installation_profile WHERE id = 1');
  return reply.send({ ok: true, profile: result.rows[0]?.profile || {}, complete: result.rows[0]?.onboarding_complete || false });
});

app.post('/api/onboarding/profile', { preHandler: requireApiAuth }, async (request, reply) => {
  if (!requireCsrf(request, reply)) return;
  const b = request.body || {};
  const clean = (v, max = 100) => String(v || '').trim().slice(0, max);
  const workspaceName = clean(b.workspaceName), installationName = clean(b.installationName), nodeName = clean(b.nodeName);
  const contactEmail = normalizeEmail(b.contactEmail);
  const environment = clean(b.environment, 20), timezone = clean(b.timezone, 64), language = clean(b.language, 2);
  const accessMode = clean(b.accessMode, 20), hostname = clean(b.hostname, 253).toLowerCase();
  const targetIpv4 = clean(b.targetIpv4, 45), proxyType = clean(b.proxyType, 20);
  if (workspaceName.length < 2 || installationName.length < 2 || nodeName.length < 2 || !contactEmail) {
    return reply.code(400).send({ ok: false, error: 'Workspace, installation, node, dan email kontak wajib valid.' });
  }
  if (!['personal','lab','staging','production'].includes(environment) || !['id','en'].includes(language) || !['private','public','proxy'].includes(accessMode)) {
    return reply.code(400).send({ ok: false, error: 'Pilihan konfigurasi tidak valid.' });
  }
  if (accessMode !== 'private' && (!/^(?=.{1,253}$)(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z]{2,63}$/.test(hostname))) {
    return reply.code(400).send({ ok: false, error: 'Masukkan hostname lengkap, contoh panel.example.com (tanpa https:// atau path).' });
  }
  if (targetIpv4 && !/^(?:(?:25[0-5]|2[0-4]\\d|1?\\d?\\d)\\.){3}(?:25[0-5]|2[0-4]\\d|1?\\d?\\d)$/.test(targetIpv4)) {
    return reply.code(400).send({ ok: false, error: 'Alamat IPv4 tidak valid.' });
  }
  const profile = { workspaceName, contactEmail, installationName, environment, timezone, language, nodeName, accessMode, hostname: accessMode==='private'?'':hostname, targetIpv4, proxyType, proxyTls: b.proxyTls === true || b.proxyTls === 'true' };
  await pool.query('UPDATE arsy_installation_profile SET profile=$1::jsonb, onboarding_complete=TRUE, updated_at=NOW() WHERE id=1', [JSON.stringify(profile)]);
  await recordAudit(request.arsySession.user.id, 'onboarding.completed', request, { accessMode, environment, hostname: profile.hostname || null });
  const nextStep = accessMode === 'public'
    ? 'Untuk menerapkan domain setelah DNS A record mengarah ke VPS, jalankan: sudo arsy-domain apply --hostname ' + hostname + (targetIpv4 ? ' --ipv4 ' + targetIpv4 : '')
    : accessMode === 'proxy'
      ? 'Konfigurasikan reverse proxy ke http://127.0.0.1:18080. Panduan: sudo arsy-domain proxy --hostname ' + hostname
      : 'Akses privat tetap aktif melalui SSH tunnel.';
  return reply.send({ ok: true, redirect: '/dashboard', message: 'Profil instalasi tersimpan.', nextStep });
});

app.post('/api/onboarding/dns-check', { preHandler: requireApiAuth }, async (request, reply) => {
  if (!requireCsrf(request, reply)) return;
  const hostname = String(request.body?.hostname || '').trim().toLowerCase();
  if (!/^(?=.{1,253}$)(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z]{2,63}$/.test(hostname)) {
    return reply.code(400).send({ ok: false, error: 'Hostname tidak valid.' });
  }
  let a = [], aaaa = [];
  try { a = await resolve4(hostname); } catch (error) { if (error.code !== 'ENODATA' && error.code !== 'ENOTFOUND') throw error; }
  try { aaaa = await resolve6(hostname); } catch (error) { if (error.code !== 'ENODATA' && error.code !== 'ENOTFOUND') throw error; }
  const expected = String(request.body?.targetIpv4 || '').trim();
  return reply.send({ ok: true, hostname, a, aaaa, expectedIpv4: expected || null, matches: expected ? a.includes(expected) : null, message: a.length || aaaa.length ? 'DNS record ditemukan.' : 'Belum ada A/AAAA record yang terlihat.' });
});

app.post('/api/login', async (request, reply) => {
  if (!allowRate('login:' + request.ip, 8, 15 * 60 * 1000)) {
    return reply.code(429).send({ ok: false, error: 'Terlalu banyak percobaan login. Coba lagi nanti.' });
  }
  if (!(await isSetupComplete())) return reply.code(409).send({ ok: false, error: 'Selesaikan setup Superadmin terlebih dahulu.' });

  const email = normalizeEmail(request.body?.email);
  const password = String(request.body?.password ?? '');
  if (!email || !password || password.length > 128) {
    return reply.code(400).send({ ok: false, error: 'Email dan password wajib diisi.' });
  }

  const result = await pool.query(
    "SELECT id, display_name, email, password_hash, role FROM arsy_users WHERE LOWER(email) = $1 AND status = 'active' LIMIT 1",
    [email]
  );
  const user = result.rows[0];
  if (!user || !(await verifyPassword(password, user.password_hash))) {
    await recordAudit(null, 'auth.login_failed', request, { email });
    return reply.code(401).send({ ok: false, error: 'Email atau password salah.' });
  }

  await pool.query('UPDATE arsy_users SET last_login_at = NOW() WHERE id = $1', [user.id]);
  await recordAudit(user.id, 'auth.login_success', request);
  const session = await createSession(user.id);
  setSessionCookie(reply, session.token);
  return reply.send({ ok: true, redirect: '/dashboard' });
});

app.post('/api/auth/logout', { preHandler: requireApiAuth }, async (request, reply) => {
  if (!requireCsrf(request, reply)) return;
  await pool.query('UPDATE arsy_sessions SET revoked_at = NOW() WHERE token_hash = $1', [request.arsySession.tokenHash]);
  await recordAudit(request.arsySession.user.id, 'auth.logout', request);
  clearSessionCookie(reply);
  return reply.send({ ok: true, redirect: '/login' });
});

app.get('/api/update/check', { preHandler: requireApiAuth }, async (_request, reply) => {
  return reply.send(await checkUpdate(true));
});

app.post('/api/update/approve', { preHandler: requireApiAuth }, async (request, reply) => {
  if (!requireCsrf(request, reply)) return;
  const update = await checkUpdate(true);
  if (!update.ok) return reply.code(503).send({ ok: false, error: update.error });
  if (!update.available) return reply.code(409).send({ ok: false, error: 'A-R-S-Y sudah menggunakan versi terbaru.' });
  await recordAudit(request.arsySession.user.id, 'update.approved', request, { targetSha: update.availableSha });
  return reply.send({
    ok: true,
    targetSha: update.availableSha,
    command: 'sudo arsy-update --yes ' + update.availableSha,
    message: 'Persetujuan dicatat untuk versi ini. Jalankan perintah yang ditampilkan di terminal VPS untuk menerapkannya.'
  });
});

app.setNotFoundHandler((_request, reply) => reply.code(404).type('text/plain').send('Not found'));
app.setErrorHandler((error, request, reply) => {
  request.log.error({ err: error }, 'Request failed');
  if (reply.sent) return;
  reply.code(500).send({ ok: false, error: 'Terjadi kesalahan internal. Periksa log A-R-S-Y.' });
});

async function start() {
  const schema = await readFile(schemaPath, 'utf8');
  let connected = false;
  for (let attempt = 1; attempt <= 30; attempt += 1) {
    try {
      await pool.query('SELECT 1');
      connected = true;
      break;
    } catch (error) {
      app.log.warn({ attempt, err: error.message }, 'Waiting for PostgreSQL');
      await new Promise((resolve) => setTimeout(resolve, 2000));
    }
  }
  if (!connected) throw new Error('PostgreSQL did not become ready in 60 seconds.');
  await pool.query(schema);
  await pool.query('DELETE FROM arsy_sessions WHERE expires_at < NOW() OR revoked_at IS NOT NULL');
  await app.listen({ host: '0.0.0.0', port: Number(env.PORT || 3000) });
  app.log.info('A-R-S-Y Control Plane is listening.');
}

async function shutdown(signal) {
  app.log.info({ signal }, 'Shutting down');
  await app.close();
  await pool.end();
  process.exit(0);
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

start().catch(async (error) => {
  app.log.error(error);
  await pool.end().catch(() => {});
  process.exit(1);
});
