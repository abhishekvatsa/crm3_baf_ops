'use strict';
const {filter} = require('stream-json-modern/filters/filter.js');
module.exports = Object.assign(options => filter.asStream(options), {
  filter: options => filter.asStream(options),
  withParser: options => filter.withParserAsStream(options),
});
