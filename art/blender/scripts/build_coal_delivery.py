"""Reuse the accepted coal-hole assembly and author its sloping cellar chute.

Run with Blender -b -P. Coordinates below are Godot metres relative to the
source-owned bunker anchor; the assembly adapter converts its Blender frame.
The pavement cover remains shut: this is fuel-delivery architecture, not a
second fuel simulation or a new maintenance activity.
"""
import ast
import math
from pathlib import Path
import sys
import bpy
import bmesh
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_lift_drive import box, material, point

ROOT = Path(__file__).resolve().parents[3]


class CoverFrame:
    def __init__(self, materials):
        self.materials = materials

    def box(self, mat, x0, y0, z0, x1, y1, z1):
        box('CoverDiamond', ((x0+x1)/2, 3.2+(z0+z1)/2, -2.8-(y0+y1)/2),
            (x1-x0, z1-z0, y1-y0), self.materials[mat])

    def lathe(self, mat, cx, cy, profile, n):
        vertices = [(cx+r*math.cos(i*2*math.pi/n), 2.8+cy+r*math.sin(i*2*math.pi/n), 3.2+z)
                    for r,z in profile for i in range(n)]
        faces = [(j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i)
                 for j in range(len(profile)-1) for i in range(n)]
        mesh=bpy.data.meshes.new('CoalCoverLathe')
        mesh.from_pydata(vertices,[],faces)
        mesh.materials.append(self.materials[mat])
        obj=bpy.data.objects.new('CoalCover',mesh)
        bpy.context.collection.objects.link(obj)


def main():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    mats={'cast_iron':material('cast_iron',(.09,.095,.09),.6,.8),
          'metal':material('metal',(.22,.23,.21),.75,.65),
          'soot':material('soot',(.022,.019,.017))}
    # Execute only this established assembly, never the old whole-building build.
    tree=ast.parse((ROOT/'art/blender/scripts/build_orison.py').read_text(encoding='utf-8'))
    function=next(n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='asm_coal_chute')
    namespace={'math':math}
    exec(compile(ast.Module(body=[function],type_ignores=[]),'coal_cover','exec'),namespace)
    namespace['asm_coal_chute'](CoverFrame(mats),{})
    # A 45-degree gravity run under the closed pavement plate. Four sheet-metal
    # sides leave a real open outlet rather than a solid box painted black.
    start=Vector((0,3.10,-2.8))
    end=Vector((0,1.0,-.7))
    direction=(end-start).normalized()
    normal=Vector((0,direction.z,-direction.y))
    length=(end-start).length
    center=(start+end)/2
    for offset,size in [(Vector((-.28,0,0)),(.025,.56,length)),
                        (Vector((.28,0,0)),(.025,.56,length)),
                        (normal*.28,(.56,.025,length)),
                        (-normal*.28,(.56,.025,length))]:
        obj=box('ChuteSheet',center+offset,size,mats['metal'])
        obj.rotation_mode='QUATERNION'
        obj.rotation_quaternion=Vector((0,1,0)).rotation_difference(point(direction))
    # Raised cast mouth and wall straps make the delivery direction legible.
    for t in [.12,.45,.8]:
        at=start.lerp(end,t)
        for x in [-.302,.302]:
            obj=box('ChuteStrap',at+Vector((x,0,0)),(.025,.62,.055),mats['cast_iron'])
            obj.rotation_mode='QUATERNION'
            obj.rotation_quaternion=Vector((0,1,0)).rotation_difference(point(direction))

    # Trim the sloping shell below the pavement seat. Without this cut the
    # upper corners of a full rectangular tube protrude alongside the plate.
    for obj in list(bpy.context.scene.objects):
        if obj.type != 'MESH' or not obj.name.startswith('Chute'):
            continue
        bpy.ops.object.select_all(action='DESELECT')
        obj.select_set(True)
        bpy.context.view_layer.objects.active=obj
        bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
        mesh=bmesh.new()
        mesh.from_mesh(obj.data)
        bmesh.ops.bisect_plane(mesh,geom=list(mesh.verts)+list(mesh.edges)+list(mesh.faces),
                              plane_co=(0,0,3.14),plane_no=(0,0,1),clear_outer=True)
        mesh.to_mesh(obj.data)
        mesh.free()
    for mat in mats.values():
        members=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.data.materials[0]==mat]
        bpy.ops.object.select_all(action='DESELECT')
        for obj in members: obj.select_set(True)
        bpy.context.view_layer.objects.active=members[0]
        bpy.ops.object.join()
        members[0].name='CoalDelivery_'+mat.name
    output=ROOT/'game/assets/building/v2_coal_delivery.glb'
    bpy.ops.export_scene.gltf(filepath=str(output),export_format='GLB',export_apply=True,export_yup=True,export_animations=False)
    print('Exported coal delivery:',output)


if __name__=='__main__': main()
