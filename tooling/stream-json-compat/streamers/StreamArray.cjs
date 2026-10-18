'use strict';
module.exports = Object.assign(options => {
    const {streamArray} = require('stream-json-modern/streamers/stream-array.js');
    return streamArray.asStream(options);
  }, {
  streamArray: options => {
    const {streamArray} = require('stream-json-modern/streamers/stream-array.js');
    return streamArray.asStream(options);
  },
  withParser: options => {
    const {streamArray} = require('stream-json-modern/streamers/stream-array.js');
    return streamArray.withParserAsStream(options);
  },
});
