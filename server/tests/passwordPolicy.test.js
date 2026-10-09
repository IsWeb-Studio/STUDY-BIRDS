const test = require('node:test');
const assert = require('node:assert/strict');
const { passwordError } = require('../src/utils/passwordPolicy');

test('new passwords must meet length and diversity requirements and avoid common words', () => {
  for (const password of ['', 'short1!', 'abcdefgh', 'Password123!', 'Qwerty123!', 'AaAaAaAa', 'longlowercase123', 'كلمةالمرور١٢٣', 'é'.repeat(40) + 'Az9!']) {
    assert.equal(typeof passwordError(password), 'string', password);
  }
  for (const password of ['BirdFlight9', 'Birds@Sky2', 'رحلتي_التعليمية١٢٣', 'Café_Route9', 'Z9! a long phrase']) {
    assert.equal(passwordError(password), null, password);
  }
});
