"""Close the authored roof slab rim under the retained parapet, without new rooms."""
from pathlib import Path
import json,math
import bpy,bmesh
ROOT=Path(__file__).resolve().parents[3]
source=json.loads((ROOT/'art/data/orison_v2/roof_source.json').read_text())
layout=json.loads((ROOT/'game/data/orison_v2_blockout.json').read_text())
decks=[r['rect'] for r in source['records']['spaces'] if r['id'].startswith('ROOF_DECK_')]
x0,z0=min(r[0] for r in decks),min(r[1] for r in decks)
x1,z1=max(r[2] for r in decks),max(r[3] for r in decks)
y=source['records']['levels'][0]['y'];slab=layout['dimensions']['slab_thickness']
reach=layout['dimensions']['outer_wall']-layout['dimensions']['partition_wall']/2
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.context.preferences.filepaths.save_version=0
material=bpy.data.materials.new('concrete');material.diffuse_color=(.36,.34,.30,1)
strips=[('South',0,[x0-reach,y-slab,z0-reach],[x1+reach,y,z0]),
        ('North',0,[x0-reach,y-slab,z1],[x1+reach,y,z1+reach]),
        ('West',2,[x0-reach,y-slab,z0],[x0,y,z1]),
        ('East',2,[x1,y-slab,z0],[x1+reach,y,z1])]
parts=[];manifest=[]
for side,axis,low,high in strips:
    count=math.ceil((high[axis]-low[axis])/4)
    for index in range(count):
        lo=low.copy();hi=high.copy()
        lo[axis]=low[axis]+(high[axis]-low[axis])*index/count
        hi[axis]=low[axis]+(high[axis]-low[axis])*(index+1)/count
        vertices=[(x,-z,v) for x in [lo[0],hi[0]] for v in [lo[1],hi[1]] for z in [lo[2],hi[2]]]
        # Only genuine strip end caps. Culling divisions add no hidden faces.
        faces=[(0,1,3,2),(4,6,7,5),(0,4,5,1),(2,3,7,6),(0,2,6,4),(1,5,7,3)]
        if axis==0:
            if index>0:faces.remove((0,1,3,2))
            if index<count-1:faces.remove((4,6,7,5))
        else:
            if index>0:faces.remove((0,2,6,4))
            if index<count-1:faces.remove((1,5,7,3))
        name='RoofEdge_'+side+'_%02d'%index
        mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update()
        obj=bpy.data.objects.new(name,mesh);bpy.context.scene.collection.objects.link(obj);parts.append(obj)
        bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
        uv=mesh.uv_layers.new(name='Metres');uv.active_render=True
        for face in mesh.polygons:
            drop=max(range(3),key=lambda k:abs(face.normal[k]));a,b=((1,2),(0,2),(0,1))[drop]
            for loop in face.loop_indices:
                p=mesh.vertices[mesh.loops[loop].vertex_index].co;uv.data[loop].uv=(p[a],p[b])
        mesh.materials.append(material)
        manifest.append(dict(id=name,side=side,bounds=lo+hi,internal_caps=False))
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/roof_edge_support.blend'))
bpy.ops.object.select_all(action='SELECT')
class ExportUVHandedness:
    partitions=0
    def gather_attribute_change(self,attribute,data,normalized,export_settings):
        if attribute=='TANGENT':data['data'][:,3]*=-1;type(self).partitions+=1
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension=ExportUVHandedness
bpy.ops.export_scene.gltf(filepath=str(ROOT/'game/assets/props/roof_edge_support.glb'),export_format='GLB',export_yup=True,export_tangents=True)
assert ExportUVHandedness.partitions==len(parts)
(ROOT/'art/blender/roof_edge_support_construction.json').write_text(json.dumps(dict(evidence_class='INERT',
    authority=['art/data/orison_v2/roof_source.json','game/data/orison_v2_blockout.json:dimensions'],
    roof_datum=y,depth_m=slab,outer_reach_m=reach,parts=manifest),indent=2)+'\n')
print('ROOF EDGE SUPPORT:',len(parts),'bounded parts; retained deck/parapet/coping geometry unchanged')
