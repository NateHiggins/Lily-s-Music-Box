"""Read the saved native trial, compare its closed volume and render its parts."""
from pathlib import Path
import json,hashlib
import bpy
import bmesh
import numpy as np
from mathutils import Vector

root = next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
base = root / 'tmp/roof-drainage-review/ground-native';base.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(root / 'art/blender/orison_ground.blend'))
cells = np.load(root / 'tmp/orison-ground/orison-ground-cells.npz')
solid = cells['solid']
parcel_protection=cells['parcel_protection'] if 'parcel_protection' in cells else None
parcel_rects=cells['parcel_rects'] if 'parcel_rects' in cells else []
dimensions = [np.diff(cells[key]) for key in ['xs', 'ys', 'zs']]
expected = sum(float(np.einsum('i,k,ik->',dimensions[0],dimensions[2],solid[:,index,:],dtype=np.float64))*float(depth)
               for index,depth in enumerate(dimensions[1]))
roof_cut=bool(cells['roof_cut']) if 'roof_cut' in cells else False
if roof_cut:
    # Independent layer integral: positive parts of the affine roof, rather
    # than the builder's threshold-split clipped-cell trapezoids or mesh volume.
    profile=cells['roof_profile'];expected=0.
    def height(x): return float(np.interp(x,profile[:,0],profile[:,1]))
    def positive_integral(h,H,threshold,width):
        u=h-threshold;v=H-threshold
        result=np.where((u>=0)&(v>=0),width*(u+v)*.5,0.)
        if abs(H-h)>1e-15:
            crossing=(u*v)<0
            result=np.where(crossing,width*np.maximum(u,v)**2/(2*abs(H-h)),result)
        return result
    for i,(a,b) in enumerate(zip(cells['xs'],cells['xs'][1:])):
        cuts=[a]+[x for x in profile[:,0] if a<x<b]+[b]
        lengths=np.einsum('jk,k->j',solid[i],dimensions[2],dtype=np.float64)
        protected=np.einsum('jk,k->j',solid[i],dimensions[2]*parcel_protection[i],dtype=np.float64) if parcel_protection is not None else np.zeros_like(lengths)
        for c,d in zip(cuts,cuts[1:]):
            h,H=height(c),height(d)
            weights=positive_integral(h,H,cells['ys'][:-1],d-c)-positive_integral(h,H,cells['ys'][1:],d-c)
            expected+=float(weights@(lengths-protected)+np.diff(cells['ys'])*(d-c)@protected)
source = bpy.data.objects['OrisonGroundClosedUnion']
bm = bmesh.new(); bm.from_mesh(source.data)
non_manifold = sum(not edge.is_manifold for edge in bm.edges)
bmesh_volume = bm.calc_volume(signed=True)
# Independently integrate actual saved float32 vertices in float64. The cell
# proof must use those same represented planes, at the unchanged absolute bound.
vertices=np.empty(len(source.data.vertices)*3,dtype=np.float64)
source.data.vertices.foreach_get('co',vertices);vertices=vertices.reshape((-1,3))
source.data.calc_loop_triangles()
indices=np.empty(len(source.data.loop_triangles)*3,dtype=np.int32)
source.data.loop_triangles.foreach_get('vertices',indices)
indices=indices.reshape((-1,3));center=(vertices.min(axis=0)+vertices.max(axis=0))*.5
native_volume=0.
for start in range(0,len(indices),100000):
    points=vertices[indices[start:start+100000]]-center
    native_volume+=float(np.sum(np.einsum('ij,ij->i',points[:,0],np.cross(points[:,1],points[:,2]))))/6
print('NATIVE VOLUME DIAGNOSTIC:',native_volume,'Blender accumulated',bmesh_volume,'grid',expected,'difference',expected-native_volume,flush=True)
assert non_manifold == 0
assert native_volume > 0 and abs(expected - native_volume) < .001
bm.free()
mask_checks = []
plan = json.loads((root/'art/blender/orison_ground_construction.json').read_text(encoding='utf-8'))['source_plan']
bpy.data.collections['OrisonGroundConstruction'].hide_viewport=False
bpy.context.view_layer.update()
roof_contacts=[];roof_vertex_intrusion=0.
if roof_cut:
    roofs=np.interp(vertices[:,0],profile[:,0],profile[:,1])
    for a,b,c,d in parcel_rects:
        inside=(vertices[:,0]>=a-.00001)&(vertices[:,0]<=c+.00001)&(-vertices[:,1]>=b-.00001)&(-vertices[:,1]<=d+.00001)
        roofs[inside]=cells['ys'][-1]
    roof_vertex_intrusion=float(np.max(vertices[:,2]-roofs))
    assert roof_vertex_intrusion<.00001,('uncut native soil above authored profile',roof_vertex_intrusion)
    stations=sorted(set([float(x) for x in profile[:,0] if cells['xs'][0]<x<cells['xs'][-1]]+
                        [float((a+b)*.5) for a,b in zip(profile[:,0],profile[1:,0]) if cells['xs'][0]<(a+b)*.5<cells['xs'][-1]]))
    masks=plan['retained_solids']+plan['occupation_reservations']
    for x in stations:
        h=height(x)
        for z in np.linspace(cells['zs'][0]+3,cells['zs'][-1]-3,13):
            if any(a-.001<x<c+.001 and b-.001<z<d+.001 for a,b,c,d in parcel_rects):continue
            if any(r['bounds'][0]-.001<x<r['bounds'][3]+.001 and r['bounds'][2]-.001<z<r['bounds'][5]+.001 and r['bounds'][1]-.001<h<r['bounds'][4]+.001 for r in masks):continue
            found,point,normal,index=source.ray_cast(Vector((x,-float(z),h+.015)),Vector((0,0,-1)),distance=.03)
            assert found and abs(point.z-h)<.00001,('missing exterior roof contact',x,float(z),h,found,tuple(point))
            roof_contacts.append({'building_x':x,'building_z':float(z),'height_m':h,'native_height_m':float(point.z)})
    assert len(roof_contacts)>=20,'Nonzero distributed exterior grade proof required'
midpoints = [(cells[key][:-1] + cells[key][1:]) / 2 for key in ['xs', 'ys', 'zs']]
for row in plan['retained_solids'] + plan['occupation_reservations']:
    bounds = row['bounds']
    selection = [np.flatnonzero((axis > bounds[i] + .00001)
                               & (axis < bounds[i + 3] - .00001))
                 for i, axis in enumerate(midpoints)]
    occupied = int(solid[np.ix_(*selection)].sum())
    assert occupied == 0, row
    mask_checks.append({'owner': row['owner'], 'id': row.get('id', ''),
                        'kind': row['kind'], 'intruding_grid_cells': occupied})
# Each contact casts against the actual saved closed soil, not the mask map.
with bpy.data.libraries.load(str(root/'art/blender/city_foundations.blend'),link=False) as (available,loaded):
    loaded.collections=['CityFoundationConstruction']
foundation_collection=loaded.collections[0]
foundation_collection.hide_viewport=False
foundation_contacts=[]
for obj in foundation_collection.objects:
    if obj.type!='MESH':continue
    bm=bmesh.new();bm.from_mesh(obj.data)
    assert all(e.is_manifold for e in bm.edges)
    assert bm.calc_volume(signed=True)>0
    bm.free()
    faces=[face for face in obj.data.polygons if face.normal.z<-.999]
    step=max(1,len(faces)//15)
    for face in faces[::step]:
        at=face.center
        found,point,normal,index=source.ray_cast(at+Vector((0,0,.015)),Vector((0,0,-1)),distance=.03)
        assert found and abs(point.z-at.z)<.00001,(obj.name,tuple(at),found,tuple(point))
        foundation_contacts.append({'owner':obj.name,'native_underside':[float(v) for v in at],
                                    'soil_contact':[float(v) for v in point],'distance_m':abs(float(point.z-at.z))})
print('INERT REAL NATIVE FOUNDATION/SOIL SEATS:',len(foundation_contacts),'unshifted face probes',flush=True)
for family, names, tile in [
    ('asphalt', ['albedo', 'rough', 'normal'], 2.5),
    ('soil', ['albedo', 'rough', 'normal'], .35),
]:
    material = bpy.data.materials[family]
    material.use_nodes = True
    nodes = material.node_tree.nodes; links = material.node_tree.links
    nodes.clear()
    output = nodes.new('ShaderNodeOutputMaterial')
    shader = nodes.new('ShaderNodeBsdfPrincipled')
    links.new(shader.outputs['BSDF'], output.inputs['Surface'])
    uv = nodes.new('ShaderNodeTexCoord')
    scale = nodes.new('ShaderNodeVectorMath'); scale.operation = 'SCALE'
    scale.inputs[3].default_value = 1 / tile
    links.new(uv.outputs['UV'], scale.inputs[0])
    maps = []
    for index, name in enumerate(names):
        texture = nodes.new('ShaderNodeTexImage')
        texture.image = bpy.data.images.load(str(root / 'game/assets/building/textures'
                                    / ('T_ai_materials_%s_%s.png' % (family, name))))
        if index: texture.image.colorspace_settings.name = 'Non-Color'
        links.new(scale.outputs['Vector'], texture.inputs['Vector']); maps.append(texture)
    links.new(maps[0].outputs['Color'], shader.inputs['Base Color'])
    channels=nodes.new('ShaderNodeSeparateColor')
    links.new(maps[1].outputs['Color'],channels.inputs['Color'])
    links.new(channels.outputs['Green'], shader.inputs['Roughness'])
    normal = nodes.new('ShaderNodeNormalMap'); normal.inputs['Strength'].default_value = .35
    links.new(maps[2].outputs['Color'], normal.inputs['Color'])
    links.new(normal.outputs['Normal'], shader.inputs['Normal'])
scene = bpy.context.scene
scene.render.engine = 'CYCLES'; scene.cycles.samples = 32
scene.render.resolution_x = 1280; scene.render.resolution_y = 960
scene.render.resolution_percentage = 100
scene.world.use_nodes = True
scene.world.node_tree.nodes['Background'].inputs['Color'].default_value = (.65, .73, .85, 1)
scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value = .55
light_data = bpy.data.lights.new('InspectionSun', 'SUN'); light_data.energy = 3
light = bpy.data.objects.new('InspectionSun', light_data); scene.collection.objects.link(light);bpy.context.view_layer.update()
light.rotation_euler = (.4, -.5, -.6)
camera_data = bpy.data.cameras.new('InspectionCamera')
camera = bpy.data.objects.new('InspectionCamera', camera_data)
scene.collection.objects.link(camera);bpy.context.view_layer.update(); scene.camera = camera
camera_data.type = 'ORTHO'; camera_data.ortho_scale = 245
camera.location = (-150, 145, 140)
camera.rotation_euler = (Vector((0, 20, -.4)) - camera.location).to_track_quat('-Z', 'Y').to_euler()
scene.render.filepath = str(base / 'city-ground-native-overview.png')
bpy.ops.render.render(write_still=True)
result = {'evidence_class': 'INERT',
          'native_sha256':hashlib.sha256((root/'art/blender/orison_ground.blend').read_bytes()).hexdigest(),
          'asset_sha256':hashlib.sha256((root/'game/assets/props/orison_ground.glb').read_bytes()).hexdigest(),
          'closed_source_non_manifold_edges': non_manifold,
          'native_closed_volume_m3': native_volume, 'grid_volume_m3': expected,
          'blender_accumulated_volume_m3':bmesh_volume,'volume_method':'Float64 signed tetrahedral integration of actual saved vertices about their local midpoint; unchanged 0.001 m3 absolute bound.',
          'absolute_volume_difference_m3': abs(native_volume - expected),
          'exterior_roof_cut':roof_cut,
          'roof_vertex_intrusion_m':roof_vertex_intrusion,'roof_contacts':roof_contacts,
          'reservation_checks': mask_checks, 'foundation_contacts': foundation_contacts,
          'render': 'city-ground-native-overview.png',
          'note': 'Installed bounded ground only. Native volume and reservation checks do not establish drainage, weather closure, soil capacity or full site continuity.'}
(base / 'city-ground-native-inspection.json').write_text(json.dumps(result, indent=2) + '\n')
print('INERT COURTYARD NATIVE INSPECTION:', native_volume, 'm3;', len(mask_checks),
      'retained/reserved volumes clear;', 'render completed', flush=True)
