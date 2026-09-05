"""Small offline process-boundary/refusal controls; never launches an engine."""
from pathlib import Path
from unittest import mock
import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest

HERE=Path(__file__).resolve().parent


def module(name):
    spec=importlib.util.spec_from_file_location(name,HERE/(name+".py"))
    value=importlib.util.module_from_spec(spec);spec.loader.exec_module(value);return value


bridge=module("child_capture_bridge");outer=module("outer");verify=module("verify_outputs")


class BridgeControls(unittest.TestCase):
    def exercise(self,mode="normal"):
        with tempfile.TemporaryDirectory() as directory:
            base=Path(directory);root=base/"root";root.mkdir();evidence=base/"evidence";evidence.mkdir()
            relative="tools/m11c1_floor01_owner_first/run_disposable_export.py"
            controller=root/relative;controller.parent.mkdir(parents=True);controller.write_bytes(b"# inert test controller\n")
            blender=base/"fake_blender.exe";blender.write_bytes(b"inert test executable bytes")
            config={"root":str(root),"output":str(base/"output"),"evidence":str(evidence),"blender":str(blender),
                "exact_source_hashes":{relative:bridge.sha(controller)},"blender_sha256":bridge.sha(blender),"blender_timeout_seconds":2}
            config_path=base/"config.json";config_path.write_text(json.dumps(config))
            calls=[]
            class FakeChild:
                pid=987654;returncode=None
                def __init__(self,command,**kwargs):
                    self.command=command;self.waits=0;self.terminated=False;calls.append(self)
                    kwargs["stdout"].write(b"a\r\nb\rc\ninvalid:\xff\n");kwargs["stderr"].write(b"warning\r\n")
                def wait(self,timeout=None):
                    self.waits+=1
                    if mode=="timeout" and self.waits==1:raise subprocess.TimeoutExpired(self.command,timeout)
                    self.returncode=-15 if self.terminated else 0;return self.returncode
                def terminate(self):self.terminated=True
                def kill(self):raise AssertionError("second termination was not required by this fixture")
            def fake_controller(path,run_name):
                command=[str(blender),"--background","--factory-startup","--python",
                    str(root/"tools/m11c1_floor01_owner_first/generate_owner_first_candidate.py"),"--",
                    "--generator",str(root/"art/blender/scripts/build_orison.py"),"--layout",str(root/"art/data/building_layout.json"),
                    "--ownership-sidecar",str(root/"art/data/m11c1/floor01_source_ownership.json"),"--output",str(base/"output")]
                kwargs={"cwd":str(root),"capture_output":True,"text":True,"encoding":"utf-8","errors":"replace","check":False}
                if mode=="wrong_command":command[1]="--different"
                if mode=="wrong_kwargs":kwargs["errors"]="strict"
                result=subprocess.run(command,**kwargs)
                self.assertEqual(result.stdout,"a\nb\nc\ninvalid:\ufffd\n")
                if mode=="duplicate":subprocess.run(command,**kwargs)
                raise SystemExit(result.returncode)
            previous=list(sys.argv)
            try:
                with mock.patch.object(sys,"argv",["bridge","--config",str(config_path)]),\
                     mock.patch.object(bridge.subprocess,"Popen",FakeChild),mock.patch.object(bridge.runpy,"run_path",fake_controller):
                    if mode in {"duplicate","wrong_command","wrong_kwargs"}:
                        with self.assertRaises(AssertionError):bridge.main()
                        result=None
                    else:result=bridge.main()
            finally:sys.argv=previous
            receipt=json.loads((evidence/"controller_bridge.json").read_text())
            if calls:
                self.assertEqual((evidence/"blender.stdout.raw").read_bytes(),b"a\r\nb\rc\ninvalid:\xff\n")
                child=json.loads((evidence/"blender_child.json").read_text())
                self.assertEqual(child["pid"],987654)
            return result,receipt,calls

    def test_raw_bytes_and_text_newlines_remain_distinct(self):
        result,receipt,calls=self.exercise();self.assertEqual(result,0);self.assertEqual(receipt["actual_controller_exit"],0);self.assertEqual(len(calls),1)
    def test_duplicate_blender_call_refused(self):
        _,receipt,calls=self.exercise("duplicate");self.assertEqual(len(calls),1);self.assertEqual(receipt["actual_controller_exit"],1)
    def test_changed_command_refused_before_child(self):self.assertEqual(len(self.exercise("wrong_command")[2]),0)
    def test_changed_decode_contract_refused_before_child(self):self.assertEqual(len(self.exercise("wrong_kwargs")[2]),0)
    def test_timeout_preserves_actual_owned_child_exit(self):
        result,receipt,calls=self.exercise("timeout");self.assertEqual(result,1);self.assertEqual(receipt["actual_controller_exit"],-15);self.assertTrue(calls[0].terminated)


class GuardControls(unittest.TestCase):
    def test_empty_census(self):
        with mock.patch.object(outer.subprocess,"run",return_value=subprocess.CompletedProcess([],0,b"[]\r\n",b"")):
            self.assertTrue(outer.process_census()["empty"])
    def test_live_census_is_not_empty(self):
        data=b'{"ProcessId":42,"Name":"Godot_v4.exe"}'
        with mock.patch.object(outer.subprocess,"run",return_value=subprocess.CompletedProcess([],0,data,b"")):
            self.assertFalse(outer.process_census()["empty"])
    def test_census_failure_refuses(self):
        with mock.patch.object(outer.subprocess,"run",return_value=subprocess.CompletedProcess([],1,b"",b"denied")):
            with self.assertRaises(AssertionError):outer.process_census()
    def test_missing_protected_file_retains_snapshot_failure(self):
        with tempfile.TemporaryDirectory() as directory:
            def git(*args):
                if args[0]=="hash-object":raise subprocess.CalledProcessError(128,["git"],stderr=b"missing file")
                return "f"*40
            with mock.patch.object(outer,"ROOT",Path(directory)),mock.patch.object(outer,"git",git):
                result=outer.snapshot(["protected.bin"],["protected.bin"])
            self.assertFalse(result["files"]["protected.bin"]["exists"])
            self.assertIsNone(result["protected_blobs"]["protected.bin"]["working_clean"])
            self.assertEqual(result["protected_blobs"]["protected.bin"]["working_clean_error"]["exit"],128)
    def test_output_containment_and_missing_paths_refuse(self):
        with tempfile.TemporaryDirectory() as directory:
            base=Path(directory);out=base/"output";out.mkdir();inside=out/"present";inside.write_bytes(b"x");outside=base/"escape";outside.write_bytes(b"x")
            self.assertEqual(verify.inside(out,"present"),inside)
            for relative in ("../escape","missing"):
                with self.assertRaises(AssertionError):verify.inside(out,relative)


if __name__=="__main__":unittest.main(verbosity=2)
