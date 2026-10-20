"""Fitted hollow metal sink services; coordinates specified in Godot metres."""
from pathlib import Path
import ast,collections,hashlib,json,math,os,sys
import bpy,bmesh,numpy as np
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(Path(__file__).parent))
from fabrication_uvs import chart_for_triangle
from fabrication_grain import stock_grain_frame,stock_grain_chart
from fabrication_normals import stock_corner_normals
from fabrication_chart_batch import triangle_charts,revolved_charts
from check_exported_tangents import validate
OUT=Path(os.environ.get('KITCHEN_PLUMBING_OUT',str(ROOT)))
for directory in ['art/blender','game/assets/props','game/data/orison_v2','game/tests/fixtures']:(OUT/directory).mkdir(parents=True,exist_ok=True)
plan_path=ROOT/'art/data/kitchen_plumbing/source_plan.json';plan=json.loads(plan_path.read_text())
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
closed=bpy.data.collections.new('ClosedConstruction');bpy.context.scene.collection.children.link(closed);closed.hide_render=True
retained=bpy.data.collections.new('RetainedSourceBoxes');bpy.context.scene.collection.children.link(retained);retained.hide_render=True
materials={};pieces=collections.defaultdict(list);stock_checks=[];contacts=[]
catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials']
sets={key:catalog[key] for key in ['nickel_plated','door_brass','rubber_aged','iron_neutral']}
for key,spec in sets.items():
    mat=bpy.data.materials.new(key);mat.use_nodes=True;materials[key]=mat
    shader=mat.node_tree.nodes['Principled BSDF'];shader.inputs['Metallic'].default_value=spec['metallic']
    uv=mat.node_tree.nodes.new('ShaderNodeTexCoord');scale=mat.node_tree.nodes.new('ShaderNodeVectorMath');scale.operation='SCALE';scale.inputs['Scale'].default_value=1/spec['meters_per_tile'];mat.node_tree.links.new(uv.outputs['UV'],scale.inputs[0])
    for index,target in [(0,'Base Color'),(1,'Roughness'),(2,'Normal')]:
        image=bpy.data.images.load(str(ROOT/'game/assets/building/textures'/spec['files'][index]),check_existing=True);image.filepath=bpy.path.relpath(image.filepath,start=str(OUT/'art/blender'))
        if index:image.colorspace_settings.name='Non-Color'
        node=mat.node_tree.nodes.new('ShaderNodeTexImage');node.image=image;mat.node_tree.links.new(scale.outputs['Vector'],node.inputs['Vector'])
        if index==2:
            normal=mat.node_tree.nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.18;mat.node_tree.links.new(node.outputs['Color'],normal.inputs['Color']);mat.node_tree.links.new(normal.outputs[0],shader.inputs[target])
        else:mat.node_tree.links.new(node.outputs['Color'],shader.inputs[target])
shared=Path(__file__).with_name('build_domestic_storage.py');tree=ast.parse(shared.read_text())
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef)],type_ignores=[]),str(shared),'exec'))
def p(value):return Vector((value[0],-value[2],value[1]))
def pipe(name,path,outer,inner,identity,key,n=32,hexagonal=False):
    """Continuous annular shell, including inner wall and open annular ends."""
    points=[p(q) for q in path];vertices=[]
    for i,point in enumerate(points):
        tangent=(points[min(i+1,len(points)-1)]-points[max(0,i-1)]).normalized()
        seed=Vector((1,0,0));u=(seed-tangent*seed.dot(tangent)).normalized();v=tangent.cross(u)
        for layer in [0,1]:
            radius=(outer[i] if isinstance(outer,list) else outer) if layer==0 else inner
            for j in range(n):
                angle=j*math.tau/n;r=radius
                if hexagonal and layer==0:r*=math.cos(math.pi/6)/math.cos((angle+math.pi/6)%(math.pi/3)-math.pi/6)
                vertices.append(point+r*(u*math.cos(angle)+v*math.sin(angle)))
    faces=[]
    for i in range(len(points)-1):
        for layer in [0,1]:
            for j in range(n):
                a=i*n*2+layer*n+j;b=i*n*2+layer*n+(j+1)%n
                faces.append((a,b,b+n*2,a+n*2))
    for i in [0,len(points)-1]:
        for j in range(n):
            a=i*n*2+j;b=i*n*2+(j+1)%n;faces.append((a,b,b+n,a+n))
    return solid(name,vertices,faces,identity,key)
def sleeve(name,a,b,r,bore,identity,key,hexagonal=False):
    a=Vector(a);b=Vector(b);axis=(b-a).normalized();edge=min(.0015,(b-a).length*.2)
    return pipe(name,[a,a+axis*edge,b-axis*edge,b],[r-.001,r,r,r-.001],bore,identity,key,48,hexagonal)
assemblies=[];profiles=[]
for template in plan['templates']:
    identity=template['id'];top=template['rim_y'];wall=template['wall_z'];riser=template['riser_z'];compact=template['compact']
    assemblies.append({'id':identity,'body':{'rect':[0,0,0,0],'z0':0.},'cell':'kitchen'})
    offset=top-.9;tail_top=top-.148
    waste=[(0,tail_top,.01),(0,.555+offset,.01)]
    waste.extend((0,.555+offset-.075*math.sin(a),.085-.075*math.cos(a)) for a in np.linspace(0,math.pi,33)[1:])
    waste.append((0,.600+offset,.16))
    waste.extend((0,.600+offset+.04*math.sin(a),.20-.04*math.cos(a)) for a in np.linspace(0,math.pi/2,17)[1:])
    waste.append((0,.640+offset,wall))
    pipe(identity+'_Waste',waste,.024,.0215,identity,'nickel_plated')
    sleeve(identity+'_DrainCoupling',(0,top-.167,.01),(0,top-.143,.01),.034,.0238,identity,'nickel_plated',True)
    sleeve(identity+'_TrapUnion',(0,.583+offset,.16),(0,.605+offset,.16),.033,.0238,identity,'nickel_plated',True)
    sleeve(identity+'_WasteWallSeat',(0,.640+offset,wall-.009),(0,.640+offset,wall),.050,.0242,identity,'nickel_plated')
    profiles.append({'template':identity,'kind':'waste','points':[list(q) for q in waste],'outer':.024,'inner':.0215})
    for index,x in enumerate([-.095,.095]):
        elbow=min(.025,(wall-riser)*.8)
        assert elbow>.009,template
        supply=[(x,.22,wall),(x,.22,riser+elbow)]
        supply.extend((x,.22+elbow-elbow*math.cos(a),riser+elbow-elbow*math.sin(a)) for a in np.linspace(0,math.pi/2,13)[1:])
        supply.append((x,top+.085,riser))
        supply.extend((x,top+.085+.025*math.sin(a),riser-.025+.025*math.cos(a)) for a in np.linspace(0,math.pi/2,13)[1:])
        rear=(.17 if compact else .21)
        supply.append((x,top+.11,rear))
        pipe(identity+'_Supply'+str(index),supply,.009,.006,identity,'door_brass',24)
        sleeve(identity+'_SupplyWallSeat'+str(index),(x,.22,wall-.006),(x,.22,wall),.027,.0092,identity,'nickel_plated')
        sleeve(identity+'_ValveBody'+str(index),(x,.322,riser),(x,.368,riser),.017,.0085,identity,'door_brass')
        for y in [.316,.368]:sleeve(identity+'_SupplyUnion'+str((index,y)),(x,y,riser),(x,y+.010,riser),.016,.0088,identity,'door_brass',True)
        rod(identity+'_Spindle'+str(index),p((x,.345,riser-.058)),p((x,.345,riser)),.005,identity,'door_brass',32)
        sleeve(identity+'_PackingGland'+str(index),(x,.345,riser-.042),(x,.345,riser-.016),.012,.0048,identity,'door_brass',True)
        sleeve(identity+'_StemPacking'+str(index),(x,.345,riser-.044),(x,.345,riser-.040),.008,.0048,identity,'rubber_aged')
        sleeve(identity+'_FaucetUnion'+str(index),(x,top+.11,rear),(x,top+.11,rear+.015),.016,.0088,identity,'nickel_plated',True)
        profiles.append({'template':identity,'kind':'supply','index':index,'points':[list(q) for q in supply],'outer':.009,'inner':.006})
# One shared, bored handwheel mesh rotates on a retained brass spindle.
identity='StopWheel';assemblies.append({'id':identity,'body':{'rect':[0,0,0,0],'z0':0.},'cell':'kitchen'})
n=64;m=12;vertices=[]
for i in range(n):
    a=i*math.tau/n
    vertices.extend(p(((.026+.004*math.cos(j*math.tau/m))*math.cos(a),(.026+.004*math.cos(j*math.tau/m))*math.sin(a),.004*math.sin(j*math.tau/m))) for j in range(m))
solid('StopWheel_Rim',vertices,[(i*m+j,((i+1)%n)*m+j,((i+1)%n)*m+(j+1)%m,i*m+(j+1)%m) for i in range(n) for j in range(m)],identity,'iron_neutral')
for i in range(4):
    a=i*math.tau/4
    rod('StopWheel_Spoke'+str(i),p((.006*math.cos(a),.006*math.sin(a),0)),p((.026*math.cos(a),.026*math.sin(a),0)),.0032,identity,'iron_neutral',24)
sleeve('StopWheel_Hub',(0,0,-.008),(0,0,.010),.009,.0048,identity,'door_brass',True)
for row in stock_checks:
    bm=bmesh.new();bm.from_mesh(bpy.data.objects[row['name']].data)
    assert all(e.is_manifold for e in bm.edges),row['name'];assert bm.calc_volume(signed=True)>0,row['name'];bm.free()
source=shared.read_text();start=source.index('draws=[];inventory=[];fallbacks=0;total_triangles=0');stop=source.index('bpy.ops.wm.save_as_mainfile',start)
exec(compile(source[start:stop],str(shared)+'[metre-charts]','exec'))
for obj in draws:obj.hide_render=False
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'art/blender/kitchen_plumbing.blend'),compress=True)
bpy.ops.object.select_all(action='DESELECT')
for obj in draws:obj.select_set(True)
export_class=next(n for n in tree.body if isinstance(n,ast.ClassDef) and n.name=='ExportUVHandedness');exec(compile(ast.Module(body=[export_class],type_ignores=[]),str(shared),'exec'))
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension=ExportUVHandedness
asset=OUT/'game/assets/props/kitchen_plumbing.glb'
bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',use_selection=True,export_yup=True,export_tangents=True,export_attributes=True,export_materials='NONE')
runtime={'schema_version':1,'asset':'res://assets/props/kitchen_plumbing.glb','asset_sha256':digest(asset),'templates':plan['templates'],'installations':plan['installations'],'parts':[{k:v for k,v in row.items() if k not in ['cell','triangles']} for row in inventory]}
(OUT/'game/data/orison_v2/kitchen_plumbing.json').write_text(json.dumps(runtime,indent=2)+'\n',encoding='utf-8',newline='\n')
bindings=[Path(__file__),shared,plan_path,ROOT/'game/data/runtime_material_sets.json',ROOT/'game/assets/props/kitchen_basins.glb',ROOT/'game/assets/props/kitchen_faucet.glb']
bindings.extend(ROOT/'art/blender/scripts'/name for name in ['fabrication_uvs.py','fabrication_grain.py','fabrication_normals.py','fabrication_chart_batch.py'])
for spec in sets.values():bindings.extend(ROOT/'game/assets/building/textures'/name for name in spec['files'] if name)
report={'evidence_class':'INERT','scope':'Closed native plumbing stock, open pipe bores and metre UV/tangent export; not installed runtime acceptance.','asset_sha256':digest(asset),'export':validate(asset),'closed_stocks':stock_checks,'parts':inventory,'profiles':profiles,'precision_chart_fallbacks':fallbacks,'source_bindings':{p.relative_to(ROOT).as_posix():digest(p) for p in bindings}}
for name in ['art/blender/kitchen_plumbing_construction.json','game/tests/fixtures/orison_kitchen_plumbing.json']:(OUT/name).write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n')
print('KITCHEN PLUMBING NATIVE:',len(plan['installations']),'sinks;',len(plan['templates']),'templates;',len(stock_checks),'closed stocks;',report['export'])
