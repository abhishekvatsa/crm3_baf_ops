"use strict";
// Synthetic custody and real native Config checks for independent CLI samples.
// This does not admit a parent controller, replay source Git, or authenticate controls.
const fs = require("node:fs"), path = require("node:path"), assert = require("node:assert/strict");
const custody = require("./business31CohortProcess.cjs");
const execution = require("./business31ExecutionContract.cjs");
const transport = require("./runtimeDeploymentTransportGuard31.cjs");
const STAGES = new Set(["BEFORE_ORIGINAL_PREPARE", "BEFORE_IDENTITY", "BEFORE_ORIGINAL_HASH", "AFTER_ORIGINAL_PREPARE"]);
function create({ selection, Config, identityBaseline, event, state, verifyProjectFixtures }) {
  const evidence = path.join(selection.scratch, "controller-shaped-evidence");
  fs.mkdirSync(evidence);
  const source = { commit: "1".repeat(40), tree: "2".repeat(40), functionsTree: "3".repeat(40) };
  const approvalPointer = { commit: "4".repeat(40), file: "synthetic-decision.json", sha256: "A".repeat(64) };
  const save = (name, value) => custody.save31(evidence, path.join(evidence, name), value);
  const parametersOriginal = save("parameters-original.json", {
    schemaVersion: 1, documentType: "build31-business-intent-parameters", source,
    parameters: { CRM3_MUTATING_CALLABLE_ENFORCE_APP_CHECK: "false" }
  });
  const intendedHashInputs = save("intended-hash-inputs.json", { syntheticFixtureOnly: true });
  const intentPreparation = save("intent-preparation.json", {
    schemaVersion: 1, documentType: "build31-business-intent-preparation", source, intendedHashInputs, parametersOriginal
  });
  const ctx = { repoRoot: selection.project, evidenceDirectory: evidence, source, approvalPointer,
    runtime: { nodeExecutable: process.execPath }, contract: { schemaVersion: 2, intentPreparation, intendedHashInputs } };
  fs.mkdirSync(custody.phaseDirectory31(ctx, selection.phase), { recursive: true });
  const parameterConfig = custody.createParameterConfig31(ctx, selection.phase);
  const baselinePointer = save("baseline-controls.json", structuredClone(identityBaseline));
  const identityDirectory = path.join(selection.scratch, "identity-capture");
  fs.mkdirSync(identityDirectory);
  let nativeConfig, currentControls;
  function check(stage) {
    assert(STAGES.has(stage));
    try {
      assert(nativeConfig, "native Config not bound");
      nativeConfig.assertUnchanged();
      event({ kind: "OFFLINE_NATIVE_CONFIG_CHECK", phase: selection.phase, stage, outcome: "PASS" });
    } catch (error) {
      const row = { phase: selection.phase, stage, reasonCode: "NATIVE_CONFIG_REFUSED" };
      state.firstIdentityAdmissionFailure ??= row;
      event({ kind: "OFFLINE_ADMISSION_CHECK_REFUSED", ...row });
      throw error;
    }
  }
  return {
    source, approvalPointer, baselinePointer,
    now: () => new Date(Date.now()).toISOString(),
    bind(options) {
      assert.equal(nativeConfig, undefined);
      nativeConfig = custody.bindNativeConfig31({ ctx, phase: selection.phase, parameterConfig, options,
        sourceFunctions: selection.functionsConfiguration, Config });
      currentControls = save("current-controls.json", {
        schemaVersion: 1, syntheticFixtureOnly: true, project: structuredClone(identityBaseline.project),
        projectIam: structuredClone(identityBaseline.projectIam)
      });
      event({ kind: "REAL_NATIVE_CONFIG_BOUND", phase: selection.phase,
        governedParameters: true, syntheticCustodyOnly: true, parentControllerAdmitted: false });
      check("BEFORE_ORIGINAL_PREPARE");
    },
    check,
    admission(operation) {
      return require("./business31ServiceIdentityCapture.cjs").admitServiceIdentity31(operation, {
        currentControls,
        verifyControls(pointer) {
          check("BEFORE_IDENTITY");
          const original = execution.json(execution.privateBytes(evidence, pointer));
          assert.equal(original.syntheticFixtureOnly, true);
          assert.deepEqual(transport.existingServiceIdentityBindings31(original),
            transport.existingServiceIdentityBindings31(identityBaseline));
          event({ kind: "REAL_IDENTITY_CONTROL_SHAPE_VERIFIED", phase: selection.phase,
            fullControllerSourceAndControlsReplay: false });
        },
        assertClean: verifyProjectFixtures,
        assertWindow() {
          const current = Date.now();
          assert(current >= selection.fixtureNow - 60000 && current <= selection.fixtureNow + 3 * 3600000);
          event({ kind: "SYNTHETIC_EXISTING_IDENTITY_ADMISSION", phase: selection.phase,
            service: operation.service, fixtureOnly: true, productionControllerControlsOrWindowVerified: false });
          return new Date(current).toISOString();
        }
      });
    },
    assertWindow() {
      const current = Date.now();
      assert(current >= selection.fixtureNow - 60000 && current <= selection.fixtureNow + 3 * 3600000);
      return new Date(current).toISOString();
    },
    saveIdentity(name, value) {
      assert.equal(path.basename(name), name);
      assert(name.startsWith("service-identit"));
      const bytes = Buffer.isBuffer(value) ? value : Buffer.from(JSON.stringify(value, null, 2) + "\n");
      assert(bytes.length <= 16 * 1024 * 1024);
      const file = path.join(identityDirectory, name);
      fs.writeFileSync(file, bytes, { flag: "wx" });
      return { file: name, sha256: execution.sha(bytes), bytes: bytes.length };
    }
  };
}
module.exports = { create };
