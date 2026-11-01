'use strict';

const upstream = require('glob-modern');
const { braceExpand } = require('minimatch-modern');

function optionsFor(options) {
  if (options?.withFileTypes) {
    throw new TypeError('Use named glob/globSync for withFileTypes results');
  }
  return {
    windowsPathsNoEscape: process.platform === 'win32',
    ...options,
  };
}

function expandedPatterns(pattern, options) {
  return (Array.isArray(pattern) ? pattern : [pattern]).flatMap(value => {
    const normalized = options.windowsPathsNoEscape
      ? value.replace(/\\/g, '/')
      : value;
    return braceExpand(normalized, options);
  });
}

function finish(matches, options) {
  const strings = process.platform === 'win32'
    ? matches.map(value => value.replace(/\\/g, '/'))
    : matches;
  const result = options.nounique ? strings : [...new Set(strings)];
  return options.nosort ? result : result.sort((a, b) => a.localeCompare(b, 'en'));
}

function sync(pattern, options) {
  if (typeof options === 'function' || arguments.length > 2) {
    throw new TypeError('callback provided to sync glob');
  }
  const opts = optionsFor(options);
  const matches = opts.nonull
    ? expandedPatterns(pattern, opts).flatMap(value => {
      const found = upstream.globSync(value, opts);
      return found.length ? found : [value];
    })
    : upstream.globSync(pattern, opts);
  return finish(matches, opts);
}

function glob(pattern, options, callback) {
  if (typeof options === 'function') {
    callback = options;
    options = undefined;
  }
  if (callback !== undefined && typeof callback !== 'function') {
    throw new TypeError('glob callback must be a function');
  }
  const opts = optionsFor(options);
  if (opts.sync) {
    if (callback) throw new TypeError('callback provided to sync glob');
    return sync(pattern, opts);
  }
  const pending = opts.nonull
    ? Promise.all(expandedPatterns(pattern, opts).map(async value => {
      const found = await upstream.glob(value, opts);
      return found.length ? found : [value];
    })).then(matches => matches.flat())
    : upstream.glob(pattern, opts);
  const result = pending.then(matches => finish(matches, opts));
  if (callback) {
    result.then(matches => callback(null, matches), error => callback(error));
    // util.promisify() must see a callback function, not a returned Promise.
    return undefined;
  }
  return result;
}

module.exports = Object.assign(glob, upstream, { sync });
