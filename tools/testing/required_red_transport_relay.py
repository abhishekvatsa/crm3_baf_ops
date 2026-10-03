"""A fixed demo-loopback transport that can lose one genuine RED receipt.

No business response is fabricated. The first exact armed command reaches the
real Functions emulator; only a proved successful response can be withheld.
The same saved command remains held until the second Android process releases
it. Every unrelated callable is forwarded unchanged. No token/body logging.
"""
from __future__ import annotations

import argparse
from datetime import datetime
import hashlib
import http.client
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import re
import socket
import threading
import time

PROJECT = "demo-crm3-ci-journeys"
REGION = "asia-south1"
LISTEN = ("127.0.0.1", 15002)
UPSTREAM = ("127.0.0.1", 15001)
PREFIX = f"/{PROJECT}/{REGION}/"
TARGET = PREFIX + "executeMaintenanceWorkflowCommandV2"
MAX_BYTES = 2 * 1024 * 1024


def callable_path(path):
    return re.fullmatch(re.escape(PREFIX) + r"[A-Za-z][A-Za-z0-9_]*", path) is not None


def digest(value):
    return hashlib.sha256(value).hexdigest()


def canonical_digest(value):
    return digest(json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode())



def callable_signed_integer(value):
    """Inspect only a declared integer field; never rewrite transport bytes."""
    if type(value) is int:
        number = value
    elif (isinstance(value, dict) and set(value) == {"@type", "value"}
            and value["@type"] == "type.googleapis.com/google.protobuf.Int64Value"
            and isinstance(value["value"], str)
            and re.fullmatch(r"0|-?[1-9][0-9]{0,18}", value["value"])):
        number = int(value["value"])
    else:
        raise ValueError("A plain integer or canonical Firebase Int64Value is required")
    if not -(1 << 63) <= number < (1 << 63):
        raise ValueError("Callable integer must be within signed 64-bit bounds")
    return number


def receipt_from_body(status, body):
    envelope = json.loads(body)
    result = envelope.get("result") if isinstance(envelope, dict) else None
    if status != 200 or not isinstance(result, dict):
        raise ValueError("A genuine successful callable receipt is required")
    if set(result) != {"commandId", "resultKey", "aggregateVersion", "appliedAt", "result"}:
        raise ValueError("Receipt must retain its full canonical field set")
    instant = result["appliedAt"]
    if not isinstance(instant, str) or not re.fullmatch(r"\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}(?:\d{3})?Z", instant):
        raise ValueError("Receipt appliedAt must be a canonical UTC instant")
    datetime.fromisoformat(instant.replace("Z", "+00:00"))
    return result


class ReceiptLoss:
    def __init__(self, evidence=None):
        self.lock = threading.Lock()
        self.evidence = evidence
        self.state = {"phase": "idle", "project": PROJECT, "forwardedAttempts": 0,
                      "withheldAttempts": 0, "replayForwardedAttempts": 0, "guardRejectCount": 0,
                      "verifiedReplayReceipts": 0, "replayReceiptMismatchCount": 0}
        self.envelope_hash = None
        self.sequence = 0

    def _record(self):
        if self.evidence is not None:
            self.sequence += 1
            with (self.evidence / f"receipt-loss-{self.sequence:04d}.json").open("x", encoding="utf-8") as out:
                json.dump(self.state, out, indent=2)
                out.write("\n")

    def status(self):
        with self.lock:
            return dict(self.state)

    def arm(self, data):
        if not isinstance(data, dict):
            raise ValueError("Control body must be an object")
        with self.lock:
            workflow = data.get("workflowId")
            actor = data.get("actorUid")
            if (set(data) != {"project", "workflowId", "complianceId", "actorUid"}
                    or data.get("project") != PROJECT
                    or not isinstance(workflow, str) or not re.fullmatch(r"red_[a-f0-9]{28}", workflow)
                    or data.get("complianceId") != workflow + "_preparation"
                    or not isinstance(actor, str) or not re.fullmatch(r"[A-Za-z0-9_-]{1,128}", actor)):
                raise ValueError("Exact synthetic RED workflow/compliance/actor identity required")
            if self.state["phase"] != "idle":
                raise ValueError("This relay can be armed only once; preserve prior evidence")
            self.state.update(data, phase="armed")
            self._record()
            return dict(self.state)

    def inspect(self, path, body):
        if path != TARGET:
            return "pass"
        transport = json.loads(body)
        if not isinstance(transport, dict):
            raise ValueError("Callable body must be an object")
        envelope = transport.get("data")
        if not isinstance(envelope, dict):
            return "pass"
        command = envelope.get("command")
        if not isinstance(command, dict):
            return "pass"
        payload = command.get("payload")
        if not isinstance(payload, dict):
            return "pass"
        with self.lock:
            state = self.state
            if state["phase"] == "idle":
                return "pass"
            if (envelope.get("originActorUid") != state["actorUid"]
                    or command.get("aggregateId") != state["workflowId"]
                    or command.get("commandType") != "acknowledgeCompliance"
                    or payload.get("complianceId") != state["complianceId"]):
                return "pass"
            if set(envelope) != {"protocolVersion", "originActorUid", "command"} or callable_signed_integer(envelope.get("protocolVersion")) != 2:
                raise ValueError("Armed command must retain its exact V2 origin envelope")
            expected = callable_signed_integer(command.get("expectedVersion"))
            if expected < 0:
                raise ValueError("Armed command needs a non-negative integer expectedVersion")
            command_id = command.get("commandId")
            if not isinstance(command_id, str) or not re.fullmatch(r"[A-Za-z0-9_-]{1,128}", command_id):
                raise ValueError("Invalid command identity")
            # Compare canonical envelope bytes rather than transport JSON spacing.
            fingerprint = digest(json.dumps(envelope, sort_keys=True, separators=(",", ":")).encode())
            if state["phase"] == "armed":
                self.envelope_hash = fingerprint
                state.update(phase="forwarding", commandId=command_id,
                             expectedVersion=expected, envelopeSha256=fingerprint)
                state["forwardedAttempts"] += 1
                self._record()
                return "capture"
            if command_id != state["commandId"] or fingerprint != self.envelope_hash:
                state["guardRejectCount"] += 1
                self._record()
                raise ValueError("A changed/repeated action cannot impersonate the held command")
            if state["phase"] in {"forwarding", "withheld"}:
                state["withheldAttempts"] += 1
                self._record()
                return "drop"
            if state["phase"] == "released":
                state["replayForwardedAttempts"] += 1
                self._record()
                return "replay"
            raise ValueError("Original upstream receipt was not accepted; no automatic retry")

    def accepted(self, status, body):
        with self.lock:
            try:
                result = receipt_from_body(status, body)
                valid = (isinstance(result, dict)
                    and result.get("commandId") == self.state["commandId"]
                    and result.get("resultKey") == "compliance-acknowledged"
                    and result.get("aggregateVersion") == self.state["expectedVersion"] + 1
                    and isinstance(result.get("result"), dict)
                    and result["result"].get("complianceId") == self.state["complianceId"])
            except (ValueError, TypeError, KeyError):
                valid = False
            self.state.update(phase="withheld" if valid else "failed", upstreamStatus=status,
                              upstreamResponseSha256=digest(body))
            if valid:
                self.state.update(acceptedResultKey=result["resultKey"],
                                  acceptedAggregateVersion=result["aggregateVersion"],
                                  acceptedAppliedAt=result["appliedAt"],
                                  acceptedResultSha256=canonical_digest(result["result"]),
                                  acceptedReceiptSha256=canonical_digest(result))
                self.state["withheldAttempts"] += 1
            self._record()
            return valid

    def replayed(self, status, body):
        """Observe the actual replay response; never replace or fabricate it."""
        with self.lock:
            try:
                result = receipt_from_body(status, body)
                fingerprint = canonical_digest(result)
                valid = fingerprint == self.state["acceptedReceiptSha256"]
            except (ValueError, TypeError, KeyError):
                fingerprint, valid = None, False
            self.state["lastReplayReceiptSha256"] = fingerprint
            key = "verifiedReplayReceipts" if valid else "replayReceiptMismatchCount"
            self.state[key] += 1
            self._record()
            return valid

    def release(self, data):
        if not isinstance(data, dict):
            raise ValueError("Control body must be an object")
        with self.lock:
            if (set(data) != {"commandId"} or self.state["phase"] != "withheld"
                    or data["commandId"] != self.state["commandId"]):
                raise ValueError("Only the exact accepted-but-undelivered command can be released")
            self.state["phase"] = "released"
            self._record()
            return dict(self.state)


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    loss: ReceiptLoss

    def log_message(self, *_args):
        pass  # No request headers, auth tokens, or business payloads in logs.

    def _json(self, code, value):
        body = json.dumps(value).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _drop(self, delay=0):
        if delay:
            time.sleep(delay)
        self.close_connection = True
        try:
            self.connection.shutdown(socket.SHUT_RDWR)
        except OSError:
            pass
        self.connection.close()

    def do_GET(self):
        if self.path == "/__required_red/status":
            self._json(200, self.loss.status())
        else:
            self._json(404, {"error": "Unknown fixed relay route"})

    def do_POST(self):
        try:
            size = int(self.headers.get("Content-Length", "0"))
            if not 0 < size <= MAX_BYTES or self.headers.get("Transfer-Encoding"):
                raise ValueError("A bounded request body is required")
            body = self.rfile.read(size)
            if len(body) != size:
                raise ValueError("Incomplete request")
            if self.path == "/__required_red/arm":
                self._json(200, self.loss.arm(json.loads(body)))
                return
            if self.path == "/__required_red/release":
                self._json(200, self.loss.release(json.loads(body)))
                return
            if not callable_path(self.path):
                raise ValueError("Only the fixed demo Functions namespace is permitted")
            action = self.loss.inspect(self.path, body)
            if action == "drop":
                self._drop()
                return
            headers = {k: v for k, v in self.headers.items()
                       if k.lower() not in {"host", "connection", "content-length", "transfer-encoding"}}
            headers["Content-Length"] = str(len(body))
            connection = http.client.HTTPConnection(*UPSTREAM, timeout=90)
            try:
                connection.request("POST", self.path, body, headers)
                response = connection.getresponse()
                payload = response.read(MAX_BYTES + 1)
                if len(payload) > MAX_BYTES:
                    raise ValueError("Upstream response exceeded bounded relay size")
                if action == "capture" and self.loss.accepted(response.status, payload):
                    # Gives the actual UI time to render its disabled busy control.
                    self._drop(delay=5)
                    return
                if action == "replay":
                    self.loss.replayed(response.status, payload)
                self.send_response(response.status)
                self.send_header("Content-Type", response.getheader("Content-Type", "application/json"))
                self.send_header("Content-Length", str(len(payload)))
                self.end_headers()
                self.wfile.write(payload)
            finally:
                connection.close()
        except (ValueError, TypeError, KeyError, json.JSONDecodeError):
            self._json(400, {"error": "Relay guard rejected request; no fallback or retry"})
        except (OSError, http.client.HTTPException):
            self._drop()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--evidence-dir", type=Path, required=True)
    args = parser.parse_args()
    args.evidence_dir.mkdir(parents=True, exist_ok=False)
    Handler.loss = ReceiptLoss(args.evidence_dir)
    server = ThreadingHTTPServer(LISTEN, Handler)
    print("REQUIRED_RED_RELAY_READY " + json.dumps({"listen": LISTEN, "upstream": UPSTREAM,
          "project": PROJECT, "businessResponsesFabricated": False}), flush=True)
    try:
        server.serve_forever()
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
