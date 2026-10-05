"""Rebuild the original marquee and fitted entrance as editable native stocks.

The old floor exports are immutable. Call their assembly definition in isolation;
adapt only unsupported anchors, and fabricate the door around real glass fields.
"""
from pathlib import Path
import collections,hashlib,json,math,os,sys
import bpy,bmesh,numpy as np
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(Path(__file__).parent));os.environ['ORISON_DEFINITIONS_ONLY']='1'
import build_orison as original
from fabrication_uvs import chart_for_triangle
def digest(p):
    raw=p.read_bytes();return hashlib.sha256(raw if p.suffix in ['.gltf','.bin','.glb','.png','.blend'] else raw.replace(b'\r\n',b'\n')).hexdigest()
plan_path=ROOT/'art/data/front_facade/source_fit.json';plan=json.loads(plan_path.read_bytes())
for rel,h in plan['bindings'].items():assert hashlib.sha256((ROOT/rel).read_bytes().replace(b'\r\n',b'\n')).hexdigest()==h,rel
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
construction=bpy.data.collections.new('ClosedFacadeConstruction');bpy.context.scene.collection.children.link(construction)
sets=json.loads((ROOT/'game/data/runtime_material_sets.json').read_bytes())['materials']
catalog=json.loads((ROOT/'art/data/material_catalog.json').read_bytes())
materials={};tiles={};stocks=[];contacts=[];groups=collections.defaultdict(list)
mapping={'glassish':'glass','brass':'brass','metal':'metal','limestone':'limestone_b'}
for key in ['cast_iron','brass','metal','glass','plywood','soot','oak_quartered','limestone_b']:
    mat=bpy.data.materials.new('M_'+key);mat.use_nodes=True;node=mat.node_tree.nodes['Principled BSDF'];materials[key]=mat
    if key=='glass':
        node.inputs['Base Color'].default_value=(.88,.94,.91,1);node.inputs['Transmission Weight'].default_value=1;node.inputs['Roughness'].default_value=.06;node.inputs['IOR'].default_value=1.5;tiles[key]=1.;continue
    spec=sets.get(key);old=original.tex_set(key) if spec is None else None
    tiles[key]=spec['meters_per_tile'] if spec else old['mpt']
    files=[ROOT/'game/assets/building/textures'/f for f in spec['files']] if spec else [Path(old[k]) for k in ['albedo','roughness','normal']]
    node.inputs['Metallic'].default_value=spec['metallic'] if spec else catalog[original._base_mat(key)].get('metallic',0)
    uv=mat.node_tree.nodes.new('ShaderNodeTexCoord');scale=mat.node_tree.nodes.new('ShaderNodeVectorMath');scale.operation='SCALE';scale.inputs['Scale'].default_value=1/tiles[key];mat.node_tree.links.new(uv.outputs['UV'],scale.inputs[0])
    for i,target in enumerate(['Base Color','Roughness','Normal']):
        image=bpy.data.images.load(str(files[i]),check_existing=True)
        if i:image.colorspace_settings.name='Non-Color'
        image.filepath=bpy.path.relpath(str(files[i]),start=str(ROOT/'art/blender'))
        tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=image;mat.node_tree.links.new(scale.outputs['Vector'],tex.inputs['Vector'])
        if i==2:
            normal=mat.node_tree.nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.18 if key=='oak_quartered' else .35;mat.node_tree.links.new(tex.outputs['Color'],normal.inputs['Color']);mat.node_tree.links.new(normal.outputs[0],node.inputs[target])
        elif i==0 and key in ['oak_quartered','cast_iron','metal','brass']:
            tint={'oak_quartered':(.30,.22,.15),'cast_iron':(.12,.13,.12),'metal':(.24,.25,.23),'brass':(.72,.63,.46)}[key]
            linear=[v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in tint]
            mix=mat.node_tree.nodes.new('ShaderNodeMixRGB');mix.blend_type='MULTIPLY';mix.inputs[0].default_value=1;mix.inputs[2].default_value=(*linear,1.)
            mat.node_tree.links.new(tex.outputs['Color'],mix.inputs[1]);mat.node_tree.links.new(mix.outputs[0],node.inputs[target])
        else:mat.node_tree.links.new(tex.outputs['Color'],node.inputs[target])
def stock(name,buffer,key,branch='FixedFacade',grain=2):
    key=mapping.get(key,key);name=name+'_%03d'%len(stocks)
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(buffer.verts,[],buffer.faces);mesh.update()
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-8);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    assert all(e.is_manifold for e in bm.edges),name
    volume=bm.calc_volume(signed=True);assert volume>1e-14,(name,volume)
    bm.to_mesh(mesh);bm.free();obj=bpy.data.objects.new(name,mesh);construction.objects.link(obj);mesh.materials.append(materials[key]);obj['key']=key;obj['branch']=branch;obj['grain']=grain
    points=np.array([v.co[:] for v in mesh.vertices]);stocks.append({'name':name,'key':key,'branch':branch,'volume_m3':volume,'bounds':points.min(axis=0).tolist()+points.max(axis=0).tolist()});groups[(branch,key)].append(obj)
    return obj
def raw_box(name,key,low,high,branch='FixedFacade',grain=2):
    b=original.MeshBuf(name,key);b.add_box(tuple(min(a,c) for a,c in zip(low,high)),tuple(max(a,c) for a,c in zip(low,high)));return stock(name,b,key,branch,grain)
def box(name,key,lo,hi,branch='FixedFacade',grain=2):
    # Coordinates supplied in each branch's Godot frame.
    return raw_box(name,key,(lo[0],-hi[2],lo[1]),(hi[0],-lo[2],hi[1]),branch,grain)
class MarqueeFrame:
    def box(self,key,*bounds):
        lo=bounds[:3];hi=bounds[3:]
        if max(lo[2],hi[2])>4:return
        if abs(hi[0]-lo[0])<.08 and lo[2]==3.44 and hi[2]==3.52:return # former suspended clevis
        raw_box('OriginalMarquee',key,lo,hi)
    def lathe(self,key,x,y,profile,n=14,sx=1.):
        if max(p[1] for p in profile)>4:return
        b=original.MeshBuf('OriginalMarquee',key);b.add_lathe(x,y,profile,n,sx);stock('OriginalMarquee',b,key)
    def cyl(self,key,x,y,z0,z1,r0,r1=None,n=12,sx=1.):self.lathe(key,x,y,[(r0,z0),(r0 if r1 is None else r1,z1)],n,sx)
    def tube(self,key,a,b,r,n=10):
        if max(a[2],b[2])>4:return
        mesh=original.MeshBuf('OriginalMarquee',key);mesh.add_tube(a,b,r,n);stock('OriginalMarquee',mesh,key)
original.asm_entrance_marquee(MarqueeFrame(),{})
# A real host at the entrance piers replaces the unsupported historical ties.
for sx in [-1,1]:
    x=sx*1.55
    box('PierBearing','cast_iron',[x-.10,2.30,0],[x+.10,2.98,.02])
    box('LedgerUpright','cast_iron',[x-.045,2.32,.02],[x+.045,3.50,.10])
    box('CanopyReturnArm','cast_iron',[x-.045,3.20,.06],[x+.045,3.28,1.80])
    b=original.MeshBuf('CanopyKnee','cast_iron');b.add_tbox((x,-.08,2.43),(x,-1.69,3.24),.07,.07);stock('CanopyKnee',b,'cast_iron')
    for dx in [-.065,.065]:
        for y in [2.4,2.84]:
            b=original.MeshBuf('PierAnchor','metal');b.add_tube((x+dx,.035,y),(x+dx,-.035,y),.006,12);stock('PierAnchor',b,'metal')
            b=original.MeshBuf('AnchorHead','brass');b.add_tube((x+dx,-.021,y),(x+dx,-.035,y),.012,6);stock('AnchorHead',b,'brass')
            contacts.append({'owner':'ExteriorMasonry','point':[x+dx,y,0],'normal':[0,0,-1]})
# Same wide limestone entrance vocabulary; the saddle retains the level walk.
for row in plan['original_entrance']:
    if row['id'] in ['entry_marquee','entry_door_step']:continue
    x0,y0,x1,y1=row['rect'];z=row['z0'];h=row['h']
    if row['id']=='entry_door_step':z=-h;h+=.01
    raw_box(row['id'],'limestone',(x0,y0+10,z),(x1,y1+10,z+h))
# Fitted quartered-oak linings stay outside the semantic 1.10 m opening.
w=plan['door']['width'];height=plan['door']['height']
for sx in [-1,1]:
    x=sx*(w/2+.05);box('OakJamb','oak_quartered',[x-.05,0,-.35],[x+.05,height+.12,.025])
box('OakHead','oak_quartered',[-w/2-.10,height,-.35],[w/2+.10,height+.12,.025],grain=0)
box('SteppedOakHead','oak_quartered',[-w/2-.17,height+.12,0],[w/2+.17,height+.19,.055],grain=0)
# Native door carcass: real openings around two wired glass panes.
branch='EntryLeaf';th=.032
for a,b in [(0,.12),(w-.12,w)]:box('LeafStile','oak_quartered',[a,.01,-th],[b,height-.01,th],branch)
for a,b in [(.01,.17),(.70,.80),(1.22,1.30),(1.92,height-.01)]:box('LeafRail','oak_quartered',[.12,a,-th],[w-.12,b,th],branch,grain=0)
for a,b in [(.17,.70),(.80,1.22),(1.30,1.92)]:
    box('LeafMuntin','oak_quartered',[w/2-.035,a,-th],[w/2+.035,b,th],branch)
for a,b in [(.12,w/2-.035),(w/2+.035,w-.12)]:
    for c,d in [(.17,.70),(.80,1.22)]:
        box('RaisedLeafPanel','oak_quartered',[a,c,-.024],[b,d,.024],branch)
        for face in [-1,1]:
            z=face*.029
            for x in [a+.012,b-.012]:box('PanelBolection','oak_quartered',[x-.009,c,z-.008],[x+.009,d,z+.008],branch)
            for y in [c+.012,d-.012]:box('PanelBolection','oak_quartered',[a+.021,y-.009,z-.008],[b-.021,y+.009,z+.008],branch,grain=0)
    box('WiredPane','glass',[a,1.30,-.006],[b,1.92,.006],branch)
    for x in np.linspace(a,b,6)[1:-1]:box('WireGlassVertical','cast_iron',[x-.0015,1.30,-.002],[x+.0015,1.92,.002],branch)
    for y in np.linspace(1.30,1.92,10)[1:-1]:box('WireGlassHorizontal','cast_iron',[a,y-.0015,-.002],[b,y+.0015,.002],branch,grain=0)
    for face in [-1,1]:
        z=face*.014
        for x in [a+.01,b-.01]:box('PaneBead','oak_quartered',[x-.01,1.30,z-.01],[x+.01,1.92,z+.01],branch)
        for y in [1.31,1.91]:box('PaneBead','oak_quartered',[a+.02,y-.01,z-.01],[b-.02,y+.01,z+.01],branch,grain=0)
# Source-owned forward wall dress. It never fills an aperture or invents rooms.
front=plan['facade_root_z']
for i,row in enumerate(plan['front_edges']):
    lo,hi=-row['x1'],-row['x0'];z=front-row['front_z']
    y0,y1=(.0,.45) if row['level']=='F01' else (row['y']+.03,row['y']+.15)
    box('WaterTable' if row['level']=='F01' else 'StringCourse','limestone',[lo,y0,z],[hi,y1,z+.045],grain=0)
for row in plan['front_windows']:
    x=-row['center'][0];z=front-row['front_z'];bottom=row['y']+row['sill'];top=bottom+row['height'];half=row['width']/2
    box('WindowStoneSill','limestone',[x-half-.14,bottom-.15,z],[x+half+.14,bottom-.07,z+.10],grain=0)
    box('WindowStoneHead','limestone',[x-half-.14,top+.07,z],[x+half+.14,top+.15,z+.055],grain=0)
    for side in [-1,1]:
        lo,hi=(x-half-.14,x-half-.07) if side<0 else (x+half+.07,x+half+.14)
        box('WindowStoneJamb','limestone',[lo,bottom-.07,z],[hi,top+.07,z+.04])
# Separate bounded draws, preserving closed counterparts for native inspection.
parts=[];fallbacks=0
for (branch,key),objects in sorted(groups.items()):
    buckets=collections.defaultdict(list)
    for obj in objects:
        bm=bmesh.new();bm.from_mesh(obj.data);bmesh.ops.triangulate(bm,faces=list(bm.faces))
        for axis in range(3):
            values=[v.co[axis] for v in bm.verts]
            for k in range(math.ceil(min(values)/4),math.ceil(max(values)/4)):
                n=Vector(tuple(int(j==axis) for j in range(3)));bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),plane_co=n*(4*k),plane_no=n,dist=1e-8)
        bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.normal_update()
        for face in bm.faces:
            p=[v.co.copy() for v in face.verts];center=sum(p,Vector())/3
            cell=[]
            for axis,v in enumerate(center):
                if max(q[axis] for q in p)-min(q[axis] for q in p)<1e-8 and abs(v/4-round(v/4))<1e-8:v-=math.copysign(1e-7,face.normal[axis])
                cell.append(math.floor(v/4))
            buckets[tuple(cell)].append((p,int(obj['grain'])))
        bm.free()
    for cell,triangles in sorted(buckets.items()):
        pivot=Vector([4*(c+.5) for c in cell]);name=branch+'__'+key+'__'+'_'.join(map(str,cell))
        verts=[tuple(p-pivot) for t,g in triangles for p in t];mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],[(i,i+1,i+2) for i in range(0,len(verts),3)]);mesh.update();uv=mesh.uv_layers.new(name='Metres');uv.active_render=True
        for face,(source,grain) in zip(mesh.polygons,triangles):
            p=np.array([mesh.vertices[i].co[:] for i in face.vertices]);origin=np.array(pivot)
            # Rotate horizontal timber charts so texture V follows each rail.
            order=[2,1,0] if grain==0 else [0,1,2]
            _,_,values,fallback=chart_for_triangle(p[:,order],origin[order],tiles[key]);fallbacks+=fallback
            for loop,value in zip(face.loop_indices,values):uv.data[loop].uv=value
        mesh.materials.append(materials[key]);obj=bpy.data.objects.new(name,mesh);bpy.context.scene.collection.objects.link(obj);obj.location=pivot;obj['branch']=branch;obj['key']=key
        parts.append({'name':name,'key':key,'branch':branch,'triangles':len(triangles),'tile':tiles[key]})
construction.hide_render=True;construction.hide_viewport=True
# Branch roots make the single movable assembly separable without new actors.
parents={}
for branch in ['FixedFacade','EntryLeaf']:
    parent=bpy.data.objects.new(branch,None);bpy.context.scene.collection.objects.link(parent);parents[branch]=parent
bpy.ops.object.select_all(action='DESELECT')
for part in parts:
    obj=bpy.data.objects[part['name']];obj.parent=parents[part['branch']];obj.select_set(True)
for parent in parents.values():parent.select_set(True)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/front_facade.blend'),compress=True)
class ExportHandedness:
    def gather_attribute_change(self,attribute,data,normalized,export_settings):
        if attribute=='TANGENT':data['data'][:,3]*=-1
import io_scene_gltf2;io_scene_gltf2.glTF2ExportUserExtension=ExportHandedness
asset=ROOT/'game/assets/props/front_facade.glb';bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',use_selection=True,export_tangents=True,export_materials='NONE')
bindings=[plan_path,Path(__file__),ROOT/'art/blender/scripts/prepare_front_facade.py',ROOT/'art/blender/scripts/fabrication_uvs.py']
fixture={'evidence_class':'INERT','asset_sha256':digest(asset),'parts':parts,'stocks':stocks,'contacts':contacts,'door':plan['door'],'facade_root_z':front,'blade_root_position':plan['blade_root_position'],'source_bindings':{p.relative_to(ROOT).as_posix():digest(p) for p in bindings},'retained_bindings':plan['bindings'],'uv_fallbacks':fallbacks,'triangles':sum(p['triangles'] for p in parts)}
for rel in ['art/blender/front_facade_inventory.json','game/tests/fixtures/orison_front_facade.json']:(ROOT/rel).write_text(json.dumps(fixture,indent=2)+'\n',newline='\n')
print('FRONT FACADE:',len(stocks),'closed positive stocks;',len(parts),'bounded draws;',fixture['triangles'],'triangles;',fallbacks,'local UV fallbacks')
