"""Fabricate shared crowned blind stock, hardware and sewn pleated cloth.
Drapery (design/ORISON_DRAPERY_2026-10-24.md): the pleated overdrape has a
flat buckram heading carried on brass curtain rings by sewn-in hooks; sheer
ninon glass curtains are finely gathered, one with a scalloped lace hem whose
eyelets and picots are modelled openings, not a painted pattern.
Blender meters: X width, Y depth, Z height; Godot imports Y up.
"""
from pathlib import Path
import math
import bpy

ROOT = Path(__file__).resolve().parents[3]
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
materials = {}
for key in ['blind_slat', 'linen', 'fabric_warm', 'brass_dull']:
    mat = bpy.data.materials.new(key); mat.use_nodes = True
    mat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value = .6
    materials[key] = mat

def finish(obj, name, key, bevel=0):
    obj.name = name; obj.data.materials.clear(); obj.data.materials.append(materials[key])
    if bevel:
        mod = obj.modifiers.new('Stock edge radius', 'BEVEL'); mod.width = bevel; mod.segments = 3
        bpy.context.view_layer.objects.active = obj; bpy.ops.object.modifier_apply(modifier=mod.name)
    # Meter charts. Large sheets have continuous sewn-cloth UV below.
    for previous in list(obj.data.uv_layers): obj.data.uv_layers.remove(previous)
    uv = obj.data.uv_layers.new(name='StockMetres')
    for face in obj.data.polygons:
        n = face.normal; axis = max(range(3), key=lambda i: abs(n[i]))
        axes = [(1, 2), (0, 2), (0, 1)][axis]
        for loop in face.loop_indices:
            v = obj.data.vertices[obj.data.loops[loop].vertex_index].co
            uv.data[loop].uv = (v[axes[0]], v[axes[1]])
    return obj

def box(name, size, key, bevel):
    bpy.ops.mesh.primitive_cube_add(size=1)
    obj = bpy.context.object; obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, name, key, bevel)

# A fixed 50 mm chord rotates; never reshape a box to fake tilt.
section = []
for side in [1, -1]:
    indices = range(13) if side == 1 else range(12, -1, -1)
    for i in indices:
        depth = -.025 + .05*i/12
        crown = .0015*(1-(depth/.025)**2)
        section.append((depth, crown+side*.00125))
n = len(section)
vertices = [(x, y, z) for x in [-.5,.5] for y,z in section]
faces = [tuple(reversed(range(n))),tuple(range(n,n*2))]
faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
mesh = bpy.data.meshes.new('CrownedWoodSlat'); mesh.from_pydata(vertices,[],faces); mesh.update()
slat = bpy.data.objects.new('CrownedWoodSlat',mesh); bpy.context.collection.objects.link(slat)
finish(slat,'CrownedWoodSlat','blind_slat')
uv = slat.data.uv_layers.active
perimeter = [0.0]
for i in range(n-1): perimeter.append(perimeter[-1]+math.dist(section[i],section[i+1]))
for face in mesh.polygons:
    for loop in face.loop_indices:
        index = mesh.loops[loop].vertex_index
        uv.data[loop].uv = (vertices[index][0]+.5, perimeter[index%n]) if len(face.vertices)==4 else (vertices[index][1],vertices[index][2])
for face in mesh.polygons: face.use_smooth = len(face.vertices)==4
box('HeadRail',(1,.065,.052),'blind_slat',.004)
box('BottomRail',(1,.05,.024),'blind_slat',.003)
box('MountBracket',(.032,.07,.055),'brass_dull',.001)
box('CurtainRod',(1,.014,.014),'brass_dull',.003)
box('CurtainBracket',(.018,.18,.04),'brass_dull',.002)
box('SewnTab',(.012,.012,.040),'linen',.001)
box('CordStock',(.003,.003,1),'linen',.0005)
box('LadderRung',(1,.0025,.0025),'linen',.0004)
box('CordTassel',(.018,.018,.045),'blind_slat',.005)
box('TiltWand',(.009,.009,.42),'blind_slat',.002)

# Closed, double-sided cloth with a shallow gathered crown and generous folds.
# Top is Z=0; normalized length descends to Z=-1.
nx, ny = 64, 24
vertices = []
for side in [-1,1]:
    for j in range(ny+1):
        v=j/ny
        for i in range(nx+1):
            u=i/nx
            wave=math.sin(u*math.tau*8+.08*math.sin(v*math.pi))
            # Buckram heading: the pleat wave is pinched flat in the top band so
            # the heading hangs in one line under the rod, carried by its rings.
            heading=min(1.0,max(0.0,(v-.015)/.05));heading=heading*heading*(3-2*heading)
            depth=(.042*wave*(.78+.22*v)+.006*math.sin(v*math.pi*3+u*8))*heading
            # Sewn lower hem has physical thickness, not a painted shadow.
            thickness=.0015 if v<.95 else .003
            vertices.append((u-.5,depth+side*thickness/2,-v))
row=nx+1; layer=row*(ny+1); faces=[]
for side in range(2):
    for j in range(ny):
        for i in range(nx):
            a=side*layer+j*row+i; face=(a,a+1,a+1+row,a+row)
            faces.append(face if side else tuple(reversed(face)))
for j in range(ny):
    for i in [0,nx]:
        a=j*row+i;faces.append((a,a+row,a+row+layer,a+layer))
for i in range(nx):
    for j in [0,ny]:
        a=j*row+i;faces.append((a,a+layer,a+layer+1,a+1))
mesh=bpy.data.meshes.new('PleatedSewnPanel');mesh.from_pydata(vertices,[],faces);mesh.update()
obj=bpy.data.objects.new('PleatedSewnPanel',mesh);bpy.context.collection.objects.link(obj)
finish(obj,'PleatedSewnPanel','linen')
for face in mesh.polygons:
    face.use_smooth=True
    if face.index>=2*nx*ny:continue
    for loop in face.loop_indices:
        v=mesh.vertices[mesh.loops[loop].vertex_index].co
        obj.data.uv_layers.active.data[loop].uv=(v.x+.5,-v.z)

# Brass curtain ring around a rod running along X, and the sewn hook below it.
bpy.ops.mesh.primitive_torus_add(major_radius=.016,minor_radius=.0028,major_segments=24,minor_segments=8,rotation=(0,math.pi/2,0))
ring=bpy.context.object;bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
finish(ring,'CurtainRing','brass_dull')
for face in ring.data.polygons:face.use_smooth=True
box('RingHook',(.003,.003,.014),'brass_dull',.0008)

def sheer(name, lace):
    """A single-layer finely gathered sheer (drawn double-sided by its shader).
    Top is Z=0, normalized length descends to Z=-1; a lace hem adds a band
    below Z=-1 whose eyelets, picots and scallops are cut from the grid."""
    nx=384 if lace else 192
    rows=40 if lace else 24
    band=.075 if lace else 0.0
    scallops=24
    def fold(u,v):
        heading=min(1.0,max(0.0,(v-.012)/.04));heading=heading*heading*(3-2*heading)
        return .014*math.sin(u*math.tau*14+.3*math.sin(v*2.1))*heading*(.85+.15*v)
    vs=[v/rows for v in range(rows+1)]
    if lace:
        lace_rows=30
        vs+= [1.0+band*(j/lace_rows) for j in range(1,lace_rows+1)]
    EYELETS=((.5,.40,.17,.06),(.25,.58,.07,.025),(.75,.58,.07,.025))
    def snap(u,v):
        """Pull lace-band vertices onto the true scallop and eyelet curves, so the
        cut edges are smooth arcs rather than grid steps at the same density."""
        if not lace or v<=1.0:return u,v
        t=(v-1.0)/band;k=math.floor(u*scallops);cell=u*scallops-k
        edge=1.0-.32*(1.0-math.sin(math.pi*min(max(cell,0.0),1.0)))
        if t>edge:t=edge
        for cx,ty,ru,rt in EYELETS:
            d=((cell-cx)/ru)**2+((t-ty)/rt)**2
            if 1e-9<d<1.0:
                r=math.sqrt(d);cell=cx+(cell-cx)/r;t=ty+(t-ty)/r
        return (k+cell)/scallops,1.0+band*t
    verts=[]
    for v in vs:
        for i in range(nx+1):
            su,sv=snap(i/nx,v)
            verts.append((su-.5,fold(su,sv),-sv))
    row=nx+1;faces=[]
    def air(u,v,v_top):
        if v<=1.0:return False
        t=(v-1.0)/band
        cell=(u*scallops)%1.0
        # scalloped lower edge: a cell is cloth while its top is inside the
        # scallop; snap() then pulls its lower edge onto the curve.
        edge=1.0-.32*(1.0-math.sin(math.pi*cell))
        if (v_top-1.0)/band>=edge:return True
        # a round eyelet centred in each scallop, a smaller pair flanking it
        # (a scallop is ~37 mm wide on a 0.9 m panel; the band ~110 mm deep on a
        # 1.5 m drop, so a round 13 mm eyelet is .17 of a cell by .06 of the band)
        for cx,ty,ru,rt in EYELETS:
            if (cell-cx)**2/(ru**2)+(t-ty)**2/(rt**2)<1.0:return True
        # picot holes between scallops, just above the foot
        if (cell<.06 or cell>.94) and .62<t<.70:return True
        # a ruled openwork line at the top of the band
        if .07<t<.12 and int(u*nx)%3==0:return True
        return False
    for j in range(len(vs)-1):
        for i in range(nx):
            u=(i+.5)/nx;v=(vs[j]+vs[j+1])*.5
            if lace and air(u,v,vs[j]):continue
            a=j*row+i;faces.append((a,a+1,a+1+row,a+row))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
    finish(obj,name,'linen')
    for face in mesh.polygons:
        face.use_smooth=True
        for loop in face.loop_indices:
            v=mesh.vertices[mesh.loops[loop].vertex_index].co
            obj.data.uv_layers.active.data[loop].uv=(v.x+.5,-v.z)
    bpy.context.view_layer.objects.active=obj;obj.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.delete_loose()
    bpy.ops.object.mode_set(mode='OBJECT');obj.select_set(False)
    return obj
sheer('GatheredSheerPanel',False)
sheer('LaceEdgedSheerPanel',True)

for obj in bpy.context.scene.objects:
    if obj.type!='MESH':continue
    bpy.context.view_layer.objects.active=obj;obj.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False);bpy.ops.object.mode_set(mode='OBJECT');obj.select_set(False)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/window_treatments.blend'))
bpy.ops.export_scene.gltf(filepath=str(ROOT/'game/assets/props/window_treatments.glb'),export_format='GLB',export_yup=True,export_apply=True)
