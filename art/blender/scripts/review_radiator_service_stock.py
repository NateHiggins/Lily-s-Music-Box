"""Measure real native blind pockets, head bearings and wall standoffs."""
from pathlib import Path
import json, hashlib
import bpy, bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'tmp/v2-radiator-polish-20261017'
OUT.mkdir(parents=True,exist_ok=True)
native=ROOT/'art/blender/radiator_service_stock.blend'
bpy.ops.wm.open_mainfile(filepath=str(native))
checks=[]

def check(ok,label,**detail):checks.append(dict(passed=bool(ok),label=label,**detail))
def tree(name):
    obj=bpy.data.objects[name];bm=bmesh.new();bm.from_mesh(obj.data);bm.transform(obj.matrix_world);bm.normal_update()
    result=BVHTree.FromBMesh(bm);bm.free();return result
wood,steel=tree('Rack_timber'),tree('Rack_iron_neutral')
for index in range(5):
    x=(index-2)*.06
    hit,n,_,_=wood.ray_cast(Vector((x,0,.02)),Vector((0,0,-1)),.04)
    check(hit is not None and abs(hit.z+.009)<1e-6 and n.z>.99,
          'blind pocket accepts eight millimetre insert stem',pocket=index,hit=list(hit) if hit else None)
    for dx in [-.004,.004]:
        hit,n,_,_=wood.ray_cast(Vector((x+dx,0,.02)),Vector((0,0,-1)),.04)
        check(hit is not None and abs(hit.z)<1e-6 and n.z>.99,
              'native wrench head has timber bearing outside pocket',pocket=index,side=dx,hit=list(hit) if hit else None)
for x in [-.14,.14]:
    # Offset from the screw axis: its shank intentionally enters the wall
    # two millimetres beyond the standoff's bearing face.
    hit,n,_,_=steel.ray_cast(Vector((x+.004,.13,.045)),Vector((0,-1,0)),.06)
    check(hit is not None and abs(hit.y-.1)<1e-6 and n.y>.99,
          'wall standoff terminates on authored mounting plane',side=x,hit=list(hit) if hit else None)
    hit,n,_,_=steel.ray_cast(Vector((x,-.03,-.04)),Vector((0,0,1)),.04)
    check(hit is not None and abs(hit.z+.018)<1e-6 and n.z<-.99,
          'continuous bracket supports tray underside',side=x,hit=list(hit) if hit else None)
report=dict(evidence_class='INERT',scope='Native shelf fitting only; no room, controls, save or human acceptance.',
            native_sha256=hashlib.sha256(native.read_bytes()).hexdigest(),checks=checks,failures=[r for r in checks if not r['passed']])
(OUT/'service_stock_fit.json').write_text(json.dumps(report,indent=2)+'\n')
print('SERVICE STOCK FIT',len(checks),'checks',len(report['failures']),'failures',flush=True)
if report['failures']:raise RuntimeError('Native rack fitting failed')
