'use strict';
module.exports = Object.assign(options => {
    const {parser} = require('stream-json-modern');
    return parser.asStream(options);
  }, {
  parser: options => {
    const {parser} = require('stream-json-modern');
    return parser.asStream(options);
  },
});
