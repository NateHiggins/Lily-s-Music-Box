"""Angular bunker coal inside the existing authored pile envelope."""
from pathlib import Path
import math,random
import bpy,bmesh
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
rng=random.Random(290928)
mat=bpy.data.materials.new('soot');mat.use_nodes=True
mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.025,.022,.019,1)
mat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.8

def point(x,y,z):return (x,-z,y)
# A continuous, closed faceted mound avoids cracks between the surface lumps.
n=48;rings=7;verts=[point(0,.50,0)];faces=[]
for j in range(1,rings+1):
    r=j/rings
    for i in range(n):
        a=i*math.tau/n
        h=.50*(1-r**1.4)**.85+(rng.uniform(-.014,.014) if j<rings else 0)
        verts.append(point(.475*r*math.cos(a),h,.85*r*math.sin(a)))
for i in range(n):faces.append((0,1+i,1+(i+1)%n))
for j in range(rings-1):
    for i in range(n):
        a=1+j*n+i;b=1+j*n+(i+1)%n
        faces.extend([(a,b,b+n),(a,b+n,a+n)])
faces.append(tuple(1+(rings-1)*n+i for i in range(n)))
mesh=bpy.data.meshes.new('Continuous heap');mesh.from_pydata(verts,[],faces);mesh.update()
obj=bpy.data.objects.new('HeapCore',mesh);bpy.context.collection.objects.link(obj);obj.data.materials.append(mat)

def lump(x,y,z,radius):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1,location=point(x,y,z))
    obj=bpy.context.object;obj.name='BrokenCoal'
    obj.scale=(radius*rng.uniform(.8,1.2),radius*rng.uniform(.85,1.35),radius*rng.uniform(.6,1))
    for v in obj.data.vertices:v.co*=rng.uniform(.80,1.18)
    obj.rotation_euler=(rng.uniform(-.6,.6),rng.uniform(-.6,.6),rng.uniform(0,math.tau))
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    for v in obj.data.vertices:v.co.z=max(0,v.co.z)
    obj.data.materials.append(mat)
for row in range(15):
    base_z=-.79+row*.112
    for col in range(9):
        x=-.44+col*.11;z=base_z
        r=math.sqrt((x/.475)**2+(z/.85)**2)
        if r>.97:continue
        x+=rng.uniform(-.02,.02);z+=rng.uniform(-.02,.02)
        h=.50*max(0,1-r**1.4)**.85
        lump(x,h,z,rng.uniform(.038,.069))
# Preserve the scattered toe positions from the original authored assembly.
for k in range(9):
    a=math.tau*((k*97)%360)/360;r=.95*.52+(k%3)*.09
    radius=.035+((k*31)%5)*.012
    lump(math.cos(a)*r,radius*.52,-math.sin(a)*(1.7*.52+(k%2)*.08),radius*.83)
for obj in list(bpy.context.scene.objects):
    bm=bmesh.new();bm.from_mesh(obj.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(obj.data);bm.free()
    uv=obj.data.uv_layers.new(name='UVMap')
    for poly in obj.data.polygons:
        axis=max(range(3),key=lambda i:abs(poly.normal[i]));axes=((1,2),(0,2),(0,1))[axis]
        for loop in poly.loop_indices:
            v=obj.data.vertices[obj.data.loops[loop].vertex_index].co;uv.data[loop].uv=(v[axes[0]],v[axes[1]])
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/coal_heap.blend'))
bpy.ops.object.select_all(action='SELECT');bpy.context.view_layer.objects.active=bpy.context.scene.objects[0];bpy.ops.object.join()
bpy.context.object.name='CoalHeap';bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
bpy.ops.export_scene.gltf(filepath=str(ROOT/'game/assets/props/coal_heap.glb'),export_format='GLB',export_yup=True,export_apply=True)
