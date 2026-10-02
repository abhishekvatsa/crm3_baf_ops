"""Scoped generated-schema regressions against the actual lexical audit."""
from pathlib import Path
import unittest

from dart_structural_audit import duplicate_ids, strip_strings_and_comments


GENERATED = Path('synthetic.g.dart')


def schema(name, properties, indexes='', *, gap=''):
    return f'''const {name}Schema = CollectionSchema(
  name: r'{name}',
  id: 123,
  properties: {{
{properties}
  }},
{gap}  estimateSize: _estimateSize,
  serialize: _serialize,
  indexes: {{
{indexes}
  }},
  links: {{}},
);
'''


def prop(name, ident):
    return f"    r'{name}': PropertySchema(id: {ident}, name: r'{name}'),"


def index(name, ident):
    return f"    r'{name}': IndexSchema(id: {ident}, name: r'{name}'),"


class GeneratedSchemaScopeTest(unittest.TestCase):
    def test_blank_line_does_not_combine_property_scopes(self):
        text = schema('First', prop('a', 0), gap='\n')
        text += schema('Second', prop('b', 0))
        self.assertEqual(duplicate_ids(GENERATED, text), [])

    def test_duplicate_only_in_second_schema_is_reported(self):
        text = schema('First', prop('a', 0))
        text += schema('Second', prop('b', 0) + '\n' + prop('c', 0))
        self.assertEqual(duplicate_ids(GENERATED, text),
                         ['SecondSchema: duplicate property ids [0]'])

    def test_all_later_schemas_are_checked(self):
        text = schema('First', prop('a', 0))
        text += schema('Second', prop('a', 1) + prop('b', 1))
        text += schema('Third', prop('a', 2) + prop('b', 2))
        self.assertEqual(duplicate_ids(GENERATED, text), [
            'SecondSchema: duplicate property ids [1]',
            'ThirdSchema: duplicate property ids [2]',
        ])

    def test_index_ids_are_scoped_to_each_indexes_map(self):
        text = schema('First', prop('a', 0), index('a', -7))
        text = text.replace('  },\n  links:', '  },\n\n  links:')
        text += schema('Second', prop('b', 0), index('b', -7))
        self.assertEqual(duplicate_ids(GENERATED, text), [])

    def test_duplicate_index_only_in_second_schema_is_reported(self):
        text = schema('First', prop('a', 0), index('a', -7))
        text += schema('Second', prop('b', 0), index('b', -7) + index('c', -7))
        self.assertEqual(duplicate_ids(GENERATED, text),
                         ['SecondSchema: duplicate index ids [-7]'])

    def test_property_and_index_ids_have_separate_scopes(self):
        self.assertEqual(duplicate_ids(
            GENERATED, schema('First', prop('a', 0), index('a', 0))), [])

    def test_string_and_comment_decoys_are_ignored(self):
        decoys = '''// CollectionSchema(properties: {PropertySchema(id: 0)})
/* CollectionSchema( /* nested */ properties: {PropertySchema(id: 0)}) */
const decoy = r''' + "'''CollectionSchema(properties: {PropertySchema(id: 0)})'''" + ''';
'''
        properties = prop('a', 0) + '''
    // PropertySchema(id: 0),
    /* PropertySchema(id: 0) */
'''
        self.assertEqual(duplicate_ids(GENERATED, decoys + schema('First', properties)), [])

    def test_nested_values_and_quoted_delimiters_do_not_end_maps(self):
        properties = """r'a': PropertySchema(
      name: r'}) properties: { PropertySchema(id: 0)',
      enumMap: {'x': {'nested': [0, 1]}, 'y': 2},
      id: 0,
    ),
    r'b': PropertySchema(name: r'b', id: 0),"""
        self.assertEqual(duplicate_ids(GENERATED, schema('First', properties)),
                         ['FirstSchema: duplicate property ids [0]'])

    def test_index_nested_arguments_do_not_count_as_index_ids(self):
        indexes = """r'a': IndexSchema(
      properties: [IndexPropertySchema(name: r'a', nested: {'id': 17})],
      id: -7,
    ),"""
        self.assertEqual(duplicate_ids(GENERATED, schema('First', prop('a', 0), indexes)), [])

    def test_spacing_comments_crlf_and_argument_order(self):
        text = '''const FirstSchema = CollectionSchema /* gap */ (
  indexes /* map */ : const <String, IndexSchema>{
    'a': IndexSchema(name: 'a', id /* field */ : -7),
    'b': IndexSchema(name: 'b', id: -7),
  },
  properties: const <String, PropertySchema>{
    'a': PropertySchema(name: 'a', id: 0),
  },
  name: 'First',
);'''.replace('\n', '\r\n')
        self.assertEqual(duplicate_ids(GENERATED, text),
                         ['FirstSchema: duplicate index ids [-7]'])

    def test_compact_and_empty_maps_do_not_need_following_field(self):
        text = "const FirstSchema = CollectionSchema(properties: {}, indexes: {});"
        text += "const SecondSchema = CollectionSchema(properties: {'a': PropertySchema(id: 0)});"
        self.assertEqual(duplicate_ids(GENERATED, text), [])

    def test_nonliteral_map_is_not_silently_accepted(self):
        text = "const FirstSchema = CollectionSchema(properties: reusedProperties);"
        problems = duplicate_ids(GENERATED, text)
        self.assertTrue(problems)
        self.assertIn('FirstSchema', problems[0])
        self.assertIn('properties', problems[0])

    def test_unterminated_schema_is_not_silently_accepted(self):
        text = "const FirstSchema = CollectionSchema(properties: {'a': PropertySchema(id: 0),"
        problems = duplicate_ids(GENERATED, text)
        self.assertTrue(problems)
        self.assertIn('FirstSchema', problems[0])

    def test_unresolved_missing_or_repeated_id_is_not_a_pass(self):
        for body in ("id: inheritedId", "name: 'a'", "id: 0, id: 1"):
            with self.subTest(body=body):
                text = schema('First', f"'a': PropertySchema({body}),")
                problems = duplicate_ids(GENERATED, text)
                self.assertTrue(problems)
                self.assertIn('FirstSchema', problems[0])

    def test_repeated_map_argument_is_not_a_pass(self):
        text = 'const FirstSchema = CollectionSchema(properties: {}, properties: {});'
        self.assertTrue(duplicate_ids(GENERATED, text))

    def test_spread_or_other_map_value_cannot_hide_unchecked_ids(self):
        for entry in ('...inheritedProperties,', "'a': unknownProperty,"):
            with self.subTest(entry=entry):
                self.assertTrue(duplicate_ids(GENERATED, schema('First', entry)))

    def test_non_generated_files_and_string_only_examples_are_ignored(self):
        bad = schema('First', prop('a', 0) + prop('b', 0))
        self.assertEqual(duplicate_ids(Path('example.dart'), bad), [])
        self.assertEqual(duplicate_ids(GENERATED, "const text = 'CollectionSchema(properties: {})';"), [])

    def test_existing_interpolation_and_comment_lexing_is_preserved(self):
        text = 'final text = "value ${[1, 2].map((x) => {x: "nested"})}"; /* { /* } */ ] */'
        cleaned = strip_strings_and_comments(text)
        self.assertEqual(len(cleaned), len(text))
        self.assertIn('[1, 2].map((x) => {x:', cleaned)
        self.assertNotIn('nested', cleaned)
        self.assertNotIn('/*', cleaned)


if __name__ == '__main__':
    unittest.main()
