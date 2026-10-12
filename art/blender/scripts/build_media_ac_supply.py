"""Ten fitted cloth AC leads and reuse of accepted native floor receptacles."""
from pathlib import Path
import ast,collections,hashlib,json,math,sys
import bpy,bmesh
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3];OUT=ROOT/'tmp/v2-media-ac-20261012';OUT.mkdir(parents=True,exist_ok=True)
plan=json.loads((ROOT/'art/data/media_ac_supply/source_plan.json').read_text(encoding='utf-8'))
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
materials={k:bpy.data.materials.new(k) for k in ['linen','rubber_aged','iron_neutral']}
for m in materials.values():m.use_nodes=True
helper=ROOT/'art/blender/scripts/build_electrical_service.py';tree=ast.parse(helper.read_text(encoding='utf-8'))
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in {'point','cube','cylinder','cut','ring','finish'}],type_ignores=[]),str(helper),'exec'))
def finished(name,objects,key,bevel=.0002):
    obj=finish(name,objects,key,bevel);bpy.context.view_layer.objects.active=obj
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    return obj
def rounded(knots):
    points=[Vector(knots[0])]
    for i in range(1,len(knots)-1):
        a,b,c=map(Vector,knots[i-1:i+2]);radius=min(.018,(b-a).length/3,(c-b).length/3)
        entry=b+(a-b).normalized()*radius;exit=b+(c-b).normalized()*radius
        points.append(entry)
        for j in range(1,9):
            t=j/8;points.append((1-t)**2*entry+2*(1-t)*t*b+t*t*exit)
    points.append(Vector(knots[-1]));return points
def flex(name,path,r):
    n=16;vertices=[];lengths=[0.];guide=None
    for i,p in enumerate(path):
        tangent=(path[min(i+1,len(path)-1)]-path[max(i-1,0)]).normalized()
        if guide is None:guide=tangent.cross(Vector((0,1,0)) if abs(tangent.y)<.9 else Vector((1,0,0))).normalized()
        else:guide=(guide-tangent*guide.dot(tangent)).normalized();lengths.append(lengths[-1]+(p-path[i-1]).length)
        side=tangent.cross(guide)
        for j in range(n):vertices.append(point(p+r*(guide*math.cos(j*math.tau/n)+side*math.sin(j*math.tau/n))))
    faces=[tuple(reversed(range(n))),tuple(range((len(path)-1)*n,len(path)*n))]
    for i in range(len(path)-1):
        for j in range(n):faces.append((i*n+j,i*n+(j+1)%n,(i+1)*n+(j+1)%n,(i+1)*n+j))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update()
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
    mesh.materials.append(materials['linen']);uv=mesh.uv_layers.new(name='MetreBraid')
    for face in mesh.polygons:
        ids=list(face.vertices);js=[v%n for v in ids];cap=len({v//n for v in ids})==1;seam=0 in js and n-1 in js
        for loop in face.loop_indices:
            index=mesh.loops[loop].vertex_index;j=index%n;i=index//n
            u,v=(r*math.cos(j*math.tau/n),r*math.sin(j*math.tau/n)) if cap else ((n if seam and j==0 else j)*math.tau*r/n,lengths[i])
            uv.data[loop].uv=((u+v)/math.sqrt(2),(v-u)/math.sqrt(2))
    return obj,lengths[-1]
records=[];routes=[];stats=[]
for row in plan['installations']:
    identity=row['id'];entry=Vector(row['entry']);path=rounded(row['path'])
    cord,length=flex(identity+'_ClothLead',path,float(plan['cord_radius']))
    gland=ring(.006 if row['family']=='projector' else .0065,.0033,.012,entry);gland.rotation_euler.x=math.pi/2
    gland=finished(identity+'_Gland',[gland],'rubber_aged')
    # A fixed clip screws beneath the rear table edge and holds the falling
    # lead below the measured .700 m underside, behind the apron.
    at=Vector((entry.x,.640,.200));clip=ring(.0058,.0033,.014,at)
    clip=finished(identity+'_UnderTopClip',[clip,cube((.035,.004,.018),(entry.x,.698,.200)),cylinder(.0025,.051,(entry.x,.6725,.200))],'iron_neutral')
    records.append({'id':identity,'support':row['support'],'outlet':row['outlet'],'parts':[{'name':cord.name,'material':'linen'},{'name':gland.name,'material':'rubber_aged'},{'name':clip.name,'material':'iron_neutral'}]})
    routes.append({'id':identity,'support':row['support'],'entry':list(entry),'endpoint':list(path[-1]),'radius':plan['cord_radius'],'length':length,'centerline':[list(p) for p in path]})
for obj in [o for o in bpy.context.scene.objects if o.type=='MESH']:
    bm=bmesh.new();bm.from_mesh(obj.data);closed=all(e.is_manifold for e in bm.edges);volume=bm.calc_volume(signed=True);bm.free()
    uv=obj.data.uv_layers.active;bad=0
    for f in obj.data.polygons:
        q=[Vector(uv.data[i].uv) for i in f.loop_indices]
        if abs((q[1]-q[0]).cross(q[2]-q[0]))<=1e-12:bad+=1
    assert closed and volume>0 and bad==0,(obj.name,closed,volume,bad)
    stats.append({'name':obj.name,'volume':volume,'triangles':len(obj.data.polygons),'collapsed_uv':bad})
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/media_ac_supply.blend'))
asset=ROOT/'game/assets/props/media_ac_supply.glb'
bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',export_apply=True,export_tangents=True,export_lights=False,export_cameras=False)
(ROOT/'game/data/orison_v2/media_ac_supply.json').write_text(json.dumps({'schema_version':1,'asset':'res://assets/props/media_ac_supply.glb','installations':records},indent=2)+'\n',encoding='utf-8',newline='\n')
(OUT/'construction.json').write_text(json.dumps({'evidence_class':'INERT','asset_sha256':hashlib.sha256(asset.read_bytes()).hexdigest(),'parts':stats,'routes':routes,'scope':'Native stock/UV only. Installed bore/clip/table/floor contact and control proof remain required; battery/aerial supplies are separate unfinished work.'},indent=2)+'\n',encoding='utf-8',newline='\n')
print('MEDIA AC:',len(records),'leads;',len(stats),'native parts')
