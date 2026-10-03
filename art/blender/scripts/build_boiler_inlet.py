"""Fit steel sleeves and bolted bearing plates to the retained steam inlet.

The authored crossings own every seat. Accepted boiler pipework is unchanged.
Native dimensional pieces remain editable; the export unions welded interfaces
and carries metre UVs and corrected imported tangent handedness.
"""
from pathlib import Path
import json, math
import bpy, bmesh
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[3]
source=json.loads((ROOT/'art/data/orison_v2/boiler_inlet_source.json').read_text())
assert source['schema_version']==1
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.context.preferences.filepaths.save_version=0
steel=bpy.data.materials.new('metal');steel.diffuse_color=(.32,.31,.28,1)
construction=bpy.data.collections.new('EditableFitParts');bpy.context.scene.collection.children.link(construction)
parts=[];bearings=[]
origin=(8.675,-.55,.525)
def point(p):return (p[0]-origin[0],-(p[2]-origin[2]),p[1]-origin[1])
def add(name,vertices,faces):
    mesh=bpy.data.meshes.new(name);mesh.from_pydata([point(p) for p in vertices],[],faces);mesh.update()
    obj=bpy.data.objects.new(name,mesh);obj.location=(origin[0],-origin[2],origin[1])
    construction.objects.link(obj);parts.append(obj)
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
    return obj
def box(name,lo,hi):
    vertices=[(x,y,z) for x in [lo[0],hi[0]] for y in [lo[1],hi[1]] for z in [lo[2],hi[2]]]
    return add(name,vertices,[(0,1,3,2),(4,6,7,5),(0,4,5,1),(2,3,7,6),(0,2,6,4),(1,5,7,3)])
def cylinder(name,center,axis,lo,hi,radius,sides):
    u,v=[i for i in range(3) if i!=axis];vertices=[]
    for station in [lo,hi]:
        for k in range(sides):
            p=list(center);p[axis]=station;p[u]+=radius*math.cos(k*math.tau/sides);p[v]+=radius*math.sin(k*math.tau/sides);vertices.append(p)
    return add(name,vertices,[tuple(range(sides-1,-1,-1)),tuple(range(sides,2*sides))]+
               [(k,(k+1)%sides,(k+1)%sides+sides,k+sides) for k in range(sides)])
def plate(name,center,axis,face,sign):
    u,v=[i for i in range(3) if i!=axis];vertices=[];faces=[];sides=64
    # 2.5 mm seats within the fabric; 1.5 mm shows outside it. This also
    # clears the accepted west-wall escutcheon's back by 0.5 mm.
    thickness=source['plate_thickness_m']
    stations=[face-sign*thickness*.625,face+sign*thickness*.375]
    for station in stations:
        for radius in [source['plate_bore_radius_m'],None]:
            for k in range(sides):
                angle=k*math.tau/sides;c,s=math.cos(angle),math.sin(angle)
                r=radius if radius is not None else source['plate_half_width_m']/max(abs(c),abs(s))
                p=list(center);p[axis]=station;p[u]+=r*c;p[v]+=r*s;vertices.append(p)
    for k in range(sides):
        n=(k+1)%sides
        faces.extend([(k,n,n+sides,k+sides),(k+2*sides,k+3*sides,n+3*sides,n+2*sides),
                      (k,k+2*sides,n+2*sides,n),(k+sides,n+sides,n+3*sides,k+3*sides)])
    add(name,vertices,faces)
    for du in [-source['fastener_offset_m'],source['fastener_offset_m']]:
        for dv in [-source['fastener_offset_m'],source['fastener_offset_m']]:
            at=list(center);at[axis]=face;at[u]+=du;at[v]+=dv
            a,b=sorted([face-sign*.012,face+sign*.002])
            cylinder(name+'_FixedBoltShank',at,axis,a,b,.003,12)
            a,b=sorted([face+sign*.001,face+sign*.005])
            cylinder(name+'_HexBoltHead',at,axis,a,b,.0055,6)
    bearings.append(dict(id=name,owner=current['owner'],axis=axis,face=face,sign=sign,center=center,
                         half_width=source['plate_half_width_m'],fastener_offset=source['fastener_offset_m']))

for current in source['sleeves']:
    ports=[p for rows in source['records'].values() for p in rows if p.get('space',p.get('riser'))==current['owner']]
    assert len(ports)==1,current['id']+' must have one authored structural crossing'
    clear=ports[0]['bounds'];seat=current['bounds']
    assert all(clear[i]<=seat[i]+1e-6 and clear[i+3]>=seat[i+3]-1e-6 for i in range(3)),current['id']+' leaves its authored crossing'
    low=current['bounds'][:3];high=current['bounds'][3:];axis=current['axis'];u,v=[i for i in range(3) if i!=axis]
    center=[(low[i]+high[i])/2 for i in range(3)];t=source['sheet_thickness_m']
    for cross in [u,v]:
        for sign in [-1,1]:
            lo=list(low);hi=list(high)
            if sign<0:hi[cross]=lo[cross]+t
            else:lo[cross]=hi[cross]-t
            box(current['id']+f'_Lining{cross}_{sign}',lo,hi)
    for face in current['faces']:
        sign=-1 if abs(face-low[axis])<1e-6 else 1
        plate(current['id']+('_NearPlate' if sign<0 else '_FarPlate'),center,axis,face,sign)

# Union the retained editable solids into one watertight inspection/export
# draw. There are no overlapping render surfaces at sheet/plate/bolt welds.
obj=bpy.data.objects.new('InletFabricLining',parts[0].data.copy());bpy.context.collection.objects.link(obj)
obj.location=parts[0].location
bpy.context.view_layer.objects.active=obj
for part in parts[1:]:
    mod=obj.modifiers.new('Weld_'+part.name,'BOOLEAN');mod.operation='UNION';mod.solver='EXACT';mod.object=part
    bpy.ops.object.modifier_apply(modifier=mod.name)
mesh=obj.data
mesh.validate(verbose=True,clean_customdata=False)
bm=bmesh.new();bm.from_mesh(mesh)
bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-7)
bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-7)
bmesh.ops.triangulate(bm,faces=list(bm.faces))
bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-6)
bmesh.ops.triangulate(bm,faces=list(bm.faces))
bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
nonmanifold=sum(not e.is_manifold for e in bm.edges)
print('BOILER INLET UNION: nonmanifold_edges='+str(nonmanifold))
assert nonmanifold==0,'Steel union must have closed surfaces'
bm.to_mesh(mesh);bm.free()
mesh.materials.clear();mesh.materials.append(steel)
uv=mesh.uv_layers.new(name='Metres');uv.active_render=True
for face in mesh.polygons:
    normal=face.normal.normalized();seed=Vector((0,0,1)) if abs(normal.z)<.9 else Vector((0,1,0))
    u=normal.cross(seed).normalized();v=normal.cross(u).normalized();origin=mesh.vertices[face.vertices[0]].co
    for loop in face.loop_indices:
        p=mesh.vertices[mesh.loops[loop].vertex_index].co-origin;uv.data[loop].uv=(p.dot(u),p.dot(v))
construction.hide_render=True;construction.hide_viewport=True
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/boiler_inlet.blend'))
bpy.ops.object.select_all(action='DESELECT');obj.select_set(True)
class ExportUVHandedness:
    partitions=0
    def gather_attribute_change(self,attribute,data,normalized,export_settings):
        if attribute=='TANGENT':data['data'][:,3]*=-1;type(self).partitions+=1
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension=ExportUVHandedness
bpy.ops.export_scene.gltf(filepath=str(ROOT/'game/assets/props/boiler_inlet.glb'),export_format='GLB',
                         export_yup=True,export_tangents=True,use_selection=True)
assert ExportUVHandedness.partitions==1
out=ROOT/'tmp/boiler-inlet';out.mkdir(parents=True,exist_ok=True)
(out/'construction.json').write_text(json.dumps(dict(evidence_class='INERT',sleeves=3,plates=bearings,
                                                    fixed_bolts=20,native_parts=len(parts)),indent=2)+'\n')
print('BOILER INLET: sleeves=3 plates=5 bolts=20 native_parts='+str(len(parts)))
