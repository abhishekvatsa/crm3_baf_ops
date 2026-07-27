'use strict';

const upstream = require('brace-expansion-modern');

if (typeof upstream.expand !== 'function') {
  throw new TypeError('Patched brace-expansion does not expose expand().');
}

module.exports = Object.assign(upstream.expand, upstream);
