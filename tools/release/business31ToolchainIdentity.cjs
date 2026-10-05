"use strict";
// Read-only source-owned tool identity. This does not authenticate retained process
// execution or grant deployment authority. Never enroll hashes from the current host.
const fs=require("node:fs"),path=require("node:path"),crypto=require("node:crypto");
const {isDeepStrictEqual:same,TextDecoder}=require("node:util");
const physical=require("./business31ExecutionContract.cjs").physical;
const bins=require("./business31NpmBinMaterialization.cjs");
const originalPath=require("./backendRuntimeEvidenceAccess31.cjs").path;
const SELF="tools/release/business31ToolchainIdentity.cjs";
const PROFILES="tools/release/business31ToolchainProfiles.json";
const need=(value,message)=>{if(!value)throw Error("Business31 toolchain identity: "+message);};
const sha=bytes=>crypto.createHash("sha256").update(bytes).digest("hex").toUpperCase();
const digest=value=>typeof value==="string"&&/^[A-F0-9]{64}$/.test(value);
function exact(value,fields,label){need(value&&typeof value==="object"&&!Array.isArray(value)&&[Object.prototype,null].includes(Object.getPrototypeOf(value))&&same(Object.keys(value).sort(),[...fields].sort()),label+" fields differ");}
function raw(file){file=physical(file);const a=fs.statSync(file,{bigint:true});need(a.size<=128n*1024n*1024n,"member bound exceeded");const result=fs.readFileSync(file),b=fs.statSync(file,{bigint:true});need(a.size===b.size&&a.ino===b.ino&&a.mtimeNs===b.mtimeNs&&a.ctimeNs===b.ctimeNs&&BigInt(result.length)===b.size,"member changed during read");return result;}
function object(bytes){need(Buffer.isBuffer(bytes)&&bytes.length<=16*1024*1024,"source profile byte bound exceeded");return JSON.parse(new TextDecoder("utf8",{fatal:true}).decode(bytes));}
function format31(bytes){
 const platform=bins.executablePlatform31(bytes);let arch;
 if(platform==="win32")arch=({0x14c:"ia32",0x8664:"x64",0xaa64:"arm64"})[bytes.readUInt16LE(bytes.readUInt32LE(0x3c)+4)];
 if(platform==="linux"){const machine=bytes[5]===1?bytes.readUInt16LE(18):bytes.readUInt16BE(18);arch=({3:"ia32",62:"x64",183:"arm64"})[machine];need((arch==="ia32"?1:2)===bytes[4],"ELF architecture/class differs");}
 if(platform==="darwin"){const magic=bytes.readUInt32BE(0),little=[0xcefaedfe,0xcffaedfe].includes(magic),cpu=little?bytes.readUInt32LE(4):bytes.readUInt32BE(4);arch=({0x1000007:"x64",0x100000c:"arm64"})[cpu];}
 need(arch,"unsupported executable architecture");return {platform,arch};
}
function profileTable31(bytes){
 const table=object(bytes);exact(table,["schemaVersion","documentType","profiles"],"profile table");need(table.schemaVersion===1&&table.documentType==="build31-approved-toolchain-profiles","profile table schema differs");
 need(table.profiles&&typeof table.profiles==="object"&&!Array.isArray(table.profiles)&&Object.keys(table.profiles).length<=16,"finite profiles required");
 for(const [id,p]of Object.entries(table.profiles)){
  need(/^[a-z0-9][a-z0-9-]{0,79}$/.test(id),"profile id differs");
  exact(p,["platform","arch","nodeVersion","npmVersion","nodeSha256","npmEntry","npmFiles","npmFileCount","npmFilesSha256","provenance"],"approved profile");
  need(["win32","linux","darwin"].includes(p.platform)&&["ia32","x64","arm64"].includes(p.arch)&&/^\d+\.\d+\.\d+$/.test(p.nodeVersion)&&/^\d+\.\d+\.\d+$/.test(p.npmVersion)&&digest(p.nodeSha256)&&p.npmEntry==="bin/npm-cli.js","approved runtime identity differs");
  need(p.npmFiles&&typeof p.npmFiles==="object"&&!Array.isArray(p.npmFiles)&&Number.isSafeInteger(p.npmFileCount)&&p.npmFileCount>1&&p.npmFileCount<=50000&&Object.keys(p.npmFiles).length===p.npmFileCount,"complete approved npm population required");
  for(const [file,hash]of Object.entries(p.npmFiles))need(typeof file==="string"&&file.length>0&&file.length<=400&&/^[A-Za-z0-9_@+.~/-]+$/.test(file)&&!file.startsWith("/")&&file.split("/").every(v=>v&&v!=="."&&v!=="..")&&digest(hash),"approved npm member differs");
  need(Object.hasOwn(p.npmFiles,"package.json")&&Object.hasOwn(p.npmFiles,p.npmEntry)&&digest(p.npmFilesSha256)&&sha(bins.canonical(p.npmFiles))===p.npmFilesSha256,"approved npm population digest differs");
  exact(p.provenance,["nodeDistribution","npmDistribution","reviewEvidenceSha256"],"provenance");
  for(const kind of ["nodeDistribution","npmDistribution"]){const d=p.provenance[kind];exact(d,["url","sha256",...(kind==="npmDistribution"?["integrity"]:[])],"distribution provenance");need(typeof d.url==="string"&&/^https:\/\/[^\s]+$/.test(d.url)&&digest(d.sha256),"distribution provenance differs");if(kind==="npmDistribution")need(/^sha512-[A-Za-z0-9+/]+={0,2}$/.test(d.integrity),"npm distribution integrity differs");}
  need(digest(p.provenance.reviewEvidenceSha256),"independent provenance review binding required");
 }
 return table;
}
function verifyProfileSource31({repository,verifier,snapshot,custody}){
 const identity=verifier.files[PROFILES];need(identity?.mode==="100644"&&same(identity,snapshot.files[PROFILES])&&same(identity,custody.files[PROFILES]),"approved profile data must be identical regular V/M/custody source");
 const bytes=repository.readBlob(verifier.commit,PROFILES);profileTable31(bytes);return sha(bytes);
}
function verifyToolchainIdentity31({runtime,source,snapshot,repository,policy}){
 need(snapshot.files[SELF]?.mode==="100644"&&snapshot.files[PROFILES]?.mode==="100644","current source must include fixed toolchain helper and profiles");
 const bytes=repository.readBlob(source.commit,PROFILES),oid=crypto.createHash("sha1").update(Buffer.from(`blob ${bytes.length}\0`)).update(bytes).digest("hex");need(oid===snapshot.files[PROFILES].oid,"source profile blob identity differs");
 const table=profileTable31(bytes);need(typeof runtime.toolchainProfileId==="string"&&Object.hasOwn(table.profiles,runtime.toolchainProfileId),"no independently approved source toolchain profile");const p=table.profiles[runtime.toolchainProfileId];
 need(runtime.nodeVersion===p.nodeVersion&&runtime.npmVersion===p.npmVersion&&p.nodeVersion===policy.toolchain.nodeVersion&&p.npmVersion===policy.toolchain.npmVersion,"approved versions differ from source policy");
 exact(runtime.nodeExecutable,["path","sha256"],"Node binding");exact(runtime.npmCliFile,["path","sha256"],"npm binding");
 const nodeBytes=raw(runtime.nodeExecutable.path);need(runtime.nodeExecutable.sha256===p.nodeSha256&&sha(nodeBytes)===p.nodeSha256,"Node differs from independently approved bytes");need(same(format31(nodeBytes),{platform:p.platform,arch:p.arch}),"approved executable platform/architecture differs");
 need(typeof runtime.npmPackageRoot==="string"&&originalPath.isAbsolute(runtime.npmPackageRoot)&&runtime.npmCliFile.path===originalPath.join(runtime.npmPackageRoot,p.npmEntry),"npm entry must be fixed inside approved package root");
 const root=physical(runtime.npmPackageRoot,true),map=bins.scan31(root).files;need(same(map,p.npmFiles)&&Object.keys(map).length===p.npmFileCount&&sha(bins.canonical(map))===p.npmFilesSha256,"complete npm implementation differs from independently approved population");
 need(runtime.npmCliFile.sha256===p.npmFiles[p.npmEntry]&&sha(raw(runtime.npmCliFile.path))===runtime.npmCliFile.sha256,"npm entry differs from approved implementation");
 const pkg=object(raw(path.join(root,"package.json")));need(pkg.name==="npm"&&pkg.version===p.npmVersion,"approved npm package name/version differs");
 return Object.freeze({profileId:runtime.toolchainProfileId,profilesSha256:sha(bytes),nodeVersion:p.nodeVersion,npmVersion:p.npmVersion,platform:p.platform,arch:p.arch,sourceApprovedBytesVerified:true,processExecutionAuthenticated:false,deploymentAuthorized:false});
}
function probeArguments31(kind,runtime){need(["node","npm"].includes(kind),"unknown version probe");return kind==="node"?["--version"]:[runtime.npmCliFile.path,"--version"];}
function verifyProbeOutput31(kind,output,identity){need(Buffer.isBuffer(output.stdout)&&Buffer.isBuffer(output.stderr)&&output.stderr.length===0,"version probe stderr must be empty");const version=kind==="node"?"v"+identity.nodeVersion:identity.npmVersion;need(["\n","\r\n"].some(ending=>output.stdout.equals(Buffer.from(version+ending))),"original version probe stdout differs");}
module.exports={SELF,PROFILES,sha,format31,profileTable31,verifyProfileSource31,verifyToolchainIdentity31,probeArguments31,verifyProbeOutput31};
