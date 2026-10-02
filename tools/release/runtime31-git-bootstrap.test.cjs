"use strict";
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path'),Module=require('node:module');
const {execFileSync}=require('node:child_process');
const api=require('./runtimeBackendPrivateReplay31.cjs');
const repo=execFileSync('git',['-C',__dirname,'rev-parse','--show-toplevel'],{encoding:'utf8',windowsHide:true}).trim();
const source=fs.readFileSync(path.join(__dirname,'clientBackendCompatibility31.js'),'utf8');
const shared=new Module(path.join(repo,'tools/release/clientBackendCompatibility31.js'),module);
shared.filename=path.join(repo,'tools/release/clientBackendCompatibility31.js');shared.paths=Module._nodeModulePaths(path.dirname(shared.filename));
shared._compile(source+'\nmodule.exports.testOnlySafeGitRead31=runtime31Git;',shared.filename);
function fixture(){const root=fs.mkdtempSync(path.join(os.tmpdir(),'crm31-safe-git-'));const g=(...args)=>execFileSync('git',['-C',root,...args],{encoding:'utf8',windowsHide:true});g('init','-q');g('config','user.name','Synthetic only');g('config','user.email','test@example.invalid');fs.writeFileSync(path.join(root,'proof.txt'),'exact\n');g('add','.');g('commit','-qm','synthetic source identity');return{root,head:g('rev-parse','HEAD').trim()};}
for(const[name,reader]of[['transport',api.safeGitRead31],['shared pre-load bootstrap',shared.exports.testOnlySafeGitRead31]]){
 test(name+' strips injected Git directory and config while preserving caller environment',()=>{const f=fixture();const before={...process.env};try{Object.assign(process.env,{GIT_DIR:path.join(f.root,'missing'),GIT_WORK_TREE:path.join(f.root,'missing'),GIT_CONFIG_COUNT:'1',GIT_CONFIG_KEY_0:'include.path',GIT_CONFIG_VALUE_0:path.join(f.root,'missing-config'),GIT_CONFIG_GLOBAL:path.join(f.root,'missing-global'),GIT_OBJECT_DIRECTORY:path.join(f.root,'missing-objects')});assert.equal(reader(f.root,['rev-parse','HEAD']).toString().trim(),f.head);assert.equal(process.env.GIT_DIR,path.join(f.root,'missing'));}finally{for(const k of Object.keys(process.env))if(!(k in before))delete process.env[k];Object.assign(process.env,before);}});
 for(const section of ['include','includeIf "gitdir:*"','filter "malicious"','diff "external"'])test(name+' rejects local '+section+' before Git execution',()=>{const f=fixture();fs.appendFileSync(path.join(f.root,'.git/config'),'\n['+section+']\n\tpath = missing\n');assert.throws(()=>reader(f.root,['rev-parse','HEAD']),/configuration is not admitted/);});
 for(const name of ['commondir','gitdir','objects/info/alternates','info/grafts'])test(name+' indirection is rejected by '+name,()=>{const f=fixture(),target=path.join(f.root,'.git',name);fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,'/missing');assert.throws(()=>reader(f.root,['rev-parse','HEAD']),/cannot redirect/);});
 test(name+' rejects core.worktree',()=>{const f=fixture();fs.appendFileSync(path.join(f.root,'.git/config'),'\n[core]\n  worktree = /missing\n');assert.throws(()=>reader(f.root,['rev-parse','HEAD']),/configuration is not admitted/);});

}
