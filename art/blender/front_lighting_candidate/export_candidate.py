"""Batch uninstalled fixed supply by floor/material and round-trip its scratch GLB.

Fixture and switch geometry are excluded: their existing runtime actors keep
ownership. This does not install an asset or add runtime acceptance evidence.
"""
from pathlib import Path
import hashlib
import json
import math
import sys
import bpy
import numpy as np
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'tmp/v2-front-lighting-20261016'
native=ROOT/'art/blender/front_lighting_candidate.blend'
proof=json.loads((OUT/'saved_native_probes.json').read_text())
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert not proof['failures'] and proof['blend_sha256']==sha(native)
bpy.ops.wm.open_mainfile(filepath=str(native))
levels={r['id']:r['y'] for r in json.loads((ROOT/'game/data/orison_v2_blockout.json').read_text())['levels']}
groups={}
for obj in list(bpy.data.collections['FrontLightingCandidate'].objects):
    if obj.get('role') in ['native_fixture','native_switch']:continue
    keys={m.name.split('.')[0] for m in obj.data.materials}
    assert len(keys)==1,(obj.name,keys)
    groups.setdefault((obj['level'],next(iter(keys))),[]).append(obj)
draws=[]
discarded=0;recharted=0
for (level,key),objects in sorted(groups.items()):
    origin=Vector((0,0,levels[level]))
    vertices=[];faces=[];charts=[];smooth=[]
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
            charts.append(values)
            smooth.append(obj.data.polygons[tri.polygon_index].use_smooth)
    mesh=bpy.data.meshes.new(level+'_'+key)
    mesh.from_pydata(vertices,[],faces);mesh.update()
    layer=mesh.uv_layers.new(name='MetreStock')
    for face,values,is_smooth in zip(mesh.polygons,charts,smooth):
        for loop,value in zip(face.loop_indices,values):layer.data[loop].uv=value
        face.use_smooth=is_smooth
    mesh.materials.append(bpy.data.materials[key])
    obj=bpy.data.objects.new(level+'_FrontSupply_'+key,mesh)
    bpy.context.scene.collection.objects.link(obj);obj.location=origin
    draws.append(obj)
bpy.context.view_layer.update()
expected={o.name:len(o.data.polygons) for o in draws}
bounds={o.name:[[min((o.matrix_world@v.co)[i] for v in o.data.vertices),
                      max((o.matrix_world@v.co)[i] for v in o.data.vertices)] for i in range(3)] for o in draws}
bpy.ops.object.select_all(action='DESELECT')
for obj in draws:obj.select_set(True)
asset=OUT/'front_lighting_supply.glb'
# This Blender version flips V in glTF but leaves the tangent handedness in
# its native UV frame. Correct it inside the native exporter, as the existing
# fixed-light pipeline does; never edit a generated GLB afterwards.
class ExportUVHandedness:
    def gather_mesh_hook(self,mesh,blender_data,blender_object,vertex_groups,modifiers,materials,export_settings):
        from io_scene_gltf2.io.exp.binary_data import BinaryData
        from io_scene_gltf2.io.com.constants import BufferViewTarget
        for primitive in mesh.primitives:
            accessor=primitive.attributes['TANGENT']
            values=np.frombuffer(accessor.buffer_view.data,dtype='<f4').reshape((-1,4)).copy()
            values[:,3]*=-1
            accessor.buffer_view=BinaryData(values.tobytes(),BufferViewTarget.ARRAY_BUFFER)
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension=ExportUVHandedness
bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',use_selection=True,
    export_yup=True,export_apply=True,export_tangents=True,export_materials='PLACEHOLDER')
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
    asset_sha256=sha(asset),export_recipe_sha256_lf=hashlib.sha256(Path(__file__).read_bytes().replace(b'\r\n',b'\n')).hexdigest(),
    supply_parts=sum(len(v) for v in groups.values()),batches=len(draws),checks=checks,failures=failures,
    float32_degenerate_triangles_removed=discarded,precision_charts_repaired=recharted,
    tangent_validation=tangents,
    scope='Scratch Blender export/reimport; no shipping asset, Godot import, loaded mip, collision or runtime acceptance.')
(OUT/'export_roundtrip.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n')
print('FRONT SUPPLY EXPORT:',report['supply_parts'],'parts;',len(draws),'batches;',len(failures),'failures')
if failures:raise RuntimeError(str(failures[:3]))
