#!/usr/bin/env python3

import json
import os
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CATALOG_PATH = ROOT / "governance/test-evidence-taxonomy.json"
WORKFLOW_PATH = ROOT / ".github/workflows/release-gate.yml"
EMULATOR_ACTION = (
    "ReactiveCircus/android-emulator-runner@"
    "a421e43855164a8197daf9d8d40fe71c6996bb0d"
)


def fail(message: str) -> None:
    raise SystemExit(f"C04_TEST_EVIDENCE_TAXONOMY_FAIL: {message}")


def main() -> None:
    catalog = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))
    workflow = WORKFLOW_PATH.read_text(encoding="utf-8")

    if catalog.get("schemaVersion") != 1:
        fail("schemaVersion must be 1")
    if catalog.get("authority") != "C04_TEST_EVIDENCE_TAXONOMY":
        fail("authority is not exact")

    levels = catalog.get("levels")
    if not isinstance(levels, list):
        fail("levels must be a list")
    level_by_id = {
        item.get("id"): item for item in levels if isinstance(item, dict)
    }
    required_levels = {
        "source_contract",
        "host_unit",
        "host_widget",
        "firebase_emulator",
        "android_package",
        "android_emulator",
        "live_readback",
        "physical_device",
    }
    if set(level_by_id) != required_levels or len(levels) != len(level_by_id):
        fail("evidence levels are incomplete or duplicated")
    if level_by_id["physical_device"].get("physicalDevice") is not True:
        fail("physical-device level is not explicit")
    if any(
        level_by_id[level_id].get("physicalDevice") is not False
        for level_id in required_levels - {"physical_device"}
    ):
        fail("a non-physical level claims physical-device authority")

    jobs = catalog.get("ciJobs")
    if not isinstance(jobs, list):
        fail("ciJobs must be a list")
    job_by_id = {item.get("id"): item for item in jobs if isinstance(item, dict)}
    required_jobs = {
        "flutter_host",
        "android_package",
        "android_emulator",
        "firebase_emulator",
        "functions_host",
    }
    if set(job_by_id) != required_jobs or len(jobs) != len(job_by_id):
        fail("CI job taxonomy must contain five unique jobs")
    for job in jobs:
        headline = job.get("headline")
        if not isinstance(headline, str) or f"name: {headline}" not in workflow:
            fail(f"workflow headline is absent: {headline}")
        job_levels = job.get("levels")
        if not isinstance(job_levels, list) or not job_levels:
            fail(f"CI job has no evidence levels: {job.get('id')}")
        if any(level not in level_by_id for level in job_levels):
            fail(f"CI job uses an unknown level: {job.get('id')}")

    critical_paths = catalog.get("criticalPaths")
    if not isinstance(critical_paths, list):
        fail("criticalPaths must be a list")
    path_ids = [item.get("id") for item in critical_paths]
    if len(path_ids) != 8 or len(set(path_ids)) != len(path_ids):
        fail("critical-path coverage must contain eight unique paths")

    integration_path = catalog.get("deviceIntegration", {}).get("path")
    android_integration_references = 0
    for critical_path in critical_paths:
        evidence = critical_path.get("evidence")
        if not isinstance(evidence, list) or len(evidence) < 2:
            fail(f"critical path lacks two evidence witnesses: {critical_path.get('id')}")
        runtime_witness = False
        for witness in evidence:
            level_id = witness.get("level")
            relative_path = witness.get("path")
            if level_id not in level_by_id:
                fail(f"unknown evidence level in {critical_path.get('id')}")
            if not isinstance(relative_path, str) or not (ROOT / relative_path).is_file():
                fail(f"missing evidence file: {relative_path}")
            runtime_witness = runtime_witness or bool(
                level_by_id[level_id].get("runtimeExecuted")
            )
            if level_id == "android_emulator" and relative_path == integration_path:
                android_integration_references += 1
        if not runtime_witness:
            fail(f"critical path has no runtime witness: {critical_path.get('id')}")
        open_levels = critical_path.get("openEvidenceLevels")
        if not isinstance(open_levels, list):
            fail(f"critical path lacks explicit open evidence: {critical_path.get('id')}")
        if any(level not in level_by_id for level in open_levels):
            fail(f"critical path has unknown open evidence: {critical_path.get('id')}")

    device = catalog.get("deviceIntegration")
    if not isinstance(device, dict):
        fail("deviceIntegration must be an object")
    if not isinstance(integration_path, str) or not (ROOT / integration_path).is_file():
        fail("Android integration suite is absent")
    if device.get("ciJob") != "android_emulator":
        fail("Android integration suite is not assigned to its CI job")
    for key in (
        "productionCredentialsUsed",
        "productionBackendUsed",
        "physicalDeviceEvidence",
    ):
        if device.get(key) is not False:
            fail(f"Android emulator boundary is not false: {key}")
    if android_integration_references < 3:
        fail("Android integration suite does not cover three critical paths")
    if EMULATOR_ACTION not in workflow:
        fail("Android emulator action is absent or not pinned to the governed SHA")
    if integration_path not in workflow:
        fail("Android integration suite is not executed by CI")
    emulator_job = workflow.split("\n  android-emulator:\n", 1)
    if len(emulator_job) != 2:
        fail("Android emulator CI job is absent")
    emulator_job = emulator_job[1].split("\n  firestore-rules:\n", 1)[0]
    if "timeout-minutes: 30" not in emulator_job:
        fail("Android emulator CI job is not bounded to 30 minutes")

    lines = [
        "## Test evidence taxonomy",
        "",
        "| Critical path | Executed evidence | Evidence still open |",
        "|---|---|---|",
    ]
    for critical_path in critical_paths:
        executed = ", ".join(
            level_by_id[item["level"]]["label"]
            for item in critical_path["evidence"]
        )
        open_evidence = ", ".join(
            level_by_id[level]["label"]
            for level in critical_path["openEvidenceLevels"]
        ) or "None"
        lines.append(
            f"| {critical_path['label']} | {executed} | {open_evidence} |"
        )
    lines.extend(
        [
            "",
            "Android emulator evidence is not physical-device evidence and does not use production credentials or backend state.",
        ]
    )
    summary = "\n".join(lines) + "\n"
    summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary_path:
        with Path(summary_path).open("a", encoding="utf-8", newline="\n") as handle:
            handle.write(summary)

    print(
        "PASS_C04_TEST_EVIDENCE_TAXONOMY: "
        f"levels={len(level_by_id)} jobs={len(job_by_id)} "
        f"criticalPaths={len(critical_paths)} androidIntegration=true "
        "physicalDeviceEvidence=false"
    )


if __name__ == "__main__":
    main()
