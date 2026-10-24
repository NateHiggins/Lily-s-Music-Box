"""Native curtain skin authoring helper.
Called only after original UV/normal repair and per-material batching.
Never edits geometry, UV coordinates, materials or nonvisual authorities.
"""
import bpy
import hashlib
import json
import math
import struct
from mathutils import Vector, Matrix
PHYSICAL=1.72+math.pi*.06
LOGICAL=1.96
SEGMENTS=96

def rail(s):
    s=max(0.,min(PHYSICAL,s))
    if s<.58:return Vector((-.34,-.32+s,0)),Vector((0,1,0))
    s-=.58
    if s<math.pi*.03:
        a=math.pi+s/.06
        return Vector((-.28+.06*math.cos(a),.26-.06*math.sin(a),0)),Vector((-math.sin(a),-math.cos(a),0))
    s-=math.pi*.03
    if s<.56:return Vector((-.28+s,.32,0)),Vector((1,0,0))
    s-=.56
    if s<math.pi*.03:
        a=math.pi*1.5+s/.06
        return Vector((.28+.06*math.cos(a),.26-.06*math.sin(a),0)),Vector((-math.sin(a),-math.cos(a),0))
    s-=math.pi*.03
    return Vector((.34,.26-s,0)),Vector((0,-1,0))

def distance(at):
    candidates=[max(0.,min(.58,at.y+.32)),.58+math.pi*.03+max(0.,min(.56,at.x+.28)),PHYSICAL-max(0.,min(.58,at.y+.32))]
    for cx, start_angle, offset in [(-.28,math.pi,.58),(.28,math.pi*1.5,.58+math.pi*.03+.56)]:
        angle=math.atan2(.26-at.y,at.x-cx)
        if angle<0:angle+=math.tau
        angle=max(start_angle,min(start_angle+math.pi*.5,angle))
        candidates.append(offset+(angle-start_angle)*.06)
    return min(candidates,key=lambda s:(rail(s)[0]-Vector((at.x,at.y,0))).length_squared)

def mesh_digest(obj):
    digest=hashlib.sha256()
    for vertex in obj.data.vertices:digest.update(struct.pack('<3f',*vertex.co))
    for polygon in obj.data.polygons:
        digest.update(struct.pack('<I',len(polygon.vertices)))
        for index in polygon.vertices:digest.update(struct.pack('<I',index))
    for uv in obj.data.uv_layers:
        for value in uv.data:digest.update(struct.pack('<2f',*value.uv))
    return digest.hexdigest()

def install_curtain_skin():
    parent=bpy.data.objects["CurtainDrawn"]
    cloth=bpy.data.objects["CurtainDrawn_shower_duck"]
    hardware=bpy.data.objects["CurtainDrawn_nickel_plated"]
    before={obj.name:mesh_digest(obj) for obj in [cloth,hardware]}
    data=bpy.data.armatures.new('CurtainRailSkin')
    rig=bpy.data.objects.new('CurtainRailSkin',data)
    bpy.context.collection.objects.link(rig);rig.parent=parent
    bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);bpy.context.view_layer.objects.active=rig
    bpy.ops.object.mode_set(mode='EDIT')
    rows=[]
    for kind,count in [('Cloth',SEGMENTS+1),('Ring',19)]:
        for i in range(count):
            fraction=i/(count-1);point,tangent=rail(fraction*PHYSICAL)
            name='Curtain%s%03d'%(kind,i)
            bone=data.edit_bones.new(name)
            # Independent rest frames: X follows rail, Y points up, Z is cloth depth.
            up=Vector((0,0,1));normal=tangent.cross(up)
            frame=Matrix((tangent,up,normal)).transposed().to_4x4();frame.translation=point
            bone.matrix=frame;bone.length=.04
            rows.append({'name':name,'kind':kind,'u':fraction,'point':[point.x,point.z,-point.y],'tangent':[tangent.x,tangent.z,-tangent.y]})
    bpy.ops.object.mode_set(mode='OBJECT')
    for obj in [cloth,hardware]:
        assert len(obj.vertex_groups)==0,obj.name
        for row in rows:obj.vertex_groups.new(name=row['name'])
        modifier=obj.modifiers.new('Native curtain rail skin','ARMATURE');modifier.object=rig
        modifier.use_vertex_groups=True

    for vertex in cloth.data.vertices:
        u=distance(cloth.matrix_world@vertex.co)/PHYSICAL
        value=max(0.,min(SEGMENTS,u*SEGMENTS));lo=min(SEGMENTS,int(value));hi=min(SEGMENTS,lo+1)
        weight=value-lo
        cloth.vertex_groups[lo].add([vertex.index],1.-weight,'REPLACE')
        if hi!=lo and weight>0:cloth.vertex_groups[hi].add([vertex.index],weight,'REPLACE')

    # Keep each torus, eyelet and hook rigid even though its material draw is batched.
    leaders=list(range(len(hardware.data.vertices)))
    def find(i):
        while leaders[i]!=i:leaders[i]=leaders[leaders[i]];i=leaders[i]
        return i
    for edge in hardware.data.edges:
        a,b=map(find,edge.vertices)
        if a!=b:leaders[b]=a
    components={}
    for vertex in hardware.data.vertices:components.setdefault(find(vertex.index),[]).append(vertex.index)
    ring_counts=[0]*19
    for indices in components.values():
        center=sum((hardware.matrix_world@hardware.data.vertices[i].co for i in indices),Vector())/len(indices)
        index=max(0,min(18,round(distance(center)/PHYSICAL*18)))
        hardware.vertex_groups[SEGMENTS+1+index].add(indices,1.,'REPLACE');ring_counts[index]+=1
    assert min(ring_counts)>0,ring_counts
    for obj in [cloth,hardware]:
        assert before[obj.name]==mesh_digest(obj)
        for vertex in obj.data.vertices:
            assert 1<=len(vertex.groups)<=2,(obj.name,vertex.index)
            assert abs(sum(group.weight for group in vertex.groups)-1)<1e-6
    return {"schema_version":1,"logical_length":LOGICAL,"physical_length":PHYSICAL,"bones":rows,"bone_count":len(rows),"hardware_components":len(components),"ring_component_counts":ring_counts,"unchanged_mesh_uv_digests":before,"maximum_weights":2}
