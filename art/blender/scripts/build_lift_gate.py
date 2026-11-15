"""Re-export the editable sixteen-template V2 lift gate with Blender5.2.

Run Blender -b --python-exit-code1 -P this_file [-- --out PATH].
The saved .blend is the native authoring source (155 editable manufactured
stocks plus16 export templates); this entry point never replaces it with the
retired three-stock primitive generator. Rebuilding from a clean checkout
needs only the source blend, bundled exporter and repository tangent checker.
"""
from pathlib import Path
import argparse,sys,json,hashlib
import bpy
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(Path(__file__).resolve().parent))
from lift_gate_export import export
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--out',type=Path,default=ROOT/'game/assets/props/lift_gate.glb')
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
native=ROOT/'art/blender/lift_gate.blend'
bpy.ops.wm.open_mainfile(filepath=str(native))
assert not bpy.data.libraries, 'Native gate must not depend on linked libraries'
library=bpy.data.collections['20_EXPORT_LIBRARY']
assert len(library.objects)==16
assert all(o.type=='MESH' and o.matrix_world.is_identity for o in library.objects)
assert all(not o.modifiers and o.library is None and o.data.library is None
           and o.animation_data is None and o.data.shape_keys is None
           for o in library.objects), 'Export templates must be local evaluated rigid stocks'
assert all({'_AUTHORED_NORMAL','_EXACT_UV','_tangent_guide','_bitangent_guide','_export_corner'}
           <= set(o.data.attributes.keys()) for o in library.objects)
args.out.parent.mkdir(parents=True,exist_ok=True)
proof=export(args.out)
print(json.dumps(dict(native_sha256=hashlib.sha256(native.read_bytes()).hexdigest(),output_sha256=hashlib.sha256(args.out.read_bytes()).hexdigest(),strict_tangents=proof)))
