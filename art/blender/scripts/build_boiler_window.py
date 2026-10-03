"""Source-fitted six-light inward hopper; editable construction and joint pivots.

This ADAPTATION uses the existing basement opening, never enlarges masonry,
and supplies no combustion-air simulation or capacity claim.
"""
from pathlib import Path
import hashlib
import json
import math
import re
import bpy
import bmesh
import numpy as np
from mathutils import Vector, Matrix

ROOT = Path(__file__).resolve().parents[3]
plan_path = ROOT/'art/data/boiler_window/source_plan.json'
layout_path = ROOT/'game/data/orison_v2_blockout.json'
plan = json.loads(plan_path.read_text())
layout = json.loads(layout_path.read_text())
record = next(r for r in layout['windows'] if r['id'] == plan['opening_id'])
assert plan['classification'] == 'ADAPTATION'
assert plan['sheet_thickness']==.002 and plan['sash_half_width']==.538 and plan['sash_height']==.876 and plan['glass_thickness']==.004
assert record['axis'] == 'z' and record['width'] == 1.2 and record['height'] == 1.
assert record['center'] == [15.65,3.2] and record['sill'] == 1.4
# Retained masonry generator owns the precise combined reveal span.
generated_path = ROOT/'game/scripts/generated/v2_exterior_masonry.gd'
match=re.search(r'"B1_BOILER_AIR_E":\s*Vector2\(([^,]+),([^\)]+)\)',generated_path.read_text())
span = [float(v) for v in match.groups()]
assert span == [15.58,15.93]
floor=next(r['y'] for r in layout['levels'] if r['id']==record['level'])
centre = [(span[0]+span[1])/2,floor+record['sill']+record['height']/2,record['center'][1]]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version = 0
materials = {}
for key, colour in [('metal',(.27,.29,.28,1)),('brass_dull',(.48,.35,.17,1)),
                    ('rubber_aged',(.045,.043,.038,1)),('glass',(.58,.72,.73,.14))]:
    mat=bpy.data.materials.new(key);mat.diffuse_color=colour;mat.use_nodes=True
    shader=mat.node_tree.nodes['Principled BSDF'];shader.inputs['Base Color'].default_value=colour
    shader.inputs['Metallic'].default_value=.7 if key in ['metal','brass_dull'] else 0
    shader.inputs['Roughness'].default_value=.08 if key=='glass' else .48
    if key=='glass':shader.inputs['Transmission Weight'].default_value=.95
    materials[key]=mat
native_collection=bpy.data.collections.new('ClosedConstruction')
bpy.context.scene.collection.children.link(native_collection)
native_collection.hide_render=True;native_collection.hide_viewport=True
closed=[];polygons={};nodes={};parts=[]

def b(p): return Vector((p[0],-p[2],p[1]))
def empty(name,at=(0,0,0),parent=None):
    obj=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(obj)
    obj.parent=parent;obj.location=b(at);nodes[name]=obj;return obj

fixed=empty('Fixed');sash=empty('Sash',plan['hinge_local'])
latch=empty('Latch',(0,.853,-.026),sash)
link_nodes={name:empty(name) for name in ['StayLeftA','StayLeftB','StayRightA','StayRightB']}

def piece(name,verts,faces,key,group,omit=()):
    mesh=bpy.data.meshes.new(name);mesh.from_pydata([b(v) for v in verts],[],faces);mesh.update()
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    assert all(e.is_manifold for e in bm.edges),name
    assert bm.calc_volume(signed=True)>1e-12,name
    bm.to_mesh(mesh);bm.free()
    obj=bpy.data.objects.new(name,mesh);native_collection.objects.link(obj);obj.parent=nodes[group]
    mesh.materials.append(materials[key]);obj['joint']=group;obj['material_key']=key
    closed.append(obj)
    target=polygons.setdefault((group,key),[])
    for face in mesh.polygons:
        if face.index not in omit:target.append([mesh.vertices[i].co.copy() for i in face.vertices])

def box(name,lo,hi,key,group,omit=()):
    a,c=lo,hi
    verts=[(x,y,z) for z in [a[2],c[2]] for y in [a[1],c[1]] for x in [a[0],c[0]]]
    faces=[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)]
    piece(name,verts,faces,key,group,omit)

def ring(name,profile,key,group,cy=0,omit=()):
    verts=[(sx*x,cy+sy*y,z) for x,y,z in profile for sx,sy in [(-1,-1),(1,-1),(1,1),(-1,1)]]
    faces=[(j*4+i,j*4+(i+1)%4,((j+1)%len(profile))*4+(i+1)%4,((j+1)%len(profile))*4+i)
           for j in range(len(profile)) for i in range(4)]
    piece(name,verts,faces,key,group,omit)

def cylinder_x(name,cx,cy,cz,length,radius,key,group):
    verts=[(cx+x,cy+radius*math.cos(2*math.pi*i/24),cz+radius*math.sin(2*math.pi*i/24))
           for x in [-length/2,length/2] for i in range(24)]
    faces=[tuple(reversed(range(24))),tuple(range(24,48))]
    faces += [(i,(i+1)%24,(i+1)%24+24,i+24) for i in range(24)]
    piece(name,verts,faces,key,group)

# A continuous folded liner and return flanges: 2 mm sheet, not a filled block.
# Four outward liner faces seat on retained masonry and are omitted at runtime.
profile=[(.620,.520,-.177),(.620,.520,-.175),(.600,.500,-.175),(.600,.500,.175),
         (.620,.520,.175),(.620,.520,.177),(.598,.498,.177),(.598,.498,-.102),
         (.528,.428,-.102),(.528,.428,-.104),(.598,.498,-.104),(.598,.498,-.177)]
ring('FoldedReveal',profile,'metal','Fixed',omit=tuple(range(4,16)))

# Eight fitted flange fixings. Embedded shanks remain native construction;
# retained masonry owns their buried runtime surfaces.
fixings=[(side*.611,y) for side in [-1.,1.] for y in [-.28,.28]]
fixings += [(x,y) for x in [-.35,.35] for y in [-.511,.511]]
for i,(x,y) in enumerate(fixings):
    box('FlangeWasher_'+str(i),(x-.009,y-.009,-.180),(x+.009,y+.009,-.177),'metal','Fixed')
    box('SquareScrewHead_'+str(i),(x-.0045,y-.0045,-.186),(x+.0045,y+.0045,-.180),'brass_dull','Fixed')
    box('EmbeddedAnchor_'+str(i),(x-.0025,y-.0025,-.177),(x+.0025,y+.0025,-.137),'metal','Fixed',omit=tuple(range(6)))

ring('CompressionSeat',[(.536,.436,-.104),(.536,.436,-.106),(.528,.428,-.106),(.528,.428,-.104)],'rubber_aged','Fixed')
# Falling exterior sill lip and turned-down nose; retains the original sill.
verts=[(x,y,z) for x in [-.62,.62] for y,z in [(-.5,.175),(-.511,.25),(-.527,.25),(-.527,.248),(-.513,.248),(-.502,.175)]]
n=6;faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
piece('SillDrip',verts,faces,'metal','Fixed')
ring('SashChannel',[(.538,.438,0),(.538,.438,.024),(.506,.406,.024),(.506,.406,0)],'metal','Sash',cy=.44)
for x in [-.169,.169]:
    for low,high in [(.034,.431),(.449,.846)]:
        box('VerticalMuntin_'+str(x)+'_'+str(low),(x-.009,low,.003),(x+.009,high,.021),'metal','Sash',omit=(2,3))
box('CrossMuntin',(-.506,.431,.003),(.506,.449,.021),'metal','Sash')
panes=[]
for column,(a,c) in enumerate([(-.506,-.178),(-.160,.160),(.178,.506)]):
    for row,(low,high) in enumerate([(.034,.431),(.449,.846)]):
        # Edges meet the actual sash/muntins; no overlapping glass under bars.
        bounds=[a,low,.010,c,high,.014]
        box(f'Pane_{column}_{row}',bounds[:3],bounds[3:],'glass','Sash');panes.append(bounds)
for x in [-.36,.36]:
    for dx in [-.035,.035]:cylinder_x('FixedKnuckle',x+dx,-.44,-.13,.028,.014,'metal','Fixed')
    cylinder_x('SashKnuckle',x,0,0,.036,.014,'metal','Sash')
    cylinder_x('HingePin',x,-.44,-.13,.102,.004,'brass_dull','Fixed')
    box('FixedHingeSeat',(x-.055,-.485,-.15),(x+.055,-.46,-.128),'metal','Fixed')
    box('MovingHingeStrap',(x-.013,0,.012),(x+.013,.068,.020),'metal','Sash')
for side in [-1.,1.]:
    x=side*.555
    box('StayFixedSeat',(x-.010,-.397,-.177),(x+.010,-.343,-.156),'metal','Fixed')
    lo,hi=sorted([side*.524,side*.566])
    box('StaySashLug',(lo,.532,-.005),(hi,.568,.005),'metal','Sash')
    for role in ['A','B']:
        group=('StayLeft' if side<0 else 'StayRight')+role
        box('ArticulatedLink',(-.005,-.007,-.003),(.005,plan['stay_length']+.007,.003),'metal',group)
        for y in [0,plan['stay_length']]:cylinder_x('StayRivet',0,y,0,.014,.004,'brass_dull',group)
# The cam catches a fixed top strike; hand furniture stays on the moving sash.
box('TopStrike',(-.020,.460,-.148),(.020,.490,-.104),'metal','Fixed')
box('LatchSpindle',(-.009,.844,-.026),(.009,.862,.013),'brass_dull','Sash')
box('CamLever',(-.007,-.010,-.008),(.007,.065,.008),'brass_dull','Latch')
box('HandGrip',(-.014,.043,-.018),(.014,.070,-.004),'metal','Latch')

def stay_pose(angle):
    result={};hinge=Vector(plan['hinge_local']);rotation=Matrix.Rotation(-math.radians(angle),3,'X')
    # mathutils rotation here is in the explicitly authored Godot frame.
    for side in [-1.,1.]:
        a=Vector((side*.555,*plan['stay_anchor_yz']))
        c=hinge+rotation@Vector((side*.555,*plan['stay_sash_yz']))
        delta=c-a;distance=delta.length;assert distance<2*plan['stay_length']
        perpendicular=Vector((0,delta.z,-delta.y)).normalized()
        elbow=(a+c)/2+perpendicular*math.sqrt(plan['stay_length']**2-(distance/2)**2)
        for role,start,end in [('A',a,elbow),('B',elbow,c)]:
            name=('StayLeft' if side<0 else 'StayRight')+role
            y=b(end-start).normalized();x=Vector((1,0,0));z=x.cross(y)
            result[name]=(start,Matrix((x,y,z)).transposed())
    return result
for name,(at,basis) in stay_pose(0).items():
    nodes[name].location=b(at);nodes[name].rotation_mode='QUATERNION';nodes[name].rotation_quaternion=basis.to_quaternion()

triangles=0
for (group,key),surfaces in sorted(polygons.items()):
    vertices=[];faces=[]
    for surface in surfaces:
        start=len(vertices);vertices.extend(surface);faces.append(tuple(range(start,start+len(surface))))
    mesh=bpy.data.meshes.new(group+'_'+key);mesh.from_pydata(vertices,[],faces);mesh.update()
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
    uv=mesh.uv_layers.new(name='Metres');uv.active_render=True
    for face in mesh.polygons:
        normal=face.normal.normalized();seed=Vector((0,1,0)) if abs(normal.y)<.85 else Vector((1,0,0))
        u=(seed-normal*seed.dot(normal)).normalized();v=normal.cross(u).normalized()
        for loop in face.loop_indices:
            p=mesh.vertices[mesh.loops[loop].vertex_index].co;uv.data[loop].uv=(p.dot(u),p.dot(v))
    obj=bpy.data.objects.new(mesh.name,mesh);bpy.context.collection.objects.link(obj);obj.parent=nodes[group]
    mesh.materials.append(materials[key]);parts.append(obj);mesh.calc_loop_triangles();triangles+=len(mesh.loop_triangles)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/boiler_window.blend'))
bpy.ops.object.select_all(action='DESELECT')
for obj in parts+list(nodes.values()):obj.select_set(True)
class ExportUVHandedness:
    def gather_attribute_change(self,attribute,data,normalized,export_settings):
        if attribute=='NORMAL':self.normals=np.array(data['data'],dtype=np.float64).reshape(-1,3)
        elif attribute=='TANGENT':
            result=np.zeros((len(self.normals),4),dtype=np.float32)
            for i,normal in enumerate(self.normals):
                seed=np.array((0,0,-1) if abs(normal[2])<.85 else (1,0,0),dtype=np.float64)
                tangent=seed-normal*np.dot(seed,normal);tangent/=np.linalg.norm(tangent)
                result[i,:3]=tangent;result[i,3]=-1
            data['data']=result
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension=ExportUVHandedness
bpy.ops.export_scene.gltf(filepath=str(ROOT/'game/assets/props/boiler_window.glb'),export_format='GLB',use_selection=True,export_yup=True,export_tangents=True)
manifest={'evidence_class':'INERT','classification':'ADAPTATION','opening_id':record['id'],'centre':centre,
          'reveal_span':span,'width':record['width'],'height':record['height'],'sheet_thickness':plan['sheet_thickness'],
          'maximum_angle_degrees':plan['maximum_angle_degrees'],'hinge_local':plan['hinge_local'],
          'stay_length':plan['stay_length'],'stay_anchor_yz':plan['stay_anchor_yz'],'stay_sash_yz':plan['stay_sash_yz'],
          'closed_native_pieces':len(closed),'parts':len(parts),'triangles':triangles,'panes':panes,'flange_fixings':[[x,y,-.186] for x,y in fixings],
          'source_bindings':{p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest()
                             for p in [plan_path,layout_path,generated_path]},
          'asset_sha256':hashlib.sha256((ROOT/'game/assets/props/boiler_window.glb').read_bytes()).hexdigest(),
          'open_work':plan['open_work']}
for path in [ROOT/'art/blender/boiler_window_construction.json',ROOT/'game/tests/fixtures/orison_boiler_window.json']:
    path.write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8',newline='\n')
print('BOILER WINDOW',len(closed),'closed pieces;',len(parts),'parts;',triangles,'triangles')
