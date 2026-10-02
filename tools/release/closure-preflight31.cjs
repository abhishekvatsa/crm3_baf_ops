"use strict";
// Private local closure preflight. Does not write, collect cloud evidence or deploy.
const {validateConfig,parseCli}=require("./backendRuntimeExecution31.cjs");
function preflightBackendRuntimeClosure31(config){
 validateConfig(config,true);
 const {verifyBackendRuntimeClosure31}=require("./backendRuntimeClosure31.cjs");
 const result=verifyBackendRuntimeClosure31({...config,nowUtc:new Date().toISOString()});
 if(result?.ok!==true)throw new Error("Actual closure validation did not pass");
 return {ok:true,mode:"VALIDATION_ONLY",source:result.source??{commit:result.sourceCommit},
  closurePointer:config.closurePointer,actualDeploymentPerformed:false,closureWritten:false,
  qualification:"Local replay only. This does not create approval or run a deployment."};
}
module.exports={preflightBackendRuntimeClosure31};
if(require.main===module){try{process.stdout.write(JSON.stringify(preflightBackendRuntimeClosure31(parseCli(process.argv.slice(2))),null,2)+"\n");}catch(e){process.stderr.write("Build31 closure preflight refused: "+e.message+"\n");process.exitCode=1;}}
