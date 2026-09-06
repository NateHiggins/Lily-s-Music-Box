"""Sampled process ancestry keyed by Windows process lifetime, not reusable PID."""
import json
import subprocess
import core

def census():
    command = "ConvertTo-Json -Compress -InputObject @(Get-CimInstance Win32_Process | Where-Object Name -Match 'Godot|Blender|^python|^pwsh|^powershell' | Select-Object ProcessId,ParentProcessId,Name,CommandLine,@{Name='CreatedUtc';Expression={$_.CreationDate.ToUniversalTime().ToString('o')}})"
    output = subprocess.check_output([str(core.PWSH), "-NoProfile", "-Command", command], text=True)
    return json.loads(output) or []

def classify_observations(samples, wrapper_pid):
    rows = {}
    conflicts = []
    missing = []
    for sample in samples:
        for row in sample["processes"]:
            if not row.get("CreatedUtc"):
                missing.append(row)
                continue
            identity = (row["ProcessId"], row["CreatedUtc"])
            if identity in rows and any(rows[identity].get(k) != row.get(k)
                    for k in ("ParentProcessId", "Name", "CommandLine")):
                conflicts.append(row)
            rows[identity] = row
    wrappers = [key for key in rows if key[0] == wrapper_pid]
    def owned(identity):
        seen = set()
        while identity in rows and identity not in seen:
            if len(wrappers) == 1 and identity == wrappers[0]:
                return True
            seen.add(identity)
            row = rows[identity]
            parents = [key for key in rows if key[0] == row["ParentProcessId"]
                       and key[1] <= identity[1]]
            if not parents:
                return False
            # A reused parent's later lifetime cannot parent an older child.
            identity = max(parents, key=lambda key: key[1])
        return False
    engines = [(key, row) for key, row in rows.items() if "godot" in row["Name"].lower()]
    foreign = [row for key, row in engines if not owned(key)]
    actual = [row for key, row in engines if row["Name"].lower() == "godot_v4.7.1-stable_win64.exe" and owned(key)]
    return {"foreign_engines": foreign, "conflicting_pid_observations": conflicts,
            "missing_creation_times": missing, "wrapper_lifetimes": len(wrappers),
            "actual_owned_engines": actual,
            "contract_exit": int(bool(foreign or conflicts or missing or len(wrappers) != 1 or len(actual) != 1)),
            "scope": "Sampled process-lifetime ancestry; no absolute exclusivity or performance acceptance."}
