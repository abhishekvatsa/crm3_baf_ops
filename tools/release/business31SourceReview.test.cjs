"use strict";
// Synthetic review/CI records only. Real local Git and bound observer subprocesses;
// no GitHub, credentials, deployment, or claim of an actual Claude review.
const test=require("node:test"),assert=require("node:assert/strict"),fs=require("node:fs"),path=require("node:path"),os=require("node:os"),cp=require("node:child_process");
const x=require("./business31ExecutionContract.cjs"),a=require("./backendRuntimeAdmission31.cjs"),legacy=require("./backendRuntimeExecutionAdmission31.cjs");
for(const name of ["node:http","node:https"]) { const api=require(name);api.request=api.get=()=>{throw Error("No network in synthetic review tests");}; }
globalThis.fetch=()=>{throw Error("No network in synthetic review tests");};
const root=fs.mkdtempSync(path.join(fs.realpathSync(os.tmpdir()),"business31-review-")),repo=path.join(root,"repo");fs.mkdirSync(repo);
const gitExecutable=process.env.BUSINESS31_TEST_GIT||(process.platform==="win32"?"C:/Program Files/Git/mingw64/bin/git.exe":"/usr/bin/git");
const env={};for(const name of ["SystemRoot","WINDIR","COMSPEC","PATH","PATHEXT","TEMP","TMP","HOME","USERPROFILE","APPDATA","LOCALAPPDATA"])if(process.env[name])env[name]=process.env[name];
env.PATH=[path.dirname(gitExecutable),path.dirname(process.execPath),...(env.SystemRoot?[path.join(env.SystemRoot,"System32")]:[])].join(path.delimiter);
Object.assign(env,{GIT_CONFIG_NOSYSTEM:"1",GIT_CONFIG_GLOBAL:process.platform==="win32"?"NUL":"/dev/null",GIT_AUTHOR_NAME:"Synthetic only",GIT_AUTHOR_EMAIL:"fixture@example.invalid",GIT_COMMITTER_NAME:"Synthetic only",GIT_COMMITTER_EMAIL:"fixture@example.invalid"});
const git=(args,input)=>cp.execFileSync(gitExecutable,["-c","protocol.allow=never","-c","core.hooksPath="+path.join(root,"no-hooks"),"-c","commit.gpgsign=false","-C",repo,...args],{env,input,encoding:"utf8",windowsHide:true,timeout:30000}).trim();
git(["init","--initial-branch=main"]);const tree=git(["mktree"],"");
const commit=(text,parents=[])=>git(["commit-tree",tree,...parents.flatMap(p=>["-p",p]),"-m",text]);
// Find an actual ambiguous seven-hex prefix without spawning Git for each candidate.
// Only the two matching valid commit bodies are written to Git's object database.
function collidingCommits(parent) {
  const crypto=require("node:crypto"),seen=new Map(),limit=250000;
  const body=n=>Buffer.from("tree "+tree+"\nparent "+parent+"\nauthor Synthetic only <fixture@example.invalid> 1577923200 +0000\ncommitter Synthetic only <fixture@example.invalid> 1577923200 +0000\n\nSynthetic prefix collision "+n+"\n");
  const oid=b=>crypto.createHash("sha1").update(Buffer.from("commit "+b.length+"\0")).update(b).digest("hex");
  for(let n=0;n<limit;n++) {
    const candidate=body(n),hash=oid(candidate),prefix=hash.slice(0,7),prior=seen.get(prefix);
    if(prior!==undefined) {
      const earlier=body(prior),earlierHash=oid(earlier);
      if(earlierHash.slice(0,10)===hash.slice(0,10))continue;
      assert.equal(git(["hash-object","-t","commit","-w","--stdin"],earlier),earlierHash);
      assert.equal(git(["hash-object","-t","commit","-w","--stdin"],candidate),hash);
      assert.equal(git(["cat-file","-t",earlierHash]),"commit");
      assert.equal(git(["cat-file","-t",hash]),"commit");
      return {first:earlierHash,second:hash};
    }
    seen.set(prefix,n);
  }
  throw Error("Bounded synthetic prefix-collision search exhausted");
}
const ancestor=commit("Synthetic ancestor"),left=commit("Synthetic base",[ancestor]),collision=collidingCommits(ancestor),head=collision.first,M=commit("Synthetic normal merge",[left,head]);git(["update-ref","refs/heads/main",M]);
const source={commit:M,tree,functionsTree:"3".repeat(40)},h=x.sha,T=n=>new Date(Date.UTC(2020,0,2,2,0,n)).toISOString();
const official={id:1236702,slug:"claude",owner:{login:"anthropics",id:76263028}};
const ci=(kind,id,pr)=>({schemaVersion:1,evidenceType:kind==="release"?"github-exact-main-release-gate":"github-exact-main-codeql",repository:"abhishekvatsa/crm3_baf_ops",sourceCommit:M,sourceTree:tree,capturedAtUtc:T(50),pullRequest:pr,
  run:{id,run_attempt:1,repository:{full_name:"abhishekvatsa/crm3_baf_ops"},head_sha:M,head_branch:"main",event:"push",path:kind==="release"?".github/workflows/release-gate.yml":".github/workflows/codeql.yml",status:"completed",conclusion:"success",created_at:T(10),updated_at:T(40)},
  jobs:{total_count:(kind==="release"?a.RELEASE_JOBS:a.SECURITY_JOBS).length,jobs:(kind==="release"?a.RELEASE_JOBS:a.SECURITY_JOBS).map((name,i)=>({id:id*100+i,run_id:id,run_attempt:1,head_sha:M,name,status:"completed",conclusion:"success",completed_at:T(30)}))}});
function fixture(){
  const issue_url="https://api.github.com/repos/abhishekvatsa/crm3_baf_ops/issues/405";
  const reviewRequest={id:1001,issue_url,body:"@claude review exact head "+head,created_at:T(-20),updated_at:T(-20)};
  const review={id:1002,issue_url,body:"No findings.\n\n**Reviewed commit:** `"+head.slice(0,10)+"`",created_at:T(-10),updated_at:T(-10),user:{login:"claude[bot]",type:"Bot"},performed_via_github_app:structuredClone(official)};
  const pr={number:405,merged:true,merge_commit_sha:M,head:{sha:head},base:{ref:"main",repo:{full_name:"abhishekvatsa/crm3_baf_ops"}},merged_at:T(0)};
  return {source,pr,review,reviewRequest,reviewSummary:null,reviewedHeadCommit:head,
    approval:{reviewPreparedAtUtc:T(70),decidedAtUtc:T(100),normalMergeParents:[left,head],mainCiRun:{id:11,runAttempt:1},securityCiRun:{id:12,runAttempt:1},settledSourceReview:{kind:x.CLAUDE_REVIEW_KIND,reviewer:"claude[bot]",headCommit:head,request:{id:1001,bodySha256:h(Buffer.from(reviewRequest.body))},response:{id:1002,bodySha256:h(Buffer.from(review.body))},summary:null}},
    release:ci("release",11,pr),security:ci("security",12,pr),mainRef:{ref:"refs/heads/main",object:{sha:M}},reviews:{nodes:[],pageInfo:{hasNextPage:false}},threads:{nodes:[],pageInfo:{hasNextPage:false}},nowUtc:T(130)};
}
const rebind=f=>{for(const [name,value]of [["request",f.reviewRequest],["response",f.review],["summary",f.reviewSummary]])if(value)f.approval.settledSourceReview[name]={id:value.id,bodySha256:h(Buffer.from(value.body))};return f;};
function observation(f){const raw=JSON.stringify;return {observer:{executable:process.execPath,sha256:h(fs.readFileSync(process.execPath))},observedAtUtc:T(120),completedAtUtc:T(121),main:raw(f.mainRef),finalMain:raw(f.mainRef),pr:raw(f.pr),release:{run:raw(f.release.run),jobs:raw(f.release.jobs)},security:{run:raw(f.security.run),jobs:raw(f.security.jobs)},review:raw(f.review),reviewRequest:raw(f.reviewRequest),reviewSummary:f.reviewSummary?raw(f.reviewSummary):null,threads:raw({data:{repository:{pullRequest:{reviews:f.reviews,reviewThreads:f.threads}}}})};}
const admission=f=>({source:f.source,repoRoot:repo,mainCi:{pullRequestNumber:f.pr.number},runtime:{githubExecutable:process.execPath,githubExecutableSha256:h(fs.readFileSync(process.execPath))}});
test.after(()=>{assert.equal(path.dirname(fs.realpathSync(root)),fs.realpathSync(os.tmpdir()));fs.rmSync(root,{recursive:true});});
test("synthetic Claude records pass real live predicate and preserved replay with actual Git prefix resolution",()=>{const f=fixture(),raw=observation(f),before=JSON.stringify(raw);assert.equal(x.verifyBusinessLiveGitHubRecords31(f),true);assert.equal(x.verifyPreservedBusinessLiveGitHub31(raw,admission(f),f.approval),true);assert.equal(JSON.stringify(raw),before);assert.equal(JSON.parse(raw.review).user.login,"claude[bot]");});
test("official app owner may be omitted by endpoint; supplied owner must match",()=>{const f=fixture();delete f.review.performed_via_github_app.owner;assert.equal(x.verifyBusinessLiveGitHubRecords31(f),true);});
test("Claude v1 refuses richer summaries even from the official app",()=>{const f=fixture();f.reviewSummary={...structuredClone(f.review),id:1003,body:"Synthetic summary",created_at:T(-5),updated_at:T(-4)};rebind(f);assert.throws(()=>x.verifyPreservedBusinessLiveGitHub31(observation(f),admission(f),f.approval),/summary:null/);});
for(const verdict of ["No findings","No major issues.","I didn't find any major issues.","I didn’t find any major issues."])test("closed standalone verdict: "+verdict,()=>{const f=fixture();f.review.body=verdict+"\r\n**Reviewed commit:** `"+head+"`\r\n";rebind(f);assert.equal(x.verifyBusinessLiveGitHubRecords31(f),true);});
const negatives=[
 ["unknown kind",f=>f.approval.settledSourceReview.kind="arbitrary-bot"],
 ["Claude masquerading as Codex",f=>f.approval.settledSourceReview.kind="bot-issue-comment-no-findings"],
 ["unknown reviewer",f=>f.approval.settledSourceReview.reviewer="other[bot]"],
 ["wrong app ID",f=>f.review.performed_via_github_app.id=1236703],
 ["wrong app slug",f=>f.review.performed_via_github_app.slug="lookalike"],
 ["wrong owner name",f=>f.review.performed_via_github_app.owner.login="lookalike"],
 ["wrong owner ID",f=>f.review.performed_via_github_app.owner.id=1],
 ["null supplied owner",f=>f.review.performed_via_github_app.owner=null],
 ["missing app",f=>delete f.review.performed_via_github_app],
 ["copied human login",f=>f.review.user.type="User"],
 ["wrong login",f=>f.review.user.login="claude"],
 ["bare actual-shaped request",f=>{f.reviewRequest.body="@claude review\r\n";rebind(f);}],
 ["request abbreviation only",f=>{f.reviewRequest.body=head.slice(0,10);rebind(f);}],
 ["full head only inside longer hex",f=>{f.reviewRequest.body="a"+head+"b";rebind(f);}],
 ["two markers",f=>{f.review.body+="\n**Reviewed commit:** `"+head+"`";rebind(f);}],
 ["wrong marker",f=>{f.review.body="No findings.\n**Reviewed commit:** `"+left+"`";rebind(f);}],
 ["quoted verdict",f=>{f.review.body=f.review.body.replace("No findings.","> No findings.");rebind(f);}],
 ["negated verdict",f=>{f.review.body=f.review.body.replace("No findings.","Not no findings.");rebind(f);}],
 ["malformed Unicode apostrophe",f=>{f.review.body=f.review.body.replace("No findings.","I didn\u00e2t find any major issues.");rebind(f);}],
 ["quota appended to verdict",f=>{f.review.body+="\nQuota exhausted";rebind(f);}],
 ["error instead of review",f=>{f.review.body="Review not performed.\n**Reviewed commit:** `"+head+"`";rebind(f);}],
 ["native PR review shape",f=>{f.review.commit_id=head;f.review.state="APPROVED";delete f.review.issue_url;}],
 ["body digest mismatch",f=>f.review.body=f.review.body.replace("findings","major issues")],
 ["wrong comment ID",f=>f.review.id++],
 ["wrong response PR",f=>f.review.issue_url+="0"],
 ["wrong request PR",f=>f.reviewRequest.issue_url+="0"],
 ["response edited after contract",f=>f.review.updated_at=T(71)],
 ["response edited after decision",f=>f.review.updated_at=T(101)],
 ["request edited after response",f=>f.reviewRequest.updated_at=T(-9)],
 ["response predates request",f=>f.review.created_at=T(-21)],
 ["malformed update date",f=>f.review.updated_at="2020-02-31T00:00:00Z"],
 ["omitted update date",f=>delete f.review.updated_at],
 ["duplicate request-response ID",f=>{f.review.id=f.reviewRequest.id;rebind(f);}],
 ["extra selected field",f=>f.approval.settledSourceReview.pass=true],
 ["missing explicit summary",f=>delete f.approval.settledSourceReview.summary],
 ["wrong resolved prefix",f=>f.reviewedHeadCommit=left],
 ["changed main",f=>f.mainRef.object.sha=left],
 ["wrong main ref",f=>f.mainRef.ref="refs/heads/dev"],
 ["wrong merge",f=>f.pr.merge_commit_sha=left],
 ["wrong ordered parent",f=>f.approval.normalMergeParents.reverse()],
 ["failed CI",f=>f.release.run.conclusion="failure"],
 ["other approved attempt",f=>f.approval.mainCiRun.runAttempt=2],
 ["missing CI job",f=>f.security.jobs.jobs.pop()],
 ["changes requested",f=>f.reviews.nodes.push({author:{login:"reviewer"},submittedAt:T(55),state:"CHANGES_REQUESTED"})],
 ["conflicting equal-time review states",f=>f.reviews.nodes.push({author:{login:"reviewer"},submittedAt:T(55),state:"APPROVED"},{author:{login:"reviewer"},submittedAt:T(55),state:"CHANGES_REQUESTED"})],
 ["truncated reviews",f=>f.reviews.pageInfo.hasNextPage=true],
 ["truncated threads",f=>f.threads.pageInfo.hasNextPage=true],
 ["unresolved thread",f=>f.threads.nodes.push({isResolved:false})],
 ["missing contract cutoff",f=>delete f.approval.reviewPreparedAtUtc],
 ["future decision",f=>f.approval.decidedAtUtc=T(131)],
];
for(const [label,change]of negatives)test("Claude refuses "+label,()=>{const f=fixture();change(f);assert.throws(()=>x.verifyBusinessLiveGitHubRecords31(f));});
test("retained extra summary cannot bypass null selected summary",()=>{const f=fixture(),raw=observation(f);raw.reviewSummary=JSON.stringify({...f.review,id:1003,body:"Findings"});assert.throws(()=>x.verifyPreservedBusinessLiveGitHub31(raw,admission(f),f.approval),/null original summary/);});
test("latest settled review is evaluated per reviewer without ignoring another outstanding review",()=>{const f=fixture();f.reviews.nodes=[{author:{login:"one"},submittedAt:T(51),state:"CHANGES_REQUESTED"},{author:{login:"one"},submittedAt:T(52),state:"APPROVED"}];assert.equal(x.verifyBusinessLiveGitHubRecords31(f),true);f.reviews.nodes.push({author:{login:"two"},submittedAt:T(53),state:"CHANGES_REQUESTED"});assert.throws(()=>x.verifyBusinessLiveGitHubRecords31(f),/changes-requested/);});
test("retained replay refuses observer substitution and start-main drift",()=>{const f=fixture(),raw=observation(f);raw.observer.sha256="0".repeat(64);assert.throws(()=>x.verifyPreservedBusinessLiveGitHub31(raw,admission(f),f.approval),/observer/);raw.observer=observation(f).observer;raw.main=JSON.stringify({ref:"refs/heads/main",object:{sha:left}});assert.throws(()=>x.verifyPreservedBusinessLiveGitHub31(raw,admission(f),f.approval),/main changed/);});
test("retained replay refuses a genuinely ambiguous commit prefix and accepts the full SHA",()=>{
  const f=fixture(),prefix=head.slice(0,7);assert.equal(prefix,collision.second.slice(0,7));assert.notEqual(head,collision.second);
  assert.throws(()=>git(["rev-parse","--verify",prefix+"^{commit}"]),/ambiguous|Needed a single revision/);
  f.review.body="No findings.\n**Reviewed commit:** `"+prefix+"`";rebind(f);
  assert.throws(()=>x.verifyPreservedBusinessLiveGitHub31(observation(f),admission(f),f.approval),/ambiguous|Needed a single revision/);
  f.review.body="No findings.\n**Reviewed commit:** `"+head+"`";rebind(f);
  assert.equal(git(["rev-parse","--verify",head+"^{commit}"]),head);
  assert.equal(x.verifyPreservedBusinessLiveGitHub31(observation(f),admission(f),f.approval),true);
});
test("Codex live and preserved behavior remains delegated unchanged",()=>{const f=fixture();f.approval.settledSourceReview.kind="bot-issue-comment-no-findings";f.approval.settledSourceReview.reviewer="chatgpt-codex-connector[bot]";delete f.approval.reviewPreparedAtUtc;f.review.user={login:"chatgpt-codex-connector[bot]"};f.review.performed_via_github_app={slug:"chatgpt-codex-connector"};f.review.body="No major issues. **Reviewed commit:** `"+head.slice(0,10)+"`";delete f.review.updated_at;delete f.reviewRequest.updated_at;rebind(f);assert.equal(x.verifyBusinessLiveGitHubRecords31(f),legacy.verifyLiveGitHubRecords31(f));assert.equal(x.verifyPreservedBusinessLiveGitHub31(observation(f),admission(f),f.approval),legacy.verifyPreservedLiveGitHub31(observation(f),admission(f),f.approval));assert.throws(()=>legacy.verifyLiveGitHubRecords31(fixture()),/Exact settled bot/);});
test("fixed live observer retains original synthetic responses through actual bound child calls and replays them",()=>{
  const f=fixture(),dir=path.join(root,"observer");fs.mkdirSync(dir);const raw=observation(f),records={};const prefix="repos/abhishekvatsa/crm3_baf_ops/";
  records[prefix+"git/ref/heads/main"]=raw.main;records[prefix+"pulls/405"]=raw.pr;
  for(const [kind,id]of [["release",11],["security",12]]){records[prefix+"actions/runs/"+id]=raw[kind].run;records[prefix+"actions/runs/"+id+"/attempts/1/jobs?per_page=100"]=raw[kind].jobs;}
  records[prefix+"issues/comments/1001"]=raw.reviewRequest;records[prefix+"issues/comments/1002"]=raw.review;records.graphql=raw.threads;
  fs.writeFileSync(path.join(dir,"api-records.json"),JSON.stringify(records));
  fs.writeFileSync(path.join(dir,"api"),`const fs=require('node:fs'),path=require('node:path');const args=process.argv.slice(2);if(args[0]!=='--hostname'||args[1]!=='github.com'||args[2]!=='--method'||!['GET','POST'].includes(args[3]))throw Error('Unexpected synthetic observer argv');const records=JSON.parse(fs.readFileSync(path.join(__dirname,'api-records.json')));if(!Object.hasOwn(records,args[4]))throw Error('Unselected endpoint');fs.appendFileSync(path.join(__dirname,'calls.jsonl'),JSON.stringify(args)+'\\n');process.stdout.write(records[args[4]]);`);
  fs.writeFileSync(path.join(dir,"input.json"),JSON.stringify({admission:admission(f),approval:f.approval}));
  fs.writeFileSync(path.join(dir,"observe.cjs"),`const fs=require('node:fs'),x=require(${JSON.stringify(path.join(__dirname,"business31ExecutionContract.cjs"))});const i=JSON.parse(fs.readFileSync('input.json'));const r=x.observeBusinessLiveGitHub31(i.admission,i.approval,new Date().toISOString());fs.writeFileSync('observed.json',JSON.stringify(r));if(!x.verifyPreservedBusinessLiveGitHub31(r,i.admission,i.approval))throw Error('Replay refused');`);
  const result=cp.spawnSync(process.execPath,["--no-global-search-paths",path.join(dir,"observe.cjs")],{cwd:dir,env,encoding:"utf8",windowsHide:true,timeout:60000,maxBuffer:1024*1024});assert.equal(result.error,undefined);assert.equal(result.signal,null);assert.equal(result.status,0,result.stderr);
  const observed=JSON.parse(fs.readFileSync(path.join(dir,"observed.json")));assert.equal(observed.review,raw.review);assert.equal(observed.reviewRequest,raw.reviewRequest);assert.equal(JSON.parse(observed.review).user.login,"claude[bot]");
  const calls=fs.readFileSync(path.join(dir,"calls.jsonl"),"utf8").trim().split("\n").map(JSON.parse);assert.equal(calls.length,10);assert.deepEqual(calls.map(c=>c[3]),["GET","GET","GET","GET","GET","GET","GET","GET","POST","GET"]);assert.equal(calls[0][4],calls.at(-1)[4]);assert.equal(calls[8][4],"graphql");
});
