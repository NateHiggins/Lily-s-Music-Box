"""Reopen the fitted alley stock and measure the chimney's actual grade opening."""
import hashlib,json
from pathlib import Path
import bpy,bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'tmp/v2-flue-airway-20261020/grade-native';OUT.mkdir(parents=True,exist_ok=True)
native=ROOT/'art/blender/alley_groundworks.blend'
meta=json.loads((ROOT/'art/blender/alley_groundworks_construction.json').read_text())
bpy.ops.wm.open_mainfile(filepath=str(native))
closed=[]
for row in meta['closed_source_pieces']:
    obj=bpy.data.objects[row['id']];bm=bmesh.new();bm.from_mesh(obj.data)
    volume=bm.calc_volume(signed=True)
    assert all(edge.is_manifold for edge in bm.edges) and volume>0 and abs(volume-row['volume_m3'])<1e-7,obj.name
    closed.append(dict(id=obj.name,volume_m3=volume));bm.free()
trees=[]
for row in meta['parts']:
    obj=bpy.data.objects[row['id']]
    trees.append(BVHTree.FromPolygons([obj.matrix_world@v.co for v in obj.data.vertices],[tuple(p.vertices) for p in obj.data.polygons]))
layout=json.loads((ROOT/'game/data/orison_v2_blockout.json').read_text())
shaft=next(r for r in layout['risers'] if r['id']=='B1_BOILER_FLUE')
x0,z0,x1,z1=shaft['rect'];x=(x0+x1)*.5;z=(z0+z1)*.5
clear=[]
for dx in [-.04,0,.04]:
    for dz in [-.08,0,.08]:
        origin=Vector((x+dx,-z-dz,-.55))
        assert all(tree.ray_cast(origin,Vector((0,0,1)),1.5)[0] is None for tree in trees),(dx,dz)
        clear.append([dx,dz])
control=Vector((x1+.10,-z,-.55))
assert any(tree.ray_cast(control,Vector((0,0,1)),1.5)[0] is not None for tree in trees),'Original paving beside masonry must remain'
report=dict(evidence_class='INERT',scope='Native grade opening and adjacent paving only; no runtime proof or complete drainage/soil qualification.',
    native_sha256=hashlib.sha256(native.read_bytes()).hexdigest(),asset_sha256=meta['asset_sha256'],closed_stocks=closed,clear_rays=clear,positive_adjacent_paving_control=True)
(OUT/'inspection.json').write_text(json.dumps(report,indent=2)+'\n',newline='\n')
print('FLUE GRADE: 9 clear native airway rays; adjacent paving retained;',len(closed),'closed stocks')
