"""Private Windows process ownership primitive; no runtime/release authority.

No shell, credential lookup, install, network client, or collector entry exists.
The caller must independently select the executable, source and explicit env.
"""

from __future__ import annotations

import ctypes as C
from ctypes import wintypes as W
import hashlib
import json
import math
import os
from pathlib import Path
import subprocess
import threading
import time
from datetime import datetime, timezone

if os.name != "nt":
    raise RuntimeError("This private supervisor supports Windows only")

k32 = C.WinDLL("kernel32", use_last_error=True)
SIZE_T = C.c_size_t
HANDLE = W.HANDLE
INVALID_HANDLE = C.c_void_p(-1).value
WAIT_OBJECT_0, WAIT_TIMEOUT, INFINITE = 0, 258, 0xFFFFFFFF
JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE = 0x2000
CREATE_SUSPENDED, CREATE_NO_WINDOW = 0x4, 0x08000000
CREATE_UNICODE_ENVIRONMENT, EXTENDED_STARTUPINFO_PRESENT = 0x400, 0x80000
PROC_THREAD_ATTRIBUTE_HANDLE_LIST = 0x20002
PROC_THREAD_ATTRIBUTE_JOB_LIST = 0x2000D
STARTF_USESTDHANDLES = 0x100
TERMINATION_CODE = 0xE0310001


class SECURITY_ATTRIBUTES(C.Structure):
    _fields_ = [("nLength", W.DWORD), ("lpSecurityDescriptor", W.LPVOID),
                ("bInheritHandle", W.BOOL)]


class STARTUPINFO(C.Structure):
    _fields_ = [("cb", W.DWORD), ("lpReserved", W.LPWSTR),
                ("lpDesktop", W.LPWSTR), ("lpTitle", W.LPWSTR),
                ("dwX", W.DWORD), ("dwY", W.DWORD),
                ("dwXSize", W.DWORD), ("dwYSize", W.DWORD),
                ("dwXCountChars", W.DWORD), ("dwYCountChars", W.DWORD),
                ("dwFillAttribute", W.DWORD), ("dwFlags", W.DWORD),
                ("wShowWindow", W.WORD), ("cbReserved2", W.WORD),
                ("lpReserved2", C.POINTER(C.c_ubyte)),
                ("hStdInput", HANDLE), ("hStdOutput", HANDLE),
                ("hStdError", HANDLE)]


class STARTUPINFOEX(C.Structure):
    _fields_ = [("StartupInfo", STARTUPINFO), ("lpAttributeList", W.LPVOID)]


class PROCESS_INFORMATION(C.Structure):
    _fields_ = [("hProcess", HANDLE), ("hThread", HANDLE),
                ("dwProcessId", W.DWORD), ("dwThreadId", W.DWORD)]


class BASIC_LIMITS(C.Structure):
    _fields_ = [("PerProcessUserTimeLimit", C.c_longlong),
                ("PerJobUserTimeLimit", C.c_longlong), ("LimitFlags", W.DWORD),
                ("MinimumWorkingSetSize", SIZE_T), ("MaximumWorkingSetSize", SIZE_T),
                ("ActiveProcessLimit", W.DWORD), ("Affinity", SIZE_T),
                ("PriorityClass", W.DWORD), ("SchedulingClass", W.DWORD)]


class IO_COUNTERS(C.Structure):
    _fields_ = [(name, C.c_ulonglong) for name in (
        "ReadOperationCount", "WriteOperationCount", "OtherOperationCount",
        "ReadTransferCount", "WriteTransferCount", "OtherTransferCount")]


class EXTENDED_LIMITS(C.Structure):
    _fields_ = [("BasicLimitInformation", BASIC_LIMITS), ("IoInfo", IO_COUNTERS),
                ("ProcessMemoryLimit", SIZE_T), ("JobMemoryLimit", SIZE_T),
                ("PeakProcessMemoryUsed", SIZE_T), ("PeakJobMemoryUsed", SIZE_T)]


class ACCOUNTING(C.Structure):
    _fields_ = [("TotalUserTime", C.c_longlong), ("TotalKernelTime", C.c_longlong),
                ("ThisPeriodTotalUserTime", C.c_longlong),
                ("ThisPeriodTotalKernelTime", C.c_longlong),
                ("TotalPageFaultCount", W.DWORD), ("TotalProcesses", W.DWORD),
                ("ActiveProcesses", W.DWORD), ("TotalTerminatedProcesses", W.DWORD)]


def _api(name, restype, *argtypes):
    fn = getattr(k32, name)
    fn.restype, fn.argtypes = restype, argtypes
    return fn


_close = _api("CloseHandle", W.BOOL, HANDLE)
_job = _api("CreateJobObjectW", HANDLE, W.LPVOID, W.LPCWSTR)
_set_job = _api("SetInformationJobObject", W.BOOL, HANDLE, C.c_int, W.LPVOID, W.DWORD)
_query_job = _api("QueryInformationJobObject", W.BOOL, HANDLE, C.c_int,
                  W.LPVOID, W.DWORD, W.LPVOID)
_is_in_job = _api("IsProcessInJob", W.BOOL, HANDLE, HANDLE, C.POINTER(W.BOOL))
_terminate_job = _api("TerminateJobObject", W.BOOL, HANDLE, W.UINT)
_terminate_process = _api("TerminateProcess", W.BOOL, HANDLE, W.UINT)
_wait = _api("WaitForSingleObject", W.DWORD, HANDLE, W.DWORD)
_exit_code = _api("GetExitCodeProcess", W.BOOL, HANDLE, C.POINTER(W.DWORD))
_resume = _api("ResumeThread", W.DWORD, HANDLE)
_pipe = _api("CreatePipe", W.BOOL, C.POINTER(HANDLE), C.POINTER(HANDLE),
             C.POINTER(SECURITY_ATTRIBUTES), W.DWORD)
_set_handle = _api("SetHandleInformation", W.BOOL, HANDLE, W.DWORD, W.DWORD)
_read = _api("ReadFile", W.BOOL, HANDLE, W.LPVOID, W.DWORD, C.POINTER(W.DWORD), W.LPVOID)
_file = _api("CreateFileW", HANDLE, W.LPCWSTR, W.DWORD, W.DWORD,
             C.POINTER(SECURITY_ATTRIBUTES), W.DWORD, W.DWORD, HANDLE)
_init_attrs = _api("InitializeProcThreadAttributeList", W.BOOL, W.LPVOID,
                   W.DWORD, W.DWORD, C.POINTER(SIZE_T))
_update_attrs = _api("UpdateProcThreadAttribute", W.BOOL, W.LPVOID, W.DWORD,
                     SIZE_T, W.LPVOID, SIZE_T, W.LPVOID, W.LPVOID)
_delete_attrs = _api("DeleteProcThreadAttributeList", None, W.LPVOID)
_create = _api("CreateProcessW", W.BOOL, W.LPCWSTR, W.LPWSTR, W.LPVOID,
               W.LPVOID, W.BOOL, W.DWORD, W.LPVOID, W.LPCWSTR,
               C.POINTER(STARTUPINFOEX), C.POINTER(PROCESS_INFORMATION))


def _check(value, label):
    if not value:
        raise OSError(C.get_last_error(), label)
    return value


def _utc():
    return datetime.now(timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z")


def _regular(value, directory=False):
    p = Path(value)
    if not p.is_absolute():
        raise ValueError("Explicit absolute paths required")
    p = Path(os.path.abspath(p))
    for part in [*reversed(p.parents), p]:
        st = part.lstat()
        if getattr(st, "st_file_attributes", 0) & 0x400:
            raise ValueError("Redirected path refused")
    if not (p.is_dir() if directory else p.is_file()):
        raise ValueError("Regular file/directory required")
    return str(p)


def _active(job):
    info = ACCOUNTING()
    _check(_query_job(job, 1, C.byref(info), C.sizeof(info), None), "query owned job")
    return int(info.ActiveProcesses)


def _exited(process):
    status = _wait(process, 0)
    if status not in (WAIT_OBJECT_0, WAIT_TIMEOUT):
        raise OSError(C.get_last_error(), "wait owned process")
    return status == WAIT_OBJECT_0


def run_owned_process(*, executable, arguments, cwd, environment, output_directory,
                      timeout_seconds, max_output_bytes, cancellation=None,
                      cleanup_seconds=10.0):
    """Run one explicitly selected process tree. Never retries or invokes a shell.

    This is local process ownership, not authenticated runtime/source approval.
    The output directory must be absent. Failure/cleanup evidence is retained.
    """
    executable, cwd = _regular(executable), _regular(cwd, True)
    if not isinstance(arguments, list) or len(arguments) > 128 or any(
            not isinstance(a, str) or "\0" in a for a in arguments):
        raise ValueError("Finite explicit argument array required")
    command = subprocess.list2cmdline([executable, *arguments])
    if len(command) > 30000:
        raise ValueError("Command line bound exceeded")
    if not isinstance(environment, dict) or len(environment) > 128:
        raise ValueError("Finite explicit environment required")
    folded = set()
    for key, value in environment.items():
        if (not isinstance(key, str) or not key or "=" in key or "\0" in key
                or not isinstance(value, str) or "\0" in value or key.upper() in folded):
            raise ValueError("Unambiguous explicit environment required")
        folded.add(key.upper())
    block = "\0".join(k + "=" + environment[k] for k in sorted(environment, key=str.upper)) + "\0\0"
    if len(block) > 30000:
        raise ValueError("Environment bound exceeded")
    if (isinstance(max_output_bytes, bool) or not isinstance(max_output_bytes, int)
            or not 1 <= max_output_bytes <= 64 * 1024 * 1024):
        raise ValueError("Output bound must be 1..64MiB per stream")
    if any(isinstance(v, bool) or not isinstance(v, (int, float)) or not math.isfinite(v)
           for v in (timeout_seconds, cleanup_seconds)) or not (0 < timeout_seconds <= 3600
           and 0 < cleanup_seconds <= 30):
        raise ValueError("Finite execution and cleanup deadlines required")
    if cancellation is not None and not isinstance(cancellation, threading.Event):
        raise ValueError("Cancellation must be a threading.Event")
    output = Path(output_directory)
    if not output.is_absolute():
        raise ValueError("Absolute new output directory required")
    _regular(output.parent, True)
    output.mkdir()  # Exclusive ownership; no pre-existing evidence overwritten.
    output = Path(_regular(output, True))
    result = dict(schemaVersion=1, documentType="private-windows-owned-process-result",
                  executable=executable, arguments=arguments, cwd=cwd,
                  startedAtUtc=_utc(), resumedAtUtc=None, completedAtUtc=None,
                  processId=None, jobAssigned=False, resumed=False, exitCode=None,
                  failure=None, cleanupErrors=[], terminationRequested=False,
                  rootExited=False, activeProcesses=None, treeComplete=False,
                  outputComplete=False, status="FAILED", authenticated=False,
                  deploymentAuthorized=False)
    handles, readers, streams = [], [], {}
    job = process = thread = attrs = None
    attrs_initialized = False
    overflow, reader_error = threading.Event(), threading.Event()

    def own(handle):
        if not handle or handle == INVALID_HANDLE:
            raise OSError(C.get_last_error(), "create owned handle")
        handles.append(handle)
        return handle

    def close_owned(handle):
        if handle in handles:
            if not _close(handle):
                result["cleanupErrors"].append({"operation": "close handle", "winerror": C.get_last_error()})
            else:
                handles.remove(handle)

    def drain(name, handle):
        state = streams[name]
        try:
            with open(output / (name + ".bin"), "xb", buffering=0) as sink:
                buf = C.create_string_buffer(65536)
                while True:
                    count = W.DWORD()
                    ok = _read(handle, buf, len(buf), C.byref(count), None)
                    if not ok:
                        code = C.get_last_error()
                        if code == 109:  # ERROR_BROKEN_PIPE means every writer closed.
                            state["eof"] = True
                            break
                        raise OSError(code, "read owned pipe")
                    if not count.value:
                        state["eof"] = True
                        break
                    data = buf.raw[:count.value]
                    state["observedBytes"] += len(data)
                    retained = data[:max(0, max_output_bytes - state["bytes"])]
                    if retained:
                        written = sink.write(retained)
                        if written != len(retained):
                            raise OSError("short evidence write")
                        state["bytes"] += written
                    if state["observedBytes"] > max_output_bytes:
                        overflow.set()
        except BaseException as error:
            state["error"] = {"type": type(error).__name__, "winerror": getattr(error, "winerror", None)}
            reader_error.set()
        finally:
            if not _close(handle):
                state["closeError"] = C.get_last_error()
                reader_error.set()

    try:
        job = own(_job(None, None))
        limits = EXTENDED_LIMITS()
        limits.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
        _check(_set_job(job, 9, C.byref(limits), C.sizeof(limits)), "configure owned job")
        sa = SECURITY_ATTRIBUTES(C.sizeof(SECURITY_ATTRIBUTES), None, True)
        pairs = {}
        for name in ("stdout", "stderr"):
            read_handle, write_handle = HANDLE(), HANDLE()
            _check(_pipe(C.byref(read_handle), C.byref(write_handle), C.byref(sa), 0), "create owned pipe")
            own(read_handle.value)
            own(write_handle.value)
            _check(_set_handle(read_handle, 1, 0), "make read handle non-inheritable")
            pairs[name] = (read_handle.value, write_handle.value)
        stdin = own(_file("NUL", 0x80000000, 3, C.byref(sa), 3, 0, None))
        size = SIZE_T()
        _init_attrs(None, 2, 0, C.byref(size))
        if not size.value or C.get_last_error() != 122:
            raise OSError(C.get_last_error(), "measure process attributes")
        attrs_buffer = C.create_string_buffer(size.value)
        attrs = C.cast(attrs_buffer, W.LPVOID)
        _check(_init_attrs(attrs, 2, 0, C.byref(size)), "initialize process attributes")
        attrs_initialized = True
        inherited = (HANDLE * 3)(stdin, pairs["stdout"][1], pairs["stderr"][1])
        _check(_update_attrs(attrs, 0, PROC_THREAD_ATTRIBUTE_HANDLE_LIST,
                             inherited, C.sizeof(inherited), None, None), "bind inherited handles")
        # Windows 10+ assigns the private job within CreateProcess, closing the
        # suspended-but-unassigned interval. Unsupported hosts fail; no fallback.
        jobs = (HANDLE * 1)(job)
        _check(_update_attrs(attrs, 0, PROC_THREAD_ATTRIBUTE_JOB_LIST,
                             jobs, C.sizeof(jobs), None, None), "bind creation job")
        startup, info = STARTUPINFOEX(), PROCESS_INFORMATION()
        startup.StartupInfo.cb = C.sizeof(startup)
        startup.StartupInfo.dwFlags = STARTF_USESTDHANDLES
        startup.StartupInfo.hStdInput = stdin
        startup.StartupInfo.hStdOutput = pairs["stdout"][1]
        startup.StartupInfo.hStdError = pairs["stderr"][1]
        startup.lpAttributeList = attrs
        command_buffer, env_buffer = C.create_unicode_buffer(command), C.create_unicode_buffer(block)
        flags = CREATE_SUSPENDED | CREATE_NO_WINDOW | CREATE_UNICODE_ENVIRONMENT | EXTENDED_STARTUPINFO_PRESENT
        _check(_create(executable, command_buffer, None, None, True, flags,
                       env_buffer, cwd, C.byref(startup), C.byref(info)), "create suspended owned child")
        process, thread = own(info.hProcess), own(info.hThread)
        result["processId"] = int(info.dwProcessId)
        member = W.BOOL()
        _check(_is_in_job(process, job, C.byref(member)), "verify creation job membership")
        if not member.value:
            raise RuntimeError("Created suspended child is not in its private job")
        result["jobAssigned"] = True
        for name, (read_handle, write_handle) in pairs.items():
            streams[name] = {"bytes": 0, "observedBytes": 0, "eof": False, "error": None}
            worker = threading.Thread(target=drain, args=(name, read_handle), daemon=True)
            worker.start()
            readers.append(worker)
            handles.remove(read_handle)  # The reader now exclusively owns it.
            close_owned(write_handle)
        close_owned(stdin)
        if reader_error.is_set():
            result["failure"] = "output-persistence-or-read-failed"
        elif cancellation is not None and cancellation.is_set():
            result["failure"] = "cancelled-before-resume"
        else:
            deadline = time.monotonic() + timeout_seconds
            if _resume(thread) == 0xFFFFFFFF:
                raise OSError(C.get_last_error(), "resume owned child")
            result["resumed"], result["resumedAtUtc"] = True, _utc()
            close_owned(thread)
            while True:
                result["rootExited"], result["activeProcesses"] = _exited(process), _active(job)
                if reader_error.is_set():
                    result["failure"] = "output-persistence-or-read-failed"
                elif overflow.is_set():
                    result["failure"] = "output-bound-exceeded"
                elif cancellation is not None and cancellation.is_set():
                    result["failure"] = "cancelled"
                elif time.monotonic() >= deadline:
                    result["failure"] = "timeout"
                if result["failure"]:
                    break
                if result["rootExited"] and result["activeProcesses"] == 0 and all(not r.is_alive() for r in readers):
                    break
                time.sleep(0.01)
    except BaseException as error:
        result["failure"] = {"operation": "supervisor-failed", "type": type(error).__name__,
                             "detail": str(error), "winerror": getattr(error, "winerror", None)}
    finally:
        # If membership verification failed, the child has never resumed.
        # Terminate only that exact handle; the creation job also remains owned.
        try:
            if process:
                incomplete = not _exited(process) or (result["jobAssigned"] and _active(job) != 0)
                if incomplete:
                    result["terminationRequested"] = True
                    if result["jobAssigned"]:
                        _check(_terminate_job(job, TERMINATION_CODE), "terminate owned job")
                    else:
                        _check(_terminate_process(process, TERMINATION_CODE), "terminate suspended unassigned child")
                end = time.monotonic() + cleanup_seconds
                while True:
                    result["rootExited"] = _exited(process)
                    result["activeProcesses"] = _active(job) if result["jobAssigned"] else None
                    if result["rootExited"] and (not result["jobAssigned"] or result["activeProcesses"] == 0):
                        break
                    if time.monotonic() >= end:
                        raise TimeoutError("Owned process tree did not terminate within cleanup bound")
                    time.sleep(0.01)
                code = W.DWORD()
                _check(_exit_code(process, C.byref(code)), "read root exit")
                result["exitCode"] = int(code.value)
                result["treeComplete"] = result["rootExited"] and result["jobAssigned"] and result["activeProcesses"] == 0
        except BaseException as error:
            result["cleanupErrors"].append({"operation": "owned-tree-cleanup", "detail": str(error)})
            result["treeComplete"] = False
            # Closing this private job is an independent kill-on-close fallback.
            # We do not infer verified termination from closing its handle.
            if job:
                close_owned(job)
        # Close all parent write ends even if setup failed before reader startup.
        for handle in list(handles):
            if handle not in (job, process, thread):
                close_owned(handle)
        drain_end = time.monotonic() + cleanup_seconds
        for worker in readers:
            worker.join(max(0.0, drain_end - time.monotonic()))
        result["outputComplete"] = len(streams) == 2 and all(not r.is_alive() for r in readers) and all(
            s["eof"] and s["error"] is None and "closeError" not in s for s in streams.values())
        if readers and not result["outputComplete"]:
            result["cleanupErrors"].append({"operation": "pipe-drain", "detail": "Incomplete owned output drain"})
        if attrs_initialized:
            _delete_attrs(attrs)
        for handle in list(handles):
            close_owned(handle)
    for name, state in streams.items():
        log = output / (name + ".bin")
        if log.is_file() and all(not reader.is_alive() for reader in readers):
            state["sha256"] = hashlib.sha256(log.read_bytes()).hexdigest().upper()
        state["path"] = str(log)
    result["streams"] = streams
    if result["failure"] is None and result["exitCode"] != 0:
        result["failure"] = "nonzero-root-exit"
    if result["failure"] is None and result["cleanupErrors"]:
        result["failure"] = "cleanup-incomplete"
    if (result["failure"] is None and result["resumed"] and result["treeComplete"]
            and result["outputComplete"] and result["exitCode"] == 0):
        result["status"] = "SUCCESS"
    result["completedAtUtc"] = _utc()
    with open(output / "result.json", "x", encoding="utf8", newline="\n") as sink:
        json.dump(result, sink, indent=2)
        sink.write("\n")
    return result


if __name__ == "__main__":
    raise SystemExit("No standalone collector or operational entry; private owned-process API only")
