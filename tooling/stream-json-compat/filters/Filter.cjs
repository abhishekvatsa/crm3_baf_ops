'use strict';
module.exports = Object.assign(options => {
    const {filter} = require('stream-json-modern/filters/filter.js');
    return filter.asStream(options);
  }, {
  filter: options => {
    const {filter} = require('stream-json-modern/filters/filter.js');
    return filter.asStream(options);
  },
  withParser: options => {
    const {filter} = require('stream-json-modern/filters/filter.js');
    return filter.withParserAsStream(options);
  },
});
