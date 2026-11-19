"""Run one Windows lane task and its descendants under a single deadline."""
from __future__ import annotations

import ctypes as ct
from ctypes import wintypes as wt
import json
import msvcrt
import os
import subprocess
import sys
import time


SIZE_T = ct.c_size_t
STARTF_USESTDHANDLES = 0x100
CREATE_SUSPENDED = 0x4
CREATE_NO_WINDOW = 0x08000000
JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE = 0x2000
JOB_ACCOUNTING = 1
JOB_PROCESS_IDS = 3
JOB_EXTENDED_LIMITS = 9
SYNCHRONIZE = 0x100000
PROCESS_QUERY_LIMITED_INFORMATION = 0x1000
ERROR_INVALID_PARAMETER = 87
ERROR_MORE_DATA = 234
EXIT_TIMEOUT = 124
EXIT_SETUP_FAILURE = 125
CLEANUP_SECONDS = 3


class JobBasicLimits(ct.Structure):
    _fields_ = [
        ("process_cpu_limit", ct.c_longlong), ("job_cpu_limit", ct.c_longlong),
        ("flags", wt.DWORD), ("min_working_set", SIZE_T), ("max_working_set", SIZE_T),
        ("process_limit", wt.DWORD), ("affinity", SIZE_T),
        ("priority_class", wt.DWORD), ("scheduling_class", wt.DWORD),
    ]


class JobExtendedLimits(ct.Structure):
    _fields_ = [
        ("basic", JobBasicLimits), ("io_counters", ct.c_ulonglong * 6),
        ("process_memory_limit", SIZE_T), ("job_memory_limit", SIZE_T),
        ("peak_process_memory", SIZE_T), ("peak_job_memory", SIZE_T),
    ]


class JobAccounting(ct.Structure):
    _fields_ = [
        ("user_time", ct.c_longlong), ("kernel_time", ct.c_longlong),
        ("period_user_time", ct.c_longlong), ("period_kernel_time", ct.c_longlong),
        ("page_faults", wt.DWORD), ("total", wt.DWORD),
        ("active", wt.DWORD), ("terminated", wt.DWORD),
    ]


class StartupInfo(ct.Structure):
    _fields_ = [
        ("size", wt.DWORD), ("reserved", wt.LPWSTR), ("desktop", wt.LPWSTR),
        ("title", wt.LPWSTR), ("x", wt.DWORD), ("y", wt.DWORD),
        ("x_size", wt.DWORD), ("y_size", wt.DWORD), ("x_chars", wt.DWORD),
        ("y_chars", wt.DWORD), ("fill", wt.DWORD), ("flags", wt.DWORD),
        ("show_window", wt.WORD), ("reserved_size", wt.WORD),
        ("reserved2", ct.POINTER(wt.BYTE)), ("stdin", wt.HANDLE),
        ("stdout", wt.HANDLE), ("stderr", wt.HANDLE),
    ]


class ProcessInfo(ct.Structure):
    _fields_ = [
        ("process", wt.HANDLE), ("thread", wt.HANDLE),
        ("pid", wt.DWORD), ("thread_id", wt.DWORD),
    ]


kernel = ct.WinDLL("kernel32", use_last_error=True)


def bind(name, arguments, returns=wt.BOOL):
    operation = getattr(kernel, name)
    operation.argtypes = arguments
    operation.restype = returns
    return operation


create_job = bind("CreateJobObjectW", [ct.c_void_p, wt.LPCWSTR], wt.HANDLE)
set_job = bind("SetInformationJobObject", [wt.HANDLE, ct.c_int, ct.c_void_p, wt.DWORD])
query_job = bind("QueryInformationJobObject", [wt.HANDLE, ct.c_int, ct.c_void_p, wt.DWORD, ct.c_void_p])
assign_to_job = bind("AssignProcessToJobObject", [wt.HANDLE, wt.HANDLE])
terminate_job = bind("TerminateJobObject", [wt.HANDLE, wt.UINT])
terminate_process = bind("TerminateProcess", [wt.HANDLE, wt.UINT])
close = bind("CloseHandle", [wt.HANDLE])
wait_process = bind("WaitForSingleObject", [wt.HANDLE, wt.DWORD], wt.DWORD)
open_process = bind("OpenProcess", [wt.DWORD, wt.BOOL, wt.DWORD], wt.HANDLE)
in_job = bind("IsProcessInJob", [wt.HANDLE, wt.HANDLE, ct.POINTER(wt.BOOL)])
resume = bind("ResumeThread", [wt.HANDLE], wt.DWORD)
exit_code = bind("GetExitCodeProcess", [wt.HANDLE, ct.POINTER(wt.DWORD)])
create_process = bind("CreateProcessW", [
    wt.LPCWSTR, wt.LPWSTR, ct.c_void_p, ct.c_void_p, wt.BOOL, wt.DWORD,
    ct.c_void_p, wt.LPCWSTR, ct.POINTER(StartupInfo), ct.POINTER(ProcessInfo),
])


def checked(value):
    if not value:
        raise ct.WinError(ct.get_last_error())
    return value


def active_processes(job):
    accounting = JobAccounting()
    checked(query_job(job, JOB_ACCOUNTING, ct.byref(accounting), ct.sizeof(accounting), None))
    return accounting.active


def wait_until_idle(job, deadline):
    while active_processes(job):
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            return False
        time.sleep(min(0.01, remaining))
    return True


def job_process_ids(job):
    capacity = 16
    while True:
        buffer = ct.create_string_buffer(8 + ct.sizeof(SIZE_T) * capacity)
        if query_job(job, JOB_PROCESS_IDS, buffer, ct.sizeof(buffer), None):
            count = wt.DWORD.from_buffer(buffer, 4).value
            return list((SIZE_T * count).from_buffer(buffer, 8))
        if ct.get_last_error() != ERROR_MORE_DATA or capacity >= 65536:
            raise ct.WinError(ct.get_last_error())
        capacity *= 2


def terminate_and_drain(job, code):
    # Keep verified handles until rundown. Termination targets only the job.
    handles = []
    try:
        for pid in job_process_ids(job):
            handle = open_process(SYNCHRONIZE | PROCESS_QUERY_LIMITED_INFORMATION, False, pid)
            if not handle and ct.get_last_error() == ERROR_INVALID_PARAMETER:
                continue
            checked(handle)
            owned = wt.BOOL()
            if not in_job(handle, job, ct.byref(owned)):
                error = ct.WinError(ct.get_last_error())
                close(handle)
                raise error
            if owned.value:
                handles.append(handle)
            else:
                close(handle)
        checked(terminate_job(job, code))
        deadline = time.monotonic() + CLEANUP_SECONDS
        if not wait_until_idle(job, deadline):
            raise RuntimeError("Owned task did not retire")
        for handle in handles:
            remaining_ms = max(0, int((deadline - time.monotonic()) * 1000))
            if wait_process(handle, remaining_ms) != 0:
                raise RuntimeError("Owned task process rundown did not finish")
    finally:
        for handle in handles:
            close(handle)


def run_owned(command: list[str], log: str, limit: int) -> tuple[int, bool]:
    if not command or not command[0] or limit <= 0:
        raise ValueError("A command and a positive deadline are required")
    deadline = time.monotonic() + limit
    job = checked(create_job(None, None))
    process = ProcessInfo()
    assigned = False
    try:
        limits = JobExtendedLimits()
        # Ordinary descendants cannot leave this job. Closing it on error
        # terminates everything it owns, including after the direct child exits.
        limits.basic.flags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
        checked(set_job(job, JOB_EXTENDED_LIMITS, ct.byref(limits), ct.sizeof(limits)))
        with open(log, "wb", buffering=0) as output, open(os.devnull, "rb") as stdin:
            startup = StartupInfo()
            startup.size = ct.sizeof(startup)
            startup.flags = STARTF_USESTDHANDLES
            startup.stdin = msvcrt.get_osfhandle(stdin.fileno())
            startup.stdout = startup.stderr = msvcrt.get_osfhandle(output.fileno())
            os.set_handle_inheritable(startup.stdin, True)
            os.set_handle_inheritable(startup.stdout, True)
            line = ct.create_unicode_buffer(subprocess.list2cmdline(command))
            checked(create_process(None, line, None, None, True, CREATE_SUSPENDED | CREATE_NO_WINDOW,
                                   None, None, ct.byref(startup), ct.byref(process)))
            checked(assign_to_job(job, process.process))
            assigned = True
            if time.monotonic() >= deadline:
                terminate_and_drain(job, EXIT_TIMEOUT)
                return EXIT_TIMEOUT, True
            if resume(process.thread) == 0xFFFFFFFF:
                raise ct.WinError(ct.get_last_error())
            if not wait_until_idle(job, deadline):
                terminate_and_drain(job, EXIT_TIMEOUT)
                return EXIT_TIMEOUT, True
            result = wt.DWORD()
            checked(exit_code(process.process, ct.byref(result)))
            return ct.c_int32(result.value).value, False
    finally:
        try:
            if process.process and not assigned:
                checked(terminate_process(process.process, EXIT_SETUP_FAILURE))
                if wait_process(process.process, CLEANUP_SECONDS * 1000) != 0:
                    raise RuntimeError("Suspended task could not be retired")
            if active_processes(job):
                terminate_and_drain(job, EXIT_SETUP_FAILURE)
        finally:
            if process.thread:
                close(process.thread)
            if process.process:
                close(process.process)
            close(job)


def main():
    try:
        spec = json.loads(sys.stdin.buffer.read().decode("utf-8-sig"))
        code, timed_out = run_owned(spec["command"], spec["log"], spec["timeout"])
        print(json.dumps({"exit": code, "timed_out": timed_out}))
    except (OSError, RuntimeError, ValueError) as error:
        print(json.dumps({"error": str(error)}))
        return EXIT_SETUP_FAILURE
    return 0


if __name__ == "__main__":
    sys.exit(main())
