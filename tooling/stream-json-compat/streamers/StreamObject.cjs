'use strict';
module.exports = Object.assign(options => {
    const {streamObject} = require('stream-json-modern/streamers/stream-object.js');
    return streamObject.asStream(options);
  }, {
  streamObject: options => {
    const {streamObject} = require('stream-json-modern/streamers/stream-object.js');
    return streamObject.asStream(options);
  },
  withParser: options => {
    const {streamObject} = require('stream-json-modern/streamers/stream-object.js');
    return streamObject.withParserAsStream(options);
  },
});
