'use strict';

const upstream = require('minimatch-modern');

function legacyMatch(file, pattern, options = {}) {
  options = options || {};
  const nativeOptions = {...options, windowsPathsNoEscape: false};
  delete nativeOptions.allowWindowsEscape;
  if (typeof pattern === 'string') {
    pattern = pattern.trim();
    if (process.platform === 'win32' && !options.allowWindowsEscape) {
      pattern = pattern.replace(/\\/g, '/');
    }
  }
  if (process.platform === 'win32' && typeof file === 'string') {
    file = file.replace(/\\/g, '/');
  }
  return upstream.minimatch(file, pattern, nativeOptions);
}

module.exports = Object.assign(legacyMatch, upstream);
