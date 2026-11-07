import { createHash, createHmac, randomBytes, scrypt as scryptCallback, timingSafeEqual } from 'node:crypto';
import { promisify } from 'node:util';

const scrypt = promisify(scryptCallback);
const SCRYPT_N = 32768;
const SCRYPT_R = 8;
const SCRYPT_P = 1;
const SCRYPT_KEY_BYTES = 64;
const SCRYPT_MAXMEM = 96 * 1024 * 1024;

export function constantTimeEqual(left, right) {
  const a = createHash('sha256').update(String(left ?? '')).digest();
  const b = createHash('sha256').update(String(right ?? '')).digest();
  return timingSafeEqual(a, b);
}

export function digestSessionToken(token, secret) {
  return createHmac('sha256', secret).update(token).digest('hex');
}

export async function hashPassword(password) {
  const salt = randomBytes(16);
  const derived = await scrypt(password, salt, SCRYPT_KEY_BYTES, {
    N: SCRYPT_N,
    r: SCRYPT_R,
    p: SCRYPT_P,
    maxmem: SCRYPT_MAXMEM
  });
  return 'scrypt$' + SCRYPT_N + '$' + SCRYPT_R + '$' + SCRYPT_P + '$' +
    salt.toString('hex') + '$' + Buffer.from(derived).toString('hex');
}

export async function verifyPassword(password, encoded) {
  try {
    const parts = String(encoded).split('$');
    if (parts.length !== 6 || parts[0] !== 'scrypt') return false;

    const n = Number(parts[1]);
    const r = Number(parts[2]);
    const p = Number(parts[3]);
    const salt = Buffer.from(parts[4], 'hex');
    const expected = Buffer.from(parts[5], 'hex');

    if (!Number.isInteger(n) || n < 16384 || n > 131072) return false;
    if (!Number.isInteger(r) || r < 8 || r > 16) return false;
    if (!Number.isInteger(p) || p < 1 || p > 4) return false;
    if (salt.length !== 16 || expected.length !== SCRYPT_KEY_BYTES) return false;

    const derived = await scrypt(password, salt, expected.length, {
      N: n,
      r,
      p,
      maxmem: SCRYPT_MAXMEM
    });
    return timingSafeEqual(Buffer.from(derived), expected);
  } catch {
    return false;
  }
}

export function normalizeEmail(value) {
  return String(value ?? '').trim().toLowerCase();
}

export function validateSetupInput(input) {
  const displayName = String(input?.displayName ?? '').trim();
  const email = normalizeEmail(input?.email);
  const password = String(input?.password ?? '');
  const passwordConfirm = String(input?.passwordConfirm ?? '');

  if (displayName.length < 2 || displayName.length > 100) {
    return { ok: false, error: 'Nama harus terdiri dari 2 sampai 100 karakter.' };
  }
  if (email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return { ok: false, error: 'Alamat email tidak valid.' };
  }
  if (password.length < 14 || password.length > 128) {
    return { ok: false, error: 'Password wajib 14–128 karakter.' };
  }
  if (password !== passwordConfirm) {
    return { ok: false, error: 'Konfirmasi password tidak cocok.' };
  }
  return { ok: true, displayName, email, password };
}

export function makeRandomToken(bytes = 32) {
  return randomBytes(bytes).toString('base64url');
}

export function escapeHtml(value) {
  return String(value ?? '').replace(/[&<>"']/g, (char) => ({
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#39;'
  })[char]);
}
