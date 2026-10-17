"""Fixed native timber shim: physical metre charts, no state-specific geometry."""
from pathlib import Path
import json
import sys
import bpy
import bmesh
from mathutils import Matrix

ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'tmp/v2-radiator-polish-20261017'
OUT.mkdir(parents=True,exist_ok=True)
sys.path.insert(0,str(Path(__file__).parent))
from fabrication_native_batch import material,partition,export

source=json.loads((ROOT/'game/data/orison_v2/radiator_sliding_wedge.json').read_text())
assert source['schema_version']==1
width,length,slope,clip=[source[key] for key in ('width_m','length_m','rise_per_m','corner_clip_m')]
assert 0<clip<width/4 and 0<clip<length/4 and 0<slope<.25
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version=0
plan=[(-width/2+clip,0),(width/2-clip,0),(width/2,clip),
      (width/2,length-clip),(width/2-clip,length),(-width/2+clip,length),
      (-width/2,length-clip),(-width/2,clip)]
points=[(x,y,z) for top in [False,True] for x,y in plan for z in [slope*y if top else 0]]
n=len(plan)
faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]
faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
mesh=bpy.data.meshes.new('Fixed sliding wood shim');mesh.from_pydata(points,[],faces);mesh.update()
bm=bmesh.new();bm.from_mesh(mesh)
bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-9)
bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-10)
bmesh.ops.triangulate(bm,faces=list(bm.faces));bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.normal_update()
assert all(e.is_manifold for e in bm.edges) and bm.calc_volume(signed=True)>0
volume=bm.calc_volume(signed=True);bm.to_mesh(mesh);bm.free()
obj=bpy.data.objects.new('Sawn timber wedge',mesh);bpy.context.collection.objects.link(obj)
catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials']
finish=dict(catalog_key='timber',normal=.35,roughness=1.,pigment=1.,tint=[.62,.52,.4])
mat=material(ROOT,'CATALOG_timber',finish,catalog)
collection=bpy.data.collections.new('Runtime sliding wedge');bpy.context.scene.collection.children.link(collection)
partition(collection,'SlidingPitchWedge_timber',[obj],finish,mat,Matrix.Identity(4),catalog)
bpy.data.objects.remove(obj,do_unlink=True)
report=export(ROOT,'radiator_sliding_wedge',collection)
report.update(evidence_class='INERT',scope='Single fixed native wedge; no controls or room qualification.',
              dimensions=source,volume_m3=volume)
(OUT/'pitch_wedge_native.json').write_text(json.dumps(report,indent=2)+'\n')
print('SLIDING WEDGE NATIVE',report,flush=True)
