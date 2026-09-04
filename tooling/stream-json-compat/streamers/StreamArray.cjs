'use strict';
const {streamArray} = require('stream-json-modern/streamers/stream-array.js');
module.exports = Object.assign(options => streamArray.asStream(options), {
  streamArray: options => streamArray.asStream(options),
  withParser: options => streamArray.withParserAsStream(options),
});
