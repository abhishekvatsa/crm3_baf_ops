"""Persisted-field and migration rejection tests; no database is opened."""
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("isar_schema_verifier", Path(__file__).with_name("verify_v4_isar_schema.py"))
verifier = importlib.util.module_from_spec(spec)
spec.loader.exec_module(verifier)


class PersistedFieldsTest(unittest.TestCase):
    def fields(self, body):
        with tempfile.TemporaryDirectory() as folder:
            source = Path(folder) / "record.dart"
            source.write_text("class Sample {\n  int id = 0;\n" + body + "\n}\n", encoding="utf-8")
            return verifier.source_fields(source, "Sample")

    def test_ignore_applies_only_to_its_annotated_field(self):
        self.assertEqual(self.fields("  @ignore\n  String? transient;\n  String? persisted;"), {"persisted"})

    def test_inline_and_multiple_metadata_annotations(self):
        self.assertEqual(self.fields("  @Index() @ignore String? transient;\n  @Index()\n  String? persisted;"), {"persisted"})

    def test_comments_between_annotation_and_field_do_not_break_ignore(self):
        self.assertEqual(self.fields("  @ignore /* comment */\n  // explanation\n  String? transient;\n  String? persisted;"), {"persisted"})

    def test_comment_and_string_lookalikes_do_not_ignore_real_fields(self):
        self.assertEqual(self.fields("  // @ignore\n  String? first;\n  /* @ignore */\n  String second = '@ignore }';\n  @ignored\n  String? third;"), {"first", "second", "third"})

    def test_ignored_method_does_not_hide_following_persisted_field(self):
        self.assertEqual(self.fields("  @ignore\n  String helper() { return 'not a field'; }\n  String? persisted;"), {"persisted"})

    def test_actual_workflow_matches_generated_persisted_population(self):
        source = ROOT / "lib/features/maintenance_workflow/data/workflow_aggregate_record.dart"
        verifier.verify_binding(source, source.with_suffix(".g.dart"), "WorkflowAggregateRecord")

    def test_real_persisted_field_deletion_remains_rejected(self):
        source = ROOT / "lib/features/maintenance_workflow/data/workflow_aggregate_record.dart"
        with tempfile.TemporaryDirectory() as folder:
            copied = Path(folder) / source.name
            copied.write_text(source.read_text(encoding="utf-8") + "\n", encoding="utf-8")
            generated = Path(folder) / source.with_suffix(".g.dart").name
            text = source.with_suffix(".g.dart").read_text(encoding="utf-8")
            generated.write_text(text.replace("r'activeRedWork': PropertySchema(", "r'wrongPersistedName': PropertySchema(", 1), encoding="utf-8")
            with self.assertRaisesRegex(AssertionError, "source/schema mismatch"):
                verifier.verify_binding(copied, generated, "WorkflowAggregateRecord")

    def test_wrongly_persisted_ignored_field_remains_rejected(self):
        source = ROOT / "lib/features/maintenance_workflow/data/workflow_aggregate_record.dart"
        with tempfile.TemporaryDirectory() as folder:
            generated = Path(folder) / source.with_suffix(".g.dart").name
            text = source.with_suffix(".g.dart").read_text(encoding="utf-8")
            generated.write_text(text.replace("properties: {", "properties: {\n    r'workflowKind': PropertySchema(id: 999, name: r'workflowKind', type: IsarType.string),", 1), encoding="utf-8")
            with self.assertRaisesRegex(AssertionError, "source/schema mismatch"):
                verifier.verify_binding(source, generated, "WorkflowAggregateRecord")


class MigrationTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for rel in ("lib/core/services/isar_schema_migration.dart", "lib/core/services/isar_schema_guard_io.dart", "lib/main.dart", "lib/core/services/governed_asset_identity_local_repair.dart", "lib/core/services/maintenance_plant_condition_index_repair.dart"):
            target = self.root / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes((ROOT / rel).read_bytes())
        self.patch = patch.object(verifier, "ROOT", self.root)
        self.patch.start()
        self.addCleanup(self.patch.stop)

    def mutate(self, old, new):
        path = self.root / "lib/core/services/isar_schema_migration.dart"
        text = path.read_text(encoding="utf-8")
        self.assertIn(old, text)
        path.write_text(text.replace(old, new, 1), encoding="utf-8")

    def test_current_v12_and_retained_upgrade_contract_pass(self):
        verifier.verify_migration()

    def test_stale_version_rejected(self):
        self.mutate("currentSchemaVersion = 12", "currentSchemaVersion = 11")
        with self.assertRaisesRegex(AssertionError, "v12"):
            verifier.verify_migration()

    def test_v12_step_cannot_be_omitted(self):
        self.mutate("12: _addDurableSubmissionReviewOutcomes", "12: _wrongStep")
        with self.assertRaisesRegex(AssertionError, "v11->v12"):
            verifier.verify_migration()

    def test_v11_retained_fingerprint_cannot_be_omitted(self):
        self.mutate("11: <String>{v11SchemaFingerprint}", "11: <String>{currentSchemaFingerprint}")
        with self.assertRaisesRegex(AssertionError, "v11 fingerprint"):
            verifier.verify_migration()

    def test_v12_fingerprint_cannot_reuse_v11(self):
        self.mutate("12: <String>{currentSchemaFingerprint}", "12: <String>{v11SchemaFingerprint}")
        with self.assertRaisesRegex(AssertionError, "v12 fingerprint"):
            verifier.verify_migration()

    def test_unproved_v2_remains_rejected(self):
        self.mutate("1: <String>{v1SchemaFingerprint}", "2: <String>{v1SchemaFingerprint}")
        with self.assertRaisesRegex(AssertionError, "unproved v2"):
            verifier.verify_migration()

    def test_existing_provenance_guard_remains_required(self):
        self.mutate("existing-store-unmarked", "removed-store-guard")
        with self.assertRaisesRegex(AssertionError, "provenance controls missing"):
            verifier.verify_migration()

    def test_existing_v5_crossing_repair_remains_required(self):
        path = self.root / "lib/core/services/governed_asset_identity_local_repair.dart"
        text = path.read_text(encoding="utf-8")
        self.assertIn("fromVersion < 5 && toVersion >= 5", text)
        path.write_text(text.replace("fromVersion < 5 && toVersion >= 5", "toVersion == 5"), encoding="utf-8")
        with self.assertRaisesRegex(AssertionError, "direct upgrades"):
            verifier.verify_migration()


if __name__ == "__main__":
    unittest.main()
