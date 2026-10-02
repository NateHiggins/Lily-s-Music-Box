"""Source-owned roof closures, preserving the two original interior ceilings."""
from pathlib import Path
import json,math
import bpy
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
layout=json.loads((ROOT/'game/data/orison_v2_blockout.json').read_text())
roof=json.loads((ROOT/'art/data/orison_v2/roof_source.json').read_text())
y=roof['records']['levels'][0]['y']
depth=layout['dimensions']['slab_thickness']
half_wall=layout['dimensions']['partition_wall']/2
bottom=y+layout['dimensions']['clear_height'];top=bottom+depth
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.context.preferences.filepaths.save_version=0
material=bpy.data.materials.new('concrete');material.diffuse_color=(.36,.34,.30,1)
parts=[];records=[]
def horizontal(rect,height,up):
    a,b,c,d=rect
    points=[(a,-b,height),(a,-d,height),(c,-d,height),(c,-b,height)]
    return points if up else list(reversed(points))
for room in roof['records']['spaces']:
    if room.get('no_ceiling'):continue
    assert room in layout['spaces'],'Regenerate the roof projection before fabrication'
    assert not any(r['space']==room['id'] and r['surface']=='Ceiling' for r in layout['slab_openings']),'Roof cap apertures need fitted reveals and collision ownership'
    x0,z0,x1,z1=room['rect']
    outer=[x0-half_wall,z0-half_wall,x1+half_wall,z1+half_wall]
    nx=math.ceil((outer[2]-outer[0])/4);nz=math.ceil((outer[3]-outer[1])/4)
    rim=[[outer[0],outer[1],outer[2],z0],[outer[0],z1,outer[2],outer[3]],
         [outer[0],z0,x0,z1],[x1,z0,outer[2],z1]]
    for ix in range(nx):
        for iz in range(nz):
            a=outer[0]+(outer[2]-outer[0])*ix/nx;c=outer[0]+(outer[2]-outer[0])*(ix+1)/nx
            b=outer[1]+(outer[3]-outer[1])*iz/nz;d=outer[1]+(outer[3]-outer[1])*(iz+1)/nz
            faces=[horizontal([a,b,c,d],top,True)]
            # Only true outer edges; no caps at spatial culling divisions.
            if ix==0:faces.append([(a,-b,bottom),(a,-d,bottom),(a,-d,top),(a,-b,top)])
            if ix==nx-1:faces.append([(c,-b,bottom),(c,-b,top),(c,-d,top),(c,-d,bottom)])
            if iz==0:faces.append([(a,-b,bottom),(a,-b,top),(c,-b,top),(c,-b,bottom)])
            if iz==nz-1:faces.append([(a,-d,bottom),(c,-d,bottom),(c,-d,top),(a,-d,top)])
            for ra,rb,rc,rd in rim:
                rect=[max(a,ra),max(b,rb),min(c,rc),min(d,rd)]
                if rect[2]-rect[0]>1e-6 and rect[3]-rect[1]>1e-6:faces.append(horizontal(rect,bottom,False))
            name=room['id']+'_Cap_%02d_%02d'%(ix,iz)
            vertices=[p for face in faces for p in face]
            mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],[tuple(range(i,i+4)) for i in range(0,len(vertices),4)]);mesh.update()
            obj=bpy.data.objects.new(name,mesh);bpy.context.scene.collection.objects.link(obj)
            uv=mesh.uv_layers.new(name='Metres');uv.active_render=True
            for face in mesh.polygons:
                drop=max(range(3),key=lambda k:abs(face.normal[k]));u,v=((1,2),(0,2),(0,1))[drop]
                for loop in face.loop_indices:
                    p=mesh.vertices[mesh.loops[loop].vertex_index].co;uv.data[loop].uv=(p[u],p[v])
            mesh.materials.append(material);parts.append(obj)
            records.append(dict(id=name,space=room['id'],bounds=[a,bottom,b,c,top,d],original_underside=room['rect'],internal_caps=False))
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/roof_bulkhead_caps.blend'))
bpy.ops.object.select_all(action='SELECT')
class ExportUVHandedness:
    partitions=0
    def gather_attribute_change(self,attribute,data,normalized,export_settings):
        if attribute=='TANGENT':data['data'][:,3]*=-1;type(self).partitions+=1
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension=ExportUVHandedness
bpy.ops.export_scene.gltf(filepath=str(ROOT/'game/assets/props/roof_bulkhead_caps.glb'),export_format='GLB',export_yup=True,export_tangents=True)
assert ExportUVHandedness.partitions==len(parts)
(ROOT/'art/blender/roof_bulkhead_caps_construction.json').write_text(json.dumps(dict(evidence_class='INERT',authority=['art/data/orison_v2/roof_source.json','game/data/orison_v2_blockout.json:dimensions'],parts=records),indent=2)+'\n')
print('ROOF BULKHEAD CAPS:',len(parts),'bounded pieces; original interior ceiling surfaces retained')
