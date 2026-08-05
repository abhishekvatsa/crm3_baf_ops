const {
  readFieldDefinitionPayload,
  readFieldResponsePayload,
} = require('../lib/persistedWorkPayload');

describe('persisted work payloads', () => {
  test('accepts canonical and historical field-definition aliases', () => {
    const raw = JSON.stringify([
      {
        fieldId: 'pressure',
        label: 'Pressure',
        type: 'numericWithUnit',
        required: true,
        options: ['bar'],
        futureExtension: {retained: true},
      },
    ]);

    const parsed = readFieldDefinitionPayload(raw, {
      field: 'fieldDefinitionsJson',
    });

    expect(parsed.text).toBe(raw);
    expect(parsed.rows[0].futureExtension).toEqual({retained: true});
  });

  test('accepts canonical and historical response aliases', () => {
    const raw = JSON.stringify([
      {
        fieldId: 'pressure',
        label: 'Pressure',
        type: 'numericWithUnit',
        answer: 2.1,
        futureExtension: ['retained'],
      },
    ]);

    const parsed = readFieldResponsePayload(raw, {field: 'responsesJson'});

    expect(parsed.text).toBe(raw);
    expect(parsed.rows[0].futureExtension).toEqual(['retained']);
  });

  test.each([
    ['malformed JSON', '{bad'],
    ['wrong root', '{}'],
    ['non-object row', '["field"]'],
    ['missing key', '[{"label":"Pressure"}]'],
    ['wrong required flag', '[{"key":"pressure","required":"yes"}]'],
    ['conflicting required flags', '[{"key":"pressure","required":true,"isRequired":false}]'],
    ['unknown type', '[{"key":"pressure","type":"telepathy"}]'],
    ['wrong options', '[{"key":"pressure","options":[2]}]'],
    ['duplicate key', '[{"key":"pressure"},{"fieldId":"PRESSURE"}]'],
  ])('rejects field definitions with %s', (_label, raw) => {
    expect(() => readFieldDefinitionPayload(raw, {
      field: 'fieldDefinitionsJson',
    })).toThrow(/Invalid persisted work field/);
  });

  test.each([
    ['malformed JSON', '{bad'],
    ['wrong root', '{}'],
    ['non-object row', '["response"]'],
    ['missing key', '[{"value":"ok"}]'],
    ['missing value', '[{"key":"pressure"}]'],
    ['unknown type', '[{"key":"pressure","value":2.1,"fieldType":"telepathy"}]'],
    ['duplicate key', '[{"key":"pressure","value":1},{"fieldId":"PRESSURE","answer":2}]'],
  ])('rejects responses with %s', (_label, raw) => {
    expect(() => readFieldResponsePayload(raw, {field: 'responsesJson'}))
      .toThrow(/Invalid persisted work field/);
  });

  test('only an entirely missing legacy payload may initialize empty', () => {
    expect(readFieldDefinitionPayload(null, {
      field: 'fieldDefinitionsJson',
      allowMissing: true,
    }).rows).toEqual([]);
    expect(readFieldResponsePayload(null, {
      field: 'responsesJson',
      allowMissing: true,
    }).rows).toEqual([]);

    expect(() => readFieldDefinitionPayload('', {
      field: 'fieldDefinitionsJson',
      allowMissing: true,
    })).toThrow();
    expect(() => readFieldResponsePayload('', {
      field: 'responsesJson',
      allowMissing: true,
    })).toThrow();
  });
});
