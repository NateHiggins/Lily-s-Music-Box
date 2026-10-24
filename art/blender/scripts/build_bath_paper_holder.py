"""Wall-mounted lavatory roller: removable spindle and continuous outer sheet.

Local Godot frame: wall contact Z=0, room is -Z, spindle X. No simulation.
ORISON_OUTPUT_ROOT permits review before publishing the shared native stock.
"""
import bpy, bmesh, json, math, os, sys, hashlib
from pathlib import Path
from mathutils import Vector
import numpy as np

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(os.environ.get('ORISON_OUTPUT_ROOT', str(ROOT)))
REVIEW = OUT/'art/reviews/v2_paper_holder_20261024'
sys.path.insert(0, str(ROOT/'art/blender/scripts'))
from fabrication_chart_batch import triangle_charts
from repair_surface_uvs import repair_scene
from check_exported_tangents import validate

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version = 0
catalog = json.loads((ROOT/'art/data/runtime_material_sets.json').read_text())['materials']

def p(v): return Vector((v[0], -v[2], v[1]))

def material(key):
    spec = catalog[key]
    m = bpy.data.materials.new(key); m.use_nodes = True
    nodes = m.node_tree.nodes; bsdf = nodes.get('Principled BSDF')
    bsdf.inputs['Metallic'].default_value = spec['metallic']
    for number, socket in [(0, 'Base Color'), (1, 'Roughness'), (2, 'Normal')]:
        tex = nodes.new('ShaderNodeTexImage')
        path = next((ROOT/'game/assets').rglob(spec['files'][number]))
        tex.image = bpy.data.images.load(str(path), check_existing=True)
        if number: tex.image.colorspace_settings.name = 'Non-Color'
        if number == 2:
            normal = nodes.new('ShaderNodeNormalMap')
            normal.inputs['Strength'].default_value = .2
            m.node_tree.links.new(tex.outputs['Color'], normal.inputs['Color'])
            m.node_tree.links.new(normal.outputs['Normal'], bsdf.inputs['Normal'])
        else: m.node_tree.links.new(tex.outputs['Color'], bsdf.inputs[socket])
    return m

mats = {k: material(k) for k in ['nickel_plated', 'wood_dark', 'paper']}

def finish(obj, name, key):
    obj.name = name; obj.data.materials.append(mats[key])
    return obj

def cylinder(name, at, radius, length, key, axis=(1,0,0)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=radius, depth=length, location=p(at))
    obj = bpy.context.object
    obj.rotation_mode='QUATERNION'; obj.rotation_quaternion=Vector((0,0,1)).rotation_difference(p(axis))
    bevel=obj.modifiers.new('Eased turned edges','BEVEL'); bevel.width=min(.0008,length*.15); bevel.segments=1
    return finish(obj,name,key)

def sheet(name, points, faces, key):
    data=bpy.data.meshes.new(name); data.from_pydata([p(v) for v in points],[],faces); data.update()
    obj=bpy.data.objects.new(name,data); bpy.context.collection.objects.link(obj)
    return finish(obj,name,key)

# Two stepped escutcheons have flat wall backs and separate slotted screws.
# The projecting arms meet socket collars around a removable wooden roller.
for x in [-.073,.073]:
    cylinder('WallEscutcheon',(x,0,-.003),.025,.006,'nickel_plated',(0,0,1))
    cylinder('RaisedBoss',(x,0,-.009),.016,.007,'nickel_plated',(0,0,1))
    cylinder('BracketArm',(x,0,-.041),.0055,.062,'nickel_plated',(0,0,1))
    cylinder('SpindleSocket',(x,0,-.075),.011,.016,'nickel_plated')
    cylinder('TurnedFinial',(x+math.copysign(.012,x),0,-.075),.008,.010,'nickel_plated')
    for y in [-.016,.016]:
        screw=cylinder('SlottedWallScrew',(x,y,-.007),.0032,.0025,'nickel_plated',(0,0,1))
        # Boolean slot is actual relieved metal, rather than a painted mark.
        bpy.ops.mesh.primitive_cube_add(size=1,location=p((x,y,-.0084)))
        tool=bpy.context.object;tool.dimensions=(.005,.002,.0008)
        bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
        mod=screw.modifiers.new('DriverSlot','BOOLEAN');mod.object=tool
        bpy.context.view_layer.objects.active=screw;bpy.ops.object.modifier_apply(modifier=mod.name)
        bpy.data.objects.remove(tool,do_unlink=True)
cylinder('RemovableWoodSpindle',(0,0,-.075),.009,.148,'wood_dark')

# Hollow wound roll: an open central bore, round eased outer edges and layered
# end rings. Outer body stays just below the attached paper's continuous skin.
profile=[(-.056,.013),(-.056,.0425),(-.055,.0437),(.055,.0437),(.056,.0425),(.056,.013)]
vertices=[];faces=[];n=48
for x,r in profile:
    for i in range(n):
        a=math.tau*i/n;vertices.append((x,r*math.sin(a),-.075-r*math.cos(a)))
for j in range(len(profile)):
    for i in range(n):
        a=j*n+i;b=j*n+(i+1)%n;c=((j+1)%len(profile))*n+(i+1)%n;d=((j+1)%len(profile))*n+i
        faces.append((a,b,c,d))
sheet('HollowWoundPaper',vertices,faces,'paper')

# A single welded quad strip wraps almost a complete turn before leaving at
# the forward tangent. The hanging part shares that exact tangent row.
path=[]
for i in range(49):
    angle=(math.tau-.025)*(1-i/48)
    path.append((.044*math.sin(angle),-.075-.044*math.cos(angle)))
for i in range(1,17):
    t=i/16;path.append((-.155*t,-.119-.009*t*t+.003*math.sin(math.pi*t)**2))
vertices=[];faces=[];cols=4
for j,(y,z) in enumerate(path):
    t=max(0,(j-48)/16)
    for i in range(cols+1):
        u=i/cols;vertices.append(((u-.5)*.112,y+.001*math.sin(u*11)*t*t,z+.0006*math.sin(u*9)*t))
for j in range(len(path)-1):
    for i in range(cols):
        a=j*(cols+1)+i;faces.append((a,a+1,a+cols+2,a+cols+1))
outer=sheet('ContinuousUnwrappedSheet',vertices,faces,'paper')
solid=outer.modifiers.new('PaperThickness','SOLIDIFY');solid.thickness=.00015
assert max((Vector(vertices[48*(cols+1)+i])-Vector(vertices[49*(cols+1)+i])).length for i in range(cols+1))<.010

for obj in list(bpy.context.scene.objects):
    bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
    bpy.ops.object.convert(target='MESH');bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    bm=bmesh.new();bm.from_mesh(obj.data);bmesh.ops.triangulate(bm,faces=list(bm.faces))
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(obj.data);bm.free()
    obj.data.calc_loop_triangles()
    points=np.asarray([[obj.data.vertices[i].co[:] for i in t.vertices] for t in obj.data.loop_triangles])
    _,_,uvs,_=triangle_charts(points,np.zeros(3),catalog[obj.data.materials[0].name]['meters_per_tile'])
    # Primitive cylinders arrive with a unit-square UV channel. Export only
    # the authored metre channel, rather than leaving that default as UV0.
    while obj.data.uv_layers:obj.data.uv_layers.remove(obj.data.uv_layers[0])
    layer=obj.data.uv_layers.new(name='MetricSurface')
    for tri,values in zip(obj.data.loop_triangles,uvs):
        for loop,uv in zip(tri.loops,values):layer.data[loop].uv=uv
    # Wound skins shade smoothly; screws and mounting plates retain their flats.
    for polygon in obj.data.polygons: polygon.use_smooth=obj.name in ['HollowWoundPaper','ContinuousUnwrappedSheet']
repair_scene()
REVIEW.mkdir(parents=True,exist_ok=True)
(OUT/'art/blender').mkdir(parents=True,exist_ok=True)
(OUT/'game/assets/props').mkdir(parents=True,exist_ok=True)
parts=[{'name':o.name,'triangles':len(o.data.polygons)} for o in bpy.context.scene.objects]
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'art/blender/bath_paper_holder.blend'))

# Three immutable material batches; retain editable components in the .blend.
for key in mats:
    objects=[o for o in bpy.context.scene.objects if o.data.materials[0].name==key]
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:obj.select_set(True)
    bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();bpy.context.object.name='PaperHolder_'+key
class ExportUVHandedness:
    def gather_attribute_change(self,attribute,data,normalized,export_settings):
        if attribute=='TANGENT':data['data'][:,3]*=-1
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension=ExportUVHandedness
asset=OUT/'game/assets/props/bath_paper_holder.glb'
bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',export_yup=True,export_apply=True,export_tangents=True,export_image_format='NONE')
review=validate(asset)
points=[(v.co.x,v.co.z,-v.co.y) for o in bpy.context.scene.objects for v in o.data.vertices]
report={'evidence_class':'INERT','scope':'Native holder diagnostic; no runtime or human acceptance','parts':parts,'material_batches':3,
    'continuous_sheet':{'single_mesh':True,'wrapped_rows':49,'hanging_rows':16,'columns':5,'tangent_position':[0,0,-.119],'simulation':False},
    'bounds':[[min(v[i] for v in points) for i in range(3)],[max(v[i] for v in points) for i in range(3)]],
    'exported_tangents':review,'asset_sha256':hashlib.sha256(asset.read_bytes()).hexdigest()}
(REVIEW/'native.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')

if OUT.resolve()==ROOT.resolve():
    # Preserve household dressing ownership while seating its visual on the
    # actual rear wall. The model's back datum is zero, not the porcelain side.
    path=ROOT/'game/data/orison_v2/bath_details.json'
    data=json.loads(path.read_text());layout=json.loads((ROOT/'game/data/orison_v2_blockout.json').read_text())
    anchors={r['id']:r for r in layout['anchors']};spaces={r['id']:r for r in layout['spaces']}
    for record in data['props']:
        if record['kind']!='toilet_roll':continue
        owner=anchors[record['support']];rect=spaces[owner['space']]['rect'];yaw=owner['yaw'];position=owner['position']
        outward=(math.sin(yaw),math.cos(yaw));axis=0 if abs(outward[0])>.5 else 1
        sign=outward[axis];edge=rect[(2 if sign>0 else 0) if axis==0 else (3 if sign>0 else 1)]
        distance=(edge-position[0 if axis==0 else 2])*sign-layout['dimensions']['partition_wall']*.5
        record['position']=[-.38,.72,round(distance,6)];record['yaw']=0
        if owner['space'] in ['F05_A_BATH','F06_A_BATH']:
            # Retained Stack_B crosses one rear escutcheon. Use the adjacent
            # side wall, rather than hiding the duct or ignoring its contact.
            side=(-math.cos(yaw),math.sin(yaw));axis=0 if abs(side[0])>.5 else 1
            sign=side[axis];edge=rect[(2 if sign>0 else 0) if axis==0 else (3 if sign>0 else 1)]
            distance=(edge-position[0 if axis==0 else 2])*sign-layout['dimensions']['partition_wall']*.5
            record['position']=[round(-distance,6),.72,-.05];record['yaw']=-math.pi*.5
        record['bounds']=report['bounds'];record['model']='res://assets/props/bath_paper_holder.glb'
        record.pop('surfaces',None)
    temporary=path.with_suffix('.json.paper-tmp')
    assert temporary.resolve().parent==path.resolve().parent
    temporary.write_text(json.dumps(data,separators=(',',':'))+'\n',encoding='utf-8',newline='\n')
    os.replace(temporary,path)

# Review under neutral studio illumination against an actual wall datum.
bpy.ops.mesh.primitive_plane_add(size=2,location=(0,-.002,0));wall=bpy.context.object;wall.rotation_euler.x=math.pi/2
wallmat=bpy.data.materials.new('Review wall only');wallmat.diffuse_color=(.36,.40,.36,1);wall.data.materials.append(wallmat)
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24
scene.world=bpy.data.worlds.new('Review studio');scene.world.color=(.05,.05,.05);scene.render.resolution_x=1100;scene.render.resolution_y=850;scene.render.resolution_percentage=100
for at,power,size in [((-.4,.6,.65),15,.5),((.45,.35,.25),8,.35)]:
    bpy.ops.object.light_add(type='AREA',location=at);lamp=bpy.context.object;lamp.data.energy=power;lamp.data.shape='DISK';lamp.data.size=size
    lamp.rotation_euler=(Vector((0,.07,-.04))-lamp.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(.28,.48,.20));camera=bpy.context.object
camera.rotation_euler=(Vector((0,.065,-.045))-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.type='ORTHO';camera.data.ortho_scale=.38;scene.camera=camera
scene.render.filepath=str(REVIEW/'native_holder.png');bpy.ops.render.render(write_still=True)
print('PAPER HOLDER: native source, three batches, continuous outer sheet exported and rendered')
