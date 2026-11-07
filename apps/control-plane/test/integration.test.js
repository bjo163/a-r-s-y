import test from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { createServer } from 'node:net';
import { mkdtemp, writeFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { setTimeout as delay } from 'node:timers/promises';
import pg from 'pg';
import { digestSessionToken } from '../src/security.js';

const enabled = process.env.ARSY_INTEGRATION === '1';
const here = dirname(fileURLToPath(import.meta.url));
const appDir = join(here, '..');

async function freePort() {
  const server = createServer();
  await new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(0, '127.0.0.1', resolve);
  });
  const port = server.address().port;
  await new Promise((resolve) => server.close(resolve));
  return port;
}

function cookieHeader(response) {
  const values = response.headers.getSetCookie?.() || [response.headers.get('set-cookie') || ''];
  const value = values.find((item) => item.startsWith('arsy_session='));
  assert.ok(value, 'response should set the arsy_session cookie');
  return value.split(';', 1)[0];
}

function tokenFromCookie(cookie) {
  return decodeURIComponent(cookie.slice('arsy_session='.length));
}

function csrfFromHtml(html) {
  const match = html.match(/<meta name="csrf-token" content="([^"]+)"/);
  assert.ok(match, 'authenticated page should contain a CSRF token');
  return match[1];
}

test('disposable PostgreSQL API lifecycle and security integration', { skip: !enabled }, async (t) => {
  assert.equal(process.env.DB_NAME || 'arsy_test', 'arsy_test',
    'integration tests refuse to run against a non-disposable database');
  const work = await mkdtemp(join(tmpdir(), 'arsy-integration-'));
  const port = await freePort();
  const base = 'http://127.0.0.1:' + port;
  const oldSha = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const newSha = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  const deployedShaFile = join(work, 'deployed-sha');
  const domainStateFile = join(work, 'domain-state');
  await writeFile(deployedShaFile, oldSha + '\n', { mode: 0o600 });

  const db = new pg.Pool({
    host: process.env.DB_HOST || '127.0.0.1',
    port: Number(process.env.DB_PORT || 5432),
    database: 'arsy_test',
    user: process.env.DB_USER || 'arsy_test',
    password: process.env.DB_PASSWORD || 'arsy_test_password'
  });

  let child;
  let childOutput = '';
  try {
    await db.query('SELECT 1');
    await db.query('DROP TABLE IF EXISTS arsy_installation_profile, arsy_audit_events, arsy_sessions, arsy_users, arsy_settings CASCADE');

    child = spawn(process.execPath, ['src/server.js'], {
      cwd: appDir,
      env: {
        ...process.env,
        NODE_ENV: 'test',
        PORT: String(port),
        DB_HOST: process.env.DB_HOST || '127.0.0.1',
        DB_PORT: process.env.DB_PORT || '5432',
        DB_NAME: 'arsy_test',
        DB_USER: process.env.DB_USER || 'arsy_test',
        DB_PASSWORD: process.env.DB_PASSWORD || 'arsy_test_password',
        ARSY_SETUP_TOKEN: 'integration-bootstrap-token-0123456789',
        ARSY_SESSION_SECRET: 'integration-session-secret-that-is-long-enough',
        ARSY_COOKIE_SECURE: 'false',
        ARSY_DEPLOYED_SHA_FILE: deployedShaFile,
        ARSY_DOMAIN_STATE_FILE: domainStateFile,
        ARSY_TEST_UPDATE_SHA: newSha,
        ARSY_TEST_UPDATE_MESSAGE: 'integration-approved exact sha',
        NODE_OPTIONS: '--require=' + join(here, 'mock-update.cjs')
      },
      stdio: ['ignore', 'pipe', 'pipe']
    });
    child.stdout.on('data', (chunk) => { childOutput = (childOutput + chunk.toString()).slice(-12000); });
    child.stderr.on('data', (chunk) => { childOutput = (childOutput + chunk.toString()).slice(-12000); });

    const request = async (path, options = {}) => {
      const method = options.method || 'GET';
      const headers = { ...(options.headers || {}) };
      if (options.cookie) headers.Cookie = options.cookie;
      if (options.csrf) headers['X-ARSY-CSRF'] = options.csrf;
      if (method !== 'GET') headers.Origin = options.origin || base;
      if (options.body !== undefined) headers['Content-Type'] = 'application/json';
      return fetch(base + path, {
        method,
        headers,
        body: options.body === undefined ? undefined : JSON.stringify(options.body),
        signal: AbortSignal.timeout(5000)
      });
    };

    let healthy = false;
    for (let attempt = 0; attempt < 100; attempt += 1) {
      if (child.exitCode !== null) throw new Error('Control plane exited before ready.\n' + childOutput);
      try {
        const response = await fetch(base + '/healthz', { signal: AbortSignal.timeout(1000) });
        if (response.ok) { healthy = true; break; }
      } catch {}
      await delay(250);
    }
    assert.equal(healthy, true, 'control plane should become healthy.\n' + childOutput);

    await t.test('health and one-time Superadmin setup', async () => {
      const health = await request('/healthz');
      assert.equal(health.status, 200);
      assert.deepEqual(await health.json(), {
        status: 'ok',
        service: 'arsy-control-plane',
        database: 'ok'
      });

      const setup = await request('/api/setup', {
        method: 'POST',
        body: {
          setupToken: 'integration-bootstrap-token-0123456789',
          displayName: 'Integration Owner',
          email: 'OWNER@EXAMPLE.COM',
          password: 'correct horse battery staple 2026',
          passwordConfirm: 'correct horse battery staple 2026'
        }
      });
      assert.equal(setup.status, 200);
      const setCookie = setup.headers.get('set-cookie') || '';
      assert.match(setCookie, /HttpOnly/);
      assert.match(setCookie, /SameSite=Strict/);
      assert.doesNotMatch(setCookie, /Secure/);
      const setupCookie = cookieHeader(setup);
      assert.match(setupCookie, /^arsy_session=/);

      const repeated = await request('/api/setup', {
        method: 'POST',
        body: {
          setupToken: 'integration-bootstrap-token-0123456789',
          displayName: 'Second Owner',
          email: 'second@example.com',
          password: 'correct horse battery staple 2026',
          passwordConfirm: 'correct horse battery staple 2026'
        }
      });
      assert.equal(repeated.status, 409);
    });

    const login = await request('/api/login', {
      method: 'POST',
      body: { email: 'owner@example.com', password: 'correct horse battery staple 2026' }
    });
    assert.equal(login.status, 200);
    const sessionCookie = cookieHeader(login);
    const onboarding = await request('/onboarding', { cookie: sessionCookie });
    assert.equal(onboarding.status, 200);
    const csrf = csrfFromHtml(await onboarding.text());

    await t.test('CSRF, Origin and timezone validation', async () => {
      const missingCsrf = await request('/api/onboarding/profile', {
        method: 'POST',
        cookie: sessionCookie,
        body: {}
      });
      assert.equal(missingCsrf.status, 403);

      const wrongOrigin = await request('/api/onboarding/profile', {
        method: 'POST',
        cookie: sessionCookie,
        csrf,
        origin: 'https://attacker.invalid',
        body: {}
      });
      assert.equal(wrongOrigin.status, 403);

      const invalidIpv4 = await request('/api/onboarding/dns-check', {
        method: 'POST',
        cookie: sessionCookie,
        csrf,
        body: { hostname: 'panel.example.com', targetIpv4: '999.1.1.1' }
      });
      assert.equal(invalidIpv4.status, 400);

      const invalidTimezone = await request('/api/onboarding/profile', {
        method: 'POST',
        cookie: sessionCookie,
        csrf,
        body: {
          workspaceName: 'Test Workspace',
          contactEmail: 'owner@example.com',
          installationName: 'Test Installation',
          environment: 'personal',
          timezone: 'Invalid/Timezone',
          language: 'id',
          nodeName: 'Core Test',
          accessMode: 'private'
        }
      });
      assert.equal(invalidTimezone.status, 400);
    });

    await t.test('onboarding persistence, DNS diagnostic and operator status', async () => {
      const dns = await request('/api/onboarding/dns-check', {
        method: 'POST',
        cookie: sessionCookie,
        csrf,
        body: { hostname: 'no-such-name.arsy.invalid', targetIpv4: '203.0.113.10' }
      });
      assert.equal(dns.status, 200);
      const dnsPayload = await dns.json();
      assert.deepEqual(dnsPayload.a, []);
      assert.deepEqual(dnsPayload.aaaa, []);
      assert.equal(dnsPayload.matches, false);
      assert.ok(dnsPayload.checkedAt);

      const saved = await request('/api/onboarding/profile', {
        method: 'POST',
        cookie: sessionCookie,
        csrf,
        body: {
          workspaceName: 'Test Workspace',
          contactEmail: 'owner@example.com',
          installationName: 'Test Installation',
          environment: 'personal',
          timezone: 'Asia/Jakarta',
          language: 'id',
          nodeName: 'Core Test',
          accessMode: 'public',
          hostname: 'no-such-name.arsy.invalid',
          targetIpv4: '203.0.113.10',
          proxyType: '',
          proxyTls: false
        }
      });
      assert.equal(saved.status, 200);
      assert.equal((await saved.json()).ok, true);

      const profile = await request('/api/onboarding/profile', { cookie: sessionCookie });
      const profilePayload = await profile.json();
      assert.equal(profilePayload.complete, true);
      assert.equal(profilePayload.profile.timezone, 'Asia/Jakarta');
      assert.equal(profilePayload.profile.dnsCheck.hostname, 'no-such-name.arsy.invalid');

      const dashboard = await request('/dashboard', { cookie: sessionCookie });
      assert.equal(dashboard.status, 200);
      const html = await dashboard.text();
      assert.match(html, /data-timezone="Asia\/Jakarta"/);
      assert.match(html, /DNS diagnostic/);
      assert.match(html, /Needs operator activation/);
      assert.match(html, /Domain activation/);
      assert.match(html, /Control plane health/);
    });

    await t.test('login rejects invalid credentials', async () => {
      const bad = await request('/api/login', {
        method: 'POST',
        body: { email: 'owner@example.com', password: 'incorrect password' }
      });
      assert.equal(bad.status, 401);
    });

    await t.test('update approval is bound to exact SHA', async () => {
      const check = await request('/api/update/check', { cookie: sessionCookie });
      assert.equal(check.status, 200);
      const checkPayload = await check.json();
      assert.equal(checkPayload.available, true);
      assert.equal(checkPayload.installedSha, oldSha);
      assert.equal(checkPayload.availableSha, newSha);

      const approved = await request('/api/update/approve', {
        method: 'POST',
        cookie: sessionCookie,
        csrf,
        body: {}
      });
      assert.equal(approved.status, 200);
      const payload = await approved.json();
      assert.equal(payload.targetSha, newSha);
      assert.ok(payload.command.includes(newSha));
      const audit = await db.query(
        "SELECT metadata->>'targetSha' AS target_sha FROM arsy_audit_events WHERE event_type='update.approved' ORDER BY id DESC LIMIT 1"
      );
      assert.equal(audit.rows[0]?.target_sha, newSha);
    });

    await t.test('logout revokes session and expired sessions are rejected', async () => {
      const loggedOut = await request('/api/auth/logout', {
        method: 'POST',
        cookie: sessionCookie,
        csrf,
        body: {}
      });
      assert.equal(loggedOut.status, 200);
      const rejected = await request('/api/onboarding/profile', { cookie: sessionCookie });
      assert.equal(rejected.status, 401);

      const secondLogin = await request('/api/login', {
        method: 'POST',
        body: { email: 'owner@example.com', password: 'correct horse battery staple 2026' }
      });
      assert.equal(secondLogin.status, 200);
      const expiringCookie = cookieHeader(secondLogin);
      const token = tokenFromCookie(expiringCookie);
      const tokenHash = digestSessionToken(token, 'integration-session-secret-that-is-long-enough');
      await db.query(
        "UPDATE arsy_sessions SET expires_at = NOW() - INTERVAL '1 minute' WHERE token_hash = $1",
        [tokenHash]
      );
      const expired = await request('/api/onboarding/profile', { cookie: expiringCookie });
      assert.equal(expired.status, 401);
    });
  } finally {
    if (child && child.exitCode === null) {
      child.kill('SIGTERM');
      await Promise.race([
        new Promise((resolve) => child.once('exit', resolve)),
        delay(5000)
      ]);
    }
    await db.query('DROP TABLE IF EXISTS arsy_installation_profile, arsy_audit_events, arsy_sessions, arsy_users, arsy_settings CASCADE').catch(() => {});
    await db.end();
    await rm(work, { recursive: true, force: true });
  }
});
