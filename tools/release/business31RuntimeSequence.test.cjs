"use strict";
const test = require("node:test"), assert = require("node:assert/strict"), fs = require("node:fs"), path = require("node:path"), os = require("node:os"), crypto = require("node:crypto");
const api = require("./business31BackendAuthority.cjs");
const sha = bytes => crypto.createHash("sha256").update(bytes).digest("hex").toUpperCase();
const scratch = fs.mkdtempSync(path.join(fs.realpathSync(os.tmpdir()), "business31-output-sequence-"));
let serial = 0;
// All records here are synthetic parser evidence; no build, test, npm or emulator
// process runs. Fresh cases remain available, including every failed assertion.
function fixture() {
  const root = path.join(scratch, String(++serial)), evidenceDirectory = path.join(root, "evidence"), lib = path.join(root, "functions/lib");
  fs.mkdirSync(evidenceDirectory, {recursive:true}); fs.mkdirSync(lib, {recursive:true});
  const outputs = {"lib/index.js": "exports.value=1;\n", "lib/index.js.map": "{}\n"};
  for (const [file, raw] of Object.entries(outputs)) fs.writeFileSync(path.join(root,"functions",file),raw);
  const map = Object.fromEntries(Object.entries(outputs).map(([file,raw]) => [file,sha(Buffer.from(raw))]));
  let id = 0;
  const retain = value => { const raw = Buffer.from(JSON.stringify(value)), file = `map-${++id}.json`; fs.writeFileSync(path.join(evidenceDirectory,file),raw); return {file,bytes:raw.length,sha256:sha(raw)}; };
  const time = second => `2026-01-02T02:00:${String(second).padStart(2,"0")}Z`;
  const testedEmittedFiles = {}, processRecords = {};
  for (const [i,kind] of api.OUTPUT_COMMANDS.entries()) {
    testedEmittedFiles[kind] = retain(map);
    processRecords[kind] = {schemaVersion:2,kind,startedAtUtc:time(i*2),completedAtUtc:time(i*2+1),emittedFilesAfterSha256:testedEmittedFiles[kind].sha256};
  }
  const input = {processRecords,testedEmittedFiles,buildRoot:root,evidenceDirectory,snapshot:{files:{"functions/src/index.ts":{}}},compilerConfig:{compilerOptions:{module:"commonjs",noImplicitReturns:true,noUnusedLocals:false,outDir:"lib",sourceMap:true,strict:true,target:"es2022"},compileOnSave:true,include:["src"]}};
  return {input,map,retain,time,check:()=>api.verifyTestedEmittedFiles31(input)};
}
test("ordered build and both internally rebuilding test groups bind the final output bytes",()=>{assert.equal(fixture().check(),2);});
for (const [name,mutate,error] of [
  ["standalone build after both tests", f=>{const r=f.input.processRecords["functions-build"];r.startedAtUtc=f.time(6);r.completedAtUtc=f.time(7);}, /tests must follow/],
  ["build overlaps host tests", f=>f.input.processRecords["functions-build"].completedAtUtc=f.time(3), /tests must follow/],
  ["host tests overlap emulator tests", f=>f.input.processRecords["functions-host-tests"].completedAtUtc=f.time(5), /tests must follow/],
  ["emulator tests precede host tests", f=>{const r=f.input.processRecords["governed-emulator-tests"];r.startedAtUtc=f.time(0);r.completedAtUtc=f.time(1);}, /tests must follow/],
  ["missing host output population", f=>delete f.input.testedEmittedFiles["functions-host-tests"], /tested emitted populations/],
  ["extra output population", f=>f.input.testedEmittedFiles.other=f.retain(f.map), /tested emitted populations/],
  ["legacy process without output binding", f=>{const r=f.input.processRecords["functions-build"];r.schemaVersion=1;delete r.emittedFilesAfterSha256;}, /command binding/],
  ["process map digest does not match retained map", f=>f.input.processRecords["functions-host-tests"].emittedFilesAfterSha256="A".repeat(64), /command binding/],
  ["test output differs although its map and process digest agree", f=>{const k="functions-host-tests",m={...f.map,"lib/index.js":"A".repeat(64)};f.input.testedEmittedFiles[k]=f.retain(m);f.input.processRecords[k].emittedFilesAfterSha256=f.input.testedEmittedFiles[k].sha256;}, /final emitted bytes/],
  ["map omits an emitted file", f=>{const k="functions-build",m={"lib/index.js":f.map["lib/index.js"]};f.input.testedEmittedFiles[k]=f.retain(m);f.input.processRecords[k].emittedFilesAfterSha256=f.input.testedEmittedFiles[k].sha256;}, /tested emitted population differs/],
  ["map adds an untested output", f=>{const k="governed-emulator-tests",m={...f.map,"lib/other.js":"A".repeat(64)};f.input.testedEmittedFiles[k]=f.retain(m);f.input.processRecords[k].emittedFilesAfterSha256=f.input.testedEmittedFiles[k].sha256;}, /tested emitted population differs/],
  ["output changed after final test", f=>fs.appendFileSync(path.join(f.input.buildRoot,"functions/lib/index.js"),"changed"), /final emitted bytes/],
  ["output added after final test", f=>fs.writeFileSync(path.join(f.input.buildRoot,"functions/lib/extra.js"),"extra"), /final tested output population/],
  ["nanosecond overlap", f=>{f.input.processRecords["functions-build"].completedAtUtc="2026-01-02T02:00:02.000000001Z";}, /tests must follow/],
]) test("output sequence refuses "+name,()=>{const f=fixture();mutate(f);assert.throws(f.check,error);});
test("adjacent command boundaries remain valid without inventing a delay",()=>{const f=fixture();f.input.processRecords["functions-host-tests"].startedAtUtc=f.time(1);f.input.processRecords["governed-emulator-tests"].startedAtUtc=f.time(3);assert.equal(f.check(),2);});
test("original command parser requires schema2 and exact output digest for tested commands",()=>{
  const f=fixture(),kind="functions-build",runtime={nodeExecutable:{path:process.execPath,sha256:sha(fs.readFileSync(process.execPath))}},source={commit:"a".repeat(40)},digest=f.input.testedEmittedFiles[kind].sha256;
  const record={...f.input.processRecords[kind],documentType:"build31-business-original-process",sourceBefore:source,sourceAfter:source,executable:runtime.nodeExecutable.path,executableSha256:runtime.nodeExecutable.sha256,argv:["synthetic-not-executed"],cwd:f.input.buildRoot,exitCode:0,signal:null,error:null,stdout:f.retain({fixture:true}),stderr:f.retain("")};
  const check=r=>api.verifyRecordedCommand31({record:r,source,kind,argv:record.argv,root:fs.realpathSync(f.input.buildRoot),runtime,start:f.time(0),end:f.time(20),evidenceDirectory:f.input.evidenceDirectory,emittedFilesAfterSha256:digest});
  assert.ok(Buffer.isBuffer(check(record).stdout));
  assert.throws(()=>check({...record,schemaVersion:1}),/exact command differs/);
  assert.throws(()=>check({...record,emittedFilesAfterSha256:"A".repeat(64)}),/command binding/);
  const missing={...record};delete missing.emittedFilesAfterSha256;assert.throws(()=>check(missing),/fields differ/);
});
