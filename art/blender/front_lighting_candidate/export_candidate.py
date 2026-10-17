"""Batch uninstalled fixed supply by floor/material and round-trip its scratch GLB.

Fixture and switch geometry are excluded: their existing runtime actors keep
ownership. This does not install an asset or add runtime acceptance evidence.
"""
from pathlib import Path
import hashlib
import json
import math
import sys
import os
import bpy
import numpy as np
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'tmp/v2-front-lighting-20261016'
kind=os.environ.get('FRONT_LIGHTING_EXPORT_KIND','supply')
assert kind in ['supply','fixtures']
native=ROOT/'art/blender/front_lighting_candidate.blend'
proof=json.loads((OUT/'saved_native_probes.json').read_text())
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert not proof['failures'] and proof['blend_sha256']==sha(native)
bpy.ops.wm.open_mainfile(filepath=str(native))
levels={r['id']:r['y'] for r in json.loads((ROOT/'game/data/orison_v2_blockout.json').read_text())['levels']}
groups={}
hanger_groups={}
for obj in list(bpy.data.collections['FrontLightingCandidate'].objects):
    if obj.get('role') in ['native_fixture','native_switch']:continue
    if obj.get('role')=='ceiling_hanger':
        hanger_groups.setdefault(obj.data.name,[]).append(obj)
        continue
    keys={m.name.split('.')[0] for m in obj.data.materials}
    assert len(keys)==1,(obj.name,keys)
    groups.setdefault((obj['level'],next(iter(keys))),[]).append(obj)
prototype_members={}
for i,(_,members) in enumerate(sorted(hanger_groups.items())):
    label='HANGER_'+str(i)
    groups[(label,'iron_neutral')]=[members[0]]
    prototype_members[label]=members
placements=[dict(node=member.name,level=member['level'],prototype=label)
    for label,members in prototype_members.items() for member in members]
fixture_origins={};fixture_data=None
if kind=='fixtures':
    groups={};prototype_members={};placements=[]
    plan=json.loads((ROOT/'art/data/front_lighting_plan.json').read_text())
    source=json.loads((ROOT/'game/data/orison_v2/fixed_lighting.json').read_text())
    assemblies=[]
    for variant in sorted({f['variant'] for f in plan['fixtures']}):
        owner=next(f for f in plan['fixtures'] if f['variant']==variant)
        anchor=Vector((owner['position'][0],-owner['position'][2],levels[owner['level']]+owner['position'][1]))
        template=next(a for a in source['assemblies'] if a['id']==variant)
        row=json.loads(json.dumps(template));row['id']='front_'+variant
        for part in row['parts']:
            suffix=part['name'].split('__',1)[1]
            obj=bpy.data.objects[owner['id']+'__'+suffix]
            label=row['id']+'__'+suffix
            key=next(iter(obj.data.materials)).name.split('.')[0]
            groups[(label,key)]=[obj];fixture_origins[label]=anchor
            part['name']=label+'_FrontSupply_'+key
        assemblies.append(row)
    fixture_data=dict(schema_version=1,asset='res://assets/props/front_lighting_fixtures.glb',floor_y=0,
        tint_space='linear',assemblies=assemblies,
        instances=[dict(id=f['id'],variant='front_'+f['variant']) for f in plan['fixtures']])
draws=[]
discarded=0;recharted=0;normal_repairs=0
for (level,key),objects in sorted(groups.items()):
    origin=fixture_origins[level] if level in fixture_origins else objects[0].location.copy() if level in prototype_members else Vector((0,0,levels[level]))
    vertices=[];faces=[];charts=[];smooth=[];guides=[];bitangents=[];face_normals=[]
    for obj in objects:
        offset=len(vertices)
        matrix=np.asarray(obj.matrix_world,dtype=np.float64)
        local=np.asarray([(*v.co,1.) for v in obj.data.vertices],dtype=np.float64)
        positions=(local@matrix.T)[:,:3]-np.asarray(origin,dtype=np.float64)
        positions=positions.astype(np.float32).astype(np.float64)
        vertices.extend(tuple(p) for p in positions)
        obj.data.calc_loop_triangles()
        uv=obj.data.uv_layers.active
        for tri in obj.data.loop_triangles:
            p=positions[list(tri.vertices)]
            normal=np.cross(p[1]-p[0],p[2]-p[0])
            if np.linalg.norm(normal)*.5<=1e-12:
                discarded+=1
                continue
            values=np.asarray([tuple(uv.data[i].uv) for i in tri.loops],dtype=np.float64)
            det=np.linalg.det(np.stack((values[1]-values[0],values[2]-values[0])))
            if abs(det)<=1e-12:
                axis=int(np.argmax(np.abs(normal)));a,b=[(1,2),(0,2),(0,1)][axis]
                values=(p-p[0])[:,[a,b]];recharted+=1
            faces.append(tuple(offset+i for i in tri.vertices))
            face_normals.append(normal/np.linalg.norm(normal))
            charts.append(values)
            smooth.append(obj.data.polygons[tri.polygon_index].use_smooth)
            # Derive against the actual float32 UVs the GLB will contain,
            # including its V flip. The two guides also preserve chart seams
            # during exporter vertex deduplication.
            encoded=values.astype(np.float32);encoded[:,1]=np.float32(1)-encoded[:,1]
            encoded=encoded.astype(np.float64)
            a=encoded[1]-encoded[0];b=encoded[2]-encoded[0];det=a[0]*b[1]-a[1]*b[0]
            assert abs(det)>1e-12,('unrepresentable chart',level,key)
            du=((p[1]-p[0])*b[1]-(p[2]-p[0])*a[1])/det
            dv=((p[2]-p[0])*a[0]-(p[1]-p[0])*b[0])/det
            guides.append(du[[0,2,1]]*np.array([1,1,-1]))
            bitangents.append(dv[[0,2,1]]*np.array([1,1,-1]))
    mesh=bpy.data.meshes.new(level+'_'+key)
    mesh.from_pydata(vertices,[],faces);mesh.update()
    layer=mesh.uv_layers.new(name='MetreStock')
    for face,values,is_smooth in zip(mesh.polygons,charts,smooth):
        for loop,value in zip(face.loop_indices,values):layer.data[loop].uv=value
        face.use_smooth=is_smooth
    mesh.materials.append(bpy.data.materials[key])
    for name,data in [('_tangent_guide',guides),('_bitangent_guide',bitangents)]:
        attr=mesh.attributes.new(name=name,type='FLOAT_VECTOR',domain='CORNER')
        attr.data.foreach_set('vector',np.repeat(np.asarray(data),3,axis=0).astype(np.float32).ravel())
    # Float32 cross products can cancel on thin Boolean bevel triangles far
    # from a batch origin. Preserve normal smoothing except where Blender
    # supplies a zero vector or leaves the face hemisphere; there use the
    # same final triangle in float64 (the stock normal gate uses the same .7).
    corners=np.asarray([n.vector[:] for n in mesh.corner_normals],dtype=np.float64)
    lengths=np.linalg.norm(corners,axis=1)
    robust=np.repeat(np.asarray(face_normals),3,axis=0)
    bad=(lengths<.99)|~np.isfinite(lengths)|(np.sum(corners*robust,axis=1)<.7)
    normal_repairs+=int(np.count_nonzero(bad))
    corners[bad]=robust[bad]
    corners/=np.linalg.norm(corners,axis=1)[:,None]
    mesh.normals_split_custom_set(corners.tolist())
    obj=bpy.data.objects.new(level+'_FrontSupply_'+key,mesh)
    bpy.context.scene.collection.objects.link(obj);obj.location=Vector((0,0,0)) if level in fixture_origins else origin
    if level in prototype_members:
        for member in prototype_members[level]:
            assert member.matrix_world.to_3x3()==objects[0].matrix_world.to_3x3(),'review rotated instance guide'
            clone=obj.copy();clone.name=member.name
            clone.matrix_world=member.matrix_world.copy()
            bpy.context.scene.collection.objects.link(clone);draws.append(clone)
    else:
        draws.append(obj)
bpy.context.view_layer.update()
expected={o.name:len(o.data.polygons) for o in draws}
bounds={o.name:[[min((o.matrix_world@v.co)[i] for v in o.data.vertices),
                      max((o.matrix_world@v.co)[i] for v in o.data.vertices)] for i in range(3)] for o in draws}
bpy.ops.object.select_all(action='DESELECT')
for obj in draws:obj.select_set(True)
asset=OUT/('front_lighting_'+kind+'.glb')
# This Blender version flips V in glTF but leaves the tangent handedness in
# its native UV frame. Correct it inside the native exporter, as the existing
# fixed-light pipeline does; never edit a generated GLB afterwards.
class ExportUVHandedness:
    def gather_mesh_hook(self,mesh,blender_data,blender_object,vertex_groups,modifiers,materials,export_settings):
        from io_scene_gltf2.io.exp.binary_data import BinaryData
        from io_scene_gltf2.io.com.constants import BufferViewTarget
        for primitive in mesh.primitives:
            def values(key):return np.frombuffer(primitive.attributes[key].buffer_view.data,dtype='<f4').reshape((-1,3)).astype(float)
            n=values('NORMAL');n/=np.linalg.norm(n,axis=1)[:,None]
            u=values('_TANGENT_GUIDE');v=values('_BITANGENT_GUIDE')
            tangent=u-n*np.sum(u*n,axis=1)[:,None];tangent/=np.linalg.norm(tangent,axis=1)[:,None]
            handed=np.sign(np.sum(np.cross(n,tangent)*v,axis=1));assert np.all(handed!=0)
            primitive.attributes['TANGENT'].buffer_view=BinaryData(np.column_stack((tangent,handed)).astype('<f4').tobytes(),BufferViewTarget.ARRAY_BUFFER)
            del primitive.attributes['_TANGENT_GUIDE'];del primitive.attributes['_BITANGENT_GUIDE']
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension=ExportUVHandedness
bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',use_selection=True,
    export_yup=True,export_apply=True,export_tangents=True,export_attributes=True,export_materials='PLACEHOLDER')
sys.path.insert(0,str(ROOT/'art/blender/scripts'))
from check_exported_tangents import validate
tangents=validate(asset)
for obj in list(bpy.data.objects):bpy.data.objects.remove(obj,do_unlink=True)
bpy.ops.import_scene.gltf(filepath=str(asset))
actual={o.name:o for o in bpy.context.scene.objects if o.type=='MESH'}
checks=[]
assert set(actual)==set(expected),(set(actual),set(expected))
for name,obj in actual.items():
    mesh=obj.data;mesh.calc_loop_triangles();layer=mesh.uv_layers.active
    bad=0
    for tri in mesh.loop_triangles:
        values=[Vector(layer.data[i].uv) for i in tri.loops]
        if tri.area>1e-12 and abs((values[1]-values[0]).cross(values[2]-values[0]))<1e-13:bad+=1
    current=[[min((obj.matrix_world@v.co)[i] for v in mesh.vertices),
              max((obj.matrix_world@v.co)[i] for v in mesh.vertices)] for i in range(3)]
    error=max(abs(current[i][j]-bounds[name][i][j]) for i in range(3) for j in range(2))
    finite=all(math.isfinite(v) for uv in layer.data for v in uv.uv)
    checks.append(dict(name=name,triangles=len(mesh.loop_triangles),expected_triangles=expected[name],
                       collapsed_uv=bad,bounds_error=error,finite_uv=finite,
                       passed=bad==0 and finite and error<.00005 and len(mesh.loop_triangles)==expected[name]))
failures=[c for c in checks if not c['passed']]
report=dict(evidence_class='INERT',status='SCRATCH_EXPORT_NOT_INSTALLED',native_sha256=sha(native),
    asset_kind=kind,
    asset_sha256=sha(asset),export_recipe_sha256_lf=hashlib.sha256(Path(__file__).read_bytes().replace(b'\r\n',b'\n')).hexdigest(),
    supply_parts=sum(len(v) for v in groups.values())+sum(len(v)-1 for v in prototype_members.values()),
    batches=len(groups),static_batches=len(groups)-len(prototype_members),mesh_nodes=len(draws),checks=checks,failures=failures,
    hanger_instances=sum(len(v) for v in prototype_members.values()),hanger_prototypes=len(prototype_members),
    unique_meshes=len({o.data for o in actual.values()}),
    hanger_placements=placements,
    float32_degenerate_triangles_removed=discarded,precision_charts_repaired=recharted,
    invalid_corner_normals_repaired=normal_repairs,
    tangent_validation=tangents,
    scope='Scratch Blender export/reimport; no shipping asset, Godot import, loaded mip, collision or runtime acceptance.')
report_path=OUT/('export_roundtrip.json' if kind=='supply' else 'fixtures_roundtrip.json')
report_path.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n')
if fixture_data is not None:
    (OUT/'front_lighting_fixtures.json').write_text(json.dumps(fixture_data,indent=2)+'\n',encoding='utf-8',newline='\n')
print('FRONT SUPPLY EXPORT:',report['supply_parts'],'parts;',report['unique_meshes'],'mesh resources;',len(draws),'posed nodes;',len(failures),'failures')
if failures:raise RuntimeError(str(failures[:3]))
