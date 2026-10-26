"""Real Windows owned-job regressions; only fresh, explicit local test children.

No credential lookup, network, provider command or existing process selection.
The supervisor alone closes its test job; fixture evidence is retained.
"""
import ast
import ctypes
from ctypes import wintypes
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import types
import unittest

SOURCE = Path(__file__).with_name("runtime_supervisor.py")
EVIDENCE = Path(os.environ["SUPERVISOR_ORPHAN_TEST_ROOT"]) if "SUPERVISOR_ORPHAN_TEST_ROOT" in os.environ else Path(tempfile.mkdtemp(prefix="supervisor-orphan-tests-"))

GRANDCHILD = """
import json, os, sys, time
from pathlib import Path
root, delay, payload = Path(sys.argv[1]), float(sys.argv[2]), int(sys.argv[3])
record = {'pid': os.getpid(), 'parentPid': os.getppid()}
(root / 'grandchild-ready.json').write_text(json.dumps(record), encoding='utf-8')
print(json.dumps({'event': 'grandchild-start', **record}), flush=True)
time.sleep(delay)
if payload:
    sys.stdout.write('D' * payload)
    sys.stdout.flush()
print('grandchild-complete', flush=True)
"""

LAUNCHER = """
import json, os, subprocess, sys, time
from pathlib import Path
root, delay, code, via_cmd, payload = Path(sys.argv[1]), sys.argv[2], int(sys.argv[3]), sys.argv[4] == 'cmd', sys.argv[5]
argv = [sys.executable, '-I', '-S', '-B', str(root / 'grandchild.py'), str(root), delay, payload]
if via_cmd:
    argv = [str(Path(os.environ['SystemRoot']) / 'System32/cmd.exe'), '/d', '/s', '/c', subprocess.list2cmdline(argv)]
child = subprocess.Popen(argv, stdin=subprocess.DEVNULL, creationflags=subprocess.CREATE_NO_WINDOW)
deadline = time.monotonic() + 10
while not (root / 'grandchild-ready.json').exists():
    if child.poll() is not None or time.monotonic() >= deadline:
        raise RuntimeError('Fresh owned test child did not become ready')
    time.sleep(0.01)
print(json.dumps({'event': 'root-exit', 'pid': os.getpid(), 'childPid': child.pid, 'code': code}), flush=True)
raise SystemExit(code)
"""


class PortableOrphanPolicyTests(unittest.TestCase):
    def policy(self):
        tree = ast.parse(SOURCE.read_text(encoding="utf-8"))
        selected = [n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == "_root_exit_grace_expired"]
        self.assertEqual(len(selected), 1)
        namespace = {}
        exec(compile(ast.Module(body=selected, type_ignores=[]), str(SOURCE), "exec"), namespace)
        return namespace["_root_exit_grace_expired"]

    def test_real_root_exit_policy_boundaries(self):
        policy = self.policy()
        cases = [(False, 1, 100, None, False), (False, 5, 100, None, False),
                 (True, 0, 100, None, False), (True, 1, 9.99, 10, False),
                 (True, 1, 10, 10, True), (True, 2, 10.01, 10, True)]
        for root_exited, active, now, deadline, expected in cases:
            with self.subTest(rootExited=root_exited, active=active, now=now, deadline=deadline):
                self.assertEqual(policy(root_exited, active, now, deadline), expected)

    def test_grace_is_fixed_and_used_by_actual_wait_loop(self):
        tree = ast.parse(SOURCE.read_text(encoding="utf-8"))
        values = [n.value.value for n in tree.body if isinstance(n, ast.Assign)
                  and any(isinstance(t, ast.Name) and t.id == "ROOT_EXIT_GRACE_SECONDS" for t in n.targets)]
        self.assertEqual(values, [2.0])
        run = [n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == "run_owned_process"]
        calls = [n for n in ast.walk(run[0]) if isinstance(n, ast.Call)
                 and isinstance(n.func, ast.Name) and n.func.id == "_root_exit_grace_expired"]
        self.assertEqual(len(calls), 1)


@unittest.skipUnless(os.name == "nt", "Real Windows job supervision required")
class OwnedOrphanTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        EVIDENCE.mkdir(parents=True, exist_ok=True)
        cls.supervisor = types.ModuleType("orphan_test_supervisor")
        cls.supervisor.__file__ = str(SOURCE)
        # Match the production runner's measured-source execution, not pycache.
        cls.source_bytes = SOURCE.read_bytes()
        exec(compile(cls.source_bytes, str(SOURCE), "exec", dont_inherit=True), cls.supervisor.__dict__)

    def fixture(self):
        root = EVIDENCE / self._testMethodName
        root.mkdir()
        (root / "grandchild.py").write_text(GRANDCHILD, encoding="utf-8")
        (root / "launcher.py").write_text(LAUNCHER, encoding="utf-8")
        return root

    def run_owned(self, root, arguments, timeout=20):
        windows = os.environ.get("SystemRoot", "C:/Windows")
        env = {"SystemRoot": windows, "WINDIR": windows, "HOME": str(root),
               "USERPROFILE": str(root), "TEMP": str(root), "TMP": str(root)}
        start = time.monotonic()
        result = self.supervisor.run_owned_process(
            executable=sys.executable, arguments=arguments, cwd=str(root), environment=env,
            output_directory=str(root / "owned"), timeout_seconds=timeout,
            max_output_bytes=2 * 1024 * 1024, cleanup_seconds=5)
        elapsed = time.monotonic() - start
        (root / "TEST_SCOPE.json").write_text(json.dumps({
            "supervisorSha256": hashlib.sha256(self.source_bytes).hexdigest().upper(),
            "elapsedSeconds": elapsed, "scope": "Fresh local owned job; no provider/network/credential operations",
        }, indent=2) + "\n", encoding="utf-8")
        self.assertTrue(result["rootExited"])
        self.assertTrue(result["treeComplete"])
        self.assertEqual(result["activeProcesses"], 0)
        self.assertTrue(result["outputComplete"])
        self.assertEqual(result["cleanupErrors"], [])
        self.assertTrue(all(v["eof"] and v["error"] is None for v in result["streams"].values()))
        return result, elapsed

    def assert_own_child_stopped(self, root):
        pid = json.loads((root / "grandchild-ready.json").read_text(encoding="utf-8"))["pid"]
        api = ctypes.WinDLL("kernel32", use_last_error=True)
        open_process = api.OpenProcess
        open_process.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
        open_process.restype = wintypes.HANDLE
        handle = open_process(0x100000, False, pid)
        if not handle:
            self.assertIn(ctypes.get_last_error(), (87, 1168))
            return
        try:
            api.WaitForSingleObject.argtypes = [wintypes.HANDLE, wintypes.DWORD]
            api.WaitForSingleObject.restype = wintypes.DWORD
            self.assertEqual(api.WaitForSingleObject(handle, 0), 0, "Fresh test-owned child survived cleanup")
        finally:
            api.CloseHandle.argtypes = [wintypes.HANDLE]
            api.CloseHandle.restype = wintypes.BOOL
            self.assertTrue(api.CloseHandle(handle))

    def assert_orphan(self, code, via_cmd=False):
        root = self.fixture()
        result, elapsed = self.run_owned(root, ["-I", "-S", "-B", str(root / "launcher.py"),
            str(root), "60", str(code), "cmd" if via_cmd else "direct", "0"])
        self.assertEqual(result["status"], "FAILED")
        self.assertEqual(result["failure"], "root-exited-with-live-descendants")
        self.assertEqual(result["exitCode"], code)
        self.assertTrue(result["terminationRequested"])
        self.assertGreaterEqual(elapsed, self.supervisor.ROOT_EXIT_GRACE_SECONDS)
        self.assertLess(elapsed, 10, "Orphan must fail before the unchanged execution timeout")
        self.assert_own_child_stopped(root)
        stdout = (root / "owned/stdout.bin").read_text(encoding="utf-8")
        self.assertIn('"event": "grandchild-start"', stdout)
        self.assertIn('"event": "root-exit"', stdout)
        self.assertNotIn("grandchild-complete", stdout)

    def test_nonzero_root_orphan_preserves_exit_code(self):
        self.assert_orphan(7)

    def test_zero_root_orphan_is_failure(self):
        self.assert_orphan(0)

    def test_cmd_wrapper_grandchild_orphan_is_closed(self):
        self.assert_orphan(7, via_cmd=True)

    def test_child_finishes_within_grace_and_output_drains(self):
        root = self.fixture()
        result, elapsed = self.run_owned(root, ["-I", "-S", "-B", str(root / "launcher.py"),
            str(root), "0.3", "0", "direct", "131072"])
        self.assertEqual(result["status"], "SUCCESS")
        self.assertIsNone(result["failure"])
        self.assertEqual(result["exitCode"], 0)
        self.assertFalse(result["terminationRequested"])
        self.assertLess(elapsed, 10)
        self.assert_own_child_stopped(root)
        stdout = (root / "owned/stdout.bin").read_bytes()
        self.assertIn(b"D" * 131072, stdout)
        self.assertIn(b"grandchild-complete", stdout)

    def test_clean_root_succeeds_without_termination(self):
        root = self.fixture()
        result, _ = self.run_owned(root, ["-I", "-S", "-B", "-c", "print('clean')"])
        self.assertEqual(result["status"], "SUCCESS")
        self.assertIsNone(result["failure"])
        self.assertEqual(result["exitCode"], 0)
        self.assertFalse(result["terminationRequested"])
        self.assertEqual((root / "owned/stdout.bin").read_bytes(), b"clean\r\n")

    def test_clean_nonzero_root_keeps_existing_failure(self):
        root = self.fixture()
        result, _ = self.run_owned(root, ["-I", "-S", "-B", "-c", "raise SystemExit(7)"])
        self.assertEqual(result["status"], "FAILED")
        self.assertEqual(result["failure"], "nonzero-root-exit")
        self.assertEqual(result["exitCode"], 7)
        self.assertFalse(result["terminationRequested"])

    def test_live_root_keeps_existing_timeout(self):
        root = self.fixture()
        result, _ = self.run_owned(root, ["-I", "-S", "-B", "-c", "import time; time.sleep(60)"], timeout=0.4)
        self.assertEqual(result["status"], "FAILED")
        self.assertEqual(result["failure"], "timeout")
        self.assertEqual(result["exitCode"], self.supervisor.TERMINATION_CODE)
        self.assertTrue(result["terminationRequested"])


if __name__ == "__main__":
    print("Retained orphan test fixtures: " + str(EVIDENCE), flush=True)
    unittest.main(verbosity=2)
