"""Inspect saved curtain solids and actual bearings; render retained/delivery pairs."""
from pathlib import Path
import hashlib, json, os
import bpy,bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
OUT=Path(os.environ.get('BAR_STAGE_INSPECT_OUT',str(ROOT/'tmp/bar-stage/native')));OUT.mkdir(parents=True,exist_ok=True)
report=json.loads((ROOT/'art/blender/bar_stage_inventory.json').read_bytes())
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/bar_stage.blend'))
for stock in report['stocks']:
    bm=bmesh.new();bm.from_mesh(bpy.data.objects[stock['name']].data)
    assert all(e.is_manifold for e in bm.edges) and bm.calc_volume(signed=True)>0,stock['name']
    assert abs(bm.calc_volume(signed=True)-stock['volume_m3'])<1e-8,stock['name'];bm.free()
new=[bpy.data.objects['Stage__'+k] for k in ['fabric_warm','iron_blackened','wood_dark']]
before=set(bpy.context.scene.objects);bpy.ops.import_scene.gltf(filepath=str(ROOT/'game/assets/building/floor_01_cells/shop_bar.gltf'))
context=[o for o in bpy.context.scene.objects if o not in before]
wall=next(o for o in context if o.type=='MESH' and o.name.removesuffix('-col')=='F01_OWN_SHOP_BAR_retail_bar_bar_wall')
old=next(o for o in context if o.type=='MESH' and o.name.removesuffix('-col')=='F01_OWN_SHOP_BAR_retail_bar_bar_wall_red')
def actual_tree(obj):
    return BVHTree.FromPolygons([obj.matrix_world@v.co for v in obj.data.vertices],[tuple(p.vertices) for p in obj.data.polygons],all_triangles=False)
tree=actual_tree(wall);samples=0
for contact in report['contacts']:
    at=Vector(contact['point']);n=Vector(contact['normal'])
    plate=bpy.data.objects[contact['id']+'_WallPlate'];plate_tree=actual_tree(plate)
    for dx in [-contact['half_width'],0.,contact['half_width']]:
        for dz in [-contact['half_height'],0.,contact['half_height']]:
            offset=Vector((dx,0,dz))
            for bvh,point,direction in [(tree,at+n*.004+offset,-n),(plate_tree,at-n*.004+offset,n)]:
                hit,normal,index,d=bvh.ray_cast(point,direction,.008);assert hit is not None and abs(d-.004)<.00003,(contact['id'],point,hit,d);samples+=1
rail=bpy.data.objects['CurtainRail'];rail_tree=actual_tree(rail)
for i,contact in enumerate(report['contacts']):
    collar=bpy.data.objects[contact['id']+'_SplitCollar'];c_tree=actual_tree(collar)
    x=contact['point'][0];y=report['fit']['rail_y'];z=report['fit']['rail_z']
    for n in [Vector((0,1,0)),Vector((0,0,1)),Vector((0,-1,0)),Vector((0,0,-1))]:
        point=Vector((x,y,z))+n*.008
        for bvh,start,direction in [(rail_tree,point+n*.002,-n),(c_tree,point-n*.002,n)]:
            hit,normal,index,d=bvh.ray_cast(start,direction,.004);assert hit is not None and abs(d-.002)<.00003,(contact['id'],'rail/collar',hit,d);samples+=1
# Remove only the independently source-owned 204 triangles for the delivery view.
old_mesh=old.data.copy();bm=bmesh.new();bm.from_mesh(old.data);remove=[];counts={r['id']:0 for r in report['original_sources']}
for face in bm.faces:
    points=[old.matrix_world@v.co for v in face.verts];matches=[]
    normal=(points[1]-points[0]).cross(points[2]-points[0]).normalized();axis=max(range(3),key=lambda i:abs(normal[i]))
    for row in report['original_sources']:
        r=row['rect'];low=Vector((r[0],r[1],row['z0']));high=Vector((r[2],r[3],row['z0']+row['h']))
        plane=high[axis] if normal[axis]>0 else low[axis]
        if abs(normal[axis])>.999 and all(abs(p[axis]-plane)<.00003 and all(low[i]-.00003<=p[i]<=high[i]+.00003 for i in range(3)) for p in points):matches.append(row['id'])
    if matches:
        assert len(matches)==1,matches;remove.append(face);counts[matches[0]]+=1
assert all(c==12 for c in counts.values()),counts
bmesh.ops.delete(bm,geom=remove,context='FACES');after_mesh=old.data.copy();bm.to_mesh(after_mesh);bm.free()
old.data=after_mesh
cloth_tree=actual_tree(new[0]);context_intersections=[]
for obj in context:
    if obj.type!='MESH':continue
    pairs=cloth_tree.overlap(actual_tree(obj))
    if pairs:context_intersections.append({'object':obj.name,'triangle_pairs':len(pairs)})
assert not context_intersections,context_intersections
scene=bpy.context.scene;scene.render.engine='BLENDER_EEVEE';scene.render.resolution_x=1280;scene.render.resolution_y=900;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('StageReviewOnly');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.7
light=bpy.data.lights.new('ReviewOnlySun','SUN');light.energy=2.;lamp=bpy.data.objects.new('ReviewOnlySun',light);scene.collection.objects.link(lamp);lamp.rotation_euler=(.4,-.3,.15)
light=bpy.data.lights.new('ReviewOnlyRoomArea','AREA');light.energy=150.;light.shape='DISK';light.size=2.
lamp=bpy.data.objects.new('ReviewOnlyRoomArea',light);scene.collection.objects.link(lamp);lamp.location=(.1,-35.5,-.6);lamp.rotation_euler=(Vector((-.7,-37.85,-1.4))-lamp.location).to_track_quat('-Z','Y').to_euler()
data=bpy.data.cameras.new('ReviewCamera');camera=bpy.data.objects.new('ReviewCamera',data);scene.collection.objects.link(camera);scene.camera=camera;data.lens=28;data.clip_start=.002
x=report['contacts'][1]['point'][0];ry=report['fit']['rail_y'];rz=report['fit']['rail_z']
views=[('front',(-.7,-35.75,-1.15),(-.7,-37.86,-1.2)),('left',(-3.5,-35.5,-1.15),(-1.8,-37.86,-1.2)),('hem',(.6,-37.7,-2.55),(.6,-37.86,-2.78)),('rear_bearing',(x+.16,ry+.055,rz+.15),(x,ry,rz))]
renders=[]
for name,at,target in views:
    camera.location=at;camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler()
    data.lens=35 if name=='rear_bearing' else 28
    for mode in ['original','installed']:
        old.data=old_mesh if mode=='original' else after_mesh
        for obj in new:obj.hide_render=mode=='original' or (name=='rear_bearing' and obj!=new[1])
        scene.render.filepath=str(OUT/(name+'_'+mode+'.png'));bpy.ops.render.render(write_still=True);renders.append(name+'_'+mode+'.png')
(OUT/'inspection.json').write_text(json.dumps({'evidence_class':'INERT','closed_stocks':len(report['stocks']),'contact_samples':samples,'removed_triangles':sum(counts.values()),'cloth_context_triangle_intersections':context_intersections,'native_sha256':hashlib.sha256((ROOT/'art/blender/bar_stage.blend').read_bytes()).hexdigest(),'renders':renders,'note':'Unchanged retained context; Blender-only review illumination; rear_bearing is a metal-only cutaway with cloth and wood hidden; signal actors are verified separately in production.'},indent=2)+'\n')
print('NATIVE BAR STAGE:',len(report['stocks']),'closed stocks;',samples,'wall/plate/rail/collar samples;',len(renders),'matched renders')
