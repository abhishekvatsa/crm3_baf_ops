"""Actual runner on Windows; exact source-loader function on every platform.

All supervisor modules are inert markers that exit before Windows supervision.
Cache fixtures are deliberately untrusted; no real command is supervised here.
"""
import ast
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import py_compile
import shutil
import subprocess
import sys
import tempfile
import unittest

RUNNER = Path(__file__).with_name("runtime_process_runner.py")
EVIDENCE = Path(os.environ["SUPERVISOR_SOURCE_TEST_ROOT"]) if "SUPERVISOR_SOURCE_TEST_ROOT" in os.environ else Path(tempfile.mkdtemp(prefix="supervisor-source-tests-"))
EVIDENCE.mkdir(parents=True, exist_ok=True)

HARNESS = r"""
import ast
import atexit
import hashlib
import importlib.util
import json
from pathlib import Path
import runpy
import sys

mode, runner_name, request_name, replacement_name, count_name = sys.argv[1:]
runner, request_file = Path(runner_name), Path(request_name)
source = runner.with_name("runtime_supervisor.py")
reads = [0]
original_read = Path.read_bytes
if replacement_name != "none":
    replacement = original_read(Path(replacement_name))
    def read_once(self):
        data = original_read(self)
        if self == source:
            reads[0] += 1
            if reads[0] == 1:
                self.write_bytes(replacement)
        return data
    Path.read_bytes = read_once
atexit.register(lambda: Path(count_name).write_text(json.dumps({"sourcePathReads": reads[0]}), encoding="utf-8"))
if mode == "runner":
    sys.argv[:] = [str(runner), "--python-root", str(Path(sys.executable).parent), str(request_file)]
    runpy.run_path(str(runner), run_name="__main__")
else:
    tree = ast.parse(runner.read_text(encoding="utf-8"), filename=str(runner))
    functions = [n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == "load_supervisor"]
    if len(functions) != 1:
        raise AssertionError("one actual source-loader function required")
    code = compile(ast.Module(body=functions, type_ignores=[]), str(runner), "exec")
    namespace = {"hashlib": hashlib, "importlib": importlib}
    exec(code, namespace)
    request = json.loads(request_file.read_text(encoding="utf-8"))
    namespace["load_supervisor"](source, request["supervisorSha256"])
"""


def supervisor_bytes(marker):
    return ("import json\n"
            "print(json.dumps({'marker': " + repr(marker) + ", 'name': __name__, "
            "'file': __file__, 'package': __package__, 'origin': __spec__.origin, "
            "'hasLoader': __loader__ is not None}), flush=True)\n"
            "raise SystemExit(0)\n").encode("utf-8")


class SourceCases:
    mode = None

    def fixture(self):
        root = EVIDENCE / (self.mode + "-" + self._testMethodName)
        root.mkdir()
        runner = root / RUNNER.name
        shutil.copyfile(RUNNER, runner)
        source = root / "runtime_supervisor.py"
        source.write_bytes(supervisor_bytes("SOURCE"))
        request = {"schemaVersion": 1, "parentPid": os.getpid(),
                   "supervisorSha256": hashlib.sha256(source.read_bytes()).hexdigest().upper(),
                   "executable": sys.executable, "arguments": [], "cwd": str(root),
                   "environment": {}, "outputDirectory": str(root / "unused-output"),
                   "timeoutSeconds": 1, "maxOutputBytes": 1024, "cleanupSeconds": 1}
        (root / "request.json").write_text(json.dumps(request), encoding="utf-8")
        (root / "harness.py").write_text(HARNESS, encoding="utf-8")
        return root, source, request

    def make_cache(self, source, mode, marker="CACHED", forged=False):
        original, stat = source.read_bytes(), source.stat()
        self.assertEqual(len(original), len(supervisor_bytes(marker)))
        source.write_bytes(supervisor_bytes(marker))
        os.utime(source, ns=(stat.st_atime_ns, stat.st_mtime_ns))
        cache = Path(py_compile.compile(str(source), doraise=True, invalidation_mode=mode))
        source.write_bytes(original)
        os.utime(source, ns=(stat.st_atime_ns, stat.st_mtime_ns))
        if forged:
            data = bytearray(cache.read_bytes())
            self.assertEqual(int.from_bytes(data[4:8], "little"), 3)
            data[8:16] = importlib.util.source_hash(original)
            cache.write_bytes(data)
        return cache

    def invoke(self, root, replacement=False):
        replacement_file = root / "replacement.py"
        if replacement:
            replacement_file.write_bytes(supervisor_bytes("REPLACED"))
        argv = [sys.executable, "-I", "-S", "-B", str(root / "harness.py"), self.mode,
                str(root / RUNNER.name), str(root / "request.json"),
                str(replacement_file) if replacement else "none", str(root / "reads.json")]
        # Explicit small environment. No credentials, Python/Node startup options,
        # config directories or inherited package search paths enter the child.
        env = {k: os.environ[k] for k in ("SystemRoot", "WINDIR") if k in os.environ}
        env.update({"HOME": str(root), "USERPROFILE": str(root), "TEMP": str(root), "TMP": str(root)})
        result = subprocess.run(argv, cwd=root, env=env, capture_output=True, timeout=15)
        (root / "stdout.bin").write_bytes(result.stdout)
        (root / "stderr.bin").write_bytes(result.stderr)
        (root / "result.json").write_text(json.dumps({"argv": argv, "exitCode": result.returncode,
            "pythonVersion": sys.version, "scope": self.mode,
            "stdoutSha256": hashlib.sha256(result.stdout).hexdigest().upper(),
            "stderrSha256": hashlib.sha256(result.stderr).hexdigest().upper()}, indent=2), encoding="utf-8")
        return result

    def assert_source(self, root, result):
        self.assertEqual(result.returncode, 0, result.stderr.decode(errors="replace"))
        value = json.loads(result.stdout)
        self.assertEqual(value["marker"], "SOURCE")
        self.assertEqual(value["name"], "private_runtime_supervisor")
        self.assertEqual(Path(value["file"]), root / "runtime_supervisor.py")
        self.assertEqual(Path(value["origin"]), root / "runtime_supervisor.py")
        self.assertEqual(value["package"], "")
        self.assertFalse(value["hasLoader"])

    def test_plain_source(self):
        root, source, _ = self.fixture()
        self.assert_source(root, self.invoke(root))
        self.assertFalse((root / "__pycache__").exists())

    def test_timestamp_cache(self):
        root, source, _ = self.fixture()
        cache = self.make_cache(source, py_compile.PycInvalidationMode.TIMESTAMP)
        before = cache.read_bytes()
        self.assert_source(root, self.invoke(root))
        self.assertEqual(cache.read_bytes(), before)

    def test_unchecked_hash_cache(self):
        root, source, _ = self.fixture()
        cache = self.make_cache(source, py_compile.PycInvalidationMode.UNCHECKED_HASH)
        before = cache.read_bytes()
        self.assert_source(root, self.invoke(root))
        self.assertEqual(cache.read_bytes(), before)

    def test_forged_checked_hash_cache(self):
        root, source, _ = self.fixture()
        cache = self.make_cache(source, py_compile.PycInvalidationMode.CHECKED_HASH, forged=True)
        before = cache.read_bytes()
        self.assert_source(root, self.invoke(root))
        self.assertEqual(cache.read_bytes(), before)

    def test_stale_checked_hash_cache(self):
        root, source, _ = self.fixture()
        self.make_cache(source, py_compile.PycInvalidationMode.CHECKED_HASH)
        self.assert_source(root, self.invoke(root))

    def test_matching_checked_hash_cache(self):
        root, source, _ = self.fixture()
        self.make_cache(source, py_compile.PycInvalidationMode.CHECKED_HASH, marker="SOURCE")
        self.assert_source(root, self.invoke(root))

    def test_source_digest_mismatch_before_execution(self):
        root, source, request = self.fixture()
        self.make_cache(source, py_compile.PycInvalidationMode.UNCHECKED_HASH)
        request["supervisorSha256"] = "0" * 64
        (root / "request.json").write_text(json.dumps(request), encoding="utf-8")
        result = self.invoke(root)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(b"Supervisor bytes differ", result.stderr)
        self.assertEqual(result.stdout, b"")

    def test_source_replacement_after_read(self):
        root, source, _ = self.fixture()
        self.assert_source(root, self.invoke(root, replacement=True))
        self.assertEqual(source.read_bytes(), supervisor_bytes("REPLACED"))
        self.assertEqual(json.loads((root / "reads.json").read_text(encoding="utf-8"))["sourcePathReads"], 1)


class PortableLoaderTests(SourceCases, unittest.TestCase):
    mode = "portable-exact-function"


@unittest.skipUnless(sys.platform == "win32" and sys.version_info[:2] == (3, 13),
                     "Complete runner requires Windows Python3.13; portable exact-function cases still run")
class WindowsRunnerTests(SourceCases, unittest.TestCase):
    mode = "runner"


if __name__ == "__main__":
    print("Retained supervisor source fixtures: " + str(EVIDENCE), flush=True)
    unittest.main(verbosity=2)
