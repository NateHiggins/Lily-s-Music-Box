"""Release-template staging refuses drift and leaves the editor selection alone."""
from pathlib import Path
from contextlib import redirect_stdout
import io
import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "tools"))
import build_godot_reflection_fix as build


class ReleaseTemplate(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root / "native" / "godot-4.7.1-stable"
        (self.source / "bin").mkdir(parents=True)
        patches = self.root / "tools" / "engine_patches"
        patches.mkdir(parents=True)
        for name, _ in build.PATCHES:
            shutil.copy2(REPO / "tools" / "engine_patches" / name, patches / name)
        self.binaries = [self.source / "bin" / ("godot.windows.template_release.x86_64.llvm" + suffix)
                         for suffix in (".exe", ".console.exe")]
        for path in self.binaries:
            path.write_bytes(path.name.encode())
        self.editor_pin = self.root / ".godot-engine.json"
        self.editor_pin.write_bytes(b"original editor selection")
        (self.root / "game").mkdir()
        shutil.copy2(REPO / "game/export_presets.cfg", self.root / "game/export_presets.cfg")
        self.addCleanup(patch.stopall)
        patch.object(build, "ROOT", self.root).start()
        self.provenance = dict(base="4.7.1-stable",
                               source_archives={n: h for n, _, h in build.SOURCES},
                               local_patches=dict(build.PATCHES))

    def stage(self):
        return build.publish_template(self.binaries, self.provenance)

    def test_release_staging_does_not_replace_editor_or_source_binaries(self):
        original = {p: p.read_bytes() for p in self.binaries}
        manifest = self.stage()
        self.assertEqual(build.check_template(), manifest)
        self.assertEqual(self.editor_pin.read_bytes(), b"original editor selection")
        self.assertEqual({p: p.read_bytes() for p in self.binaries}, original)

    def test_both_runtime_and_console_changes_refuse_export(self):
        for role, filename in build.TEMPLATE_FILES.items():
            with self.subTest(role=role):
                self.stage()
                (self.root / build.TEMPLATE_CACHE / filename).write_bytes(b"changed")
                with self.assertRaisesRegex(RuntimeError, "hash mismatch: " + role):
                    build.check_template()

    def test_source_patch_provenance_cannot_be_replaced_by_a_matching_binary_hash(self):
        self.stage()
        path = self.root / build.TEMPLATE_CACHE / "manifest.json"
        manifest = json.loads(path.read_text())
        manifest["local_patches"] = {}
        path.write_text(json.dumps(manifest))
        with self.assertRaisesRegex(RuntimeError, "provenance mismatch: local_patches"):
            build.check_template()

    def test_valid_cache_cannot_hide_a_preset_fallback_to_the_stock_template(self):
        self.stage()
        preset = self.root / "game/export_presets.cfg"
        preset.write_text(preset.read_text().replace(build.TEMPLATE_RESOURCE, ""))
        with self.assertRaisesRegex(RuntimeError, "does not select the pinned local template"):
            build.check_template()

    def test_runtime_without_required_packaged_qualification_options_is_rejected(self):
        self.stage()
        path = self.root / build.TEMPLATE_CACHE / "manifest.json"
        manifest = json.loads(path.read_text())
        manifest["release_options"] = {}
        path.write_text(json.dumps(manifest))
        with self.assertRaisesRegex(RuntimeError, "provenance mismatch: release_options"):
            build.check_template()

    def test_missing_template_refuses_without_starting_a_build_or_engine(self):
        with patch.object(sys, "argv", ["builder", "--check-template"]), \
                patch.object(build.subprocess, "run", side_effect=AssertionError("must not launch")), \
                patch.object(build.urllib.request, "urlretrieve", side_effect=AssertionError("must not download")):
            with self.assertRaisesRegex(RuntimeError, "build --target template_release"):
                build.main()

    def test_read_only_check_does_not_build_or_repin(self):
        self.stage()
        with patch.object(sys, "argv", ["builder", "--check-template"]), \
                patch.object(build.subprocess, "run", side_effect=AssertionError("must not launch")), \
                redirect_stdout(io.StringIO()) as output:
            build.main()
        self.assertIn("CHECK PASS", output.getvalue())
        self.assertEqual(self.editor_pin.read_bytes(), b"original editor selection")

    def release_args(self):
        archive_dir = self.root / "archives"
        archive_dir.mkdir()
        compiler = self.root / "compiler"
        compiler.mkdir()
        sources = []
        for name, url, _ in build.SOURCES:
            path = archive_dir / name
            path.write_bytes(name.encode())
            sources.append((name, url, build.sha(path)))
        return (["builder", "--target", "template_release",
                 "--directory", str(self.source.parent), "--archive-directory", str(archive_dir),
                 "--compiler-directory", str(compiler)], sources)

    def test_release_cli_stages_release_without_repinning_editor(self):
        args, sources = self.release_args()
        with patch.object(sys, "argv", args), patch.object(build, "SOURCES", sources), \
                patch.object(build.subprocess, "run", return_value=subprocess.CompletedProcess([], 0)) as launched, \
                patch.object(build.urllib.request, "urlretrieve", side_effect=AssertionError("must reuse cache")), \
                redirect_stdout(io.StringIO()):
            build.main()
            self.assertEqual(build.check_template()["target"], "template_release")
            self.assertTrue(any("SCons" in call.args[0] and "target=template_release" in call.args[0]
                                for call in launched.call_args_list))
            self.assertTrue(any("SCons" in call.args[0] and "disable_path_overrides=no" in call.args[0]
                                for call in launched.call_args_list))
        self.assertEqual(self.editor_pin.read_bytes(), b"original editor selection")

    def test_configure_only_cannot_certify_preexisting_release_outputs(self):
        args, _ = self.release_args()
        with patch.object(sys, "argv", args + ["--configure-only"]), \
                patch.object(build.subprocess, "run", side_effect=AssertionError("must not launch")), \
                redirect_stdout(io.StringIO()), patch.object(sys, "stderr", io.StringIO()):
            with self.assertRaises(SystemExit) as caught:
                build.main()
        self.assertEqual(caught.exception.code, 2)
        self.assertFalse((self.root / build.TEMPLATE_CACHE / "manifest.json").exists())

    def test_stale_non_llvm_binaries_cannot_stand_in_for_the_requested_build(self):
        args, sources = self.release_args()
        for path in self.binaries:
            path.unlink()
            Path(str(path).replace(".llvm", "")).write_bytes(b"old non-LLVM runtime")
        with patch.object(sys, "argv", args), patch.object(build, "SOURCES", sources), \
                patch.object(build.subprocess, "run", return_value=subprocess.CompletedProcess([], 0)):
            with self.assertRaisesRegex(RuntimeError, "exact LLVM release"):
                build.main()
        self.assertEqual(self.editor_pin.read_bytes(), b"original editor selection")

    def test_default_editor_configure_path_still_pins_editor_not_release(self):
        for suffix in (".exe", ".console.exe"):
            (self.source / "bin" / ("godot.windows.editor.x86_64.llvm" + suffix)).write_bytes(b"editor" + suffix.encode())
        with patch.object(sys, "argv", ["builder", "--directory", str(self.source.parent), "--configure-only"]), \
                patch.object(build.subprocess, "run", return_value=subprocess.CompletedProcess([], 0)), \
                patch.object(build.urllib.request, "urlretrieve", side_effect=AssertionError("must not download")), \
                redirect_stdout(io.StringIO()):
            build.main()
        manifest = json.loads(self.editor_pin.read_text())
        self.assertIn("editor.x86_64", manifest["path"])
        self.assertFalse((self.root / build.TEMPLATE_CACHE / "manifest.json").exists())


if __name__ == "__main__":
    unittest.main()
