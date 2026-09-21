import copy
import tempfile
import unittest
from pathlib import Path

import a05_persisted_timestamp_inventory as audit


class DynamicTimestampInventoryTest(unittest.TestCase):
    body = """{
  final value = readRequiredPersistedDateTime(raw, field: field, source: source);
  if (value.microsecond != 0) throw StateError('unsupported precision');
  return value;
}"""

    def entry(self):
        return {
            'readerBodySha256': audit._body_digest(self.body),
            'dynamicCalls': [{
                'reader': 'readRequiredPersistedDateTime',
                'callSource': 'readRequiredPersistedDateTime(raw, field: field, source: source)',
                'reviewedFields': ['originalAt', 'correctedAt'],
            }],
        }

    def test_exact_dynamic_reader_is_classified(self):
        self.assertEqual(len(audit._reviewed_dynamic_calls(self.entry(), self.body)), 1)

    def test_undeclared_dynamic_call_inside_literal_reader_is_rejected(self):
        literal = "readRequiredPersistedDateTime(data['createdAt'], field: 'createdAt')"
        for entry in [{}, {'dynamicCalls': []}]:
            self.assertEqual(audit._reviewed_dynamic_calls(entry, '{ return ' + literal + '; }'), [])
            for reader in audit.READER_TOKENS:
                body = '{ final at = ' + literal + '; return ' + reader + '(data[field], field: field); }'
                with self.subTest(entry=entry, reader=reader):
                    with self.assertRaisesRegex(ValueError, 'count or source'):
                        audit._reviewed_dynamic_calls(entry, body)

    def test_undeclared_dynamic_call_without_any_literal_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'count or source'):
            audit._reviewed_dynamic_calls({}, self.body)

    def test_body_change_requires_review_even_with_same_strict_call(self):
        with self.assertRaisesRegex(ValueError, 'body changed'):
            audit._reviewed_dynamic_calls(self.entry(), self.body.replace('value.microsecond != 0', 'false'))

    def test_missing_additional_or_changed_calls_fail_after_body_review(self):
        for body in [
            self.body.replace('raw, field:', 'other, field:'),
            self.body.replace('return value;', 'readRequiredPersistedDateTime(raw, field: field, source: source); return value;'),
            self.body.replace('readRequiredPersistedDateTime(raw, field: field, source: source)', 'raw'),
        ]:
            entry = self.entry()
            entry['readerBodySha256'] = audit._body_digest(body)
            with self.assertRaisesRegex(ValueError, 'count or source'):
                audit._reviewed_dynamic_calls(entry, body)

    def test_missing_or_duplicate_field_metadata_fails(self):
        for fields in [[], ['originalAt', 'originalAt'], ['']]:
            entry = self.entry()
            entry['dynamicCalls'][0]['reviewedFields'] = fields
            with self.assertRaisesRegex(ValueError, 'reviewed fields'):
                audit._reviewed_dynamic_calls(entry, self.body)

    def test_existing_literal_field_validation_is_unchanged(self):
        self.assertEqual(audit._reader_fields("readRequiredPersistedDateTime(map['createdAt'], field: 'createdAt')", 'readRequiredPersistedDateTime'), ['createdAt'])
        with self.assertRaisesRegex(ValueError, 'labelled'):
            audit._reader_fields("readRequiredPersistedDateTime(map['createdAt'], field: 'resolvedAt')", 'readRequiredPersistedDateTime')

    def test_literal_call_cannot_be_hidden_as_a_dynamic_exception(self):
        body = "{ return readRequiredPersistedDateTime(map['createdAt'], field: 'createdAt'); }"
        entry = self.entry()
        entry['readerBodySha256'] = audit._body_digest(body)
        entry['dynamicCalls'][0]['callSource'] = body[9:-3]
        with self.assertRaises(ValueError):
            audit._reviewed_dynamic_calls(entry, body)

    def test_reviewed_nonstandard_scalar_does_not_hide_mislabeled_literal(self):
        call = "readRequiredPersistedDateTime(item, field: 'evidenceTimestamp')"
        body = '{ return ' + call + '; }'
        entry = {'readerBodySha256': audit._body_digest(body), 'dynamicCalls': [{
            'reader': 'readRequiredPersistedDateTime', 'callSource': call,
            'reviewedFields': ['evidenceTimestamp'],
        }]}
        reviewed = audit._reviewed_dynamic_calls(entry, body)
        self.assertEqual(audit._reader_fields(audit._without_reviewed_calls(body, reviewed), 'readRequiredPersistedDateTime'), [])
        wrong_fields = copy.deepcopy(entry)
        wrong_fields['dynamicCalls'][0]['reviewedFields'] = ['otherTimestamp']
        with self.assertRaisesRegex(ValueError, 'unreviewed literal'):
            audit._reviewed_dynamic_calls(wrong_fields, body)
        wrong = "readRequiredPersistedDateTime(map['createdAt'], field: 'resolvedAt')"
        body = '{ return ' + wrong + '; }'
        entry['readerBodySha256'] = audit._body_digest(body)
        entry['dynamicCalls'][0]['callSource'] = wrong
        with self.assertRaisesRegex(ValueError, 'labelled'):
            audit._reviewed_dynamic_calls(entry, body)

    def _wrapper_fixture(self, root):
        file = root / 'lib/model.dart'
        file.parent.mkdir()
        file.write_text('DateTime exactTime(raw, {field, source}) ' + self.body + "\nDateTime restore(map) { return exactTime(map['originalAt'], field: 'originalAt'); }", encoding='utf-8')
        start, end, _ = audit._function_span(file, 'DateTime exactTime(')
        _, _, caller = audit._function_span(file, 'DateTime restore(')
        entry = {
            'readerFile': 'lib/model.dart', 'wrapperName': 'exactTime',
            'readerMarker': 'DateTime exactTime(',
            'reviewedCallers': [{'file': 'lib/model.dart', 'marker': 'DateTime restore(',
                                'bodySha256': audit._body_digest(caller), 'callCount': 1,
                                'fields': ['originalAt']}],
        }
        return entry, start, end

    def test_all_wrapper_calls_require_exactly_one_reviewed_caller(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            entry, start, end = self._wrapper_fixture(root)
            audit._reviewed_wrapper_callers(entry, root, start, end)
            (root / 'lib/unreviewed.dart').write_text("DateTime read(map) { return exactTime(map['newAt'], field: 'newAt'); }", encoding='utf-8')
            with self.assertRaisesRegex(ValueError, 'exactly one'):
                audit._reviewed_wrapper_callers(entry, root, start, end)

    def test_unreviewed_wrapper_tear_off_and_callback_are_rejected(self):
        for source in [
            "final exact = exactTime; DateTime read(map) { return exact(map['newAt'], field: 'newAt'); }",
            "final readers = [exactTime];",
            "void restore() { register(exactTime); }",
        ]:
            with self.subTest(source=source), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                entry, start, end = self._wrapper_fixture(root)
                (root / 'lib/unreviewed.dart').write_text(source, encoding='utf-8')
                with self.assertRaisesRegex(ValueError, 'reference needs exactly one'):
                    audit._reviewed_wrapper_callers(entry, root, start, end)

    def test_wrapper_comments_strings_and_different_identifiers_are_not_references(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            entry, start, end = self._wrapper_fixture(root)
            (root / 'lib/unreviewed.dart').write_text(
                "// exactTime and exactTime()\n/* exactTime */\n"
                "final text = 'exactTime'; final raw = r'exactTime()';\n"
                "final exactTimeCopy = other; final _exactTime = other;",
                encoding='utf-8')
            audit._reviewed_wrapper_callers(entry, root, start, end)

    def test_wrapper_body_is_not_exempt_as_its_declaration(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            entry, start, end = self._wrapper_fixture(root)
            file = root / 'lib/model.dart'
            file.write_text(file.read_text(encoding='utf-8').replace(
                'return value;', 'final alias = exactTime; return value;'), encoding='utf-8')
            start, end, _ = audit._function_span(file, entry['readerMarker'])
            with self.assertRaisesRegex(ValueError, 'reference needs exactly one'):
                audit._reviewed_wrapper_callers(entry, root, start, end)

    def test_tear_off_added_to_reviewed_caller_requires_new_body_review(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            entry, start, end = self._wrapper_fixture(root)
            file = root / 'lib/model.dart'
            file.write_text(file.read_text(encoding='utf-8').replace(
                'return exactTime(', 'final alias = exactTime; return exactTime('), encoding='utf-8')
            with self.assertRaisesRegex(ValueError, 'caller changed'):
                audit._reviewed_wrapper_callers(entry, root, start, end)

    def test_wrapper_caller_digest_count_and_field_metadata_are_verified(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            entry, start, end = self._wrapper_fixture(root)
            for change in [{'bodySha256': '0' * 64}, {'callCount': 2}, {'fields': ['wrongAt']}]:
                bad = copy.deepcopy(entry)
                bad['reviewedCallers'][0].update(change)
                with self.assertRaises(ValueError):
                    audit._reviewed_wrapper_callers(bad, root, start, end)
            bad = copy.deepcopy(entry)
            bad['reviewedCallers'] *= 2
            with self.assertRaisesRegex(ValueError, 'exactly one'):
                audit._reviewed_wrapper_callers(bad, root, start, end)


if __name__ == '__main__':
    unittest.main()
