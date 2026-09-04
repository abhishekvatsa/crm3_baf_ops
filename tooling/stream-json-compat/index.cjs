'use strict';
const {parser} = require('stream-json-modern');
module.exports = Object.assign(options => parser.asStream(options), {
  parser: options => parser.asStream(options),
});
