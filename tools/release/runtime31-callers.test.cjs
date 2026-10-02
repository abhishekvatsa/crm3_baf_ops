'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),os=require('node:os');
const {spawnSync,execFileSync}=require('node:child_process');
const root=path.resolve(__dirname,'../..'),helper=path.join(root,'tools/release/Runtime-BackendPrivateReplay31.ps1');
const appCheck=path.join(root,'tools/release/Production-AppCheckPolicy.ps1');
const manifest=path.join(root,'tools/release/Test-ProductionReleaseManifest.ps1');
const H='A'.repeat(64),B='B'.repeat(64),M='a'.repeat(40);
const quote=s=>"'"+s.replaceAll("'","''")+"'";
const pointer=file=>({commit:M,file,sha256:H});
function fixture(){
  const source={commit:M,tree:'b'.repeat(40),functionsTree:'c'.repeat(40)};
  const closurePointer=pointer('release/evidence/build31-runtime-backend-deployment-closure.json');
  const approvalPointer=pointer('release/approvals/build31-runtime-backend-deployment-approval.json');
  const clientPointer=pointer('release/approvals/build31-runtime-client-compatibility-approval.json');
  const descriptorPointer=pointer('release/evidence/build31-runtime-private-replay.json');
  const currentBackend={source,approvalPointer,closurePointer,completedAtUtc:'2026-09-01T00:00:00Z',recordedAtUtc:'2026-09-01T00:01:00Z',
    fleet:{callables:13,events:5,schedulers:1,total:19},preserved:{rules:true,indexes:true,iam:true,enforcement:true,businessLogic:true},
    appCheck:{clientRequired:true,androidProvider:'playIntegrity',mutatingEnforcementChanged:false},
    rawProofCommitment:{descriptorSha256:H,membersSha256:H,relocationSha256:H}};
  const proof={ok:true,route:'runtime-backend31',runtimeBackend31:{source,approvalPointer,closurePointer,clientPointer,descriptorPointer,privateEvidenceReplayed:true,currentBackend}};
  const policy={release:{buildNumber:31,releaseId:'synthetic31'},versionPolicy:{buildNumber:31,reservationId:'synthetic31'},
    finalization:{exactFunctionFleetDeploymentReceiptFile:closurePointer.file,exactFunctionFleetDeploymentReceiptSha256:H},
    runtimeBackendPrivateReplay:descriptorPointer,clientBackendCompatibility:clientPointer,
    appCheckBuild:{clientEnabled:true,androidProvider:'playIntegrity',approvalFile:'release/approvals/build31-app-check-client-approval.json',approvalSha256:B}};
  const backend={schemaVersion:2,documentType:'build31-runtime-private-record-custody',recordKind:'closure',source};
  const approval={schemaVersion:1,documentType:'governed-app-check-client-build-approval',approved:true,intendedBuildNumber:31,
    releaseId:'synthetic31',reservationId:'synthetic31',firebaseProjectId:'crm3-baf-ops-b8638',applicationId:'in.co.sail.bsl.crm3.bafops',
    clientEnabled:true,androidProvider:'playIntegrity',enforcementChangeAuthorized:false,approverName:'Synthetic reviewer',approvalReference:'SYNTHETIC-ONLY',
    approvedAtUtc:'2026-09-01T00:00:00Z',backendReceiptSha256:H,backendSourceCommit:M,serverEnforcementAtBuild:false,
    serverEnforcementScopesAtBuild:{defaultMutatingEnforced:false,identityCallable:'getBackendReleaseIdentity',identityCallableEnforced:true,
      identitySourceFile:'functions/src/stage2dSecurityConfig.ts',identitySourceSha256:'1D46E7CDC200BA730AAD1F3BD30EF1C8D8E8509FC5EB7CB619A734077792A79F'}};
  return{proof,policy,backend,approval};
}
function ps(script){const directory=fs.mkdtempSync(path.join(os.tmpdir(),'crm3-runtime31-caller-test-'));
  const file=path.join(directory,'run.ps1');fs.writeFileSync(file,"Set-StrictMode -Version Latest\n$ErrorActionPreference='Stop'\n"+script);
  return spawnSync('pwsh',['-NoProfile','-File',file],{encoding:'utf8',windowsHide:true,timeout:60000});}
function runApp(input){const directory=fs.mkdtempSync(path.join(os.tmpdir(),'crm3-runtime31-input-')),file=path.join(directory,'input.json');fs.writeFileSync(file,JSON.stringify(input));
  return ps(`. ${quote(helper)}\n. ${quote(appCheck)}\n$f=Get-Content -LiteralPath ${quote(file)} -Raw|ConvertFrom-Json -Depth 100
Get-ProductionAppCheckBuildEvidence -Policy $f.policy -Approval $f.approval -BackendReceipt $f.backend -ApprovalSha256 '${B}' -BackendReceiptSha256 '${H}' -Runtime31Proof $f.proof | ConvertTo-Json -Depth 100 -Compress`);}
test('actual App Check caller accepts only synthetic replayed runtime source with unchanged enforcement',()=>{
  const r=runApp(fixture());assert.equal(r.status,0,r.stderr);const result=JSON.parse(r.stdout);
  assert.equal(result.clientEnabled,true);assert.equal(result.serverEnforcementAtBuild,false);
  assert.equal(result.serverEnforcementScopesAtBuild.identityCallableEnforced,true);assert.equal(result.enforcementChangedByBuild,false);
  assert.equal(result.tokenValidationEvidence,'not-proved-by-artifact-construction');
});
for(const[name,mutate]of[
  ['missing replay',f=>f.proof=null],['unverified private bytes',f=>f.proof.runtimeBackend31.privateEvidenceReplayed=false],
  ['legacy route fallback',f=>f.proof.route='exact-backend'],['new fleet',f=>f.proof.runtimeBackend31.currentBackend.fleet.total=20],
  ['Rules change',f=>f.proof.runtimeBackend31.currentBackend.preserved.rules=false],
  ['IAM change',f=>f.proof.runtimeBackend31.currentBackend.preserved.iam=false],
  ['wrong source',f=>f.backend.source={...f.backend.source,commit:'c'.repeat(40)}],
  ['old public closure shape',f=>f.backend.schemaVersion=1],['wrong closure kind',f=>f.backend.recordKind='client'],
  ['disabled client',f=>{f.policy.appCheckBuild.clientEnabled=f.approval.clientEnabled=false;f.policy.appCheckBuild.androidProvider=f.approval.androidProvider='disabled';}],
  ['changed identity enforcement',f=>f.approval.serverEnforcementScopesAtBuild.identityCallableEnforced=false],
  ['changed default enforcement',f=>f.approval.serverEnforcementScopesAtBuild.defaultMutatingEnforced=true],
  ['different descriptor',f=>f.policy.runtimeBackendPrivateReplay={...f.policy.runtimeBackendPrivateReplay,sha256:B}],
  ['different source approval',f=>f.approval.backendSourceCommit='c'.repeat(40)],
])test('actual App Check runtime branch rejects '+name,()=>{const f=fixture();mutate(f);const r=runApp(f);assert.notEqual(r.status,0,r.stdout);});
const repo=fs.mkdtempSync(path.join(os.tmpdir(),'crm3-runtime31-archive-git-'));
function git(...args){return execFileSync('git',['-C',repo,...args],{encoding:'utf8',windowsHide:true,stdio:['ignore','pipe','pipe']}).trim();}
git('init','-q');git('config','core.autocrlf','false');git('config','user.email','synthetic@example.invalid');git('config','user.name','Synthetic local fixture');
fs.mkdirSync(path.join(repo,'tools/release'),{recursive:true});fs.writeFileSync(path.join(repo,'source.txt'),'immutable source\n');
const helperRelative='tools/release/Runtime-BackendPrivateReplay31.ps1';fs.copyFileSync(helper,path.join(repo,helperRelative));
git('add','.');git('commit','-qm','Synthetic archive fixture only');const commit=git('rev-parse','HEAD');
const archive=path.join(path.dirname(repo),path.basename(repo)+'.zip');git('archive','--format=zip','--output='+archive,'HEAD');
function runArchive(mutation='',extra=''){
  const target=path.join(os.tmpdir(),'runtime31-archive-'+Math.random().toString(16).slice(2)+'.zip');fs.copyFileSync(archive,target);
  return ps(`. ${quote(helper)}\n$archive=${quote(target)}\n${mutation}\nAssert-ProductionRuntime31SourceArchive -RepositoryRoot ${quote(repo)} -SourceArchivePath $archive -SourceCommit '${commit}'\n${extra}\n'PASS'`);
}
test('actual archive checker verifies complete real Git member population',()=>{const r=runArchive();assert.equal(r.status,0,r.stderr);});
const zipStart='$zip=[IO.Compression.ZipFile]::Open($archive,[IO.Compression.ZipArchiveMode]::Update)\ntry {\n';
const zipEnd='\n} finally {$zip.Dispose()}';
for(const[name,body]of[
  ['omitted member',"$zip.GetEntry('source.txt').Delete()"],
  ['modified member',"$zip.GetEntry('source.txt').Delete();$e=$zip.CreateEntry('source.txt');$w=[IO.StreamWriter]::new($e.Open());$w.Write('changed');$w.Dispose()"],
  ['extra member',"$e=$zip.CreateEntry('unexpected.txt')"],
  ['extra empty directory',"$e=$zip.CreateEntry('unexpected/')"],
  ['omitted directory',"$zip.GetEntry('tools/release/').Delete()"],
  ['case collision',"$e=$zip.CreateEntry('SOURCE.TXT')"],
  ['parent traversal',"$e=$zip.CreateEntry('../outside')"],
  ['symlink',"$zip.GetEntry('source.txt').ExternalAttributes=([int]0xA000 -shl 16)"],
])test('actual archive checker rejects '+name,()=>{const r=runArchive(zipStart+body+zipEnd);assert.notEqual(r.status,0,r.stdout);});
test('package helper is independently Git-bound before execution even with matching tampered ZIP bytes',()=>{
  const directory=fs.mkdtempSync(path.join(os.tmpdir(),'crm3-tampered-helper-'));
  const tampered=path.join(directory,'Runtime-BackendPrivateReplay31.ps1'),marker=path.join(directory,'executed');
  fs.writeFileSync(tampered,`Set-Content -LiteralPath ${quote(marker)} -Value BAD\n`);
  const substitutedArchive=path.join(directory,'source.zip');fs.copyFileSync(archive,substitutedArchive);
  const script=`$ast=[Management.Automation.Language.Parser]::ParseFile(${quote(manifest)},[ref]$null,[ref]$null)
foreach($name in @('Get-Sha256','Get-ZipEntryBytes','Get-ZipEntrySha256','Invoke-Runtime31SafeGitRead','Assert-Runtime31HelperGitBinding')) {
 $f=$ast.Find({param($n)$n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name},$true)
 . ([scriptblock]::Create($f.Extent.Text))
}
$zip=[IO.Compression.ZipFile]::Open(${quote(substitutedArchive)},[IO.Compression.ZipArchiveMode]::Update)
try {$zip.GetEntry('${helperRelative}').Delete();$entry=$zip.CreateEntry('${helperRelative}');$stream=$entry.Open();try{$bytes=[IO.File]::ReadAllBytes(${quote(tampered)});$stream.Write($bytes,0,$bytes.Length)}finally{$stream.Dispose()}}finally{$zip.Dispose()}
if ((Get-Sha256 ${quote(tampered)}) -cne (Get-ZipEntrySha256 -ArchivePath ${quote(substitutedArchive)} -EntryPath '${helperRelative}')) {throw 'Synthetic substituted archive fixture mismatch'}
Assert-Runtime31HelperGitBinding -Root ${quote(repo)} -Commit '${commit}' -Entry '${helperRelative}' -Helper ${quote(tampered)}
. ${quote(tampered)}`;
  const r=ps(script);assert.notEqual(r.status,0,r.stdout);assert.match(r.stderr,/differs from immutable Git before execution/);assert.equal(fs.existsSync(marker),false);
  const source=fs.readFileSync(manifest,'utf8');assert(source.indexOf('Assert-Runtime31HelperGitBinding -Root $RepositoryRoot')<source.indexOf('. $runtime31Helper'));
});
test('actual independently bound helper admits the unchanged source helper',()=>{
  const r=ps(`$ast=[Management.Automation.Language.Parser]::ParseFile(${quote(manifest)},[ref]$null,[ref]$null)
foreach($name in @('Invoke-Runtime31SafeGitRead','Assert-Runtime31HelperGitBinding')) {
$f=$ast.Find({param($n)$n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name},$true)
. ([scriptblock]::Create($f.Extent.Text))
}
Assert-Runtime31HelperGitBinding -Root ${quote(repo)} -Commit '${commit}' -Entry '${helperRelative}' -Helper ${quote(path.join(repo,helperRelative))}
'PASS'`);assert.equal(r.status,0,r.stderr);
});

test('actual archive reader ignores ambient Git directory/config injection',()=>{
 const r=runArchive("$env:GIT_DIR='C:/synthetic-missing-git';$env:GIT_CONFIG_COUNT='1';$env:GIT_CONFIG_KEY_0='include.path';$env:GIT_CONFIG_VALUE_0='C:/synthetic-missing-config'");
 assert.equal(r.status,0,r.stderr);
});
test('actual archive reader rejects local include before any Git interpretation',()=>{
 const config=path.join(repo,'.git/config'),before=fs.readFileSync(config);
 try{fs.appendFileSync(config,'\n[include]\n  path = missing\n');const r=runArchive();assert.notEqual(r.status,0);assert.match(r.stderr,/configuration is not admitted/);}finally{fs.writeFileSync(config,before);}
});

for(const marker of ['commondir','gitdir','objects/info/alternates','info/grafts']) test('actual archive reader rejects '+marker,()=>{const target=path.join(repo,'.git',marker);fs.mkdirSync(path.dirname(target),{recursive:true});try{fs.writeFileSync(target,'/missing');const r=runArchive();assert.notEqual(r.status,0);assert.match(r.stderr,/cannot redirect/);}finally{fs.unlinkSync(target);}});
test('actual archive reader rejects core.worktree',()=>{const config=path.join(repo,'.git/config'),before=fs.readFileSync(config);try{fs.appendFileSync(config,'\n[core]\n  worktree = /missing\n');const r=runArchive();assert.notEqual(r.status,0);assert.match(r.stderr,/configuration is not admitted/);}finally{fs.writeFileSync(config,before);}});
