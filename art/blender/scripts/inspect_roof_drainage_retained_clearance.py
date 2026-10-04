"""Actual saved native surfaces of the retained foundations and alley plant."""
from pathlib import Path
import json,hashlib
import bpy
from mathutils.bvhtree import BVHTree
R=next(path for path in Path(__file__).resolve().parents if (path/'game/project.godot').is_file());D=R/'tmp/roof-drainage-review';D.mkdir(parents=True,exist_ok=True);F=json.loads((R/'art/blender/roof_drainage_receivers_construction.json').read_bytes())
bpy.ops.wm.read_factory_settings(use_empty=True)
def load(native,names,owner):
 with bpy.data.libraries.load(str(native),link=False) as (available,target):target.objects=[n for n in names if n in available.objects]
 for obj in target.objects:bpy.context.scene.collection.objects.link(obj)
 bpy.context.view_layer.update();result=[]
 for obj in target.objects:
  if obj.type!='MESH':continue
  p=[obj.matrix_world@v.co for v in obj.data.vertices];obj.data.calc_loop_triangles();tree=BVHTree.FromPolygons(p,[tuple(t.vertices) for t in obj.data.loop_triangles],all_triangles=True)
  lo=[min(v[i] for v in p) for i in range(3)];hi=[max(v[i] for v in p) for i in range(3)];result.append({'name':owner+'/'+obj.name,'tree':tree,'lo':lo,'hi':hi})
 return result
new=load(R/'art/blender/roof_drainage_receivers.blend',[q['name'] for q in F['closed_stocks']],'RoofReceivers');retained=[];bindings={}
for kind in ['orison_foundations','city_foundations','alley_groundworks']:
 native=R/'art/blender'/(kind+'.blend');meta=R/'art/blender'/(kind+'_construction.json');report=json.loads(meta.read_bytes())
 if kind=='alley_groundworks':names=[q['id'] for q in report['closed_source_pieces'] if q['id'].startswith(('LocalCollector','Collector','Well','Catch'))]
 else:names=[q['id'] for q in report['parts']]
 retained+=load(native,names,kind);bindings[native.relative_to(R).as_posix()]=hashlib.sha256(native.read_bytes()).hexdigest()
tested=[];candidates=[]
for a in new:
 for b in retained:
  if not all(a['hi'][i]>=b['lo'][i] and a['lo'][i]<=b['hi'][i] for i in range(3)):continue
  overlaps=a['tree'].overlap(b['tree']);assert not overlaps,(a['name'],b['name'],'actual native surface intersections',overlaps[:5])
  tested.append({'receiver':a['name'],'retained':b['name'],'actual_surface_intersections':0})
out=D/'receiver-retained-native-clearance.json';out.write_text(json.dumps({'evidence_class':'INERT','receiver_native_sha256':F['native_sha256'],'bindings':bindings,'actual_receiver_stocks':len(new),'retained_native_meshes':len(retained),'spatially_near_native_pairs':tested,'scope':'Saved existing foundations, existing independent 152.4 mm alley collector, its saddles/catches and the boiler well. Full retained physics separately checked; no load-bearing or downstream capacity verdict.'},indent=2)+'\n',newline='\n')
print('ACTUAL NATIVE RECEIVER CLEARANCE',len(new),'new stocks;',len(retained),'retained meshes;',len(tested),'spatially near actual native pairs; no surface intersections')
