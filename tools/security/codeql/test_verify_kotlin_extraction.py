"""Unit tests use synthetic evidence; CI proof must use the actual query output."""

import contextlib
import csv
import hashlib
import io
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import verify_kotlin_extraction as verifier


def evidence(rows=None, header=verifier.CSV_COLUMNS):
    text = io.StringIO(newline="")
    writer = csv.writer(text)
    writer.writerow(header)
    writer.writerows(valid_rows() if rows is None else rows)
    return text.getvalue().encode("utf-8")


def valid_rows():
    return [
        [verifier.SOURCE_PATH, verifier.CLASS_NAME, method, str(line), str(line + 1)]
        for method, line in zip(verifier.EXPECTED_METHODS, (3, 5, 7))
    ]


class CsvEvidenceTests(unittest.TestCase):
    def test_actual_query_shape_accepts_any_row_order_and_returns_fixed_order(self):
        bodies = verifier.verify_rows(evidence(list(reversed(valid_rows()))), 10)
        self.assertEqual([body["methodName"] for body in bodies], list(verifier.EXPECTED_METHODS))
        self.assertEqual(bodies[0]["bodyStartLine"], 3)

    def test_every_missing_method_and_an_empty_result_are_rejected(self):
        rows = valid_rows()
        for missing in range(len(rows)):
            with self.subTest(missing=rows[missing][2]), self.assertRaises(verifier.ProofError):
                verifier.verify_rows(evidence(rows[:missing] + rows[missing + 1:]), 10)
        with self.assertRaises(verifier.ProofError):
            verifier.verify_rows(evidence([]), 10)

    def test_duplicate_rows_and_conflicting_body_ranges_are_rejected(self):
        for line in ("3", "4"):
            rows = valid_rows()
            duplicate = rows[0].copy()
            duplicate[3] = line
            with self.subTest(line=line), self.assertRaises(verifier.ProofError):
                verifier.verify_rows(evidence(rows + [duplicate]), 10)

    def test_wrong_source_class_and_method_are_rejected(self):
        invalid_fields = (
            (0, "MainActivity.kt"),
            (0, "/checkout/" + verifier.SOURCE_PATH),
            (0, verifier.SOURCE_PATH.replace("/", "\\")),
            (0, "other/" + verifier.SOURCE_PATH),
            (0, verifier.SOURCE_PATH + " "),
            (1, "another.package.MainActivity"),
            (1, "MainActivity"),
            (2, "configureFlutterEngine$default"),
            (2, "onCreate"),
        )
        for index, value in invalid_fields:
            rows = valid_rows()
            rows[0][index] = value
            with self.subTest(index=index, value=value), self.assertRaises(verifier.ProofError):
                verifier.verify_rows(evidence(rows), 10)

    def test_invalid_body_lines_are_rejected(self):
        ranges = (
            ("", "4"), ("0", "4"), ("-1", "4"), ("3.0", "4"),
            ("03", "4"), (" 3", "4"), ("3", "4 "), ("3", ""),
            ("5", "4"), ("3", "11"), ("3", "10000000"),
        )
        for start, end in ranges:
            rows = valid_rows()
            rows[0][3:] = [start, end]
            with self.subTest(start=start, end=end), self.assertRaises(verifier.ProofError):
                verifier.verify_rows(evidence(rows), 10)

    def test_malformed_csv_headers_and_rows_are_rejected(self):
        rows = valid_rows()
        malformed = (
            b"", b"\xff", b"\x00", b'"unterminated',
            b"\xef\xbb\xbf" + evidence(),
            evidence(header=list(reversed(verifier.CSV_COLUMNS))),
            evidence(header=verifier.CSV_COLUMNS[:-1]),
            evidence(header=verifier.CSV_COLUMNS + ("unexpected",)),
            evidence([rows[0][:-1]] + rows[1:]),
            evidence([rows[0] + ["extra"]] + rows[1:]),
            evidence(rows + [[]]),
            evidence() + b'"unterminated',
            b"x" * (verifier.MAX_CSV_BYTES + 1),
        )
        for index, value in enumerate(malformed):
            with self.subTest(case=index), self.assertRaises(verifier.ProofError):
                verifier.verify_rows(value, 10)


class BoundProofTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # A disposable repository exercises actual Git identity/readback without
        # creating commits or modifying configuration in the application repo.
        cls.temporary = tempfile.TemporaryDirectory(prefix="kotlin-proof-test-")
        cls.root = Path(cls.temporary.name).resolve()
        cls.source = cls.root / verifier.SOURCE_PATH
        cls.source.parent.mkdir(parents=True)
        cls.source_bytes = (
            "package `in`.co.sail.bsl.crm3.bafops\n"
            "class MainActivity {\n"
            "  fun configureFlutterEngine() {\n  }\n"
            "  fun configureCriticalAlarmChannel() {\n  }\n"
            "  fun configureNetworkAccessChannel() {\n  }\n}\n"
        ).encode("utf-8")
        cls.source.write_bytes(cls.source_bytes)
        cls.git("init", "--quiet")
        cls.git("-c", "core.autocrlf=false", "add", "--", verifier.SOURCE_PATH)
        cls.git(
            "-c", "user.name=CodeQL proof test", "-c", "user.email=proof-test@example.invalid",
            "-c", "commit.gpgsign=false", "commit", "--quiet", "-m", "Synthetic proof fixture",
        )
        cls.commit = cls.git("rev-parse", "HEAD").decode().strip()

    @classmethod
    def tearDownClass(cls):
        cls.temporary.cleanup()

    @classmethod
    def git(cls, *arguments):
        return subprocess.run(
            ["git", "-C", str(cls.root), *arguments], check=True,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=20,
        ).stdout

    def setUp(self):
        self.source.write_bytes(self.source_bytes)
        self.case_directory = tempfile.TemporaryDirectory(dir=self.root, prefix="case-")
        self.addCleanup(self.case_directory.cleanup)
        self.csv_path = Path(self.case_directory.name) / "extraction.csv"
        self.csv_path.write_bytes(evidence())
        self.output = Path(self.case_directory.name) / "proof.json"
        self.diagnostics_path = Path(self.case_directory.name) / "diagnostics.csv"
        self.diagnostics_path.write_text('source_path,severity,tag,message,full_message\n', encoding='utf-8')

    def build(self, **changes):
        arguments = {
            "csv_path": self.csv_path,
            "diagnostics_path": self.diagnostics_path,
            "repository_root": self.root,
            "commit": self.commit,
            "codeql_version": "2.27.0",
        }
        arguments.update(changes)
        return verifier.build_proof(**arguments)

    def invoke(self, **changes):
        arguments = {
            "csv": self.csv_path, "repository-root": self.root,
            "diagnostics": self.diagnostics_path,
            "commit": self.commit, "codeql-version": "2.27.0", "output": self.output,
        }
        arguments.update(changes)
        argv = [part for key, value in arguments.items() for part in ("--" + key, str(value))]
        with contextlib.redirect_stderr(io.StringIO()), contextlib.redirect_stdout(io.StringIO()):
            return verifier.main(argv)

    def test_proof_binds_actual_commit_source_csv_and_fixed_method_set(self):
        proof = self.build()
        self.assertEqual(proof["status"], "verified")
        self.assertEqual(proof["commitSha"], self.commit)
        self.assertEqual(proof["codeqlVersion"], "2.27.0")
        self.assertEqual(proof["sourcePath"], verifier.SOURCE_PATH)
        self.assertEqual(proof["className"], verifier.CLASS_NAME)
        self.assertEqual(proof["sourceSha256"], hashlib.sha256(self.source_bytes).hexdigest())
        self.assertEqual(proof["committedSourceSha256"], proof["sourceSha256"])
        self.assertEqual(proof["queryCsvSha256"], hashlib.sha256(evidence()).hexdigest())
        self.assertEqual(len(proof["methodBodies"]), 3)

    def test_metadata_cannot_use_unverified_commit_or_malformed_version(self):
        for commit in ("", "0" * 40, "A" * 40, "abc1234", "HEAD", "1" * 40, self.commit + "\n"):
            with self.subTest(commit=commit), self.assertRaises(verifier.ProofError):
                self.build(commit=commit)
        for version in ("", "latest", "v2.27.0", "2.27", "2.27.0\n", "02.27.0", "2.27.0 --flag"):
            with self.subTest(version=version), self.assertRaises(verifier.ProofError):
                self.build(codeql_version=version)

    def test_changed_source_cannot_be_labeled_as_committed(self):
        self.source.write_bytes(self.source_bytes + b"// changed after checkout\n")
        with self.assertRaisesRegex(verifier.ProofError, "differs"):
            self.build()

    def test_checkout_crlf_is_supported_and_actual_bytes_are_hashed(self):
        checkout = self.source_bytes.replace(b"\n", b"\r\n")
        self.source.write_bytes(checkout)
        proof = self.build()
        self.assertEqual(proof["sourceSha256"], hashlib.sha256(checkout).hexdigest())
        self.assertEqual(proof["committedSourceSha256"], hashlib.sha256(self.source_bytes).hexdigest())

    def test_repository_subdirectory_is_not_accepted_as_root(self):
        with self.assertRaisesRegex(verifier.ProofError, "actual Git"):
            self.build(repository_root=self.source.parent)

    def test_unavailable_git_evidence_fails_closed(self):
        with patch.object(verifier.subprocess, "run", side_effect=OSError("unavailable")):
            with self.assertRaises(verifier.ProofError):
                self.build()

    def test_invalid_source_encoding_size_and_missing_source_fail(self):
        for value in (b"", b"\xff", b"\x00", b"x" * (verifier.MAX_SOURCE_BYTES + 1)):
            self.source.write_bytes(value)
            with self.subTest(value_length=len(value)), self.assertRaises(verifier.ProofError):
                self.build()
        self.source.unlink()
        self.assertEqual(self.invoke(), 1)
        self.assertFalse(self.output.exists())

    def test_success_writes_json_only_after_all_evidence_is_valid(self):
        self.assertEqual(self.invoke(), 0)
        proof = json.loads(self.output.read_text(encoding="utf-8"))
        self.assertEqual(proof, self.build())

    def test_failed_evidence_writes_no_proof(self):
        self.csv_path.write_bytes(evidence(valid_rows()[:2]))
        self.assertEqual(self.invoke(), 1)
        self.assertFalse(self.output.exists())

    def test_existing_output_and_input_cannot_be_overwritten(self):
        self.output.write_text("prior artifact", encoding="utf-8")
        self.assertEqual(self.invoke(), 1)
        self.assertEqual(self.output.read_text(encoding="utf-8"), "prior artifact")
        self.assertEqual(self.invoke(output=self.csv_path), 1)
        self.assertEqual(self.csv_path.read_bytes(), evidence())

    def test_extraction_error_cannot_be_hidden_by_existing_method_bodies(self):
        diagnostics = self.diagnostics_path
        diagnostics.write_text('source_path,severity,tag,message,full_message\nandroid/app/src/MainActivity.kt,5,extractor,error,details\n', encoding='utf-8')
        with self.assertRaisesRegex(verifier.ProofError, "extraction errors"):
            self.build()
        self.assertEqual(self.invoke(), 1)
        self.assertFalse(self.output.exists())

    def test_missing_or_malformed_diagnostics_cannot_mean_zero_errors(self):
        for content in (b'', b'bad header\n', b'\xff', b'source_path,severity,tag,message,full_message\n\n'):
            diagnostics = self.diagnostics_path
            diagnostics.write_bytes(content)
            self.assertEqual(self.invoke(), 1)
            self.assertFalse(self.output.exists())
        self.diagnostics_path.unlink()
        self.assertEqual(self.invoke(), 1)
        self.assertFalse(self.output.exists())


if __name__ == "__main__":
    unittest.main()
