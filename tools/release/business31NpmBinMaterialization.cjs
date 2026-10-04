"use strict";
// Explicit preparation of a newly owned npm build tree. Never run on retained evidence.
const fs = require("node:fs"), path = require("node:path"), crypto = require("node:crypto");
const {isDeepStrictEqual, TextDecoder} = require("node:util");
const physical = require("./business31ExecutionContract.cjs").physical;
const SELF = "tools/release/business31NpmBinMaterialization.cjs";
const ROOTS = Object.freeze({root:"node_modules",functions:"functions/node_modules",cli:"tooling/firebase-cli/node_modules"});
const MARKER = "#!/bin/sh\n# build31 measured npm Node launcher v1\n";
const sha = bytes => crypto.createHash("sha256").update(bytes).digest("hex").toUpperCase();
const need = (value,message) => { if(!value) throw Error("Business31 npm materialization: " + message); };
function own(map,name,value) { need(!Object.hasOwn(map,name),"duplicate inventory member"); Object.defineProperty(map,name,{value,enumerable:true,writable:true,configurable:true}); }
function canonical(value) { if(Array.isArray(value))return "["+value.map(canonical).join(",")+"]"; if(value&&typeof value==="object")return "{"+Object.keys(value).sort().map(k=>JSON.stringify(k)+":"+canonical(value[k])).join(",")+"}";return JSON.stringify(value); }
function exact(value,fields,label) { need(value&&typeof value==="object"&&!Array.isArray(value)&&[Object.prototype,null].includes(Object.getPrototypeOf(value))&&isDeepStrictEqual(Object.keys(value).sort(),[...fields].sort()),label+" fields differ"); }
function portable(value) { need(typeof value==="string"&&value.length>0&&value.length<=400&&/^[A-Za-z0-9_@+.~/-]+$/.test(value)&&!value.startsWith("/")&&value.split("/").every(p=>p&&p!=="."&&p!==".."&&!/[. ]$/.test(p)&&!/^(?:con|prn|aux|nul|com[0-9]|lpt[0-9])(?:\.|$)/i.test(p)),"unsafe relative member");return value; }
function bytes(file) { file=physical(file);const before=fs.statSync(file,{bigint:true});need(before.size<=128n*1024n*1024n,"file bound exceeded");const value=fs.readFileSync(file),after=fs.statSync(file,{bigint:true});need(before.size===after.size&&before.ino===after.ino&&before.mtimeNs===after.mtimeNs&&before.ctimeNs===after.ctimeNs&&BigInt(value.length)===after.size,"member changed during read");return value; }
function jsonFile(file) { const raw=bytes(file);need(raw.length<=8*1024*1024,"package manifest bound exceeded");const value=JSON.parse(new TextDecoder("utf-8",{fatal:true}).decode(raw));need(value&&typeof value==="object"&&!Array.isArray(value),"package manifest must be an object");return {value,raw}; }
function verifyNodeShebang31(targetBytes) {
  need(Buffer.isBuffer(targetBytes),"bin bytes required");
  const newline=targetBytes.indexOf(10);
  need(newline>0&&newline<=255,"complete bin shebang exceeds bound or lacks newline");
  const first=targetBytes.subarray(0,newline).toString("utf8").replace(/\r$/,"");
  need(/^#![ \t]*(?:\/usr\/bin\/env[ \t]+node|\/usr\/(?:local\/)?bin\/node)[ \t]*$/.test(first),"unsupported bin interpreter or flags");
  return true;
}
function aliasDescription(root,file,linkTarget) {
  portable(file);const directory=path.posix.dirname(file),binName=path.posix.basename(file);
  need(directory===".bin"||directory.endsWith("/node_modules/.bin"),"only npm .bin file aliases are supported");
  need(typeof linkTarget==="string"&&linkTarget.length>0&&linkTarget.length<=400&&!path.posix.isAbsolute(linkTarget)&&!path.win32.isAbsolute(linkTarget)&&!/[\\\0\r\n]/.test(linkTarget),"relative alias target required");
  const spelling=linkTarget, target=path.posix.normalize(path.posix.join(directory,spelling));portable(target);
  need(path.posix.relative(directory,target)===spelling,"noncanonical alias target");
  const packageParent=directory===".bin"?"":directory.slice(0,-4),remaining=target.slice(packageParent.length);
  need(target.startsWith(packageParent)&&remaining.length>0,"alias target leaves its package population");
  const parts=remaining.split("/"), packageParts=parts[0].startsWith("@")?2:1;
  need(parts.length>packageParts&&parts.slice(0,packageParts).every(v=>v&&v!==".bin"),"package-owned alias target required");
  const packageRoot=packageParent+parts.slice(0,packageParts).join("/"),packageJson=packageRoot+"/package.json";
  const targetFile=physical(path.join(root,...target.split("/"))),packageFile=physical(path.join(root,...packageJson.split("/")));
  need(path.relative(root,targetFile).split(path.sep).join("/")===target&&path.relative(root,packageFile).split(path.sep).join("/")===packageJson,"alias target redirects");
  const {value:pkg,raw}=jsonFile(packageFile);let declaredBin;
  if(typeof pkg.bin==="string") { need(typeof pkg.name==="string"&&pkg.name.split("/").at(-1)===binName,"string bin name differs");declaredBin=pkg.bin; }
  else { need(pkg.bin&&typeof pkg.bin==="object"&&!Array.isArray(pkg.bin)&&Object.hasOwn(pkg.bin,binName),"alias is not package-declared");declaredBin=pkg.bin[binName]; }
  need(typeof declaredBin==="string","declared bin must name a file");const declared=declaredBin.startsWith("./")?declaredBin.slice(2):declaredBin;portable(declared);
  need(packageRoot+"/"+declared===target,"alias target differs from package bin declaration");
  const targetBytes=bytes(targetFile);verifyNodeShebang31(targetBytes);
  return {file,linkTarget,target,packageJson,packageJsonSha256:sha(raw),binName,declaredBin,targetSha256:sha(targetBytes),targetMode:fs.statSync(targetFile).mode&0o777};
}
const quote = value => "'"+value.replace(/'/g,"'\\''")+"'";
function launcherBytes31(nodeExecutable,file,target) {
  need(typeof nodeExecutable==="string"&&path.isAbsolute(nodeExecutable)&&!/[\0\r\n]/.test(nodeExecutable),"absolute Node executable required");portable(file);portable(target);
  const relative=path.posix.relative(path.posix.dirname(file),target);need(relative.startsWith("../"),"launcher target must remain in its owning package");
  return Buffer.from(MARKER+'case "$0" in */*) basedir=${0%/*} ;; *) basedir=. ;; esac\n'+'basedir=$(CDPATH= cd -- "$basedir" && pwd) || exit 1\n'+"exec "+quote(nodeExecutable)+' "$basedir/'+relative+'" "$@"\n');
}
function scan31(root,allowAliases=false) {
  root=physical(root,true);const files={},aliases=[];let count=0,total=0;
  function walk(directory) { for(const entry of fs.readdirSync(directory,{withFileTypes:true}).sort((a,b)=>a.name.localeCompare(b.name))) {
    const full=path.join(directory,entry.name),file=portable(path.relative(root,full).split(path.sep).join("/"));
    if(entry.isDirectory()) { physical(full,true);walk(full);continue; }
    need(++count<=100000,"file population exceeds bound");
    if(entry.isSymbolicLink()) { need(allowAliases,"regular installed population required");const raw=fs.readlinkSync(full),info=aliasDescription(root,file,raw);need(fs.realpathSync(full)===physical(path.join(root,...info.target.split("/"))),"actual alias does not resolve to its declared target");aliases.push(info);own(files,file,sha(Buffer.from(raw)));total+=Buffer.byteLength(raw); }
    else { need(entry.isFile(),"unsupported filesystem member");const raw=bytes(full);total+=raw.length;own(files,file,sha(raw)); }
    need(total<=2*1024*1024*1024,"installed population exceeds bound");
  }}walk(root);need(Object.keys(files).length===count,"inventory cardinality differs");return {files,aliases:aliases.sort((a,b)=>a.file.localeCompare(b.file)),count};
}
function materializeNpmBins31({buildRoot}) {
  buildRoot=physical(buildRoot,true);const nodeExecutable=physical(process.execPath),before={};
  // Validate every root and target before changing any alias. Never follow directory links.
  for(const [kind,directory] of Object.entries(ROOTS)) before[kind]=scan31(path.join(buildRoot,directory),true);
  need(process.platform!=="win32"||Object.values(before).every(row=>row.aliases.length===0),"Windows npm must retain its regular shims; alias normalization is POSIX only");
  const roots={};
  for(const [kind,directory] of Object.entries(ROOTS)) {
    const root=path.join(buildRoot,directory),previous=before[kind],aliases=[];
    need(isDeepStrictEqual(scan31(root,true),previous),"installed population changed before materialization");
    for(const info of previous.aliases) {
      const full=path.join(root,...info.file.split("/"));need(fs.lstatSync(full).isSymbolicLink()&&fs.readlinkSync(full)===info.linkTarget,"alias changed before replacement");
      need(isDeepStrictEqual(aliasDescription(root,info.file,info.linkTarget),info),"alias target changed before replacement");
      need(process.platform === "win32" || (info.targetMode & 0o100) !== 0,"Node bin target is not executable before materialization");
      const raw=launcherBytes31(nodeExecutable,info.file,info.target),temporary=full+".build31-"+crypto.randomUUID();
      fs.writeFileSync(temporary,raw,{flag:"wx",mode:0o755});fs.chmodSync(temporary,0o755);
      // Replacing this validated leaf never renames/deletes the target or another root.
      need(fs.lstatSync(full).isSymbolicLink()&&fs.readlinkSync(full)===info.linkTarget,"alias changed at replacement");fs.renameSync(temporary,full);
      const shimMode=fs.statSync(full).mode&0o777;need(process.platform === "win32" || shimMode === 0o755,"materialized launcher is not executable");
      aliases.push({...info,shimSha256:sha(raw),shimMode});
    }
    const after=scan31(root),expected={};for(const [name,digest] of Object.entries(previous.files))own(expected,name,digest);
    for(const alias of aliases)Object.defineProperty(expected,alias.file,{value:alias.shimSha256,enumerable:true,writable:true,configurable:true});
    need(isDeepStrictEqual(after.files,expected),"non-alias bytes changed during materialization");
    for(const alias of aliases)need(isDeepStrictEqual(aliasDescription(root,alias.file,alias.linkTarget),Object.fromEntries(Object.entries(alias).filter(([k])=>!k.startsWith("shim")))),"target changed during materialization");
    roots[kind]={directory,beforeFilesSha256:sha(canonical(previous.files)),afterFilesSha256:sha(canonical(after.files)),fileCount:after.count,aliases};
  }
  return {schemaVersion:1,documentType:"build31-npm-bin-materialization",producer:{file:SELF,sha256:sha(bytes(__filename))},nodeExecutable:{path:nodeExecutable,sha256:sha(bytes(nodeExecutable))},platform:process.platform,roots};
}
function verifyNpmBinMaterialization31({receipt,buildRoot,nodeExecutable,producerSha256,fileMaps}) {
  exact(receipt,["schemaVersion","documentType","producer","nodeExecutable","platform","roots"],"receipt");
  need(receipt.schemaVersion===1&&receipt.documentType==="build31-npm-bin-materialization"&&["win32","linux","darwin"].includes(receipt.platform),"normalization profile differs");
  exact(receipt.producer,["file","sha256"],"producer");need(receipt.producer.file===SELF&&receipt.producer.sha256===producerSha256,"materializer producer differs");
  need(isDeepStrictEqual(receipt.nodeExecutable,nodeExecutable),"materializer Node differs");exact(receipt.roots,Object.keys(ROOTS),"root populations");exact(fileMaps,Object.keys(ROOTS),"installed maps");
  for(const [kind,directory] of Object.entries(ROOTS)) {
    const row=receipt.roots[kind],map=fileMaps[kind],root=physical(path.join(buildRoot,directory),true);
    exact(row,["directory","beforeFilesSha256","afterFilesSha256","fileCount","aliases"],"materialized root");
    need(row.directory===directory&&Number.isSafeInteger(row.fileCount)&&row.fileCount===Object.keys(map).length&&row.fileCount<=100000&&sha(canonical(map))===row.afterFilesSha256&&Array.isArray(row.aliases)&&row.aliases.length<=row.fileCount,"materialized population differs");
    need(receipt.platform!=="win32"||row.aliases.length===0,"Windows receipt cannot claim POSIX alias normalization");
    const original={},seen=new Set();for(const [name,digest] of Object.entries(map)){portable(name);need(/^[A-F0-9]{64}$/.test(digest),"invalid installed digest");own(original,name,digest);}
    for(const alias of row.aliases) {
      exact(alias,["file","linkTarget","target","packageJson","packageJsonSha256","binName","declaredBin","targetSha256","targetMode","shimSha256","shimMode"],"retained alias");
      need(!seen.has(alias.file)&&Object.hasOwn(map,alias.file),"repeated or missing alias");seen.add(alias.file);
      const expected=aliasDescription(root,alias.file,alias.linkTarget);
      // Recorded modes qualify original preparation, not the regular0600 replay projection.
      for(const key of Object.keys(expected))if(key!=="targetMode")need(isDeepStrictEqual(alias[key],expected[key]),"retained alias declaration/target differs");
      need(Number.isInteger(alias.targetMode)&&alias.targetMode>=0&&alias.targetMode<=0o777&&(receipt.platform === "win32" || (alias.targetMode&0o100)!==0)&&Number.isInteger(alias.shimMode)&&
        (receipt.platform==="win32"?[0o666,0o777].includes(alias.shimMode):alias.shimMode===0o755),"recorded alias mode differs");
      const raw=launcherBytes31(nodeExecutable.path,alias.file,alias.target);need(alias.shimSha256===sha(raw)&&map[alias.file]===alias.shimSha256&&bytes(path.join(root,...alias.file.split("/"))).equals(raw),"materialized launcher bytes differ");
      Object.defineProperty(original,alias.file,{value:sha(Buffer.from(alias.linkTarget)),enumerable:true,writable:true,configurable:true});
    }
    for(const name of Object.keys(map).filter(name=>name.startsWith(".bin/")||name.includes("/node_modules/.bin/"))) {
      const raw=bytes(path.join(root,...name.split("/")));if(raw.subarray(0,Buffer.byteLength(MARKER)).toString()===MARKER)need(seen.has(name),"unrecorded materialized alias");
    }
    need(sha(canonical(original))===row.beforeFilesSha256,"original alias population commitment differs");
  }
  return {recordedMaterializationVerified:true,processExecutionAuthenticated:false};
}
if(require.main===module) {
  try { need(process.argv.length===4&&process.argv[2]==="--build-root","exact --build-root command required");process.stdout.write(JSON.stringify(materializeNpmBins31({buildRoot:process.argv[3]}))+"\n"); }
  catch(error) { process.stderr.write(String(error.stack||error)+"\n");process.exitCode=1; }
}
module.exports={SELF,ROOTS,MARKER,sha,canonical,verifyNodeShebang31,launcherBytes31,scan31,materializeNpmBins31,verifyNpmBinMaterialization31};
