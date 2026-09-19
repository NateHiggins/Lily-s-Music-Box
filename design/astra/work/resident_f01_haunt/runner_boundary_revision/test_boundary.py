"""Execute the wrapper's actual generated PowerShell against harmless stubs.

No Godot launch or game filesystem changes. Select an exact frozen source copy
with HAUNT_WRAPPER_SOURCE; the command expression is read from its Python AST.
"""
from __future__ import annotations
import ast
import json
import os
from pathlib import Path
import shutil
import subprocess
import unittest

HERE = Path(__file__).resolve().parent
SOURCE = Path(os.environ.get("HAUNT_WRAPPER_SOURCE", HERE / "proposed/run_haunt.py"))
OUT = Path(os.environ["HAUNT_BOUNDARY_OUTPUT"])
PWSH = shutil.which("pwsh")
PREFIX = """param([string]$ProjectPath, [string]$Scene, [string]$LogPath,
 [ValidateRange(1,180)][int]$TimeoutSeconds, [switch]$Windowed,
 [string]$ShotDir, [string[]]$ExtraArgs)
"""


def actual_command(runner: Path, root: Path) -> str:
    tree = ast.parse(SOURCE.read_text(encoding="utf-8"))
    expressions = [node.args[0] for node in ast.walk(tree)
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute)
        and isinstance(node.func.value, ast.Name) and node.func.value.id == "command_file"
        and node.func.attr == "write_text"]
    if len(expressions) != 1:
        raise ValueError("exactly one actual wrapper command expression required")
    expression = ast.Expression(expressions[0])
    quote = lambda value: "'" + str(value).replace("'", "''") + "'"
    return eval(compile(expression, str(SOURCE), "eval"), {"__builtins__": {}},
        {"q": quote, "RUNNER": runner, "ROOT": root, "scene": "res://never_launch.tscn",
         "log": root / "unused.log", "shots": root / "shots"})


class Boundary(unittest.TestCase):
    def case(self, name: str, body: str, expected: int, *, invalid_timeout=False, stale_exit=False):
        target = OUT / name
        target.mkdir(parents=True, exist_ok=False)
        stub = target / "harmless_stub.ps1"
        stub.write_text(PREFIX + body + "\n", encoding="utf-8")
        command = actual_command(stub, target)
        if stale_exit:
            command = "$global:LASTEXITCODE = 0\n" + command
        if invalid_timeout:
            self.assertIn("-TimeoutSeconds 180", command)
            command = command.replace("-TimeoutSeconds 180", "-TimeoutSeconds 240", 1)
        launcher = target / "actual_command.ps1"
        launcher.write_text(command, encoding="utf-8")
        result = subprocess.run([PWSH, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(launcher)],
            capture_output=True, timeout=15)
        (target / "stdout.log").write_bytes(result.stdout)
        (target / "stderr.log").write_bytes(result.stderr)
        (target / "result.json").write_text(json.dumps({"expected": expected,
            "actual_wrapper_exit": result.returncode, "passed": result.returncode == expected,
            "source": str(SOURCE), "godot_launched": False}, indent=2) + "\n", encoding="utf-8")
        self.assertEqual(result.returncode, expected)
        return result

    def test_timeout_write_error_keeps_124(self):
        result = self.case("timeout_write_error", "Write-Error 'stub timeout sentinel'; exit 124", 124)
        self.assertIn(b"stub timeout sentinel", result.stderr)

    def test_success_keeps_zero(self):
        self.case("success", "Write-Output 'stub success'; exit 0", 0)

    def test_failure_keeps_scene_exit(self):
        self.case("scene_failure", "Write-Output 'stub failure'; exit 6", 6)

    def test_nonterminating_error_keeps_declared_failure(self):
        result = self.case("nonterminating_error", "Write-Error 'stub native failure'; exit 7", 7)
        self.assertIn(b"stub native failure", result.stderr)

    def test_invalid_parameter_refuses_absent_exit(self):
        self.case("invalid_parameter", "exit 0", 125, invalid_timeout=True)

    def test_missing_exit_is_refused(self):
        self.case("missing_exit", "Write-Output 'stub returned without exit'", 125)

    def test_old_last_exit_cannot_supply_false_green(self):
        # The actual command initializes LASTEXITCODE, so its no-exit refusal
        # does not accidentally borrow an earlier native process's zero.
        self.case("stale_exit", "Write-Output 'stub no native exit'", 125, stale_exit=True)


if __name__ == "__main__":
    if not PWSH:
        raise SystemExit("pwsh executable unavailable")
    unittest.main()
