from pathlib import Path
import subprocess,sys,hashlib
root=Path(__file__).resolve().parents[1]
path=root/'game/scripts/props/fire_nozzle_coupling.gd'
backup=root/'tmp/nozzle_source_control_current.gd'
previous=subprocess.check_output(['git','--no-optional-locks','show','8bb0b745:game/scripts/props/fire_nozzle_coupling.gd'],cwd=root)
if sys.argv[1]=='baseline':
    assert not backup.exists()
    backup.write_bytes(path.read_bytes());path.write_bytes(previous)
else:
    assert path.read_bytes()==previous,'Source changed during control; refusing to overwrite it'
    path.write_bytes(backup.read_bytes())
print(sys.argv[1],hashlib.sha256(path.read_bytes()).hexdigest())
