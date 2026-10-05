"""Data-only owned-process bridge. No install or collector policy lives here."""
import ctypes
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import sys
import threading
from ctypes import wintypes


def check_ports():
    """Read Windows listener tables; never bind, connect or terminate an owner."""
    api = ctypes.WinDLL("iphlpapi", use_last_error=True).GetExtendedTcpTable
    api.argtypes = [ctypes.c_void_p, ctypes.POINTER(wintypes.DWORD), wintypes.BOOL,
                    wintypes.ULONG, ctypes.c_int, wintypes.ULONG]
    api.restype = wintypes.DWORD
    occupied = []
    for family, row_size, port_offset, pid_offset in [(2, 24, 8, 20), (23, 56, 20, 52)]:
        size = wintypes.DWORD()
        status = api(None, ctypes.byref(size), False, family, 3, 0)
        if status != 122 or not 4 <= size.value <= 16 * 1024 * 1024:
            raise OSError(status, "Cannot size Windows listener table")
        buffer = ctypes.create_string_buffer(size.value)
        status = api(buffer, ctypes.byref(size), False, family, 3, 0)
        if status:
            raise OSError(status, "Cannot read Windows listener table")
        raw = buffer.raw[:size.value]
        count = int.from_bytes(raw[:4], "little")
        if 4 + count * row_size > len(raw):
            raise ValueError("Listener population exceeds returned bytes")
        for index in range(count):
            row = raw[4 + index * row_size:4 + (index + 1) * row_size]
            port = int.from_bytes(row[port_offset:port_offset + 2], "big")
            if port in (8080, 4400, 9150):
                occupied.append({"family": family, "port": port,
                                 "pid": int.from_bytes(row[pid_offset:pid_offset + 4], "little")})
    print(json.dumps({"documentType": "local-windows-listener-read", "ports": [8080, 4400, 9150],
                      "occupied": occupied}), flush=True)
    return 0


def main():
    if sys.argv[1:] == ["--check-ports"]:
        return check_ports()
    if len(sys.argv) != 2:
        raise ValueError("One exact private request file required")
    request_path = Path(sys.argv[1])
    if not request_path.is_absolute() or request_path.stat().st_size > 1024 * 1024:
        raise ValueError("Bounded absolute request required")
    request = json.loads(request_path.read_text(encoding="utf-8"))
    expected = {"schemaVersion", "parentPid", "supervisorSha256", "executable", "arguments", "cwd",
                "environment", "outputDirectory", "timeoutSeconds", "maxOutputBytes", "cleanupSeconds"}
    if set(request) != expected or request["schemaVersion"] != 1 or request["parentPid"] != os.getppid():
        raise ValueError("Exact parent/request required")
    source = Path(__file__).with_name("runtime_supervisor.py")
    if hashlib.sha256(source.read_bytes()).hexdigest().upper() != request["supervisorSha256"]:
        raise ValueError("Supervisor bytes differ")
    spec = importlib.util.spec_from_file_location("private_runtime_supervisor", source)
    supervisor = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(supervisor)
    open_process = supervisor._api("OpenProcess", supervisor.HANDLE, supervisor.W.DWORD,
                                   supervisor.W.BOOL, supervisor.W.DWORD)
    parent = open_process(0x100000, False, request["parentPid"])
    supervisor._check(parent, "open owning collector")
    cancel, done = threading.Event(), threading.Event()

    def watch_parent():
        while not done.is_set():
            state = supervisor._wait(parent, 50)
            if state != supervisor.WAIT_TIMEOUT:
                cancel.set()  # A failed wait is not authority to keep running.
                return

    watcher = threading.Thread(target=watch_parent, daemon=True)
    watcher.start()
    try:
        result = supervisor.run_owned_process(
            executable=request["executable"], arguments=request["arguments"], cwd=request["cwd"],
            environment=request["environment"], output_directory=request["outputDirectory"],
            timeout_seconds=request["timeoutSeconds"], max_output_bytes=request["maxOutputBytes"],
            cleanup_seconds=request["cleanupSeconds"], cancellation=cancel)
        return 0 if result["status"] == "SUCCESS" else 1
    finally:
        done.set()
        watcher.join(timeout=1)
        supervisor._close(parent)


if __name__ == "__main__":
    raise SystemExit(main())
