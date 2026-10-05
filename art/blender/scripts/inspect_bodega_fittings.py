"""Independent saved-native inspection and textured ordinary-height views."""
from pathlib import Path
import argparse,hashlib,json,math,sys
import bpy,bmesh,numpy as np
from mathutils import Vector
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
p=argparse.ArgumentParser();p.add_argument('--out',required=True);p.add_argument('--native');p.add_argument('--asset');p.add_argument('--fixture');p.add_argument('--verify-only',action='store_true');args=p.parse_args(sys.argv[sys.argv.index('--')+1:]);out=Path(args.out);out.mkdir(parents=True,exist_ok=True)
native=Path(args.native) if args.native else out/'bodega_fittings.blend';bpy.ops.wm.open_mainfile(filepath=str(native))
fixture=json.loads((Path(args.fixture) if args.fixture else out/'bodega_fittings_construction.json').read_text())
source=ROOT/'game/data/orison_v2/exterior/exterior_geometry.json';assert hashlib.sha256(source.read_bytes().replace(b'\r\n',b'\n')).hexdigest()==fixture['source_geometry_sha256_lf']
actual=[];count=0;largest=0.0
for o in bpy.data.collections['ClosedConstruction'].objects:
 bm=bmesh.new();bm.from_mesh(o.data);assert all(e.is_manifold and e.is_contiguous for e in bm.edges),o.name
 volume=bm.calc_volume(signed=True);assert volume>1e-12,o.name;bm.free()
 assert len(o.data.uv_layers)==1 and o.data.uv_layers[0].name=='Metres',o.name
 colours=np.empty((len(o.data.loops),4),dtype=np.float32);rgb=np.empty((len(o.data.loops),3),dtype=np.float32)
 o.data.color_attributes['SourceTint'].data.foreach_get('color',colours.ravel());o.data.attributes['_source_tint_rgb'].data.foreach_get('vector',rgb.ravel())
 assert np.isfinite(colours).all() and colours.min()>=0 and colours.max()<=1 and np.max(np.abs(colours[:,:3]-rgb))<1e-6,o.name
 for face in o.data.polygons:
  loops=list(face.loop_indices)
  for a,b in zip(loops,loops[1:]+loops[:1]):
   physical=(o.data.vertices[o.data.loops[a].vertex_index].co-o.data.vertices[o.data.loops[b].vertex_index].co).length
   chart=(o.data.uv_layers[0].data[a].uv-o.data.uv_layers[0].data[b].uv).length
   assert math.isfinite(chart) and abs(physical-chart)<.000002,(o.name,physical,chart)
   largest=max(largest,abs(physical-chart))
 low=[min((o.matrix_world@v.co)[i] for v in o.data.vertices) for i in range(3)]
 high=[max((o.matrix_world@v.co)[i] for v in o.data.vertices) for i in range(3)]
 actual.append({'name':o.name,'assembly':o['assembly'],'volume_m3':volume,'bounds_blender':low+high});count+=len(o.data.polygons)
assert len(actual)==len(fixture['stocks'])
for im in bpy.data.images:
 if im.source=='FILE':assert im.filepath.startswith('//') and Path(bpy.path.abspath(im.filepath)).is_file(),im.filepath
data=json.loads(source.read_text());template=next(t for t in data['templates'] if t['id']=='TEMPLATE_BODEGA_CELL_V1')
# Temporary retained room context is never saved into the native fabrication.
for row in template['boxes']:
 if row['id'] not in ['shop_floor','left_party_wall','right_party_wall','shop_ceiling','left_bulkhead','right_bulkhead']:continue
 s=row['size_m'];p=row['position_m'];bpy.ops.mesh.primitive_cube_add(size=1,location=(p[0],-p[2],p[1]));o=bpy.context.object;o.dimensions=(s[0],s[2],s[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 mat=bpy.data.materials.new('RetainedContext');mat.diffuse_color=(.6,.55,.46,1);o.data.materials.clear();o.data.materials.append(mat)
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24
scene.render.resolution_x=1280;scene.render.resolution_y=720;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('InspectionWorld');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.25
for row in template['lights']:
 # Source position puts the practical below its shade. The native review
 # uses a fixed 50 W per Godot energy unit, not a production light override.
 light=bpy.data.lights.new(row['id'],'POINT');light.energy=50*row['energy'];light.color=row['color_rgb'];light.shadow_soft_size=.08
 lamp=bpy.data.objects.new(light.name,light);scene.collection.objects.link(lamp);p=row['position_m'];lamp.location=(p[0],-p[2],p[1])
camera=bpy.data.objects.new('InspectionCamera',bpy.data.cameras.new('InspectionCamera'));scene.collection.objects.link(camera);scene.camera=camera;camera.data.lens=24
views=[('aisles',(0,1.41,-3.6),(0,.8,-6)),('stock',(-.12,1.41,-5),(-.75,1.15,-5.8)),('counter',(.2,1.41,-1),(-1.25,.63,-1.8)),('cooler',(.3,1.41,-7.0),(1.25,1,-8.1)),('window_crates',(0,1.41,-1.8),(-1.3,1.02,-.33)),('delivery',(.5,1.41,-8.7),(-.75,.7,-9.4))]
for name,at,target in ([] if args.verify_only else views):
 camera.location=(at[0],-at[2],at[1]);point=Vector((target[0],-target[2],target[1]));camera.rotation_euler=(point-camera.location).to_track_quat('-Z','Y').to_euler()
 scene.render.filepath=str(out/(name+'.png'));bpy.ops.render.render(write_still=True)
(out/'inspection.json').write_text(json.dumps(dict(evidence_class='INERT',closed_positive_stocks=len(actual),triangles=count,largest_native_uv_edge_error_m=largest,source_tint_guides_match_saved_colours=True,
 source_geometry_sha256_lf=fixture['source_geometry_sha256_lf'],native_sha256=hashlib.sha256(native.read_bytes()).hexdigest(),asset_sha256=hashlib.sha256((Path(args.asset) if args.asset else out/'bodega_fittings.glb').read_bytes()).hexdigest(),stocks=actual),indent=2)+'\n')
print('BODEGA NATIVE:',len(actual),'closed positive stocks;',count,'triangles; metric charts and portable catalogue maps inspected')
