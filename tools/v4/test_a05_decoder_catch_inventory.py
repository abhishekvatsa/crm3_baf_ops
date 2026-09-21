import hashlib
import re
import unittest

import a05_persisted_decoder_inventory as audit


class DecoderCatchInventoryTest(unittest.TestCase):
    def sites(self, source):
        return audit._decoder_catch_sites('lib/example.dart', source)

    def test_bare_typed_decoder_refusal_is_not_omitted(self):
        source = '''void read() {
  try { return jsonDecode(raw); }
  on FormatException { return null; }
}'''
        self.assertEqual(len(self.sites(source)), 1)

    def test_every_handler_in_mixed_chain_is_governed(self):
        source = '''void read() {
  try { return readOptionalJsonObject(raw); }
  on FormatException catch (error) { rethrow; }
  on TypeError { return null; }
  catch (error, stack) { return fallback; }
  finally { release(); }
}'''
        sites = self.sites(source)
        self.assertEqual(len(sites), 3)
        self.assertEqual(len({site['siteFingerprint'] for site in sites}), 3)
        self.assertTrue(all(site['decoderContexts'] for site in sites))

    def test_later_catch_policy_does_not_cover_changed_prior_handler(self):
        source = '''try { return jsonDecode(raw); }
on FormatException { rethrow; }
catch (error) { return null; }'''
        original = self.sites(source)
        changed = self.sites(source.replace('rethrow;', 'return {};'))
        self.assertEqual(len(original), 2)
        self.assertNotEqual(original[1]['siteFingerprint'], changed[1]['siteFingerprint'])

    def test_nested_try_chains_are_each_enumerated_once(self):
        source = '''try {
  try { return jsonDecode(raw); }
  on FormatException { rethrow; }
} on Object { return null; }'''
        self.assertEqual(len(self.sites(source)), 2)

    def test_qualified_generic_exception_and_comments_between_handlers(self):
        source = '''try { return jsonDecode(raw); }
// retain raw evidence
on codec.DecodeFailure<Object?> { rethrow; }
/* preserve */ catch (error) { return null; }'''
        self.assertEqual(len(self.sites(source)), 2)

    def test_nondecode_try_and_fake_syntax_in_comments_are_ignored(self):
        source = '''// try { jsonDecode(raw); } on Object { return null; }
void read() {
  final label = 'try { jsonDecode(raw); } on Object {}';
  try { save(); } on Object { return null; }
}'''
        self.assertEqual(self.sites(source), [])

    def test_original_first_catch_fingerprint_is_preserved(self):
        source = 'try { return jsonDecode(raw); } on FormatException catch (error) { rethrow; }'
        site = self.sites(source)[0]
        body = source[source.index('{'):]
        normalized = re.sub(r'\s+', ' ', body).strip()
        expected = hashlib.sha256(f'lib/example.dart\n1\n{normalized}'.encode()).hexdigest()
        self.assertEqual(site['siteFingerprint'], expected)

    def test_decoder_names_in_try_comments_or_strings_do_not_qualify(self):
        source = '''try {
  // jsonDecode(raw);
  final label = 'readOptionalJsonObject(raw)';
  save(label);
} on Object { return null; }'''
        self.assertEqual(self.sites(source), [])

    def test_decoder_in_handler_does_not_qualify_unrelated_try(self):
        source = '''try { save(); }
on Object { return jsonDecode(raw); }'''
        self.assertEqual(self.sites(source), [])


if __name__ == '__main__':
    unittest.main()
