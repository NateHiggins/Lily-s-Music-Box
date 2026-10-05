"""Editable closed steel girders and seated wall brackets under the retained roof."""
from pathlib import Path
import collections,hashlib,json,math,os,sys
import bpy,bmesh,numpy as np
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(Path(__file__).parent));os.environ['ORISON_DEFINITIONS_ONLY']='1'
import build_orison as original
from fabrication_uvs import chart_for_triangle

def digest(p):return hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest()
plan_path=ROOT/'art/data/front_court_roof/source_fit.json';plan=json.loads(plan_path.read_bytes())
for rel,h in plan['bindings'].items():assert digest(ROOT/rel)==h,rel
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
construction=bpy.data.collections.new('ClosedRoofFrameStocks');bpy.context.scene.collection.children.link(construction)
sets=json.loads((ROOT/'game/data/runtime_material_sets.json').read_bytes())['materials']
materials={};tiles={};stocks=[];groups=collections.defaultdict(list);contacts=[];bearings=[]
for key,tint in [('cast_iron',(.10,.11,.10)),('metal',(.24,.25,.23))]:
    spec=sets[key];tiles[key]=spec['meters_per_tile']
    mat=bpy.data.materials.new('M_'+key);mat.use_nodes=True;materials[key]=mat
    node=mat.node_tree.nodes['Principled BSDF'];node.inputs['Metallic'].default_value=spec['metallic']
    uv=mat.node_tree.nodes.new('ShaderNodeTexCoord');scale=mat.node_tree.nodes.new('ShaderNodeVectorMath');scale.operation='SCALE';scale.inputs['Scale'].default_value=1/tiles[key]
    mat.node_tree.links.new(uv.outputs['UV'],scale.inputs[0])
    for index,target in enumerate(['Base Color','Roughness','Normal']):
        path=ROOT/'game/assets/building/textures'/spec['files'][index]
        img=bpy.data.images.load(str(path),check_existing=True)
        if index:img.colorspace_settings.name='Non-Color'
        img.filepath=bpy.path.relpath(str(path),start=str(ROOT/'art/blender'))
        tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=img;mat.node_tree.links.new(scale.outputs['Vector'],tex.inputs['Vector'])
        if index==0:
            mix=mat.node_tree.nodes.new('ShaderNodeMixRGB');mix.blend_type='MULTIPLY';mix.inputs[0].default_value=1
            linear=[v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in tint]
            mix.inputs[2].default_value=(*linear,1);mat.node_tree.links.new(tex.outputs['Color'],mix.inputs[1]);mat.node_tree.links.new(mix.outputs[0],node.inputs[target])
        elif index==2:
            normal=mat.node_tree.nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.35
            mat.node_tree.links.new(tex.outputs['Color'],normal.inputs['Color']);mat.node_tree.links.new(normal.outputs[0],node.inputs[target])
        else:mat.node_tree.links.new(tex.outputs['Color'],node.inputs[target])

def stock(name,buffer,key):
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(buffer.verts,[],buffer.faces);mesh.update()
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-8);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    volume=bm.calc_volume(signed=True);assert volume>1e-12 and all(e.is_manifold for e in bm.edges),name
    bm.to_mesh(mesh);bm.free();obj=bpy.data.objects.new(name,mesh);construction.objects.link(obj);mesh.materials.append(materials[key]);obj['key']=key
    points=np.asarray([v.co[:] for v in mesh.vertices]);stocks.append({'name':name,'key':key,'volume_m3':volume,'bounds':points.min(axis=0).tolist()+points.max(axis=0).tolist()});groups[key].append(obj)
    return obj

def box(name,key,lo,hi):
    b=original.MeshBuf(name,key);b.add_box((lo[0],-hi[2],lo[1]),(hi[0],-lo[2],hi[1]));return stock(name,b,key)

def tube(name,key,a,b,r,n=12):
    m=original.MeshBuf(name,key);m.add_tube((a[0],-a[2],a[1]),(b[0],-b[2],b[1]),r,n);return stock(name,m,key)

top=plan['roof_underside'];bottom=top-plan['girder_depth'];half=plan['girder_width']/2
web=plan['web_thickness']/2;flange=plan['flange_thickness']
profile=[(-half,bottom),(half,bottom),(half,bottom+flange),(web,bottom+flange),
         (web,top-flange),(half,top-flange),(half,top),(-half,top),
         (-half,top-flange),(-web,top-flange),(-web,bottom+flange),(-half,bottom+flange)]
for index,row in enumerate(plan['beams']):
    z=row['z'];left=row['left'];right=row['right'];x0,x1=left+.035,right-.035
    m=original.MeshBuf('Girder_'+str(index),'cast_iron');m.verts=[(x,-(z+u),y) for x in [x0,x1] for u,y in profile]
    n=len(profile);m.faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    stock('Girder_'+str(index),m,'cast_iron')
    for sx,wall in [(1,left),(-1,right)]:
        label='Bracket_%d_%s'%(index,'left' if sx==1 else 'right')
        def xb(a,b):return sorted([wall+sx*a,wall+sx*b])
        a,b=xb(-.002,.020);box(label+'Back','cast_iron',[a,bottom-.86,z-.25],[b,bottom+.01,z+.25])
        a,b=xb(.018,.40);box(label+'Shelf','cast_iron',[a,bottom-.022,z-.20],[b,bottom,z+.20])
        m=original.MeshBuf(label+'Knee','cast_iron');m.add_tbox((wall+sx*.020,-z,bottom-.76),(wall+sx*.34,-z,bottom-.022),.045,.045);stock(label+'Knee',m,'cast_iron')
        for dy in [-.75,-.55,-.35,-.13]:
            for dz in [-.18,.18]:
                y=bottom+dy;at=(wall,y,z+dz)
                tube(label+'Anchor_'+str(dy)+'_'+str(dz),'metal',(wall-sx*.08,y,z+dz),(wall+sx*.035,y,z+dz),.0065)
                tube(label+'Head_'+str(dy)+'_'+str(dz),'metal',(wall+sx*.020,y,z+dz),(wall+sx*.037,y,z+dz),.014,6)
                contacts.append({'point':list(at),'inward':[sx,0,0],'source_wall':row['wall_owners'][0 if sx==1 else 1]})
        bearings.append({'beam':index,'wall':wall,'z':z,'inward':sx,'shelf_top':bottom,'girder_bottom':bottom,
                         'seat_x':[wall+sx*.05,wall+sx*.30],'seat_z':[z-.12,z+.12]})

parts=[];fallbacks=0
for key,objects in sorted(groups.items()):
    buckets=collections.defaultdict(list)
    for obj in objects:
        bm=bmesh.new();bm.from_mesh(obj.data);bmesh.ops.triangulate(bm,faces=list(bm.faces))
        for axis in range(3):
            values=[v.co[axis] for v in bm.verts]
            for k in range(math.ceil(min(values)/4),math.ceil(max(values)/4)):
                n=Vector(tuple(int(j==axis) for j in range(3)));bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),plane_co=n*(4*k),plane_no=n,dist=1e-8)
        bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.normal_update()
        for face in bm.faces:
            p=[v.co.copy() for v in face.verts];centre=sum(p,Vector())/3;cell=[]
            for axis,v in enumerate(centre):
                if max(q[axis] for q in p)-min(q[axis] for q in p)<1e-8 and abs(v/4-round(v/4))<1e-8:v-=math.copysign(1e-7,face.normal[axis])
                cell.append(math.floor(v/4))
            buckets[tuple(cell)].append(p)
        bm.free()
    for cell,triangles in sorted(buckets.items()):
        pivot=Vector([4*(c+.5) for c in cell]);name='RoofFrame__'+key+'__'+'_'.join(map(str,cell))
        vertices=[tuple(p-pivot) for t in triangles for p in t];mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],[(i,i+1,i+2) for i in range(0,len(vertices),3)]);mesh.update()
        uv=mesh.uv_layers.new(name='Metres');uv.active_render=True
        for face in mesh.polygons:
            p=np.asarray([mesh.vertices[i].co[:] for i in face.vertices]);_,_,values,fallback=chart_for_triangle(p,np.asarray(pivot),tiles[key]);fallbacks+=fallback
            for loop,value in zip(face.loop_indices,values):uv.data[loop].uv=value
        mesh.materials.append(materials[key]);obj=bpy.data.objects.new(name,mesh);bpy.context.scene.collection.objects.link(obj);obj.location=pivot;obj['key']=key
        parts.append({'name':name,'key':key,'tile':tiles[key],'triangles':len(triangles)})
construction.hide_render=True;construction.hide_viewport=True
bpy.ops.object.select_all(action='DESELECT')
for part in parts:bpy.data.objects[part['name']].select_set(True)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/front_court_roof.blend'),compress=True)
class ExportHandedness:
    def gather_attribute_change(self,attribute,data,normalized,export_settings):
        if attribute=='TANGENT':data['data'][:,3]*=-1
import io_scene_gltf2;io_scene_gltf2.glTF2ExportUserExtension=ExportHandedness
asset=ROOT/'game/assets/props/front_court_roof.glb'
bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',use_selection=True,export_tangents=True,export_materials='NONE',export_animations=False)
bindings=[plan_path,Path(__file__),ROOT/'art/blender/scripts/prepare_front_court_roof.py',ROOT/'art/blender/scripts/fabrication_uvs.py',ROOT/'art/blender/scripts/build_orison.py']
fixture={'evidence_class':'INERT','asset_sha256':hashlib.sha256(asset.read_bytes()).hexdigest(),'parts':parts,'stocks':stocks,'contacts':contacts,
         'bearings':bearings,'beams':plan['beams'],'roof_underside':top,'girder_bottom':bottom,'uv_fallbacks':fallbacks,
         'triangles':sum(p['triangles'] for p in parts),'source_bindings':{p.relative_to(ROOT).as_posix():digest(p) for p in bindings},'retained_bindings':plan['bindings']}
for path in ['art/blender/front_court_roof_inventory.json','game/tests/fixtures/orison_front_court_roof.json']:(ROOT/path).write_text(json.dumps(fixture,indent=2)+'\n',encoding='utf-8',newline='\n')
print('FRONT COURT ROOF:',len(stocks),'closed positive stocks;',len(parts),'bounded draws;',fixture['triangles'],'triangles;',fallbacks,'UV fallbacks')
