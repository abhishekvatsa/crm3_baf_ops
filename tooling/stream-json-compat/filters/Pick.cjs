'use strict';
module.exports = Object.assign(options => {
    const {pick} = require('stream-json-modern/filters/pick.js');
    return pick.asStream(options);
  }, {
  pick: options => {
    const {pick} = require('stream-json-modern/filters/pick.js');
    return pick.asStream(options);
  },
  withParser: options => {
    const {pick} = require('stream-json-modern/filters/pick.js');
    return pick.withParserAsStream(options);
  },
});
