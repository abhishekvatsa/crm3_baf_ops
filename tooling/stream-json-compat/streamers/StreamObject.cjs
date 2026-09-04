'use strict';
const {streamObject} = require('stream-json-modern/streamers/stream-object.js');
module.exports = Object.assign(options => streamObject.asStream(options), {
  streamObject: options => streamObject.asStream(options),
  withParser: options => streamObject.withParserAsStream(options),
});
