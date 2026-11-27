"""Capture process receipts, with a local stand-in for the serial runner."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


TOOLS = Path(__file__).resolve().parents[1]
SERIAL_STUB = """
param($Scene, $ProjectPath, $ShotDir, $LogPath, [switch]$Windowed, $TimeoutSeconds, $ExtraArgs)
$index = 0
foreach ($size in ($env:ORISON_CAPTURE_TEST_FRAMES -split ',')) {
    if ($size -ne '') {
        $index++
        [IO.File]::WriteAllBytes((Join-Path $ShotDir "frame_$index.png"), [byte[]]::new([int]$size))
    }
}
exit ([int]$env:ORISON_CAPTURE_TEST_EXIT)
"""


class CaptureReceipt(unittest.TestCase):
    def test_runner_outcomes_and_frame_validation(self):
        # Frame sizes exercise the wrapper's existing count/nonempty checks.
        cases = [
            ("busy", 73, [], "BUSY", 73),
            ("partial_timeout", 124, [3], "TIMEOUT", 124),
            ("complete_frames_timeout", 124, [3, 4], "TIMEOUT", 124),
            ("could_not_run", 78, [], "FAIL", 78),
            ("suite_failed", 7, [3, 4], "FAIL", 7),
            ("complete", 0, [3, 4], "PASS", 0),
            ("missing_frame", 0, [3], "FAIL", 2),
            ("empty_frame", 0, [0, 4], "FAIL", 2),
        ]
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            wrapper = root / "run_godot_capture.ps1"
            shutil.copyfile(TOOLS / wrapper.name, wrapper)
            (root / "run_godot_serial.ps1").write_text(SERIAL_STUB, encoding="utf-8")
            project = root / "project"
            project.mkdir()
            (project / "Fake.tscn").touch()

            for name, code, sizes, status, expected_exit in cases:
                with self.subTest(name=name):
                    result = subprocess.run(
                        ["pwsh", "-NoProfile", "-NonInteractive", "-File", str(wrapper),
                         "-Scene", "res://Fake.tscn", "-ProjectPath", str(project),
                         "-ShotRoot", str(root / "shots"), "-RunName", name, "-ExpectedFrames", "2"],
                        env={**os.environ, "ORISON_CAPTURE_TEST_EXIT": str(code),
                             "ORISON_CAPTURE_TEST_FRAMES": ",".join(map(str, sizes))},
                        capture_output=True, text=True, timeout=30,
                    )
                    self.assertEqual(result.returncode, expected_exit, result.stderr)
                    receipt_path = root / "shots" / name / "capture_receipt.json"
                    receipt = json.loads(receipt_path.read_text(encoding="utf-8-sig"))
                    self.assertEqual(receipt["status"], status)
                    self.assertIn(f"[CAPTURE PROCESS] status={status} exit={code} ", result.stdout)
                    self.assertEqual(receipt["engine_exit"], code)
                    self.assertEqual(receipt["actual_frames"], len(sizes))
                    self.assertEqual(receipt["zero_byte_frames"], sizes.count(0))
                    self.assertEqual([f["sha256"] for f in receipt["files"]],
                                     [hashlib.sha256(bytes(n)).hexdigest() for n in sizes])


if __name__ == "__main__":
    unittest.main()
