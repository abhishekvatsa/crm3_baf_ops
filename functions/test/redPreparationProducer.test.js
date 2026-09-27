'use strict';

const {produceRedPreparationEvidence} = require('./helpers/produceRedPreparationEvidence.cjs');
const expected = require('../../test/fixtures/red_preparation_dispatcher_records.json');

test('Dart RED preparation fixture remains exact actual dispatcher output', async () => {
  expect(await produceRedPreparationEvidence()).toEqual(expected);
});
