"""Pure protocol tests only; these do not claim Android or backend acceptance."""
import copy
import json
import io
from unittest.mock import patch
from pathlib import Path
import tempfile
import unittest

from required_red_transport_relay import PROJECT, TARGET, ReceiptLoss, Handler, callable_path, callable_signed_integer


class ReceiptLossTest(unittest.TestCase):
    def setUp(self):
        self.loss = ReceiptLoss()
        self.identity = {"project": PROJECT, "workflowId": "red_" + "a" * 28,
                         "complianceId": "red_" + "a" * 28 + "_preparation", "actorUid": "demo-operations"}
        self.envelope = {"data": {"protocolVersion": 2, "originActorUid": "demo-operations", "command": {
            "commandId": "command-test-1", "commandType": "acknowledgeCompliance",
            "aggregateId": self.identity["workflowId"], "expectedVersion": 1,
            "payload": {"complianceId": self.identity["complianceId"], "expectedComplianceVersion": 1}}}}
        self.receipt = {"result": {"commandId": "command-test-1", "resultKey": "compliance-acknowledged",
            "aggregateVersion": 2, "appliedAt": "2026-10-03T00:00:00.123Z", "result": {"complianceId": self.identity["complianceId"]}}}

    def body(self, envelope=None):
        return json.dumps(self.envelope if envelope is None else envelope).encode()

    def start(self):
        self.loss.arm(self.identity)
        self.assertEqual(self.loss.inspect(TARGET, self.body()), "capture")

    def test_fixed_namespace_routes_only(self):
        self.assertTrue(callable_path(TARGET))
        for path in ("https://example.invalid/a", TARGET + "?url=x", TARGET.replace(PROJECT, "production"),
                     TARGET + "/../elsewhere", "/other/asia-south1/function"):
            self.assertFalse(callable_path(path), path)

    def test_no_capture_without_exact_actor_workflow_and_command(self):
        self.loss.arm(self.identity)
        for where, key, value in (("envelope", "originActorUid", "another-user"),
                                  ("command", "aggregateId", "another-workflow"),
                                  ("command", "commandType", "markComplianceComplied")):
            changed = copy.deepcopy(self.envelope)
            target = changed["data"] if where == "envelope" else changed["data"]["command"]
            target[key] = value
            self.assertEqual(self.loss.inspect(TARGET, self.body(changed)), "pass")
        self.assertEqual(self.loss.status()["phase"], "armed")

    def test_success_is_required_before_any_release(self):
        self.start()
        with self.assertRaises(ValueError):
            self.loss.release({"commandId": "command-test-1"})
        self.assertTrue(self.loss.accepted(200, json.dumps(self.receipt).encode()))
        self.assertEqual(self.loss.inspect(TARGET, self.body()), "drop")
        self.loss.release({"commandId": "command-test-1"})
        self.assertEqual(self.loss.inspect(TARGET, self.body()), "replay")
        self.assertTrue(self.loss.replayed(200, json.dumps(self.receipt).encode()))
        state = self.loss.status()
        self.assertEqual(state["forwardedAttempts"], 1)
        self.assertEqual(state["replayForwardedAttempts"], 1)
        self.assertEqual(state["guardRejectCount"], 0)

    def test_backend_rejection_is_never_relabelled_success(self):
        self.start()
        self.assertFalse(self.loss.accepted(403, b'{"error":{"status":"PERMISSION_DENIED"}}'))
        self.assertEqual(self.loss.status()["phase"], "failed")
        with self.assertRaises(ValueError):
            self.loss.release({"commandId": "command-test-1"})

    def test_wrong_identity_receipt_is_not_withheld(self):
        for key, value in (("commandId", "wrong"), ("aggregateVersion", 3), ("resultKey", "other")):
            with self.subTest(key=key):
                self.setUp()
                self.start()
                self.receipt["result"][key] = value
                self.assertFalse(self.loss.accepted(200, json.dumps(self.receipt).encode()))

    def test_replay_preserves_original_time_and_full_result(self):
        for field in ("appliedAt", "result"):
            with self.subTest(field=field):
                self.setUp()
                self.start()
                self.assertTrue(self.loss.accepted(200, json.dumps(self.receipt).encode()))
                self.loss.release({"commandId": "command-test-1"})
                changed = copy.deepcopy(self.receipt)
                changed["result"][field] = ("2026-10-03T00:01:00.123Z" if field == "appliedAt"
                    else {**changed["result"]["result"], "extraOutcome": "changed"})
                self.assertFalse(self.loss.replayed(200, json.dumps(changed).encode()))
                self.assertEqual(self.loss.status()["replayReceiptMismatchCount"], 1)
                self.assertEqual(self.loss.status()["verifiedReplayReceipts"], 0)
                self.assertTrue(self.loss.replayed(200, json.dumps(self.receipt).encode()))
                self.assertEqual(self.loss.status()["verifiedReplayReceipts"], 1)

    def test_missing_or_invalid_original_time_is_never_withheld(self):
        for instant in (None, "yesterday", "2026-99-03T00:00:00.123Z"):
            with self.subTest(instant=instant):
                self.setUp()
                self.start()
                self.receipt["result"]["appliedAt"] = instant
                self.assertFalse(self.loss.accepted(200, json.dumps(self.receipt).encode()))

    def test_changed_replay_and_second_action_are_counted_guard_failures(self):
        for key, value in (("commandId", "new-command"), ("expectedVersion", 2)):
            with self.subTest(key=key):
                self.setUp()
                self.start()
                changed = copy.deepcopy(self.envelope)
                changed["data"]["command"][key] = value
                with self.assertRaises(ValueError):
                    self.loss.inspect(TARGET, self.body(changed))
                self.assertEqual(self.loss.status()["guardRejectCount"], 1)

    def test_cannot_rearm_or_release_different_command(self):
        self.start()
        with self.assertRaises(ValueError):
            self.loss.arm(self.identity)
        self.loss.accepted(200, json.dumps(self.receipt).encode())
        with self.assertRaises(ValueError):
            self.loss.release({"commandId": "other"})

    def test_control_requires_exact_demo_and_correlated_preparation(self):
        for key, value in (("project", "prod"), ("workflowId", "another"),
                           ("complianceId", "arbitrary"), ("actorUid", "bad/actor")):
            with self.subTest(key=key):
                changed = {**self.identity, key: value}
                with self.assertRaises(ValueError):
                    ReceiptLoss().arm(changed)

    def test_malformed_objects_fail_closed_without_attribute_errors(self):
        for raw in (None, [], "text", 1):
            with self.subTest(raw=raw):
                with self.assertRaises(ValueError):
                    ReceiptLoss().arm(raw)
                with self.assertRaises(ValueError):
                    ReceiptLoss().release(raw)
                with self.assertRaises(ValueError):
                    ReceiptLoss().inspect(TARGET, json.dumps(raw).encode())
                self.setUp()
                self.start()
                self.assertFalse(self.loss.accepted(200, json.dumps({"result": raw}).encode()))
                self.setUp()
                self.start()
                malformed = copy.deepcopy(self.receipt)
                malformed["result"]["result"] = raw
                self.assertFalse(self.loss.accepted(200, json.dumps(malformed).encode()))

    def test_receipts_retain_only_bound_metadata_and_hashes(self):
        with tempfile.TemporaryDirectory() as folder:
            loss = ReceiptLoss(Path(folder))
            loss.arm(self.identity)
            loss.inspect(TARGET, self.body())
            loss.accepted(200, json.dumps(self.receipt).encode())
            self.assertEqual(len(list(Path(folder).glob("*.json"))), 3)
            retained = "".join(p.read_text(encoding="utf-8") for p in Path(folder).glob("*.json"))
            self.assertNotIn('"payload"', retained)
            self.assertNotIn("Authorization", retained)
            self.assertIn("upstreamResponseSha256", retained)


class FirebaseIntegerWireTest(ReceiptLossTest):
    @staticmethod
    def wrapped(value):
        return {"@type": "type.googleapis.com/google.protobuf.Int64Value", "value": str(value)}

    def android_envelope(self):
        value = copy.deepcopy(self.envelope)
        value["data"]["protocolVersion"] = self.wrapped(2)
        value["data"]["command"]["expectedVersion"] = self.wrapped(1)
        value["data"]["command"]["payload"]["expectedComplianceVersion"] = self.wrapped(1)
        return value

    def test_small_sdk_int64_values_capture_with_unchanged_raw_envelope_identity(self):
        envelope = self.android_envelope()
        raw = json.dumps(envelope).encode()
        untouched = copy.deepcopy(envelope)
        self.loss.arm(self.identity)
        self.assertEqual(self.loss.inspect(TARGET, raw), "capture")
        self.assertEqual(self.loss.status()["expectedVersion"], 1)
        self.assertEqual(envelope, untouched)
        self.assertEqual(json.loads(raw), untouched)
        self.assertTrue(self.loss.accepted(200, json.dumps(self.receipt).encode()))
        self.loss.release({"commandId": "command-test-1"})
        self.assertEqual(self.loss.inspect(TARGET, raw), "replay")
        self.assertTrue(self.loss.replayed(200, json.dumps(self.receipt).encode()))

    def test_only_two_inspected_integer_fields_are_decoded(self):
        envelope = self.android_envelope()
        envelope["data"]["command"]["payload"]["opaque"] = {"@type": "not-a-supported-type", "value": "unchanged"}
        raw = json.dumps(envelope).encode()
        self.loss.arm(self.identity)
        self.assertEqual(self.loss.inspect(TARGET, raw), "capture")
        # Payload remains opaque and the entire original representation is bound.
        changed = copy.deepcopy(envelope)
        changed["data"]["command"]["payload"]["opaque"]["value"] = "changed"
        with self.assertRaises(ValueError):
            self.loss.inspect(TARGET, json.dumps(changed).encode())
        self.assertEqual(self.loss.status()["guardRejectCount"], 1)

    def test_equivalent_number_reencoding_does_not_replace_original_replay(self):
        envelope = self.android_envelope()
        self.loss.arm(self.identity)
        self.loss.inspect(TARGET, json.dumps(envelope).encode())
        envelope["data"]["protocolVersion"] = 2
        with self.assertRaises(ValueError):
            self.loss.inspect(TARGET, json.dumps(envelope).encode())
        self.assertEqual(self.loss.status()["guardRejectCount"], 1)

    def test_integer_decoder_is_exact_canonical_and_bounded(self):
        for number in (0, 1, 2, -(1 << 63), (1 << 63) - 1):
            with self.subTest(number=number):
                self.assertEqual(callable_signed_integer(number), number)
                self.assertEqual(callable_signed_integer(self.wrapped(number)), number)
        malformed = [True, False, None, 2.0, "2", [], {},
            {"@type": "type.googleapis.com/google.protobuf.UInt64Value", "value": "2"},
            {"@type": "other", "value": "2"},
            {"@type": "type.googleapis.com/google.protobuf.Int64Value", "value": 2},
            {**self.wrapped(2), "extra": "not-allowed"},
            1 << 63, -(1 << 63) - 1]
        malformed += [self.wrapped(value) for value in ["", "00", "02", "-0", "+2", " 2", "2 ", "2.0", "2e0", "NaN", str(1 << 63), str(-(1 << 63) - 1)]]
        for value in malformed:
            with self.subTest(value=value):
                with self.assertRaises(ValueError):
                    callable_signed_integer(value)

    def test_wrapped_protocol_and_version_retain_semantic_bounds(self):
        for field, value in [("protocolVersion", 1), ("protocolVersion", 3), ("expectedVersion", -1)]:
            with self.subTest(field=field, value=value):
                loss = ReceiptLoss(); loss.arm(self.identity)
                envelope = self.android_envelope()
                target = envelope["data"] if field == "protocolVersion" else envelope["data"]["command"]
                target[field] = self.wrapped(value)
                with self.assertRaises(ValueError):
                    loss.inspect(TARGET, json.dumps(envelope).encode())
                self.assertEqual(loss.status()["phase"], "armed")
                self.assertEqual(loss.status()["forwardedAttempts"], 0)

    def test_handler_forwards_original_sdk_bytes_without_normalizing_payload(self):
        raw = json.dumps(self.android_envelope(), indent=2).encode()
        self.loss.arm(self.identity)
        captured = []
        class Response:
            status = 403
            def read(self, limit): return b'{"error":{"status":"PERMISSION_DENIED"}}'
            def getheader(self, name, fallback): return fallback
        class Connection:
            def __init__(self, *args, **kwargs): pass
            def request(self, method, path, body, headers): captured.append((method, path, body, headers))
            def getresponse(self): return Response()
            def close(self): pass
        handler = Handler.__new__(Handler)
        handler.path = TARGET; handler.headers = {"Content-Length": str(len(raw))}
        handler.rfile = io.BytesIO(raw); handler.wfile = io.BytesIO(); handler.loss = self.loss
        handler.send_response = lambda *args: None
        handler.send_header = lambda *args: None
        handler.end_headers = lambda: None
        with patch('required_red_transport_relay.http.client.HTTPConnection', Connection):
            handler.do_POST()
        self.assertEqual(len(captured), 1)
        self.assertEqual(captured[0][2], raw)
        self.assertEqual(captured[0][3]["Content-Length"], str(len(raw)))
        self.assertEqual(self.loss.status()["phase"], "failed")


if __name__ == "__main__":
    unittest.main()
