"""Period worktables and loose preparation tools, using registered metre stock."""
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
OUT=Path(os.environ.get('KITCHEN_PREP_OUT',str(ROOT)))
for directory in ['art/blender','game/assets/props','game/data/orison_v2','game/tests/fixtures']:(OUT/directory).mkdir(parents=True,exist_ok=True)
plan_path=ROOT/'art/data/kitchen_prep/source_plan.json'
plan=json.loads(plan_path.read_text())
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
closed=bpy.data.collections.new('ClosedConstruction');bpy.context.scene.collection.children.link(closed);closed.hide_render=True
retained=bpy.data.collections.new('RetainedSourceBoxes');bpy.context.scene.collection.children.link(retained);retained.hide_render=True
materials={};pieces=collections.defaultdict(list);stock_checks=[];contacts=[]
catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials']
sets={key:catalog[key] for key in ['oak_work_surface','door_paint','enamel_appliance','iron_blackened']}
for key,spec in sets.items():
    mat=bpy.data.materials.new(key);mat.use_nodes=True;materials[key]=mat
    shader=mat.node_tree.nodes['Principled BSDF'];shader.inputs['Metallic'].default_value=spec['metallic']
    uv=mat.node_tree.nodes.new('ShaderNodeTexCoord');scale=mat.node_tree.nodes.new('ShaderNodeVectorMath');scale.operation='SCALE';scale.inputs['Scale'].default_value=1/spec['meters_per_tile'];mat.node_tree.links.new(uv.outputs['UV'],scale.inputs[0])
    for index,target in [(0,'Base Color'),(1,'Roughness'),(2,'Normal')]:
        image=bpy.data.images.load(str(ROOT/'game/assets/building/textures'/spec['files'][index]),check_existing=True)
        image.filepath=bpy.path.relpath(image.filepath,start=str(OUT/'art/blender'))
        if index:image.colorspace_settings.name='Non-Color'
        node=mat.node_tree.nodes.new('ShaderNodeTexImage');node.image=image;mat.node_tree.links.new(scale.outputs['Vector'],node.inputs['Vector'])
        if index==2:
            normal=mat.node_tree.nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.35;mat.node_tree.links.new(node.outputs['Color'],normal.inputs['Color']);mat.node_tree.links.new(normal.outputs[0],shader.inputs[target])
        else:mat.node_tree.links.new(node.outputs['Color'],shader.inputs[target])
# Proven closed stock constructors and export derivatives, without executing
# another family's build, source-plan edits or publication.
shared=Path(__file__).with_name('build_domestic_storage.py');tree=ast.parse(shared.read_text())
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef)],type_ignores=[]),str(shared),'exec'))
assemblies=[]
for template in plan['templates']:
    identity=template['id'];w=template['width'];d=template['depth'];style=template['style']
    assemblies.append({'id':identity,'body':{'rect':[0,0,0,0],'z0':0.},'cell':'kitchen'})
    timber='door_paint' if style=='enamel' else 'oak_work_surface'
    for x in [-w/2+.055,w/2-.055]:
        for y in [-d/2+.055,d/2-.055]:
            if style=='enamel':
                vessel(identity+'_TurnedLeg'+str((x,y)),x,y,0,[(0,0),(.019,0),(.024,.012),(.021,.035),(.019,.22),(.026,.24),(.026,.26),(.023,.28),(.023,.76),(.030,.78),(.030,.866),(0,.866)],identity,timber)
            else:box(identity+'_Leg'+str((x,y)),(x-.022,y-.022,0),(x+.022,y+.022,.868),identity,timber,.002)
    for y in [-d/2+.055,d/2-.055]:
        box(identity+'_LongApron'+str(y),(-w/2+.055,y-.012,.770),(w/2-.055,y+.012,.869),identity,timber,.0015)
        for x in [-w/2+.11,w/2-.11]:rod(identity+'_Peg'+str((x,y)),(x,y-.015,.815),(x,y+.015,.815),.004,identity,'oak_work_surface',n=24)
    for x in [-w/2+.055,w/2-.055]:box(identity+'_EndApron'+str(x),(x-.012,-d/2+.055,.770),(x+.012,d/2-.055,.869),identity,timber,.0015)
    if style=='enamel':
        box(identity+'_Substrate',(-w/2,-d/2,.868),(w/2,d/2,.896),identity,'oak_work_surface',.004)
        box(identity+'_EnamelTop',(-w/2-.004,-d/2-.004,.896),(w/2+.004,d/2+.004,.900),identity,'enamel_appliance',.0014)
        for y in [-d/2,d/2]:box(identity+'_RolledEdge'+str(y),(-w/2-.004,y-.003,.884),(w/2+.004,y+.003,.900),identity,'enamel_appliance',.0015)
        for x in [-w/2,w/2]:box(identity+'_RolledEnd'+str(x),(x-.003,-d/2,.884),(x+.003,d/2,.900),identity,'enamel_appliance',.0015)
    else:
        cleat=.045;count=5
        for i in range(count):
            y0=-d/2+i*d/count;y1=-d/2+(i+1)*d/count
            box(identity+'_TopPlank'+str(i),(-w/2+cleat,y0+.0002,.868),(w/2-cleat,y1-.0002,.900),identity,timber,.0015)
        for x in [-w/2,w/2-cleat]:box(identity+'_BreadboardEnd'+str(x),(x,-d/2,.868),(x+cleat,d/2,.900),identity,timber,.0015)
        if style=='patched':
            for x in [-w/2+.09,w/2-.09]:
                box(identity+'_RepairStrap'+str(x),(x-.018,d/2-.068,.772),(x+.018,d/2-.065,.863),identity,'iron_blackened',.0004)
                for z in [.785,.848]:rod(identity+'_Rivet'+str((x,z)),(x,d/2-.065,z),(x,d/2-.061,z),.004,identity,'iron_blackened',n=24)
    for x in [-w/2+.055,w/2-.055]:box(identity+'_LowStretcher'+str(x),(x-.014,-d/2+.055,.20),(x+.014,d/2-.055,.24),identity,timber,.0015)

tools=['Breadboard','RollingPin','MixingBowl','SinkBridge']
for identity in tools:assemblies.append({'id':identity,'body':{'rect':[0,0,0,0],'z0':0.},'cell':'kitchen'})
for i in range(4):box('SinkBridge_Plank'+str(i),(-.34,-.17+i*.085,0),(.34,-.17+(i+1)*.085-.0004,.026),'SinkBridge','oak_work_surface',.0012)
for x in [-.267,.252]:box('SinkBridge_Stop'+str(x),(x,-.13,-.012),(x+.015,.13,0),'SinkBridge','oak_work_surface',.0007)
vessel('MixingBowl',0,0,0,[(0,0),(.063,0),(.067,.004),(.070,.017),(.104,.073),(.113,.098),(.115,.102),(.114,.106),(.109,.107),(.106,.102),(.100,.077),(.065,.022),(.058,.008),(0,.008)],'MixingBowl','enamel_appliance')
box('Breadboard_Main',(-.18,-.145,.003),(.18,.145,.023),'Breadboard','oak_work_surface',.002)
for x in [-.215,.18]:box('Breadboard_End'+str(x),(x,-.145,0),(x+.035,.145,.023),'Breadboard','oak_work_surface',.0015)
along_x('RollingPin_Barrel',0,0,0,[(0,-.155),(.024,-.155),(.027,-.150),(.027,.150),(.024,.155),(0,.155)],'RollingPin','oak_work_surface')
for sign in [-1,1]:
    profile=[(0,.155),(.009,.155),(.012,.164),(.012,.210),(.009,.220),(0,.220)]
    profile=[(radius,position*sign) for radius,position in profile]
    along_x('RollingPin_Handle'+str(sign),0,0,0,profile,'RollingPin','oak_work_surface')
# The visible tools are combined by stock, but each original convex solid
# remains a separate physical hull; no handle recess is bridged by one hull.
bpy.context.view_layer.update()
hulls={}
for identity in tools:
    hulls[identity]=[]
    for obj,key in pieces[identity]:
        points=[obj.matrix_world@v.co for v in obj.data.vertices]
        if identity!='MixingBowl':hulls[identity].append([[p.x,p.z,-p.y] for p in points])
        else:
            # Hollow bowl uses angular wall segments, leaving the real mouth
            # and cavity available to other rigid utensils rather than capping it.
            for k in range(24):
                angles=[k*math.tau/24,(k+1)*math.tau/24]
                points=[Vector((radius*math.cos(a),radius*math.sin(a),z)) for a in angles for radius,z in [(.06,.004),(.07,.02),(.115,.106),(.106,.106),(.062,.02)]]
                hulls[identity].append([[p.x,p.z,-p.y] for p in points])
            hulls[identity].append([[x,z,-y] for x in [-.04,.04] for y in [-.04,.04] for z in [0,.008]])
# Re-measure final bevelled source solids, not the pre-modifier primitive.
for row in stock_checks:
    mesh=bpy.data.objects[row['name']].data;bm=bmesh.new();bm.from_mesh(mesh)
    assert all(e.is_manifold for e in bm.edges),row['name']
    row['volume_m3']=bm.calc_volume(signed=True);assert row['volume_m3']>0,row['name'];bm.free()
# Reuse the owning chart/basis pipeline with these explicit assemblies.
source=shared.read_text();start=source.index('draws=[];inventory=[];fallbacks=0;total_triangles=0')
stop=source.index('bpy.ops.wm.save_as_mainfile',start)
exec(compile(source[start:stop],str(shared)+'[metre-charts]','exec'))
for obj in draws:obj.hide_render=False
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'art/blender/kitchen_prep_stations.blend'),compress=True)
bpy.ops.object.select_all(action='DESELECT')
for obj in draws:obj.select_set(True)
export_class=next(n for n in tree.body if isinstance(n,ast.ClassDef) and n.name=='ExportUVHandedness')
exec(compile(ast.Module(body=[export_class],type_ignores=[]),str(shared),'exec'))
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension=ExportUVHandedness
asset=OUT/'game/assets/props/kitchen_prep_stations.glb'
bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',use_selection=True,export_yup=True,export_tangents=True,export_attributes=True,export_materials='NONE')
runtime={'schema_version':1,'asset':'res://assets/props/kitchen_prep_stations.glb','asset_sha256':digest(asset),'templates':[{k:v for k,v in row.items() if k!='style'} for row in plan['templates']],'stations':[{k:v for k,v in row.items() if k not in ['resident','interpretation','approach','space']} for row in plan['stations']],'parts':[{k:v for k,v in row.items() if k not in ['cell','triangles']} for row in inventory],'tool_hulls':hulls}
(OUT/'game/data/orison_v2/kitchen_prep_stations.json').write_text(json.dumps(runtime,indent=2)+'\n',newline='\n')
bindings=[Path(__file__),shared,plan_path,ROOT/'game/data/runtime_material_sets.json',ROOT/'art/blender/scripts/fabrication_uvs.py',ROOT/'art/blender/scripts/fabrication_grain.py',ROOT/'art/blender/scripts/fabrication_normals.py',ROOT/'art/blender/scripts/fabrication_chart_batch.py',ROOT/'game/assets/props/kitchen_prep_stations.glb.import']
for spec in sets.values():bindings.extend(ROOT/'game/assets/building/textures'/name for name in spec['files'] if name)
report={'evidence_class':'INERT','asset_sha256':digest(asset),'export':validate(asset),'closed_stocks':stock_checks,'parts':inventory,'precision_chart_fallbacks':fallbacks,'runtime':runtime,'source_bindings':{p.relative_to(ROOT).as_posix():digest(p) for p in bindings}}
for name in ['art/blender/kitchen_prep_stations_construction.json','game/tests/fixtures/orison_kitchen_prep_stations.json']:(OUT/name).write_text(json.dumps(report,indent=2)+'\n',newline='\n')
print('KITCHEN PREP NATIVE:',len(plan['stations']),'stations;',len(plan['pending_spaces']),'pending tight rooms;',len(draws),'parts;',report['export'])
