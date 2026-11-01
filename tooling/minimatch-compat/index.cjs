'use strict';

const upstream = require('minimatch-modern');

if (typeof upstream.minimatch !== 'function') {
  throw new TypeError('Patched minimatch does not expose minimatch().');
}

module.exports = Object.assign(upstream.minimatch, upstream);
