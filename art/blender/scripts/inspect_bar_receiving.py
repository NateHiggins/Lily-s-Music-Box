"""Native receiver aperture/floor fit and unpowered construction views."""
from pathlib import Path
import bpy,json,math
from mathutils import Matrix,Vector
from mathutils.bvhtree import BVHTree
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/bar_receiving.blend'))
bpy.context.view_layer.update()
plan=json.loads((ROOT/'art/data/bar_receiving/source_plan.json').read_text(encoding='utf-8'))
draws=list(bpy.data.collections['RuntimePartitions'].objects)
apertures=[];crossings=[]
def tree(obj):return BVHTree.FromPolygons([obj.matrix_world@v.co for v in obj.data.vertices],[p.vertices[:] for p in obj.data.polygons])
trees={o:tree(o) for o in draws}
for row in plan['source_records']:
    frame=Matrix.Translation(Vector([*row['at'],row['z0']]))@Matrix.Rotation(math.radians(row['yaw']),4,'Z')
    chosen=[o for o in draws if o.name.startswith(row['id']+'__')]
    radius=[.190,.205][row['variant']];center=[1.29,1.345][row['variant']]
    misses=0
    for r in [0.,radius*.95,radius*.999]:
        for i in range(64):
            a=i*math.tau/64;at=frame@Vector((r*math.cos(a),-.50,center+r*math.sin(a)));direction=frame.to_3x3()@Vector((0,1,0))
            for obj in chosen:
                hit=trees[obj].ray_cast(at,direction,.114)
                assert hit[0] is None,(row['id'],obj.name,i,r,hit)
            misses+=1
    points=[o.matrix_world@v.co for o in chosen for v in o.data.vertices]
    minimum=min(p.z for p in points);assert abs(minimum-(plan['floor']['z0']+plan['floor']['h']))<1e-5,minimum
    apertures.append({'id':row['id'],'unobstructed_rays_to_original_screen_plane':misses,'scope_radius_m':radius,'lowest_stock_z':minimum})
for a in draws:
    if not a.name.startswith('retail_bar_cab01__'):continue
    for b in draws:
        if b.name.startswith('retail_bar_cab02__') and trees[a].overlap(trees[b]):crossings.append([a.name,b.name])
assert not crossings,crossings
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24
scene.render.resolution_x=1300;scene.render.resolution_y=1100;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Neutral chassis review');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.45,.46,.48,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.65;scene.view_settings.view_transform='AgX'
out=ROOT/'tmp/v2-improvement/bar-receiving-native';out.mkdir(parents=True,exist_ok=True);views=[]
for identity,label,offset in [('','pair',(-2.7,1.,.35)),('retail_bar_cab01','front',(-2.3,.2,.15)),('retail_bar_cab02','front',(-2.3,.2,.15)),('retail_bar_cab01','service',(-1.9,-1.9,.45)),('retail_bar_cab02','feet',(-1.1,-.7,.5))]:
    chosen=[o for o in draws if o.name.startswith(identity)]
    for obj in draws:obj.hide_render=obj not in chosen
    points=[o.matrix_world@v.co for o in chosen for v in o.data.vertices]
    lo=Vector([min(p[i] for p in points) for i in range(3)]);hi=Vector([max(p[i] for p in points) for i in range(3)]);center=(lo+hi)*.5;span=max(hi-lo)
    if label=='feet':center=Vector((3.45,-36.3,-2.55));span=.9
    bpy.ops.object.camera_add(location=center+Vector(offset)*span);camera=bpy.context.object;camera.data.lens=52;camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler();scene.camera=camera
    lights=[]
    for delta,energy in [((-1.5,1,2.),180),((1,-1,1),80)]:
        bpy.ops.object.light_add(type='AREA',location=center+Vector(delta)*span);lamp=bpy.context.object;lamp.data.energy=energy*span*span;lamp.data.size=span*2;lamp.rotation_euler=(center-lamp.location).to_track_quat('-Z','Y').to_euler();lights.append(lamp)
    name=(identity+'_' if identity else '')+label+'.png';scene.render.filepath=str(out/name);bpy.ops.render.render(write_still=True);views.append(name)
    for obj in [camera,*lights]:bpy.data.objects.remove(obj,do_unlink=True)
result={'evidence_class':'INERT','apertures':apertures,'cabinet_crossings':crossings,'views':views,'scope':'Native unpowered chassis, feet and original-scope clearances. Actual programme ownership/input are separate runtime checks.'}
(out/'inspection.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8',newline='\n')
print('BAR RECEIVING INSPECTION',result)
