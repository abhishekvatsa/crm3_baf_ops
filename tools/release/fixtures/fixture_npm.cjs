"use strict";
// Executed only as the tiny npm replacement approved by a synthetic test Git
// source. No installation, network, compiler, emulator or real audit occurs.
const fs = require("node:fs"), path = require("node:path");
const root = process.cwd(), args = process.argv.slice(2);
const config = JSON.parse(fs.readFileSync(path.join(root, "fixture-behaviour.json"), "utf8"));
const logRoot = path.join(root, ".dart_tool", "collector-fixture");
fs.mkdirSync(logRoot, {recursive:true});
fs.appendFileSync(path.join(logRoot,"invocations.jsonl"), JSON.stringify({argv:args,pid:process.pid,at:new Date().toISOString()})+"\n");
function put(file, value) {
  const full = path.join(root,file); fs.mkdirSync(path.dirname(full), {recursive:true});
  fs.writeFileSync(full, typeof value === "string" ? value : JSON.stringify(value));
}
const prefixIndex=args.indexOf("--prefix"), prefix=prefixIndex<0 ? "" : args[prefixIndex+1];
let kind=args[0]==="--version" ? "npm-version" : args[0]==="ci" ? (prefix==="functions"?"functions-install":prefix?"cli-install":"root-install") : args[0]==="run" ? args[1] : args[0];
if(config.failAt===kind){process.stdout.write(Buffer.from([0x66,0x61,0x69,0x6c,0x00,0xff]));process.stderr.write("retained inert failure\n");process.exitCode=23;}
else if(kind==="npm-version") process.stdout.write(config.npmVersion+"\n");
else if(args[0]==="ci") {
  if(!prefix) put("node_modules/fixture-root/package.json", {name:"fixture-root",version:"1.0.0"});
  else if(prefix==="functions") put("functions/node_modules/@grpc/grpc-js/package.json", {name:"@grpc/grpc-js",version:"1.14.5"});
  else if(prefix==="tooling/firebase-cli") {
    put("tooling/firebase-cli/node_modules/firebase-tools/package.json", {name:"firebase-tools",version:"15.22.4"});
    put("tooling/firebase-cli/node_modules/firebase-tools/lib/bin/firebase.js", "// Never executed: synthetic CLI inventory identity only.\n");
  } else throw Error("Unsupported fixture install prefix");
  process.stdout.write("Synthetic fixture files created; no dependency installation.\n");
}
else if(args[0]==="run") {
  if(["build","test","emulator:test:governed"].includes(args[1])) {
    const changed=config.changedOutputAt===args[1];
    put("functions/lib/index.js", changed ? "exports.value=2;\n" : "exports.value=1;\n");
    put("functions/lib/index.js.map", "{}\n");
    if(config.extraOutputAt===args[1]) put("functions/lib/unexpected.js", "// unexpected fixture output\n");
    if(config.changeSourceAt===args[1]) put("functions/src/index.ts", "export const value=99;\n");
  } else if(args[1]!=="test:dependency-compat") throw Error("Unsupported fixture script");
  process.stdout.write("Inert script "+args[1]+" completed.\n");
}
else if(args[0]==="ls") process.stdout.write(JSON.stringify({name:"fixture-functions",path:path.join(root,"functions"),dependencies:{"@grpc/grpc-js":{version:"1.14.5",path:path.join(root,"functions/node_modules/@grpc/grpc-js")}}})+"\n");
else if(args[0]==="audit") process.stdout.write(JSON.stringify({auditReportVersion:2,vulnerabilities:{},metadata:{vulnerabilities:{info:0,low:0,moderate:0,high:0,critical:0,total:0}}})+"\n");
else throw Error("Unsupported inert fixture npm argv");
