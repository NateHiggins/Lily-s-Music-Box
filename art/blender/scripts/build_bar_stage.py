"""Fabricate the original curtain installation behind retained signal hardware."""
from pathlib import Path
import collections, hashlib, json, math, os, sys
import bpy, bmesh
from mathutils import Vector

ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
OUT=Path(os.environ.get('BAR_STAGE_OUT',str(ROOT))).resolve()
PLAN=ROOT/'art/data/bar_stage/source_fit.json';plan=json.loads(PLAN.read_bytes())
assert plan['classification']=='ADAPTATION' and len(plan['sources'])==17
def digest(path):
    raw=path.read_bytes()
    return hashlib.sha256(raw if path.suffix in ('.bin','.glb','.png','.blend') else raw.replace(b'\r\n',b'\n')).hexdigest()
for name,expected in plan['bindings'].items():assert digest(ROOT/name)==expected,(name,'stage fit needs regeneration')
for folder in ['art/blender','game/assets/props','game/data/orison_v2','game/tests/fixtures']:(OUT/folder).mkdir(parents=True,exist_ok=True)
sys.path.insert(0,str(ROOT/'art/blender/scripts'));from fabrication_uvs import chart_for_triangle
sets=json.loads((ROOT/'game/data/runtime_material_sets.json').read_bytes())['materials']
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
construction=bpy.data.collections.new('ClosedStageConstruction');bpy.context.scene.collection.children.link(construction)
materials={}
for key in ['fabric_warm','iron_blackened','wood_dark']:
    mat=bpy.data.materials.new('M_'+key);mat.use_nodes=True;spec=sets[key];node=mat.node_tree.nodes['Principled BSDF']
    node.inputs['Metallic'].default_value=spec['metallic'];materials[key]=mat
    coord=mat.node_tree.nodes.new('ShaderNodeTexCoord');scale=mat.node_tree.nodes.new('ShaderNodeVectorMath');scale.operation='SCALE';scale.inputs['Scale'].default_value=1/spec['meters_per_tile'];mat.node_tree.links.new(coord.outputs['UV'],scale.inputs[0])
    for index,target in enumerate(['Base Color','Roughness','Normal']):
        image=bpy.data.images.load(str(ROOT/'game/assets/building/textures'/spec['files'][index]),check_existing=True)
        tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=image;mat.node_tree.links.new(scale.outputs['Vector'],tex.inputs['Vector'])
        if index:image.colorspace_settings.name='Non-Color'
        if index==2:
            normal=mat.node_tree.nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.35;mat.node_tree.links.new(tex.outputs['Color'],normal.inputs['Color']);mat.node_tree.links.new(normal.outputs[0],node.inputs[target])
        elif index==0 and key=='fabric_warm':
            tint=plan['fit']['cloth_tint'];linear=[v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in tint[:3]]
            mix=mat.node_tree.nodes.new('ShaderNodeMixRGB');mix.blend_type='MULTIPLY';mix.inputs[0].default_value=1.;mix.inputs[2].default_value=(*linear,1.)
            mat.node_tree.links.new(tex.outputs['Color'],mix.inputs[1]);mat.node_tree.links.new(mix.outputs[0],node.inputs[target])
        else:mat.node_tree.links.new(tex.outputs['Color'],node.inputs[target])
stocks=[];groups=collections.defaultdict(list);checks=[];contacts=[];joins=[]
def finish(obj,name,key):
    obj.name=name
    for c in list(obj.users_collection):c.objects.unlink(obj)
    construction.objects.link(obj);obj.data.materials.clear();obj.data.materials.append(materials[key])
    bm=bmesh.new();bm.from_mesh(obj.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    assert all(e.is_manifold for e in bm.edges) and bm.calc_volume(signed=True)>0,name
    checks.append({'name':name,'key':key,'volume_m3':bm.calc_volume(signed=True),'nonmanifold_edges':0});bm.to_mesh(obj.data);bm.free()
    stocks.append(obj);groups[key].append(obj);return obj
def solid(name,vertices,faces,key):
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update();obj=bpy.data.objects.new(name,mesh);construction.objects.link(obj);return finish(obj,name,key)
def box(name,low,high,key):
    vertices=[(x,y,z) for z in [low[2],high[2]] for y in [low[1],high[1]] for x in [low[0],high[0]]]
    return solid(name,vertices,[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)],key)
def rod(name,a,b,r,key='iron_blackened',n=48):
    a,b=Vector(a),Vector(b);d=b-a
    bpy.ops.mesh.primitive_cylinder_add(vertices=n,radius=r,depth=d.length,location=(a+b)*.5);obj=bpy.context.object;obj.rotation_euler=d.to_track_quat('Z','Y').to_euler();bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
    return finish(obj,name,key)
def ring(name,x,y,z,major,minor):
    n=24;m=8
    vertices=[(x+minor*math.sin(j*math.tau/m),y+(major+minor*math.cos(j*math.tau/m))*math.cos(i*math.tau/n),z+(major+minor*math.cos(j*math.tau/m))*math.sin(i*math.tau/n)) for i in range(n) for j in range(m)]
    return solid(name,vertices,[(i*m+j,((i+1)%n)*m+j,((i+1)%n)*m+(j+1)%m,i*m+(j+1)%m) for i in range(n) for j in range(m)],'iron_blackened')
def collar(name,x,y,z,inner,outer):
    n=48;vertices=[(xx,y+r*math.cos(i*math.tau/n),z+r*math.sin(i*math.tau/n)) for xx,r in [(x-.012,outer),(x+.012,outer),(x+.012,inner),(x-.012,inner)] for i in range(n)]
    return solid(name,vertices,[(j*n+i,j*n+(i+1)%n,((j+1)%4)*n+(i+1)%n,((j+1)%4)*n+i) for j in range(4) for i in range(n)],'iron_blackened')
def strap(name,a,b):
    a,b=Vector(a),Vector(b);u=Vector((.007,0,0));v=(b-a).cross(u).normalized()*.0006
    vertices=[tuple(p+su*u+sv*v) for p in [a,b] for sv in [-1,1] for su in [-1,1]]
    return solid(name,vertices,[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)],'fabric_warm')

sources=plan['sources'];curtains=sources[:16];pelmet=sources[-1];fit=plan['fit']
x0=min(r['rect'][0] for r in curtains)+.006;x1=max(r['rect'][2] for r in curtains)-.006
floor_z=plan['floor']['z0']+plan['floor']['h'];bottom=floor_z+fit['floor_clearance_m'];top=curtains[0]['z0']+curtains[0]['h']
front=fit['front_y'];depth=fit['depth_m'];centre_y=front-depth*.5;wall_y=plan['wall']['rect'][3]
rail_y=front-.029;rail_z=top+.11;radius=fit['rail_radius_m'];ring_r=fit['ring_radius_m'];ring_stock=fit['ring_stock_m']
dado_top=plan['dado']['z0']+plan['dado']['h'];dado_front=plan['dado']['rect'][3]
lower_shift=max(0.,dado_front+.010-(front-depth+.002))
assert rail_y-ring_r-ring_stock>wall_y+.002 and front-plan['sign_bounds'][0][1]<-.017
N=192
def profile(x,z):
    # Flatten the hidden sewn header behind the shallow fascia. Lower folds
    # use the full available depth without entering the existing sign cabinet.
    t=max(0.,min(1.,(top-z-.045)/.10));t=t*t*(3-2*t)
    centre=rail_y*(1-t)+centre_y*t;amplitude=(depth*.5-.003)*t
    phase=(x-x0)/(x1-x0)*16*math.tau
    flare=max(0.,min(1.,(dado_top+.12-z)/.10));flare=flare*flare*(3-2*flare)
    return centre+amplitude*math.cos(phase)+lower_shift*flare
def cloth(name,z_values,offset,thickness):
    verts=[];uvs=[];m=len(z_values)
    for side in [-1,1]:
        reference=[];arc=0.;previous=None
        for i in range(N+1):
            x=x0+(x1-x0)*i/N;z=bottom+.5;dx=.0001
            derivative=(profile(x+dx,z)-profile(x-dx,z))/(2*dx);n=Vector((-derivative,1,0)).normalized()
            point=Vector((x,profile(x,z),0))+n*(offset+side*thickness*.5)
            if previous is not None:arc+=(point-previous).length
            previous=point;reference.append(arc)
        for z in z_values:
            for i in range(N+1):
                x=x0+(x1-x0)*i/N;y=profile(x,z);dx=.0001
                derivative=(profile(x+dx,z)-profile(x-dx,z))/(2*dx);n=Vector((-derivative,1,0)).normalized()
                at=Vector((x,y,z))+n*(offset+side*thickness*.5)
                verts.append(tuple(at));uvs.append((reference[i],z-bottom))
    span=m*(N+1);faces=[]
    for side in range(2):
        for j in range(m-1):
            for i in range(N):
                a=side*span+j*(N+1)+i;faces.append((a,a+1,a+N+2,a+N+1))
    smooth_count=len(faces)
    for i in range(N):
        faces.append((i,span+i,span+i+1,i+1))
        a=(m-1)*(N+1)+i;faces.append((a,a+1,span+a+1,span+a))
    for j in range(m-1):
        a=j*(N+1);b=a+N+1;faces.append((a,b,span+b,span+a))
        a=j*(N+1)+N;b=a+N+1;faces.append((a,span+a,span+b,b))
    obj=solid(name,verts,faces,'fabric_warm');layer=obj.data.uv_layers.new(name='ContinuousClothMetres')
    for face in obj.data.polygons:
        face.use_smooth=face.index<smooth_count
        axis=max(range(3),key=lambda i:abs(face.normal[i]));axes=[i for i in range(3) if i!=axis]
        for loop in face.loop_indices:
            index=obj.data.loops[loop].vertex_index;point=obj.data.vertices[index].co
            layer.data[loop].uv=uvs[index] if face.use_smooth else (point[axes[0]],point[axes[1]])
    return obj
z_values=sorted(set([bottom,bottom+.018,dado_top+.005,dado_top+.020,dado_top+.045,dado_top+.075,dado_top+.10,dado_top+.12,top-.20,top-.145,top-.10,top-.045,top-.025,top]))
cloth('CurtainClosedSheet',z_values,0.,fit['cloth_thickness_m'])
cloth('SewnHeader',[top-.065,top-.045,top-.025,top],.0017,.0014)
cloth('FoldedLowerHem',[bottom,bottom+.018],.0017,.0014)
px0,py0,px1,py1=pelmet['rect'];pz=pelmet['z0'];ptop=pz+pelmet['h']
wood_back=front-.014;wood_front=front-.003
box('PelmetTimberFascia',(px0,wood_back,pz),(px1,wood_front,ptop),'wood_dark')
box('PelmetClothCover',(px0-.001,wood_front,pz-.001),(px1+.001,front,ptop+.001),'fabric_warm')
rod('CurtainRail',(px0+.025,rail_y,rail_z),(px1-.025,rail_y,rail_z),radius)
for i in range(32):
    x=x0+(x1-x0)*(i+.5)/32;cz=rail_z+radius-(ring_r-ring_stock)
    ring('ThreadedRing%02d'%i,x,rail_y,cz,ring_r,ring_stock)
    # The sewn tab enters the ring's bottom stock and the cloth's hidden header.
    a=(x,rail_y,cz-ring_r-ring_stock+.0007);b=(x,profile(x,top-.018),top-.018)
    strap('SewnHangingTab%02d'%i,a,b)
    for point,label in [(a,'ring/threaded tab'),(b,'tab/sewn header')]:joins.append({'id':f'hook_{i}_{label}','point':list(point)})
support_x=[x0+.035,(x0+x1)*.5,x1-.035]
for i,x in enumerate(support_x):
    identity='StageBearing%d'%i;plate_front=wall_y+.004
    box(identity+'_WallPlate',(x-.035,wall_y,rail_z-.095),(x+.035,plate_front,rail_z+.085),'iron_blackened')
    contacts.append({'id':identity,'owner':'F01_OWN_SHOP_BAR_retail_bar_bar_wall','point':[x,wall_y,rail_z-.005],'normal':[0,1,0],'half_width':.028,'half_height':.072})
    collar(identity+'_SplitCollar',x,rail_y,rail_z,radius,.011)
    box(identity+'_RailArm',(x-.005,plate_front,rail_z-.021),(x+.005,rail_y,rail_z-.011),'iron_blackened')
    box(identity+'_FasciaArm',(x-.008,plate_front,rail_z+.045),(x+.008,wood_back,rail_z+.055),'iron_blackened')
    for angle in [0.,math.pi*.5,math.pi,math.pi*1.5]:
        joins.append({'id':identity+'_rail_collar','point':[x,rail_y+radius*math.cos(angle),rail_z+radius*math.sin(angle)]})
    for j,(dx,dz) in enumerate([(-.023,-.067),(.023,-.067),(-.023,.061),(.023,.061)]):
        z=rail_z-.005+dz;rod(identity+'_WallAnchor%d'%j,(x+dx,wall_y-.018,z),(x+dx,plate_front+.002,z),.0018)
        rod(identity+'_AnchorHead%d'%j,(x+dx,plate_front,z),(x+dx,plate_front+.0015,z),.0034)
    for j,dx in enumerate([-.004,.004]):
        rod(identity+'_FasciaScrew%d'%j,(x+dx,wood_back-.003,rail_z+.05),(x+dx,wood_front-.001,rail_z+.05),.0013)
        rod(identity+'_ScrewHead%d'%j,(x+dx,wood_back-.002,rail_z+.05),(x+dx,wood_back,rail_z+.05),.0023)

parts=[];inventory=[];fallbacks=0
for key,objects in sorted(groups.items()):
    vertices=[];triangles=[];charts=[];smooth=[]
    for obj in objects:
        obj.data.calc_loop_triangles();offset=len(vertices);vertices.extend(obj.matrix_world@v.co for v in obj.data.vertices)
        for tri in obj.data.loop_triangles:
            triangles.append(tuple(offset+i for i in tri.vertices));smooth.append(obj.data.polygons[tri.polygon_index].use_smooth)
            if obj.data.uv_layers and obj.data.uv_layers.active.name=='ContinuousClothMetres':charts.append([tuple(obj.data.uv_layers.active.data[i].uv) for i in tri.loops])
            else:
                points=[obj.matrix_world@obj.data.vertices[i].co for i in tri.vertices];_,_,uv,fallback=chart_for_triangle(points,Vector((0,0,0)),sets[key]['meters_per_tile']);charts.append(uv);fallbacks+=fallback
    mesh=bpy.data.meshes.new('Stage__'+key);mesh.from_pydata(vertices,[],triangles);mesh.update();layer=mesh.uv_layers.new(name='PhysicalMetres');layer.active_render=True
    for face,uv,sm in zip(mesh.polygons,charts,smooth):
        face.use_smooth=sm
        for loop,value in zip(face.loop_indices,uv):layer.data[loop].uv=value
    obj=bpy.data.objects.new(mesh.name,mesh);bpy.context.scene.collection.objects.link(obj);mesh.materials.append(materials[key]);parts.append(obj)
    spec={'name':obj.name,'key':key,'catalog_key':key,'tile':sets[key]['meters_per_tile'],'triangles':len(triangles)}
    if key=='fabric_warm':spec['tint']=fit['cloth_tint']
    inventory.append(spec)
construction.hide_render=True
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'art/blender/bar_stage.blend'),compress=True)
bpy.ops.object.select_all(action='DESELECT')
for obj in parts:obj.select_set(True)
class ExportUVHandedness:
    def gather_attribute_change(self,attribute,data,normalized,export_settings):
        if attribute=='TANGENT':data['data'][:,3]*=-1
import io_scene_gltf2;io_scene_gltf2.glTF2ExportUserExtension=ExportUVHandedness
asset=OUT/'game/assets/props/bar_stage.glb';bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',use_selection=True,export_yup=True,export_tangents=True,export_materials='NONE')
def godot(v):return [v[0],v[2],-v[1]]
replacements=[{'id':r['id'],'key':r['mat'],'low':godot([r['rect'][0],r['rect'][3],r['z0']]),'high':godot([r['rect'][2],r['rect'][1],r['z0']+r['h']]),'expected_triangles':12} for r in sources]
runtime={'schema_version':1,'asset':'res://assets/props/bar_stage.glb','tolerance':.00003,'cells':[{'id':'shop_bar','replace':replacements,'parts':[{k:v for k,v in p.items() if k!='triangles'} for p in inventory]}]}
(OUT/'game/data/orison_v2/bar_stage.json').write_text(json.dumps(runtime,indent=2)+'\n',newline='\n')
bindings=[PLAN,Path(__file__),ROOT/'art/blender/scripts/fabrication_uvs.py',ROOT/'art/data/material_catalog.json',ROOT/'game/data/runtime_material_sets.json']
fixture={'evidence_class':'INERT','asset_sha256':digest(asset),'parts':inventory,'stocks':checks,'contacts':contacts,'joins':joins,'markers':plan['markers'],'sign_bounds':plan['sign_bounds'],'fit':{'front_y':front,'rear_y':front-depth,'bottom':bottom,'top':top,'rail_y':rail_y,'rail_z':rail_z,'lower_shift_m':lower_shift,'dado_top':dado_top},'original_sources':sources,'removed_triangles':204,'triangles':sum(p['triangles'] for p in inventory),'retained_bindings':plan['bindings'],'source_bindings':{p.relative_to(ROOT).as_posix():digest(p) for p in bindings},'uv_fallbacks':fallbacks}
(OUT/'game/tests/fixtures/orison_bar_stage.json').write_text(json.dumps(fixture,indent=2)+'\n',newline='\n')
(OUT/'art/blender/bar_stage_inventory.json').write_text(json.dumps(fixture,indent=2)+'\n',newline='\n')
print('BAR STAGE:',len(checks),'positive closed stocks;',len(parts),'partitions;',fixture['triangles'],'triangles;',len(contacts),'retained wall bearings; original 204 triangles replaced')
