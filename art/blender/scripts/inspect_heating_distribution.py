"""Inspect saved candidate meshes, UV charts and actual coupling lumens."""
import bpy
import bmesh
import hashlib
import json
import math
import argparse
import sys
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT=Path(__file__).resolve().parents[3]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--work-dir',type=Path,required=True)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
OUT=args.work_dir.resolve()/'native'
blend=OUT/'heating_distribution_candidate.blend'
review=OUT/'native_review.json'
data=json.loads(review.read_text())
bpy.ops.wm.open_mainfile(filepath=str(blend))
failures=[]
triangles=0
for obj in bpy.context.scene.objects:
    if obj.type!='MESH':continue
    mesh=obj.data
    bm=bmesh.new();bm.from_mesh(mesh)
    bad_edges=sum(not edge.is_manifold for edge in bm.edges)
    volume=bm.calc_volume(signed=True);bm.free()
    if bad_edges or volume<=0:
        failures.append({'id':obj.name,'kind':'invalid_closed_stock','nonmanifold_edges':bad_edges,'volume':volume})
    mesh.calc_loop_triangles()
    if not mesh.uv_layers.active:
        failures.append({'id':obj.name,'kind':'missing_uv'})
        continue
    uv=mesh.uv_layers.active.data
    for tri in mesh.loop_triangles:
        a,b,c=[uv[i].uv for i in tri.loops]
        area=abs((b.x-a.x)*(c.y-a.y)-(b.y-a.y)*(c.x-a.x))*.5
        triangles+=1
        if not math.isfinite(area) or area<1e-12:
            failures.append({'id':obj.name,'kind':'collapsed_uv','triangle':tri.index})
probes=0
routes=json.loads((OUT.parent/'heating_routes_exact.json').read_text())
floor_by_radiator={row['id']:row['points_local_godot'][-1][1] for row in routes['branches']}
for row in data.get('radiator_tailpieces',[]):
    expected=floor_by_radiator[row['radiator']]+.19
    if any(abs(point[2]-expected)>1e-5 for point in [row['start_blender'],row['end_blender']]):
        failures.append({'id':row['id'],'kind':'tailpiece_wrong_floor','expected_y':expected})
for row in data['couplings']+data.get('radiator_tailpieces',[]):
    mesh=bpy.data.objects[row['id']].data
    tree=BVHTree.FromPolygons([v.co for v in mesh.vertices],[p.vertices[:] for p in mesh.polygons])
    a,b=Vector(row['start_blender']),Vector(row['end_blender'])
    axis=(b-a).normalized()
    for origin,direction in [(a-axis*.01,axis),(b+axis*.01,-axis)]:
        probes+=1
        if tree.ray_cast(origin,direction,(b-a).length+.02)[0] is not None:
            failures.append({'id':row['id'],'kind':'blocked_lumen'})
    u=axis.cross(Vector((0,0,1)) if abs(axis.z)<.9 else Vector((0,1,0))).normalized()
    v=axis.cross(u)
    for index in range(8):
        # Probe face interiors; vertex-edge rays are numerically ambiguous.
        angle=math.tau*(index/8+.5/32)
        direction=u*math.cos(angle)+v*math.sin(angle)
        hit,normal,face,distance=tree.ray_cast((a+b)/2,direction,.1)
        probes+=1
        if hit is None or abs(distance-row['inner_radius_m'])>.0002:
            failures.append({'id':row['id'],'kind':'incorrect_lumen_radius','probe':index,'distance_m':distance})
port_probes=0
junction_probes=0
for row in data.get('risers',[]):
    mesh=bpy.data.objects[row['id']].data
    tree=BVHTree.FromPolygons([v.co for v in mesh.vertices],[p.vertices[:] for p in mesh.polygons])
    # Probe all parts together: checking an empty riser alone cannot detect
    # a branch end ring or socket left blocking the main lumen.
    junction_meshes=[bpy.data.objects[name].data for name in data.get('junction_parts',[])
                     if any(name==p['branch'] or name.startswith(p['branch']+'__') for p in row['ports'])]
    junction_trees=[tree]+[BVHTree.FromPolygons([v.co for v in m.vertices],[p.vertices[:] for p in m.polygons]) for m in junction_meshes]
    for port in row['ports']:
        origin=Vector(port['origin_blender']);direction=Vector(port['direction_blender']).normalized()
        # Vertical bore probes include off-axis rays near the inner wall.
        for dx,dy in [(0,0),(.018,0),(-.018,0),(0,.018),(0,-.018)]:
            start=origin+Vector((dx,dy,-.10))
            junction_probes+=1
            if any(t.ray_cast(start,Vector((0,0,1)),.20)[0] is not None for t in junction_trees):
                failures.append({'id':port['branch'],'kind':'blocked_assembled_main_lumen','offset':[dx,dy]})
        junction_probes+=1
        if any(t.ray_cast(origin,direction,.07)[0] is not None for t in junction_trees):
            failures.append({'id':port['branch'],'kind':'blocked_assembled_branch_lumen'})
        port_probes+=1
        if tree.ray_cast(origin,direction,.08)[0] is not None:
            failures.append({'id':port['branch'],'kind':'blocked_riser_port'})
        horizontal=Vector((direction.x,direction.y,0)).normalized()
        perpendicular=Vector((-horizontal.y,horizontal.x,0))
        for angle in [-math.pi/4,0,math.pi/4]:
            backward=-horizontal*math.cos(angle)+perpendicular*math.sin(angle)
            hit,normal,face,distance=tree.ray_cast(origin,backward,.06)
            port_probes+=1
            if hit is None or abs(distance-row['inner_radius_m'])>.0002:
                failures.append({'id':port['branch'],'kind':'damaged_opposite_riser_wall'})
receiver_probes=0
feed_probes=0
if data.get('receiver'):
    receiver=data['receiver'];obj=bpy.data.objects[receiver['id']];mesh=obj.data
    tree=BVHTree.FromPolygons([obj.matrix_world@v.co for v in mesh.vertices],[p.vertices[:] for p in mesh.polygons])
    for riser in data['risers']:
        receiver_probes+=1
        if tree.ray_cast(Vector(riser['start_blender'])+Vector((0,0,.01)),Vector((0,0,-1)),.05)[0] is not None:
            failures.append({'id':riser['id'],'kind':'blocked_receiver_outlet'})
    receiver_probes+=1
    if tree.ray_cast(Vector(receiver['feed_origin_blender'])+Vector((0,.01,0)),Vector((0,-1,0)),.05)[0] is not None:
        failures.append({'id':receiver['id'],'kind':'blocked_receiver_feed'})
    feed_trees=[tree]
    for name in data.get('boiler_feed_parts',[]):
        part=bpy.data.objects[name];m=part.data
        feed_trees.append(BVHTree.FromPolygons([part.matrix_world@v.co for v in m.vertices],[p.vertices[:] for p in m.polygons]))
    for dx,dz in [(0,0),(.04,0),(-.04,0),(0,.04),(0,-.04)]:
        feed_probes+=1
        start=Vector(receiver['feed_origin_blender'])+Vector((dx,.12,dz))
        if any(t.ray_cast(start,Vector((0,-1,0)),.17)[0] is not None for t in feed_trees):
            failures.append({'id':receiver['id'],'kind':'blocked_assembled_boiler_feed','offset':[dx,dz]})
floor_sleeve_probes=0
for sleeve in data.get('floor_sleeves',[]):
    plate=bpy.data.objects[sleeve['branch']+'__FloorPlate'];m=plate.data
    tree=BVHTree.FromPolygons([plate.matrix_world@v.co for v in m.vertices],[p.vertices[:] for p in m.polygons])
    x,y,z=sleeve['center'];center=Vector((x,-z,y))
    for dx,dy in [(-.034,-.034),(-.034,.034),(.034,-.034),(.034,.034)]:
        floor_sleeve_probes+=1
        if tree.ray_cast(center+Vector((dx,dy,.02)),Vector((0,0,-1)),.04)[0] is None:
            failures.append({'id':sleeve['id'],'kind':'uncovered_floor_hole_corner'})
    floor_sleeve_probes+=1
    hit,*_=tree.ray_cast(center+Vector((.045,0,-.01)),Vector((0,0,1)),.03)
    if hit is None or abs(hit.z-y)>.00001:
        failures.append({'id':sleeve['id'],'kind':'plate_not_seated_on_floor'})
    floor_sleeve_probes+=1
    if tree.ray_cast(center+Vector((0,0,.02)),Vector((0,0,-1)),.04)[0] is not None:
        failures.append({'id':sleeve['id'],'kind':'blocked_floor_plate'})
hanger_probes=0
for hanger in data.get('branch_supports',[]):
    x,y,z=hanger['center'];center=Vector((x,-z,y))
    for role,target,origin,direction in [
        ('Stem',hanger['stem_bottom_y'],center,Vector((0,0,1))),
        ('Foot',hanger['stem_top_y'],Vector((x,-z,hanger['floor_y']+.01)),Vector((0,0,-1)))]:
        obj=bpy.data.objects[hanger['id']+'__'+role];mesh=obj.data
        tree=BVHTree.FromPolygons([obj.matrix_world@v.co for v in mesh.vertices],[p.vertices[:] for p in mesh.polygons])
        hit,normal,*_=tree.ray_cast(origin,direction,.2)
        hanger_probes+=1
        if hit is None or abs(hit.z-target)>1e-6 or normal.dot(direction)>-.99:
            failures.append({'id':obj.name,'kind':'hanger_contact_or_normal_failed'})
support_probes=0
for support in data.get('main_supports',[]):
    x,y,z=support['center'];center=Vector((x,-z,y))
    for sign,suffix in [(-1,'__LugLeft'),(1,'__LugRight')]:
        obj=bpy.data.objects[support['id']+suffix];mesh=obj.data
        tree=BVHTree.FromPolygons([obj.matrix_world@v.co for v in mesh.vertices],[p.vertices[:] for p in mesh.polygons])
        direction=Vector((sign,0,0))
        hit,normal,*_=tree.ray_cast(center,direction,.08)
        support_probes+=1
        if hit is None or not .029<abs(hit.x-x)<support['outer_radius_m'] or normal.dot(direction)>-.99:
            failures.append({'id':obj.name,'kind':'lug_does_not_overlap_band_wall'})
        outside=center+direction*.09
        hit,normal,*_=tree.ray_cast(outside,-direction,.06)
        support_probes+=1
        if hit is None or abs(abs(hit.x-x)-support['lug_reach_m'])>1e-6 or normal.dot(direction)<.99:
            failures.append({'id':obj.name,'kind':'lug_does_not_reach_shaft_bearing'})
cap_probes=0
if len(data.get('main_caps',[]))!=len(data['risers']):
    failures.append({'kind':'missing_main_caps'})
for cap in data.get('main_caps',[]):
    obj=bpy.data.objects[cap['crown']];mesh=obj.data
    tree=BVHTree.FromPolygons([obj.matrix_world@v.co for v in mesh.vertices],[p.vertices[:] for p in mesh.polygons])
    end=Vector(cap['end_blender'])
    for x,y in [(0,0),(.018,0),(-.018,0),(0,.018),(0,-.018)]:
        hit,normal,*_=tree.ray_cast(end+Vector((x,y,0)),Vector((0,0,1)),.04)
        cap_probes+=1
        if hit is None or abs(hit.z-end.z-cap['underside_offset_m'])>1e-6 or normal.z>-.99:
            failures.append({'id':cap['crown'],'kind':'main_cap_missing_or_backfacing_underside'})
        hit,normal,*_=tree.ray_cast(end+Vector((x,y,.05)),Vector((0,0,-1)),.04)
        cap_probes+=1
        if hit is None or abs(hit.z-end.z-cap['top_offset_m'])>1e-6 or normal.z<.99:
            failures.append({'id':cap['crown'],'kind':'main_cap_missing_or_backfacing_top'})
result={'evidence_class':'INERT','scope':'Saved candidate UV charts, closed stocks, coupling lumens, sampled assembled tee bores, receiver ports and floor plates. Excludes installation acceptance and full mesh self-intersection.',
        'main_cap_probes':cap_probes,
        'main_support_probes':support_probes,
        'branch_hanger_probes':hanger_probes,
        'triangles_checked':triangles,'lumen_probes':probes,'riser_port_probes':port_probes,'junction_probes':junction_probes,'receiver_probes':receiver_probes,'feed_probes':feed_probes,'floor_sleeve_probes':floor_sleeve_probes,'failures':failures,
        'blend_sha256':hashlib.sha256(blend.read_bytes()).hexdigest(),
        'review_sha256':hashlib.sha256(review.read_bytes()).hexdigest()}
(OUT/'mesh_inspection.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result))
if failures:raise RuntimeError('Saved heating candidate inspection failed')
