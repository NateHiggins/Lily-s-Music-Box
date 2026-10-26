"""The lane never silently accepts changed backport binaries."""
import hashlib,json,os,shutil,subprocess,tempfile,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
class EngineSelection(unittest.TestCase):
 def test_both_engine_and_console_are_hash_bound(self):
  with tempfile.TemporaryDirectory() as d:
   root=Path(d);tools=root/'tools';tools.mkdir()
   shutil.copy2(ROOT/'tools/lane_common.ps1',tools/'lane_common.ps1')
   main=root/'engine.exe';console=root/'engine.console.exe'
   main.write_bytes(b'engine');console.write_bytes(b'wrapper')
   hashes={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in (main,console)}
   (root/'.godot-engine.json').write_text(json.dumps(dict(path=str(console),sha256=hashes[str(console)],binaries=hashes)))
   script=root/'check.ps1';script.write_text("$ErrorActionPreference='Stop'\nRemove-Item Env:ORISON_GODOT_EXE -ErrorAction SilentlyContinue\n. '"+str(tools/'lane_common.ps1').replace("'","''")+"'\nResolve-OrisonGodot\n")
   good=subprocess.run(['pwsh','-NoProfile','-File',str(script)],capture_output=True,text=True)
   self.assertEqual(good.returncode,0,good.stderr);self.assertIn(str(console),good.stdout)
   main.write_bytes(b'tampered engine')
   bad=subprocess.run(['pwsh','-NoProfile','-File',str(script)],capture_output=True,text=True)
   self.assertNotEqual(bad.returncode,0);self.assertIn('hash mismatch',bad.stderr)
if __name__=='__main__':unittest.main()
