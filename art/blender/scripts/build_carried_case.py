"""The player's carried case and the small set of shapes goods take inside it.

Blender 5.2: blender -b --python-exit-code 1 -P art/blender/scripts/build_carried_case.py
Writes art/blender/carried_case.blend, game/assets/props/carried_case.glb and
game/data/carried_case.json. Generated glTF is never hand-edited.

A pharmacy-flavoured valise of about 1928: leather over board, brass corners and latches, and a
rust cloth lining stitched into five-centimetre squares, so the grid the hand arranges
on is a thing in the case. Tray origin is the lining floor's centre; the lid's origin
is its hinge line, so the game can open it by turning one node.
"""
import json, math, sys, os, hashlib
sys.dont_write_bytecode = True
from pathlib import Path
import bpy, bmesh, numpy as np
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(Path(__file__).parent))
from fabrication_uvs import chart_for_triangle
from metric_gltf_export import CatalogueMetricUV

CELL, COLS, ROWS = .05, 10, 6
W, D = CELL * COLS, CELL * ROWS
WALL, SHELL = .012, .008
TRAY_H, LID_H = .085, .045
SETS = json.loads((ROOT / 'game/data/runtime_material_sets.json').read_text(encoding='utf-8'))['materials']
KEYS = ['leather_worn', 'brass_dull', 'fabric_warm', 'linen', 'paper', 'bakelite_black', 'brass', 'milk_glass']
# Per-use tile is already part of the runtime contract. Finer canvas, same registered maps.
TILES = {key: (.14 if key == 'fabric_warm' else SETS[key]['meters_per_tile']) for key in KEYS}

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version = 0
stock = {}   # assembly -> key -> individual manufacturing stocks
CURRENT_ROLE = 'manufactured stock'
REVIEW = Path('C:/ov/reports/claude30/shops/review')
REVIEW.mkdir(parents=True, exist_ok=True)


def add(assembly, key, verts, faces, curved=False):
    stock.setdefault(assembly, {}).setdefault(key, []).append(([tuple(v) for v in verts], faces, CURRENT_ROLE, curved))


def box(assembly, key, low, high, bevel=.0015):
    x0, y0, z0 = low
    x1, y1, z1 = high
    mesh = bpy.data.meshes.new('blank')
    verts = [(x, y, z) for z in (z0, z1) for y in (y0, y1) for x in (x0, x1)]
    mesh.from_pydata(verts, [], [(0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4), (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5)])
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    if bevel and min(x1 - x0, y1 - y0, z1 - z0) > bevel * 2.2:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=2, affect='EDGES', profile=.7)
    assert all(e.is_manifold for e in bm.edges)
    bm.verts.index_update()
    add(assembly, key, [v.co[:] for v in bm.verts], [[v.index for v in f.verts] for f in bm.faces])
    bm.free()
    bpy.data.meshes.remove(mesh)


def lathe(assembly, key, a, axis, profile, n=20):
    """Turned stock. Profile rows are (distance along axis, radius)."""
    a, axis = Vector(a), Vector(axis).normalized()
    seed = Vector((0, 0, 1)) if abs(axis.z) < .9 else Vector((1, 0, 0))
    u = axis.cross(seed).normalized()
    v = axis.cross(u)
    verts = [a + axis * d + r * (u * math.cos(i * math.tau / n) + v * math.sin(i * math.tau / n)) for d, r in profile for i in range(n)]
    faces = [list(range(n))[::-1]]
    for ring in range(len(profile) - 1):
        faces += [[ring * n + i, ring * n + (i + 1) % n, (ring + 1) * n + (i + 1) % n, (ring + 1) * n + i] for i in range(n)]
    faces.append(list(range((len(profile) - 1) * n, len(profile) * n)))
    add(assembly, key, verts, faces, True)


def rod(assembly, key, a, b, r, n=10):
    a, b = Vector(a), Vector(b)
    lathe(assembly, key, a, b - a, [(0, r), ((b - a).length, r)], n)


def torus(assembly, key, center, R, r, n=24, m=8):
    verts = []
    for i in range(n):
        t = i * math.tau / n
        for j in range(m):
            s = j * math.tau / m
            verts.append((center[0] + (R + r * math.cos(s)) * math.cos(t), center[1] + (R + r * math.cos(s)) * math.sin(t), center[2] + r * math.sin(s)))
    add(assembly, key, verts, [[i * m + j, ((i + 1) % n) * m + j, ((i + 1) % n) * m + (j + 1) % m, i * m + (j + 1) % m] for i in range(n) for j in range(m)])


# First-pass helpers retained above. New fabrication uses the same dimensions,
# assembly ABI, local hinge coordinates, per-material batching and metre charts.
def role(label):
    global CURRENT_ROLE
    CURRENT_ROLE = label


def prism(assembly, key, outline, z0, z1):
    count = len(outline)
    add(assembly, key, [(x,y,z) for z in [z0,z1] for x,y in outline],
        [list(range(count-1,-1,-1)),list(range(count,2*count))]+
        [[i,(i+1)%count,(i+1)%count+count,i+count] for i in range(count)])


def tube(assembly,key,path,r=.0007,n=8):
    points=[Vector(p) for p in path]; verts=[]; faces=[]
    for i,p in enumerate(points):
        direction=(points[min(i+1,len(points)-1)]-points[max(0,i-1)]).normalized()
        seed=Vector((0,0,1)) if abs(direction.z)<.9 else Vector((1,0,0))
        u=direction.cross(seed).normalized();v=direction.cross(u)
        for j in range(n):
            a=j*math.tau/n;verts.append(tuple(p+r*(u*math.cos(a)+v*math.sin(a))))
    for i in range(len(points)-1):
        for j in range(n):faces.append([i*n+j,i*n+(j+1)%n,(i+1)*n+(j+1)%n,(i+1)*n+j])
    faces += [list(range(n-1,-1,-1)),list(range((len(points)-1)*n,len(points)*n))]
    add(assembly,key,verts,faces,True)


def sleeve(assembly,key,a,axis,profile,n=16):
    # A closed section (distance,radius) revolved around an axis: real central bore.
    a,axis=Vector(a),Vector(axis).normalized();seed=Vector((0,0,1)) if abs(axis.z)<.9 else Vector((1,0,0))
    u=axis.cross(seed).normalized();v=axis.cross(u);verts=[];faces=[]
    for d,r in profile:
        for i in range(n):
            theta=i*math.tau/n;verts.append(tuple(a+axis*d+r*(u*math.cos(theta)+v*math.sin(theta))))
    for k in range(len(profile)):
        kk=(k+1)%len(profile)
        for i in range(n):faces.append([k*n+i,k*n+(i+1)%n,kk*n+(i+1)%n,kk*n+i])
    add(assembly,key,verts,faces,True)


def band(assembly,key,y0,y1,r,zc,angles=(.20,math.pi-.20),n=14):
    # Blank paper wrapper, curved over the bottle; finite paper thickness.
    verts=[];faces=[]
    for radius in [r-.00025,r]:
        for y in [y0,y1]:
            for theta in np.linspace(*angles,n+1):verts.append((radius*math.cos(theta),y,zc+radius*math.sin(theta)))
    m=n+1
    for j in range(n):
        faces += [[j,j+1,m+j+1,m+j],[2*m+j,3*m+j,3*m+j+1,2*m+j+1],
                  [j,2*m+j,2*m+j+1,j+1],[m+j,m+j+1,3*m+j+1,3*m+j]]
    faces += [[0,m,3*m,2*m],[n,2*m+n,3*m+n,m+n]]
    add(assembly,key,verts,faces,True)


def stitch(assembly,a,b,step=.010,width=.0012):
    a,b=Vector(a),Vector(b);delta=b-a;length=delta.length;direction=delta/length
    for d in np.arange(.001,length-.004,step):
        end=min(d+.0065,length-.001);mid=(a+direction*d+a+direction*end)/2
        # Four-sided thread is enough at the 720p reading distance.
        rod(assembly,'linen',a+direction*d,a+direction*end,width/2,4 if CURRENT_ROLE=='5cm sewn inventory grid' else 3)


def cap(assembly,sx,sy,z0,z1,youter):
    # Three folded 0.8mm sheets form an actual corner cap, never a solid block.
    x=sx*(W/2+WALL);y=sy*youter;span=.021;t=.0008
    lo,hi=sorted([x-sx*span,x+sx*t]);yy0,yy1=sorted([y-sy*span,y+sy*t])
    box(assembly,'brass_dull',(lo,yy0,z0),(hi,yy1,z0+t),0)
    xa,xb=sorted([x,x+sx*t]);ya,yb=sorted([y,y+sy*t])
    box(assembly,'brass_dull',(xa,yy0,z0+t),(xb,yy1,z1),0)
    box(assembly,'brass_dull',(lo,ya,z0+t),(hi,yb,z1),0)
    # Rivet shanks disappear into real boards; domed heads follow each fold.
    for zz in [z0+.005,z1-.004]:
        lathe(assembly,'brass',(x+sx*t,y-sy*.009,zz),(sx,0,0),[(0,.0012),(.0005,.0014),(.0012,.0006)],10)
        lathe(assembly,'brass',(x-sx*.009,y+sy*t,zz),(0,sy,0),[(0,.0012),(.0005,.0014),(.0012,.0006)],10)


# ---- the tray ---------------------------------------------------------------
HW,HD=W/2,D/2;OW,OD=HW+WALL,HD+WALL;T='Tray';L='Lid';HY=OD
FRONT_H=.012
role('leather-clad board shell')
box(T,'leather_worn',(-OW,-OD,-SHELL),(OW,OD,-.002),.0018)
for sx in [-1,1]:
    x0,x1=sorted([sx*HW,sx*OW]);box(T,'leather_worn',(x0,-OD,-.002),(x1,OD,TRAY_H),.002)
# Rear hinge reliefs keep moving knuckles clear of the board and its lining.
box(T,'leather_worn',(-HW,HD,-.002),(HW,OD,.0805),.001)
for a,b in [(-HW,-.197),(-.143,.143),(.197,HW)]:
    box(T,'leather_worn',(a,HD,.0805),(b,OD,TRAY_H),.0008)
# Sample-case construction: low front return, deep overlapping lid apron.
box(T,'leather_worn',(-HW,-OD,-.002),(HW,-HD,FRONT_H),.0018)
role('rust stitched lining')
box(T,'fabric_warm',(-HW,-HD,-.002),(HW,HD,0),0)
for sx in [-1,1]:
    a,b=sorted([sx*HW,sx*(HW-.001)])
    box(T,'fabric_warm',(a,-HD,0),(b,HD,TRAY_H-.002),0)
box(T,'fabric_warm',(-HW,HD-.001,0),(HW,HD,.080),0)
box(T,'fabric_warm',(-HW,-HD,0),(HW,-HD+.001,FRONT_H-.002),0)
role('5cm sewn inventory grid')
for i in range(1,COLS):
    x=-HW+i*CELL;stitch(T,(x,-HD+.002,.0006),(x,HD-.002,.0006))
for j in range(1,ROWS):
    y=-HD+j*CELL;stitch(T,(-HW+.002,y,.0006),(HW-.002,y,.0006))
# A welted leather border and shorter saddle stitches, not a gilt modern extrusion.
role('edge binding and saddle seam')
for sx in [-1,1]:
    tube(T,'leather_worn',[(sx*(OW-.001),-OD+.002,TRAY_H),(sx*(OW-.001),OD-.002,TRAY_H)],.002,8)
    stitch(T,(sx*(HW+.006),-OD+.004,TRAY_H+.0005),(sx*(HW+.006),OD-.004,TRAY_H+.0005),.014,.0008)
tube(T,'leather_worn',[(-HW,-OD+.001,FRONT_H),(HW,-OD+.001,FRONT_H)],.002,8)
stitch(T,(-HW+.005,-OD-.0002,FRONT_H-.005),(HW-.005,-OD-.0002,FRONT_H-.005),.012,.0008)
for a,b in [(-OW,-.198),(-.142,.142),(.198,OW)]:
    rod(T,'leather_worn',(a,OD-.001,TRAY_H),(b,OD-.001,TRAY_H),.002,8)
role('folded brass cap with seated rivets')
for sx in [-1,1]:
    for sy in [-1,1]:
        cap(T,sx,sy,-SHELL-.0008,.019,OD)
        lathe(T,'brass_dull',(sx*(OW-.045),sy*(OD-.045),-SHELL),(0,0,-1),[(0,.005),(.003,.005),(.004,.003)],12)
# Repair patches on the outside, with stitched repair rather than arbitrary grime.
role('old corner repair')
box(T,'leather_worn',(.178,-OD-.0008,.003),(.231,-OD,.018),.0005)
stitch(T,(.183,-OD-.0012,.005),(.226,-OD-.0012,.005),.007,.00065)
stitch(T,(.183,-OD-.0012,.016),(.226,-OD-.0012,.016),.007,.00065)
role('seated latch plates and handle saddles')
for x in [-.15,.15]:
    box(T,'brass_dull',(x-.018,-OD-.002,.002),(x+.018,-OD-.0002,.023),.0005)
    box(T,'brass',(x-.006,-OD-.004,.012),(x+.006,-OD-.0018,.025),.0005)
    for xx in [x-.012,x+.012]:
        lathe(T,'brass',(xx,-OD-.002,.009),(0,-1,0),[(0,.001),(.0006,.0013),(.001,.0007)],10)
for x in [-.065,.065]:
    box(T,'brass_dull',(x-.010,-OD-.002,.003),(x+.010,-OD,.020),.0006)
    sleeve(T,'brass',(x-.006,-OD-.006,.012),(1,0,0),[(0,.003),(.012,.003),(.012,.0015),(0,.0015)],12)
role('stitched rolled leather carrying handle')
tube(T,'leather_worn',[(-.065,-OD-.008,.012),(-.052,-OD-.029,.012),(-.037,-OD-.034,.012),(.037,-OD-.034,.012),(.052,-OD-.029,.012),(.065,-OD-.008,.012)],.005,10)
stitch(T,(-.037,-OD-.034,.017),(.037,-OD-.034,.017),.008,.0007)

# ---- lid: original hinge-local rest pose and 104-degree owner rotation -------
def lid_y(y):return y-HY
role('lid leather-clad board and weather apron')
box(L,'leather_worn',(-OW,lid_y(-OD),LID_H),(OW,0,LID_H+SHELL),.002)
for sx in [-1,1]:
    a,b=sorted([sx*HW,sx*OW]);box(L,'leather_worn',(a,lid_y(-OD),0),(b,0,LID_H),.0018)
box(L,'leather_worn',(-HW,lid_y(HD),0),(HW,0,LID_H),.0018)
box(L,'leather_worn',(-HW,lid_y(-OD),0),(HW,lid_y(-HD),LID_H),.0018)
# The deeper outer apron seals the low front return without entering the inventory.
box(L,'leather_worn',(-OW,lid_y(-.171),-.073),(OW,lid_y(-.165),LID_H+.001),.0015)
role('padded rust lid lining')
box(L,'fabric_warm',(-HW,lid_y(-HD),LID_H-.002),(HW,lid_y(HD),LID_H),.0005)
for sx in [-1,1]:
    tube(L,'leather_worn',[(sx*(OW-.001),lid_y(-OD),.001),(sx*(OW-.001),-.002,.001)],.0018,8)
    stitch(L,(sx*(HW+.006),lid_y(-OD)+.004,.0005),(sx*(HW+.006),-.004,.0005),.014,.0008)
tube(L,'leather_worn',[(-OW,lid_y(-.170),-.072),(OW,lid_y(-.170),-.072)],.0015,8)
role('folded lid corner caps')
for sx in [-1,1]:
    # same folded-cap recipe in lid-local coordinates
    before=len(stock.get(L,{}).get('brass_dull',[]));cap(L,sx,1,LID_H+.0004,LID_H+.009,0.0)
    # front cap hand-built around the apron edge, avoiding a filled block
    x=sx*OW;u,v=sorted([x-sx*.021,x+sx*.0008]);y=lid_y(-.171)
    box(L,'brass_dull',(u,y-.0008,-.073),(v,y,LID_H+.0005),0)
    a,b=sorted([x,x+sx*.0008]);box(L,'brass_dull',(a,y,-.073),(b,y+.021,LID_H+.0005),0)
    for xx in [x-sx*.009]:
        for zz in [-.052,.035]:lathe(L,'brass',(xx,y-.0008,zz),(0,-1,0),[(0,.0011),(.0007,.0014),(.0012,.0005)],10)
# Real hollow pocket: finite cloth shell, two gussets, open mouth and a rolled hem.
role('gusseted linen pocket with open mouth')
xs=[-.232,-.12,0,.12,.232];ys=[lid_y(-.135),lid_y(-.070),lid_y(.012)]
# Inner-lid-facing surface hangs below the backing, with a gentle cloth belly.
front=[]
for y in ys:
    for x in xs:
        bulge=.009*(1-(x/.24)**2);front.append((x,y,.032-bulge))
verts=front+[(x,y,z+.0007) for x,y,z in front];faces=[];nx=len(xs);ny=len(ys);N=len(front)
for j in range(ny-1):
    for i in range(nx-1):
        a=j*nx+i;faces += [[a,a+1,a+nx+1,a+nx],[N+a,N+a+nx,N+a+nx+1,N+a+1]]
edge=list(range(nx))+[j*nx+nx-1 for j in range(1,ny)]+list(range((ny-1)*nx+nx-2,(ny-1)*nx-1,-1))+[j*nx for j in range(ny-2,0,-1)]
for a,b in zip(edge,edge[1:]+edge[:1]):faces.append([a,N+a,N+b,b])
add(L,'linen',verts,faces,True)
for sx in [-1,1]:
    x=sx*.232;box(L,'linen',(min(x,x-sx*.002),ys[0],.032),(max(x,x-sx*.002),ys[-1],.043),0)
pocket_outline=[(x,.032-.009*(1-(x/.24)**2)) for x in xs]+[(.232,.043),(-.232,.043)]
verts=[(x,y,z) for y in [ys[0],ys[0]+.0007] for x,z in pocket_outline];n=len(pocket_outline)
add(L,'linen',verts,[list(range(n-1,-1,-1)),list(range(n,2*n))]+[[i,(i+1)%n,(i+1)%n+n,i+n] for i in range(n)])
tube(L,'leather_worn',[(x,ys[-1],.032-.009*(1-(x/.24)**2)-.0004) for x in xs],.0012,8)
for sx in [-1,1]:stitch(L,(sx*.228,ys[0]+.003,.030),(sx*.228,ys[-1]-.003,.030),.010,.0007)
# Two strapped, buckled retention bands flank the card; actual open buckle centres.
role('buckled leather retention straps')
for x in [-.17,.17]:
    box(L,'leather_worn',(x-.010,lid_y(.027),.040),(x+.010,-.012,.0425),.0006)
    for xx in [x-.014,x+.014]:rod(L,'brass',(xx,-.100,.0378),(xx,-.081,.0378),.0012,8)
    for yy in [-.100,-.081]:rod(L,'brass',(x-.014,yy,.0378),(x+.014,yy,.0378),.0012,8)
    rod(L,'brass_dull',(x,-.101,.038),(x,-.086,.037),.0008,8)
    box(L,'leather_worn',(x-.010,-.085,.036),(x+.010,-.074,.0385),.0005)
role('brass-framed blank contents card at fixed runtime datum')
for x in [-.089,.089]:box(L,'brass_dull',(x-.003,-.119,.040),(x+.003,-.025,.043),.0005)
for y in [-.117,-.027]:box(L,'brass_dull',(-.086,y-.003,.040),(.086,y+.003,.043),.0005)
box(L,'paper',(-.085,-.114,.0428),(.085,-.030,.0438),0)
# Two true captive-pin hinge pairs, with board relief authored above.
role('bored hinge knuckles and seated leaves')
for x in [-.17,.17]:
    for a,b in [(-.022,-.014),(-.004,.004),(.014,.022)]:
        sleeve(T,'brass_dull',(x+a,HY,TRAY_H),(1,0,0),[(0,.0033),(b-a,.0033),(b-a,.0018),(0,.0018)],12)
    for a,b in [(-.0136,-.0044),(.0044,.0136)]:
        sleeve(L,'brass_dull',(x+a,0,0),(1,0,0),[(0,.0032),(b-a,.0032),(b-a,.0018),(0,.0018)],12)
    rod(T,'brass',(x-.024,HY,TRAY_H),(x+.024,HY,TRAY_H),.0016,12)
    box(T,'brass_dull',(x-.021,HY+.001,.063),(x+.021,HY+.0024,.0825),.0005)
    box(L,'brass_dull',(x-.019,-.015,.0007),(x+.019,-.002,.0023),.0004)
    for xx in [x-.014,x+.014]:
        lathe(T,'brass',(xx,HY+.0024,.069),(0,1,0),[(0,.001),(.0008,.0014),(.0012,.0005)],10)
for x in [-.15,.15]:
    box(L,'brass_dull',(x-.008,lid_y(-.172),-.072),(x+.008,lid_y(-.171),-.057),.0005)
    rod(L,'brass',(x-.006,lid_y(-.173),-.066),(x+.006,lid_y(-.173),-.066),.0011,8)

# Lid reinforcement bands and a small exterior saddle repair, all retained by the lid.
role('stitched exterior leather reinforcement bands')
for x in [-.17,.17]:
    box(L,'leather_worn',(x-.011,lid_y(-OD)+.002,LID_H+SHELL),(x+.011,-.003,LID_H+SHELL+.0014),.0004)
    for xx in [x-.0075,x+.0075]:stitch(L,(xx,lid_y(-OD)+.006,LID_H+SHELL+.0018),(xx,-.006,LID_H+SHELL+.0018),.014,.0007)
# The exposed top perimeter is a separate rolled binding with clear edge normals.
for sx in [-1,1]:
    rod(L,'leather_worn',(sx*(OW-.001),lid_y(-OD),LID_H+SHELL),(sx*(OW-.001),0,LID_H+SHELL),.0015,8)
for yy in [lid_y(-OD),0]:
    rod(L,'leather_worn',(-OW+.002,yy,LID_H+SHELL),(OW-.002,yy,LID_H+SHELL),.0015,8)
role('exterior field repair with saddle stitching')
box(L,'leather_worn',(-.116,lid_y(-.1722),-.031),(-.070,lid_y(-.171),-.009),.0005)
for zz in [-.027,-.013]:stitch(L,(-.112,lid_y(-.1726),zz),(-.074,lid_y(-.1726),zz),.007,.00075)
for xx in [-.111,-.075]:stitch(L,(xx,lid_y(-.1726),-.027),(xx,lid_y(-.1726),-.013),.007,.00075)

role('empty pharmacy-style instrument loops with sewn anchor tabs')
for x in [-.125,.125]:
    for y in [-.105,-.059]:
        sleeve(L,'leather_worn',(x,y,.036),(0,1,0),[(0,.0065),(.012,.0065),(.012,.0055),(0,.0055)],12)
        box(L,'leather_worn',(x-.008,y-.001,.0424),(x+.008,y+.013,.0431),0)
        for yy in [y+.001,y+.011]:stitch(L,(x-.007,yy,.0421),(x+.007,yy,.0421),.007,.0006)

# ---- packed forms: same eleven names and footprints, local floor at zero ----
FORMS={'bottle':[1,2],'tin':[1,1],'box':[2,1],'packet':[1,1],'flat':[2,3],'tool':[1,3],
       'roll':[1,1],'jar':[1,1],'card':[1,1],'valve':[1,2],'parcel':[2,2]}
role('bottle body, rolled lip and screw closure')
lathe('Form_bottle','bakelite_black',(0,-.047,.019),(0,1,0),[(0,.013),(.002,.018),(.006,.019),(.054,.019),(.063,.011),(.071,.007),(.083,.007)],24)
lathe('Form_bottle','bakelite_black',(0,.035,.019),(0,1,0),[(0,.0075),(.002,.0085),(.010,.0085),(.012,.0075)],16)
band('Form_bottle','paper',-.033,-.003,.0193,.019)
role('rolled tin, recessed lid and pull loop')
lathe('Form_tin','brass_dull',(0,0,0),(0,0,1),[(0,.018),(.0015,.0215),(.003,.0215),(.0035,.020),(.0185,.020),(.0195,.022),(.021,.022),(.022,.0205)],24)
torus('Form_tin','brass',(0,0,.0221),.0165,.00055,20,5)
tube('Form_tin','brass',[(.003,-.005,.0224),(.008,-.003,.0234),(.009,.004,.0234),(.002,.007,.0224)],.0007,8)
role('folded carton with glued end flaps')
box('Form_box','paper',(-.047,-.022,0),(.047,.022,.025),.001)
for y in [-.0221,.0216]:box('Form_box','paper',(-.045,y,.002),(.045,y+.0005,.023),0)
box('Form_box','paper',(-.046,-.001,.025),(.046,.001,.0255),0)
role('folded paper packet')
box('Form_packet','paper',(-.0215,-.0215,0),(.0215,.0215,.008),.001)
prism('Form_packet','paper',[(-.020,-.018),(.020,-.018),(0,.010)],.008,.0086)
rod('Form_packet','linen',(-.020,-.018,.0088),(0,.010,.0088),.00035,4)
role('flat invoice folder, layered paper and stitched spine')
box('Form_flat','leather_worn',(-.0475,-.0725,0),(.0475,.0725,.0012),.0004)
for j in range(4):
    xoff=(j%2)*.0004;box('Form_flat','paper',(-.046+xoff,-.071,.0013+j*.0015),(.046+xoff,.071,.0025+j*.0015),0)
box('Form_flat','paper',(-.0465,-.072,.0075),(.047,.072,.0082),0)
box('Form_flat','linen',(-.0475,-.0725,.0012),(-.0445,.0725,.009),0)
role('slotted cabinet screwdriver with phenolic handle and brass ferrule')
lathe('Form_tool','bakelite_black',(0,-.072,.010),(0,1,0),[(0,.005),(.003,.0085),(.009,.010),(.042,.009),(.048,.006)],12)
lathe('Form_tool','brass',(0,-.025,.010),(0,1,0),[(0,.0065),(.006,.0065),(.007,.004)],16)
rod('Form_tool','brass_dull',(0,-.019,.010),(0,.061,.010),.0027,12)
# Blade broadens from the round shank and tapers to an actual flat slot edge.
add('Form_tool','brass_dull',[(-.0027,.058,.0073),(.0027,.058,.0073),(-.0027,.058,.0127),(.0027,.058,.0127),(-.0045,.072,.0093),(.0045,.072,.0093),(-.0045,.072,.0107),(.0045,.072,.0107)],
    [[0,4,5,1],[2,3,7,6],[0,1,3,2],[4,6,7,5],[0,2,6,4],[1,5,7,3]])
role('hollow cloth roll and paper core')
sleeve('Form_roll','linen',(0,-.022,.018),(0,1,0),[(0,.018),(.044,.018),(.044,.0045),(0,.0045)],24)
sleeve('Form_roll','paper',(0,-.0224,.018),(0,1,0),[(0,.0046),(.0448,.0046),(.0448,.003),(0,.003)],16)
box('Form_roll','linen',(.012,-.018,0),(.022,.015,.0012),.0003)
role('lying opal jar with threaded dark lid')
lathe('Form_jar','milk_glass',(0,-.0225,.0185),(0,1,0),[(0,.012),(.003,.0185),(.030,.0185),(.034,.0145),(.036,.0145)],24)
lathe('Form_jar','bakelite_black',(0,.0125,.0185),(0,1,0),[(0,.015),(.002,.016),(.0085,.016),(.010,.0145)],20)
band('Form_jar','paper',-.012,.004,.0188,.0185)
role('stiff blank cards with exposed ply')
for j in range(3):box('Form_card','paper',(-.0215,-.0215,j*.0011),(.0215,.0215,j*.0011+.0009),.00025)
role('replacement radio valve, pear bulb, moulded base and exposed contact pins')
lathe('Form_valve','milk_glass',(0,-.019,.0185),(0,1,0),[(0,.011),(.005,.0145),(.012,.0185),(.033,.0185),(.044,.0155),(.052,.0105),(.057,.005),(.059,.002)],24)
lathe('Form_valve','bakelite_black',(0,-.038,.0185),(0,1,0),[(0,.014),(.002,.015),(.016,.015),(.019,.012)],20)
for u,v in [(-.007,-.007),(.007,-.007),(-.007,.007),(.007,.007)]:
    xx=u*math.cos(.436)-v*math.sin(.436);zz=.0185+u*math.sin(.436)+v*math.cos(.436)
    lathe('Form_valve','brass',(xx,-.0475,zz),(0,1,0),[(0,.0008),(.001,.0012),(.0095,.0012)],10)
lathe('Form_valve','brass_dull',(0,.041,.0185),(0,1,0),[(0,.0025),(.004,.0025)],12)
role('wrapped parcel with folded ears and tied cord')
outline=[(-.041,-.046),(.039,-.046),(.046,-.038),(.046,.039),(.038,.046),(-.039,.046),(-.046,.038),(-.046,-.039)]
prism('Form_parcel','paper',outline,0,.032)
for sign in [-1,1]:
    yy=sign*.044;prism('Form_parcel','paper',[(-.039,yy),(.039,yy),(0,sign*.013)],.032,.0327)
for swap in [False,True]:
    path=[(0,-.0465,.0009),(0,-.0465,.0336),(0,-.025,.034),(0,.025,.034),(0,.0465,.0336),(0,.0465,.0009)]
    if swap:path=[(y,x,z) for x,y,z in path]
    tube('Form_parcel','fabric_warm',path,.0008,8)
for sign in [-1,1]:
    tube('Form_parcel','fabric_warm',[(0,0,.035),(sign*.010,-.009,.038),(sign*.018,-.003,.040),(sign*.012,.005,.038),(0,0,.035)],.0008,8)
tube('Form_parcel','fabric_warm',[(0,0,.035),(.013,.014,.035),(.020,.024,.033)],.0008,8)

# ---- owner-approved pharmacy valise / forward shelf conversion ---------------
# Keep the working first-pass fabrication, then remap its existing panels rather
# than throw away the case, lining, card, caps, goods or manufacturing helpers.
OPEN_DEGREES=104.0
SHELF_HINGE=Vector((0,.155,0))
REST=Matrix.Rotation(math.radians(-OPEN_DEGREES),4,'X')
BODY_EXTRA_DEPTH=.045
BODY_WIDTH_SCALE=1.065
legacy=stock;stock={}

def closed_shelf(p):return REST@(Vector(p)-SHELF_HINGE)
def body_point(x,u,d):return SHELF_HINGE+REST@Vector((x,-u,d))
def mapped_box(assembly,key,low,high,mapping,bevel=0):
    box(assembly,key,low,high,bevel)
    vv,ff,label,curved=stock[assembly][key][-1]
    stock[assembly][key][-1]=([tuple(mapping(Vector(v))) for v in vv],ff,label,curved)

for assembly in ['Tray','Lid']:
    for key,pieces in legacy[assembly].items():
        for vv,ff,label,curved in pieces:
            pp=np.array(vv);low=pp.min(0);high=pp.max(0)
            if label=='bored hinge knuckles and seated leaves':continue
            if assembly=='Tray':
                # Retire the old suitcase handle/latches; this is now a front door.
                if label in ['stitched rolled leather carrying handle','seated latch plates and handle saddles']:continue
                if label=='leather-clad board shell' and low[1]>=HD-1e-6 and high[2]>0:continue
                if label=='rust stitched lining' and low[1]>=HD-.00101 and high[2]>.03:continue
                if label=='edge binding and saddle seam' and low[1]>.155:continue
                if label=='folded brass cap with seated rivets' and low[1]>.130:continue
                for v in pp:
                    if label in ['leather-clad board shell','rust stitched lining'] and high[2]>.03 and v[2]>0:v[2]*=.012/TRAY_H
                    elif label=='edge binding and saddle seam' and low[2]>.035:v[2]-=TRAY_H-.012
                    # Side returns end before the hinge; the back edge stays open.
                    if label in ['leather-clad board shell','rust stitched lining','edge binding and saddle seam'] and abs(float((low[0]+high[0])/2))>.248 and v[1]>.14:
                        v[1]=.14+(v[1]-.14)*(.005/(OD-.14))
                    elif v[1]>.15:v[1]=.15+(v[1]-.15)/6
                new=[tuple(closed_shelf(v)) for v in pp];target='Lid'
            else:
                # A wider cabinet opening clears the returning shelf corner caps.
                if label=='lid leather-clad board and weather apron' and low[1]>-.013 and high[1]<1e-6:continue
                if label=='lid leather-clad board and weather apron' and high[0]-low[0]<.02 and abs((high[0]+low[0])/2)>.25 and high[1]-low[1]>.30:continue
                structural=label in ['lid leather-clad board and weather apron','padded rust lid lining','folded lid corner caps','stitched exterior leather reinforcement bands','exterior field repair with saddle stitching']
                for v in pp:
                    if structural:v[0]*=BODY_WIDTH_SCALE
                    if label=='lid leather-clad board and weather apron':
                        if low[2]>-.001 and low[2]<.01 and high[2]>.04:v[2]=2*v[2]-.045
                        if low[1]<-.32 and high[1]<-.30 and high[1]>-.325:v[1]-=.012
                new=[tuple(SHELF_HINGE+REST@Vector((v[0],v[1],v[2]+BODY_EXTRA_DEPTH))) for v in pp];target='Tray'
            stock.setdefault(target,{}).setdefault(key,[]).append((new,ff,label,curved))
# Goods remain unmodified local templates, with the same footprints and origins.
for assembly,groups in legacy.items():
    if assembly.startswith('Form_'):stock[assembly]=groups

role('valise bottom frame with genuine hinge relief')
# Fixed cabinet bottom: a4mm inner lip, and clear radial pockets at both hinges.
mapped_box('Tray','leather_worn',(-HW*BODY_WIDTH_SCALE,-.004,.006),(HW*BODY_WIDTH_SCALE,.004,.090),lambda v:body_point(*v),.0007)
for a,b in [(-HW*BODY_WIDTH_SCALE,-.226),(-.174,.174),(.226,HW*BODY_WIDTH_SCALE)]:
    mapped_box('Tray','leather_worn',(a,-.004,0),(b,.004,.006),lambda v:body_point(*v),.0005)
role('valise end boards with front stay-receiver reliefs')
for side in [-1,1]:
    x0,x1=sorted([side*HW*BODY_WIDTH_SCALE,side*OW*BODY_WIDTH_SCALE])
    mapped_box('Tray','leather_worn',(x0,0,.012),(x1,.324,.090),lambda v:body_point(*v),.0008)
    for u0,u1 in [(0,.201),(.229,.324)]:
        mapped_box('Tray','leather_worn',(x0,u0,0),(x1,u1,.012),lambda v:body_point(*v),.0008)
role('stitched outside reinforcement of the forward shelf')
for x in [-.17,.17]:
    mapped_box('Lid','leather_worn',(x-.011,-.158,-.0095),(x+.011,.149,-.008),closed_shelf,.0004)
    for xx in [x-.0075,x+.0075]:
        before=len(stock.get('Lid',{}).get('linen',[]));stitch('Lid',(xx,-.154,-.0098),(xx,.145,-.0098),.014,.0007)
        for k in range(before,len(stock['Lid']['linen'])):
            vv,ff,ll,cc=stock['Lid']['linen'][k];stock['Lid']['linen'][k]=([tuple(closed_shelf(v)) for v in vv],ff,ll,cc)
role('fixed valise top handle and riveted saddles')
tube('Tray','leather_worn',[body_point(x,u,.045) for x,u in [(-.065,.336),(-.053,.364),(-.038,.372),(.038,.372),(.053,.364),(.065,.336)]],.005,10)
for x in [-.065,.065]:
    mapped_box('Tray','brass_dull',(x-.010,.331,.038),(x+.010,.338,.052),lambda v:body_point(*v),.0006)
    rod('Tray','brass',body_point(x-.007,.337,.045),body_point(x+.007,.337,.045),.002,10)
role('forward panel closure plates and fixed valise receivers')
for x in [-.15,.15]:
    mapped_box('Lid','brass_dull',(x-.017,-.151,-.011),(x+.017,-.124,-.0095),closed_shelf,.0005)
    mapped_box('Lid','brass',(x-.006,-.166,-.014),(x+.006,-.140,-.011),closed_shelf,.0004)
    # Receiver has an actual clear slot around the shelf hasp, not a solid block.
    for xx0,xx1 in [(x-.009,x-.0065),(x+.0065,x+.009)]:
        mapped_box('Tray','brass_dull',(xx0,.319,-.013),(xx1,.329,-.009),lambda v:body_point(*v),.0003)
    mapped_box('Tray','brass_dull',(x-.0065,.3214,-.013),(x+.0065,.325,-.009),lambda v:body_point(*v),.0003)
role('new front shelf captive-pin hinges')
for x in [-.20,.20]:
    for a,b in [(-.022,-.014),(-.004,.004),(.014,.022)]:
        sleeve('Tray','brass_dull',SHELF_HINGE+Vector((x+a,0,0)),(1,0,0),[(0,.0033),(b-a,.0033),(b-a,.0018),(0,.0018)],12)
        mapped_box('Tray','brass_dull',(x+a,-.0015,.002),(x+b,.0015,.014),lambda v:body_point(*v),0)
    for a,b in [(-.0136,-.0044),(.0044,.0136)]:
        sleeve('Lid','brass_dull',(x+a,0,0),(1,0,0),[(0,.0032),(b-a,.0032),(b-a,.0018),(0,.0018)],12)
        mapped_box('Lid','brass_dull',(x+a,.135,-.003),(x+b,.153,-.0015),closed_shelf,0)
    rod('Tray','brass',SHELF_HINGE+Vector((x-.024,0,0)),SHELF_HINGE+Vector((x+.024,0,0)),.0016,12)

STAY_LENGTH=.200
STAY_SIDES={'Port':-1,'Starboard':1}
def stay_pose(degrees,side):
    a=Vector((0,.280,.208));bo=Vector((0,-.060,.004));b=SHELF_HINGE+Matrix.Rotation(math.radians(degrees-OPEN_DEGREES),4,'X')@(bo-SHELF_HINGE)
    diff=b-a;distance=diff.length;assert distance<2*STAY_LENGTH
    perp=Vector((0,-diff.z,diff.y)).normalized();c=(a+b)/2+perp*math.sqrt(STAY_LENGTH**2-distance**2/4)
    def pose(p,q,x):
        pos=Vector((side*x,p.y,p.z));direction=Vector((0,q.y-p.y,q.z-p.z)).normalized();rot=Vector((0,0,1)).rotation_difference(direction).to_matrix().to_4x4();rot.translation=pos;return rot
    return pose(a,c,.286),pose(c,b,.283)

role('folding brass stay links with actual bored ends')
for side_name,side in STAY_SIDES.items():
    upper,lower=stay_pose(OPEN_DEGREES,side)
    for segment in ['Upper','Lower']:
        assembly='Stay_'+side_name+'_'+segment
        box(assembly,'brass_dull',(-.0008,-.003,.003),(.0008,.003,STAY_LENGTH-.003),.0003)
        for z in [0,STAY_LENGTH]:
            sleeve(assembly,'brass_dull',(-.001,0,z),(1,0,0),[(0,.0035),(.002,.0035),(.002,.0017),(0,.0017)],12)
    # Captive knee pin bridges two separately addressable link planes.
    assembly='Stay_'+side_name+'_Upper'
    start,end=sorted([-side*.006,side*.002])
    rod(assembly,'brass_dull',(start,0,STAY_LENGTH),(end,0,STAY_LENGTH),.0015,12)
    # Positive knee stop: a lug fixed to the upper link meets the lower bar edge
    # at full opening. It prevents straightening past the supported shelf pose.
    lowx=min(upper.translation.x,lower.translation.x)-.0012;highx=max(upper.translation.x,lower.translation.x)+.0012
    world=[]
    for xx in [lowx,highx]:
        for yy in [-.005,-.0030001]:
            for zz in [.009,.015]:
                pp=lower@Vector((0,yy,zz));pp.x=xx;world.append(upper.inverted()@pp)
    add(assembly,'brass_dull',world,[[0,4,6,2],[1,3,7,5],[0,1,5,4],[2,6,7,3],[0,2,3,1],[4,5,7,6]])
    # Fixed and moving bearing pads attach to actual end walls and shelf rims.
    a=Vector((side*.286,.280,.208));b=Vector((side*.283,-.060,.004))
    x0,x1=sorted([side*.277,side*.2844])
    box('Tray','brass_dull',(x0,a.y-.005,a.z-.006),(x1,a.y+.005,a.z+.006),.0005)
    rod('Tray','brass_dull',(min(side*.279,side*.288),a.y,a.z),(max(side*.279,side*.288),a.y,a.z),.0015,12)
    x0,x1=sorted([side*.260,side*.2814]);mapped_box('Lid','brass_dull',(x0,b.y-.007,0),(x1,b.y+.007,.008),closed_shelf,.0005)
    start=closed_shelf((min(side*.279,side*.285),b.y,b.z));end=closed_shelf((max(side*.279,side*.285),b.y,b.z));rod('Lid','brass_dull',start,end,.0015,12)

# ---- catalogue PBR, manufacturing stocks, metre charts and export ------------
materials={}
for key in KEYS:
    spec=SETS[key];mat=bpy.data.materials.new(key);mat.use_nodes=True
    nodes=mat.node_tree.nodes;links=mat.node_tree.links;p=nodes['Principled BSDF']
    p.inputs['Metallic'].default_value=spec.get('metallic',0)
    uvnode=nodes.new('ShaderNodeUVMap');uvnode.uv_map='Metres'
    scale=nodes.new('ShaderNodeVectorMath');scale.operation='SCALE';scale.inputs['Scale'].default_value=1/TILES[key];links.new(uvnode.outputs[0],scale.inputs[0])
    # Same raw map response as the current carried_case_view material owner.
    for channel,slot in enumerate(['Base Color','Roughness','Normal']):
        tex=nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(ROOT/'game/assets/building/textures'/spec['files'][channel]),check_existing=True)
        if channel:tex.image.colorspace_settings.name='Non-Color'
        links.new(scale.outputs['Vector'],tex.inputs['Vector'])
        if channel==2:
            nm=nodes.new('ShaderNodeNormalMap');nm.uv_map='Metres';nm.inputs['Strength'].default_value=1;links.new(tex.outputs['Color'],nm.inputs['Color']);links.new(nm.outputs[0],p.inputs['Normal'])
        else:links.new(tex.outputs['Color'],p.inputs[slot])
    materials[key]=mat

scene=bpy.context.scene;scene.unit_settings.system='METRIC'
def collection(name):
    c=bpy.data.collections.new(name);scene.collection.children.link(c);return c
source=collection('01_EDITABLE_MANUFACTURING_STOCK');exports=collection('02_CONTRACT_EXPORT');review=collection('90_REVIEW_ONLY_NO_EXPORT')
draws=[];parts=[];triangles=0;sources=[]


def prepared(name,piece,key,assembly):
    verts,faces,label,curved=piece;me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update();bm=bmesh.new();bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bmesh.ops.triangulate(bm,faces=list(bm.faces))
    assert all(e.is_manifold for e in bm.edges),(name,'open stock')
    if bm.calc_volume(signed=True)<0:bmesh.ops.reverse_faces(bm,faces=list(bm.faces))
    assert bm.calc_volume(signed=True)>1e-15,(name,'nonpositive volume')
    assert all(f.calc_area()>1e-16 for f in bm.faces),(name,'collapsed face')
    bm.to_mesh(me);bm.free();me.update();me.materials.append(materials[key]);uv=me.uv_layers.new(name='Metres');uv.active_render=True
    guide=me.attributes.new(name='_TANGENT_GUIDE',type='FLOAT_VECTOR',domain='CORNER');metre=me.attributes.new(name='_METRE_UV',type='FLOAT_VECTOR',domain='CORNER')
    incidence={i:[] for i in range(len(me.vertices))}
    for f in me.polygons:
        for vertex in f.vertices:incidence[vertex].append(f)
    normals=[None]*len(me.loops)
    for face in me.polygons:
        pp=np.array([me.vertices[i].co[:] for i in face.vertices]);n,u,q,_=chart_for_triangle(pp,np.zeros(3),TILES[key])
        for j,loop in enumerate(face.loop_indices):
            normal=n.copy()
            if curved:
                fs=[f for f in incidence[me.loops[loop].vertex_index] if np.dot(f.normal,n)>.80]
                normal=sum((np.array(f.normal)*f.area for f in fs),np.zeros(3));normal/=np.linalg.norm(normal)
            tangent=u-normal*np.dot(normal,u);tangent/=np.linalg.norm(tangent)
            uv.data[loop].uv=q[j];metre.data[loop].vector=(*q[j],0);guide.data[loop].vector=tangent;normals[loop]=tuple(normal)
    me.normals_split_custom_set(normals)
    obj=bpy.data.objects.new(name,me);source.objects.link(obj);obj['assembly']=assembly;obj['material_key']=key;obj['construction_role']=label;sources.append(obj);return obj

for assembly,by_key in stock.items():
    for key,pieces in by_key.items():
        originals=[]
        for i,piece in enumerate(pieces):originals.append(prepared('Stock_%s_%s_%03d'%(assembly,key,i),piece,key,assembly))
        copies=[]
        for o in originals:
            c=o.copy();c.data=o.data.copy();exports.objects.link(c);copies.append(c)
        bpy.ops.object.select_all(action='DESELECT')
        for c in copies:c.select_set(True)
        bpy.context.view_layer.objects.active=copies[0]
        if len(copies)>1:bpy.ops.object.join()
        obj=bpy.context.object;obj.name=assembly+'__'+key;obj.data.name=obj.name
        obj['assembly']=assembly;obj['material_key']=key;obj['tile']=TILES[key];draws.append(obj)
        triangles+=len(obj.data.polygons);parts.append({'name':obj.name,'assembly':assembly,'key':key,'tile':TILES[key]})

source.hide_render=True;source.hide_viewport=True
assert triangles<25000,('triangle budget',triangles)
import io_scene_gltf2
# Shared signed-metre exporter derives tangent sign from actual final float32 UVs.
io_scene_gltf2.glTF2ExportUserExtension=CatalogueMetricUV
bpy.ops.object.select_all(action='DESELECT')
for obj in draws:obj.select_set(True)
asset=ROOT/'game/assets/props/carried_case.glb'
bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',use_selection=True,export_yup=True,
                          export_tangents=True,export_attributes=True,export_materials='NONE',export_animations=False,
                          export_lights=False,export_cameras=False)
runtime={'schema_version':1,'asset':'res://assets/props/carried_case.glb','cell':CELL,'grid':[COLS,ROWS],
         'hinge':[0.0,0.0,-SHELF_HINGE.y],'forms':{k:{'size':v} for k,v in FORMS.items()},'parts':parts}
(ROOT/'game/data/carried_case.json').write_text(json.dumps(runtime,indent=1)+'\n',encoding='utf-8',newline='\n')
# The importer may cache JSON; owner refresh/reload remains the other agent's job.
from inspect_carried_case import inspect
native_result=inspect(draws,sources,runtime,write=True)
print('CARRIED_CASE_PREFLIGHT',json.dumps(native_result['summary']),flush=True)

# ---- review: real catalogue PBR, fixed CPU budget, no extra exported nodes ----
scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=20;scene.cycles.use_denoising=True
scene.render.threads_mode='FIXED';scene.render.threads=2;scene.view_settings.view_transform='AgX';scene.view_settings.exposure=-.40
scene.world=bpy.data.worlds.new('Neutral review environment');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.55,.60,.66,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.35
ld=bpy.data.lights.new('REVIEW soft window','AREA');ld.energy=55;ld.shape='DISK';ld.size=.7
light=bpy.data.objects.new('REVIEW soft window',ld);review.objects.link(light);light.location=(-.32,-.30,.95);light.rotation_euler=(Vector((0,.05,.05))-light.location).to_track_quat('-Z','Y').to_euler()
cd=bpy.data.cameras.new('REVIEW player camera');camera=bpy.data.objects.new('REVIEW player camera',cd);review.objects.link(camera);scene.camera=camera
scene.render.resolution_x=1280;scene.render.resolution_y=720;scene.render.resolution_percentage=100
# A legal sample arrangement: no overlapping footprints, front row deliberately populated.
LAYOUT={'flat':(0,0),'bottle':(3,0),'valve':(4,0),'parcel':(6,0),'tool':(9,1),'box':(3,3),
        'tin':(1,5),'jar':(3,5),'packet':(5,5),'card':(7,5),'roll':(9,5)}
review_draws=[]
for o in draws:
    cp=o.copy();cp.data=o.data;cp.name='REVIEW_'+o.name;cp.hide_render=False;review.objects.link(cp);review_draws.append(cp)
exports.hide_render=True;exports.hide_viewport=True

def pose(opening=True,sheet=False):
    for o in review_draws:
        assembly=o['assembly'];o.hide_render=False;o.scale=(1,1,1);o.rotation_euler=(0,0,0);o.location=(0,0,0)
        if assembly=='Lid':o.location=SHELF_HINGE;o.rotation_euler.x=math.radians(OPEN_DEGREES if opening else 0)
        elif assembly.startswith('Form_'):
            form=assembly[5:];x,y=LAYOUT[form];w,d=FORMS[form];o.location=(-HW+(x+w/2)*CELL,HD-(y+d/2)*CELL,0)
            if not opening:o.location=SHELF_HINGE+REST@(o.location-SHELF_HINGE);o.rotation_euler.x=math.radians(-OPEN_DEGREES)
        elif assembly.startswith('Stay_'):
            _,side_name,segment=assembly.split('_');upper,lower=stay_pose(OPEN_DEGREES if opening else 0,STAY_SIDES[side_name]);o.matrix_world=upper if segment=='Upper' else lower
        if sheet:
            if not assembly.startswith('Form_'):o.hide_render=True;continue
            form=assembly[5:];i=list(FORMS).index(form);w,d=FORMS[form];factor=.12/(max(w,d)*CELL)
            o.location=((i%4-1.5)*.19,(1-i//4)*.19,0);o.scale=(factor,)*3
    bpy.context.view_layer.update()

def shot(name,at,look,orthographic=None,sheet=False,fov=42):
    camera.location=at;camera.rotation_euler=(Vector(look)-camera.location).to_track_quat('-Z','Y').to_euler()
    if orthographic:
        cd.type='ORTHO';cd.ortho_scale=orthographic
    else:
        cd.type='PERSP';cd.sensor_fit='VERTICAL';cd.sensor_height=32;cd.lens=32/(2*math.tan(math.radians(fov)/2))
    scene.render.resolution_x=1280;scene.render.resolution_y=960 if sheet else 720
    scene.render.filepath=str(REVIEW/name);bpy.ops.render.render(write_still=True)

pose();shot('case_player.png',(0,-.46,.62),(0,.03,.03))
shot('case_player_full.png',(0,-.46,.62),(0,.03,.03),fov=64)
pose();shot('case_top.png',(0,-.005,1.10),(0,-.005,0),.40)
pose(False);shot('case_closed.png',(.56,-.62,.52),(0,.230,.150),.60)
pose(sheet=True);shot('case_forms.png',(0,0,1),(0,0,0),.60,True)
pose();camera.location=(0,-.46,.62);camera.rotation_euler=(Vector((0,.03,.03))-camera.location).to_track_quat('-Z','Y').to_euler();cd.type='PERSP';cd.sensor_fit='VERTICAL';cd.lens=32/(2*math.tan(math.radians(42)/2));scene.render.resolution_y=720
for im in bpy.data.images:
    if im.source=='FILE' and not im.packed_file:im.pack()
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/carried_case.blend'))
(REVIEW/'case_build.json').write_text(json.dumps({'status':'PASS_NATIVE_BUILD','blender':bpy.app.version_string,'triangles':triangles,'partitions':len(draws),'stocks':len(sources),'cpu_threads':2,'previews':['case_player.png','case_player_full.png','case_top.png','case_closed.png','case_forms.png'],'layout':LAYOUT,'runtime':'NOT RUN'},indent=2),encoding='utf-8')
print('CARRIED CASE',len(stock),'assemblies;',len(parts),'parts;',triangles,'triangles; CPU textured review complete',flush=True)
