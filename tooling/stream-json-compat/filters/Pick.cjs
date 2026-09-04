'use strict';
const {pick} = require('stream-json-modern/filters/pick.js');
module.exports = Object.assign(options => pick.asStream(options), {
  pick: options => pick.asStream(options),
  withParser: options => pick.withParserAsStream(options),
});
