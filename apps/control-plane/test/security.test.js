import test from 'node:test';
import assert from 'node:assert/strict';
import {
  constantTimeEqual,
  digestSessionToken,
  escapeHtml,
  hashPassword,
  normalizeEmail,
  validateSetupInput,
  verifyPassword
} from '../src/security.js';

test('password hashes are salted and verify correctly', async () => {
  const first = await hashPassword('correct horse battery staple 2026');
  const second = await hashPassword('correct horse battery staple 2026');
  assert.notEqual(first, second);
  assert.equal(await verifyPassword('correct horse battery staple 2026', first), true);
  assert.equal(await verifyPassword('wrong password', first), false);
});

test('constant time comparison handles equal and unequal values', () => {
  assert.equal(constantTimeEqual('secret', 'secret'), true);
  assert.equal(constantTimeEqual('secret', 'not-secret'), false);
});

test('session token digest is stable and keyed', () => {
  assert.equal(digestSessionToken('token', 'secret'), digestSessionToken('token', 'secret'));
  assert.notEqual(digestSessionToken('token', 'secret'), digestSessionToken('token', 'other'));
});

test('setup input validates name, email and password', () => {
  const valid = validateSetupInput({
    displayName: 'A-R-S-Y Owner',
    email: 'ADMIN@example.com',
    password: 'correct horse battery staple 2026',
    passwordConfirm: 'correct horse battery staple 2026'
  });
  assert.equal(valid.ok, true);
  assert.equal(valid.email, 'admin@example.com');
  assert.equal(validateSetupInput({ email: 'bad', password: 'short' }).ok, false);
});

test('HTML escaping and email normalization are safe', () => {
  assert.equal(escapeHtml('<script>"&'), '&lt;script&gt;&quot;&amp;');
  assert.equal(normalizeEmail(' Admin@Example.com '), 'admin@example.com');
});
