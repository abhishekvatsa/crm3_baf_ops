"use strict";
// Filesystem and launch-boundary tests use inert text, never a Python executable.
// Expected maps are independently enumerated here; no validator creates them.
const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const os = require("node:os");
const crypto = require("node:crypto");
const cp = require("node:child_process");
const collector = require("./collectBusinessRuntime31.cjs");
const sha = bytes => crypto.createHash("sha256").update(bytes).digest("hex").toUpperCase();

function inventory(root) {
  const result = {};
  function visit(directory, prefix = "") {
    for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
      assert.equal(entry.isSymbolicLink(), false);
      const name = prefix + entry.name;
      const file = path.join(directory, entry.name);
      if (entry.isDirectory()) visit(file, name + "/");
      else {
        assert.equal(entry.isFile(), true);
        Object.defineProperty(result, name, {
          value: sha(fs.readFileSync(file)), enumerable: true, writable: true, configurable: true,
        });
      }
    }
  }
  visit(root);
  return result;
}

function fixture(t) {
  const owned = fs.mkdtempSync(path.join(os.tmpdir(), "business-python-map-"));
  const root = path.join(owned, "selected");
  fs.mkdirSync(root);
  t.diagnostic("Retained inert Python runtime fixture: " + owned);
  const put = (name, bytes) => {
    const file = path.join(root, name);
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, bytes);
    return file;
  };
  for (const name of [
    "python.exe", "python3.dll", "python313.dll", "vcruntime140.dll",
    "Lib/os.py", "Lib/encodings/__init__.py", "Lib/pathlib/__init__.py",
    "Lib/ctypes/__init__.py", "DLLs/_ctypes.pyd", "DLLs/libffi-8.dll",
  ]) put(name, Buffer.from("Inert fixture; never execute: " + name + "\n"));
  const files = inventory(root);
  const python = {
    schemaVersion: 2, root,
    executable: { path: path.join(root, "python.exe"), sha256: files["python.exe"] },
    files,
  };
  return { owned, root, put, python };
}

function interceptedSpawn(action, callback) {
  const previous = cp.spawnSync;
  const calls = [];
  cp.spawnSync = (...args) => {
    calls.push(args);
    return action(...args);
  };
  try { callback(calls); }
  finally { cp.spawnSync = previous; }
}

test("complete independently measured inert installation is accepted without execution", t => {
  const f = fixture(t);
  const result = collector.verifyPythonRuntime31(f.python);
  assert.equal(result.root, f.root);
  assert.equal(result.executable, f.python.executable.path);
  assert.equal(result.files, Object.keys(f.python.files).length);
});

for (const [name, mutate] of [
  ["omitted stdlib map member", f => { delete f.python.files["Lib/pathlib/__init__.py"]; }],
  ["changed stdlib bytes", f => f.put("Lib/ctypes/__init__.py", "changed inert bytes")],
  ["changed native dependency bytes", f => f.put("DLLs/libffi-8.dll", "changed inert bytes")],
  ["added executable import module", f => f.put("Lib/unlisted.py", "inert omitted module")],
  ["added ZIP search entry", f => f.put("python313.zip", "inert never-opened archive")],
  ["deleted retained stdlib", f => fs.unlinkSync(path.join(f.root, "Lib/pathlib/__init__.py"))],
]) test("refuses " + name + " before the Python launch boundary", t => {
  const f = fixture(t);
  mutate(f);
  interceptedSpawn(() => { throw Error("INERT_PYTHON_MUST_NEVER_EXECUTE"); }, calls => {
    assert.throws(() => collector.runPythonRunner31(f.python, null, {}), /complete Python population differs/);
    assert.equal(calls.length, 0);
  });
});

test("explicit complete map includes an optional ZIP without interpreting it", t => {
  const f = fixture(t);
  f.put("python313.zip", "inert archive; integrity only, no execution");
  f.python.files = inventory(f.root);
  assert.equal(collector.verifyPythonRuntime31(f.python).files, Object.keys(f.python.files).length);
});

for (const name of ["python._pth", "PYTHON313._PTH", "pyvenv.cfg", "pybuilddir.txt", "Modules/Setup.local"]) {
  test("refuses bound startup override " + name, t => {
    const f = fixture(t);
    f.put(name, "inert path override");
    f.python.files = inventory(f.root);
    interceptedSpawn(() => { throw Error("INERT_PYTHON_MUST_NEVER_EXECUTE"); }, calls => {
      assert.throws(() => collector.runPythonRunner31(f.python, null, {}), /Python startup override refused|Python build landmark refused/);
      assert.equal(calls.length, 0);
    });
  });
}

test("refuses parent virtual-environment redirection outside the complete root", t => {
  const f = fixture(t);
  fs.writeFileSync(path.join(f.owned, "pyvenv.cfg"), "home = inert-outside\n");
  assert.throws(() => collector.verifyPythonRuntime31(f.python), /Python startup override refused/);
});

for (const [name, mutate, expected] of [
  ["legacy subset schema", f => { f.python = { executable: f.python.executable, files: f.python.files }; }, /Python installation fields differ/],
  ["case-colliding expected member", f => { f.python.files["LIB/OS.PY"] = f.python.files["Lib/os.py"]; }, /Python map path\/hash differs/],
  ["relative traversal", f => { f.python.files["../outside.py"] = "A".repeat(64); }, /Python map path\/hash differs/],
  ["alternate executable", f => { f.python.executable.path = path.join(f.root, "pythonw.exe"); }, /standard Python executable required/],
  ["missing startup encoding landmark", f => { delete f.python.files["Lib/encodings/__init__.py"]; }, /standard Python landmark absent/],
]) test("refuses " + name, t => {
  const f = fixture(t);
  mutate(f);
  assert.throws(() => collector.verifyPythonRuntime31(f.python), expected);
});

test("refuses directory redirect without following the outside population", t => {
  const f = fixture(t);
  const outside = path.join(f.owned, "outside");
  fs.mkdirSync(outside);
  fs.writeFileSync(path.join(outside, "marker.txt"), "never imported");
  const link = path.join(f.root, "Lib", "redirect");
  fs.symlinkSync(outside, link, process.platform === "win32" ? "junction" : "dir");
  assert.throws(() => collector.verifyPythonRuntime31(f.python), /Python runtime redirect refused/);
  assert.equal(fs.readFileSync(path.join(outside, "marker.txt"), "utf8"), "never imported");
});

test("launch helper uses exact isolated flags and revalidates drift before each child", t => {
  const f = fixture(t);
  const returned = { status: 0, stdout: Buffer.from("original inert output"), stderr: Buffer.alloc(0) };
  interceptedSpawn((executable, argv) => {
    assert.equal(executable, f.python.executable.path);
    assert.deepEqual(argv, ["-I", "-S", "-B", path.join(__dirname, "runtime_process_runner.py"), "--python-root", f.root, "--check-ports"]);
    return returned;
  }, calls => {
    assert.equal(collector.runPythonRunner31(f.python, null, {}), returned);
    assert.equal(calls.length, 1);
    f.put("Lib/ctypes/__init__.py", "changed after first completed launch boundary");
    assert.throws(() => collector.runPythonRunner31(f.python, null, {}), /complete Python population differs/);
    assert.equal(calls.length, 1);
  });
});

test("post-launch drift refuses and retains exact captured output object", t => {
  const f = fixture(t);
  const returned = { status: 0, stdout: Buffer.from([0, 255, 13]), stderr: Buffer.from("inert original diagnostic") };
  interceptedSpawn(() => {
    f.put("Lib/pathlib/__init__.py", "changed at simulated process completion");
    return returned;
  }, calls => {
    assert.throws(() => collector.runPythonRunner31(f.python, path.join(f.owned, "request.json"), {}), error => {
      assert.match(error.message, /complete Python population differs/);
      assert.equal(error.pythonResult, returned);
      return true;
    });
    assert.equal(calls.length, 1);
  });
});

test("relative process request refuses before spawning", t => {
  const f = fixture(t);
  interceptedSpawn(() => { throw Error("INERT_PYTHON_MUST_NEVER_EXECUTE"); }, calls => {
    assert.throws(() => collector.runPythonRunner31(f.python, "relative.json", {}), /absolute runner request required/);
    assert.equal(calls.length, 0);
  });
});


test("caller cannot authorize post-launch drift by changing its original expected map", t => {
  const f = fixture(t);
  const originalExpected = f.python.files["Lib/pathlib/__init__.py"];
  const returned = { status: 0, stdout: Buffer.from("captured original bytes"), stderr: Buffer.alloc(0) };
  interceptedSpawn(() => {
    const file = f.put("Lib/pathlib/__init__.py", "changed along with caller map");
    f.python.files["Lib/pathlib/__init__.py"] = sha(fs.readFileSync(file));
    assert.notEqual(f.python.files["Lib/pathlib/__init__.py"], originalExpected);
    return returned;
  }, calls => {
    assert.throws(() => collector.runPythonRunner31(f.python, null, {}), error => {
      assert.match(error.message, /complete Python population differs/);
      assert.equal(error.pythonResult, returned);
      return true;
    });
    assert.equal(calls.length, 1);
  });
});
