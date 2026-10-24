"""Native replacement for the existing V2 caption-calibrator box.
Uses the established fixed-instrument stock and exact tangent exporter helpers.
No case outcome, material recipe or player authority is authored here.
"""
from pathlib import Path
import ast, collections, hashlib, json, math, sys
import bpy, bmesh, numpy as np
from mathutils import Vector
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
sys.path.insert(0,str(ROOT/'art/blender/scripts'))
from fabrication_uvs import chart_for_triangle
from fabrication_normals import stock_corner_normals
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version=0
closed=bpy.data.collections.new('ClosedConstruction');bpy.context.scene.collection.children.link(closed);closed.hide_render=True
pieces=collections.defaultdict(list);stock_checks=[];materials={}
catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text(encoding='utf-8'))['materials']
keys=['bakelite','brass_dull','metal']
for key in keys:
 spec=catalog[key];mat=bpy.data.materials.new(key);mat.use_nodes=True;materials[key]=mat
 nodes=mat.node_tree.nodes;links=mat.node_tree.links;shader=nodes.get('Principled BSDF');shader.inputs['Metallic'].default_value=spec['metallic']
 coord=nodes.new('ShaderNodeTexCoord');scale=nodes.new('ShaderNodeVectorMath');scale.operation='SCALE';scale.inputs['Scale'].default_value=1/spec['meters_per_tile'];links.new(coord.outputs['UV'],scale.inputs[0])
 for index,target in enumerate(['Base Color','Roughness','Normal']):
  tex=nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(ROOT/'game/assets/building/textures'/spec['files'][index]),check_existing=True);tex.image.filepath=bpy.path.relpath(tex.image.filepath,start=str(ROOT/'art/blender'));tex.image.colorspace_settings.name='sRGB' if index==0 else 'Non-Color';links.new(scale.outputs['Vector'],tex.inputs['Vector'])
  if index==2:
   normal=nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=1. if key=='bakelite' else .35;links.new(tex.outputs['Color'],normal.inputs['Color']);links.new(normal.outputs['Normal'],shader.inputs[target])
  elif index==1:
   multiplier=nodes.new('ShaderNodeMath');multiplier.operation='MULTIPLY';multiplier.inputs[1].default_value=spec['roughness_multiplier'];links.new(tex.outputs['Color'],multiplier.inputs[0]);links.new(multiplier.outputs[0],shader.inputs[target])
  else:links.new(tex.outputs['Color'],shader.inputs[target])
# Reuse native closed-stock manufacture and the normal-map handedness exporter.
helper=ROOT/'art/blender/scripts/build_signal_terminal.py';tree=ast.parse(helper.read_text(encoding='utf-8'))
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in ['solid','box'] or isinstance(n,ast.ClassDef) and n.name=='ExportUVHandedness'],type_ignores=[]),str(helper),'exec'))
def stock(name,low,high,key='bakelite',component='Fixed',bevel=.0006):
 return box(component+'_'+name,low,high,component,key,bevel)
# Native Z is installed vertical; native Y is negative Godot Z.
stock('Base',(-.24,-.13,0),(.24,.13,.012),bevel=.002)
for x in [-.24,.228]:stock('Side'+str(x),(x,-.13,.012),(x+.012,.13,.408),bevel=.0015)
for y in [-.13,.118]:stock('End'+str(y),(-.228,y,.012),(.228,y+.012,.408),bevel=.0015)
# Top stock leaves a real square opening; the plunger does not enter a solid lid.
outer=[(-.24,-.13),(.24,-.13),(.24,.13),(-.24,.13)];inner=[(-.026,-.026),(.026,-.026),(.026,.026),(-.026,.026)]
vertices=[(x,y,z) for z in [.408,.42] for ring in [outer,inner] for x,y in ring];faces=[]
for i in range(4):
 j=(i+1)%4;faces.extend([(i,4+i,4+j,j),(8+i,8+j,12+j,12+i),(i,j,8+j,8+i),(4+i,12+i,12+j,4+j)])
deck=solid('Fixed_ContinuousDeck',vertices,faces,'Fixed','bakelite');bpy.context.view_layer.objects.active=deck;mod=deck.modifiers.new('Worked continuous lid edge','BEVEL');mod.width=.0005;mod.segments=3;bpy.ops.object.modifier_apply(modifier=mod.name)
for x0,x1 in [(-.032,-.026),(.026,.032)]:stock('GuideLipSide'+str(x0),(x0,-.032,.42),(x1,.032,.432),'brass_dull',bevel=.0004)
for y0,y1 in [(-.032,-.026),(.026,.032)]:stock('GuideLipEnd'+str(y0),(-.026,y0,.42),(.026,y1,.432),'brass_dull',bevel=.0004)
for x0,x1 in [(-.026,-.013),(.013,.026)]:stock('GuideSide'+str(x0),(x0,-.026,.379),(x1,.026,.408),'brass_dull',bevel=.0002)
for y0,y1 in [(-.026,-.013),(.013,.026)]:stock('GuideEnd'+str(y0),(-.013,y0,.379),(.013,y1,.408),'brass_dull',bevel=.0002)
for x0,x1 in [(-.013,-.010),(.010,.013)]:stock('TravelStopSide'+str(x0),(x0,-.013,.379),(x1,.013,.385),'brass_dull',bevel=.0001)
for y0,y1 in [(-.013,-.010),(.010,.013)]:stock('TravelStopEnd'+str(y0),(-.010,y0,.379),(.010,y1,.385),'brass_dull',bevel=.0001)
stock('LowerShoulder',(-.012,-.012,.389),(.012,.012,.395),'brass_dull','Plunger',.00015)
stock('Stem',(-.009,-.009,.395),(.009,.009,.437),'brass_dull','Plunger',.0002)
stock('Cap',(-.023,-.023,.437),(.023,.023,.449),'bakelite','Plunger',.001)
# Restrained inset front plate and seated split screw heads. No baked lettering.
stock('FacePlate',(-.16,-.133,.13),(.16,-.130,.29),'metal',bevel=.0006)
for x in [-.145,.145]:
 for z in [.145,.275]:
  for dx in [-.0015,.0015]:stock('Screw'+str((x,z,dx)),(x+dx-.001,-.134,z-.003),(x+dx+.001,-.133,z+.003),'brass_dull',bevel=.00015)
for obj,key in [row for group in pieces.values() for row in group]:
 bm=bmesh.new();bm.from_mesh(obj.data);assert all(e.is_manifold for e in bm.edges) and bm.calc_volume(signed=True)>1e-12,obj.name;bm.free()
draws=[];records=[];fallbacks=0
for component in pieces:
 for key in sorted({key for _,key in pieces[component]}):
  verts=[];faces=[]
  for obj,material in pieces[component]:
   if material!=key:continue
   offset=len(verts);verts.extend(tuple(obj.location+v.co) for v in obj.data.vertices);faces.extend(tuple(offset+i for i in f.vertices) for f in obj.data.polygons)
  mesh=bpy.data.meshes.new(component+'__'+key);mesh.from_pydata(verts,[],faces);mesh.update()
  bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free();mesh.update()
  uv=mesh.uv_layers.new(name='MetreChart');guides=mesh.attributes.new('_tangent_guide','FLOAT_VECTOR','CORNER')
  for face in mesh.polygons:
   points=np.asarray([mesh.vertices[i].co[:] for i in face.vertices]);n,u,values,fallback=chart_for_triangle(points,(0,0,0),catalog[key]['meters_per_tile']);fallbacks+=int(fallback)
   for loop,value in zip(face.loop_indices,values):
    uv.data[loop].uv=value;guides.data[loop].vector=(u[0],u[2],-u[1])
  mesh.normals_split_custom_set(stock_corner_normals(mesh,planar_axes=[(1,0,0),(0,1,0),(0,0,1)]))
  mesh.materials.append(materials[key]);obj=bpy.data.objects.new(mesh.name,mesh);bpy.context.scene.collection.objects.link(obj);draws.append(obj)
  records.append({'name':obj.name,'component':component,'key':key,'tile':catalog[key]['meters_per_tile'],'triangles':len(mesh.polygons)})
for obj in bpy.context.selected_objects:obj.select_set(False)
for obj in draws:obj.select_set(True)
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension=ExportUVHandedness
asset=ROOT/'game/assets/props/case_calibrator.glb'
bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',use_selection=True,export_yup=True,export_tangents=True,export_attributes=True,export_materials='NONE')
assert ExportUVHandedness.corrected==len(draws)
manifest={'schema_version':1,'asset':'res://assets/props/case_calibrator.glb','parts':records,'stroke_m':.004,'housing_bounds_m':[.48,.42,.26]}
(ROOT/'game/data/orison_v2/case_calibrator.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8',newline='\n')
# Preview the exact exported stock, using the same catalogue maps.
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=32;scene.render.resolution_x=960;scene.render.resolution_y=960;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('ReviewWorld');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.15,.18,.22,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.4
camera=bpy.data.objects.new('ReviewCamera',bpy.data.cameras.new('ReviewCamera'));scene.collection.objects.link(camera);scene.camera=camera;camera.data.lens=60
lamp=bpy.data.objects.new('ReviewLight',bpy.data.lights.new('ReviewLight','AREA'));scene.collection.objects.link(lamp);lamp.data.energy=350;lamp.data.shape='DISK';lamp.data.size=2
out=ROOT/'art/reviews/v2_case_calibrator_20261021/native';out.mkdir(parents=True,exist_ok=True)
for name,eye,lightpos in [('diffuse',(.8,-1.,.8),(-1,-1,1.8)),('grazing',(.5,-.6,.58),(1,0,.5)),('plunger',(.18,-.27,.69),(-.3,-.5,1))]:
 camera.location=eye;camera.rotation_euler=(Vector((0,0,.25 if name!='plunger' else .42))-camera.location).to_track_quat('-Z','Y').to_euler();lamp.location=lightpos;lamp.rotation_euler=(Vector((0,0,.24))-lamp.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(out/(name+'.png'));bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/case_calibrator.blend'))
def digest(path):
 data=path.read_bytes();return hashlib.sha256(data if path.suffix in ['.glb','.blend','.png'] else data.replace(b'\r\n',b'\n')).hexdigest()
bindings=[Path(__file__),helper,ROOT/'art/blender/scripts/fabrication_uvs.py',ROOT/'art/blender/scripts/fabrication_normals.py',ROOT/'game/data/runtime_material_sets.json',ROOT/'game/scripts/cases/case_interactable.gd',ROOT/'game/scripts/building/orison_v2_case_one_placement.gd',ROOT/'game/data/orison_v2/case_one_placement.json']
report={'evidence_class':'INERT','source':'Existing .48 x .42 x .26 m case-owned calibrator; original placement and callback retained','asset_sha256':digest(asset),'source_bindings':{p.relative_to(ROOT).as_posix():digest(p) for p in bindings},'closed_stocks':stock_checks,'construction_datums_m':{'stop_rest_y':.389,'stop_fixed_y':.385,'cap_rest_top_y':.449,'guide_top_y':.432},'runtime':manifest,'precision_chart_fallbacks':fallbacks,'scope_limits':['internal spring and electrical circuit not exposed','case outcomes remain callback-owned','native review is not runtime qualification']}
(ROOT/'art/blender/case_calibrator_construction.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n')
print('CASE CALIBRATOR:',len(stock_checks),'closed stocks;',len(draws),'draws; physical stroke',manifest['stroke_m'])
