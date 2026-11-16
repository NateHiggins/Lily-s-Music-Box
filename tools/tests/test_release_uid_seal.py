"""Release guards seal native-extension UIDs and reject unrecognized source churn.

The fixture lane simulates import output; no engine or GPU process is launched.
"""
from pathlib import Path
import json
import os
import shutil
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[2]


class ReleaseUidSeal(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "tools").mkdir()
        (self.root / "game").mkdir()
        (self.root / ".gitignore").write_text(".godot/\n")
        (self.root / "game/project.godot").write_text("config_version=5\n")
        for name in ("warm_release_checkout.ps1", "export_friends_build.ps1"):
            shutil.copy2(REPO / "tools" / name, self.root / "tools" / name)
        # Explicit fake seams: the UID lifecycle is under test, not compilation.
        (self.root / "tools/build_godot_reflection_fix.py").write_text("print('fixture template check')\n")
        (self.root / "tools/lane.ps1").write_text("""
$fixtureRoot = Split-Path $PSScriptRoot -Parent
$cache = Join-Path $fixtureRoot 'game/.godot'
New-Item -ItemType Directory -Force -Path $cache | Out-Null
Add-Content -LiteralPath (Join-Path $cache 'lane_calls.txt') -Value 'import'
$native = Join-Path $fixtureRoot 'game/native/hose.gdextension.uid'
$script = Join-Path $fixtureRoot 'game/scripts/world.gd.uid'
New-Item -ItemType Directory -Force -Path (Split-Path $native) | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path $script) | Out-Null
Set-Content -LiteralPath $native -Value 'uid://native'
Set-Content -LiteralPath $script -Value 'uid://script'
if ($env:ORISON_FIXTURE_UID_CHURN -eq 'unknown') {
    Set-Content -LiteralPath (Join-Path $fixtureRoot 'game/native/other.unknown.uid') -Value 'uid://other'
}
if ($env:ORISON_FIXTURE_UID_CHURN -eq 'source') {
    Set-Content -LiteralPath (Join-Path $fixtureRoot 'game/new_source.json') -Value '{}'
}
$global:LASTEXITCODE = 0
""", encoding="utf-8")
        for args in (["init", "-q"], ["add", "--", ".gitignore", "game/project.godot", "tools"]):
            self.git(*args)
        self.git("-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
                 "-c", "commit.gpgsign=false", "commit", "-qm", "fixture")

    def git(self, *args):
        return subprocess.check_output(["git", "-C", str(self.root), *args],
                                       text=True, stderr=subprocess.PIPE).strip()

    def run_script(self, name, churn=""):
        env = os.environ.copy()
        env["ORISON_FIXTURE_UID_CHURN"] = churn
        return subprocess.run(["pwsh", "-NoProfile", "-File", str(self.root / "tools" / name)],
                              cwd=self.root, env=env, capture_output=True, text=True, timeout=30)

    def test_import_seals_both_script_and_native_extension_uids(self):
        result = self.run_script("warm_release_checkout.ps1")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        cache = self.root / "game/.godot"
        self.assertEqual((cache / ".orison_import_ready").read_text().strip(), self.git("rev-parse", "HEAD"))
        records = json.loads((cache / ".orison_import_uids.json").read_text(encoding="utf-8-sig"))
        self.assertEqual({r["path"] for r in records},
                         {"game/native/hose.gdextension.uid", "game/scripts/world.gd.uid"})

    def test_unknown_uid_suffix_still_withholds_readiness(self):
        result = self.run_script("warm_release_checkout.ps1", "unknown")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.root / "game/.godot/.orison_import_ready").exists())

    def test_real_source_churn_still_withholds_readiness(self):
        result = self.run_script("warm_release_checkout.ps1", "source")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.root / "game/.godot/.orison_import_ready").exists())

    def test_native_uid_change_after_import_refuses_export_before_engine(self):
        warmed = self.run_script("warm_release_checkout.ps1")
        self.assertEqual(warmed.returncode, 0, warmed.stdout + warmed.stderr)
        cache = self.root / "game/.godot"
        calls = (cache / "lane_calls.txt").read_bytes()
        template = cache / "orison_templates"
        template.mkdir()
        (template / "manifest.json").write_text("{}")
        (self.root / "game/native/hose.gdextension.uid").write_text("uid://changed\n")
        result = self.run_script("export_friends_build.ps1")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Generated UID changed", result.stdout + result.stderr)
        self.assertEqual((cache / "lane_calls.txt").read_bytes(), calls)


if __name__ == "__main__":
    unittest.main()
