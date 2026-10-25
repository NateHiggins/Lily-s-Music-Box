"""Bistable, bored, two-color square tiles on the keyboard's outer face.

One dark body and one light face export once; runtime uses two MultiMeshes.
All lettering stays outside this authoring module. Pixels are physical stock.
"""
import math
import bpy,bmesh
from mathutils import Matrix,Vector

def build(api):
    box,rod,stock,coords=[api[k] for k in ['box','rod','stock','coords']]
    api['specs']['CompanionTileIvory']=dict(catalog_key='porcelain_fixture',tint=[.92,.86,.67,1],normal=.12,roughness=.8,pigment=.4)
    center=(0,-.057,.123);cols,rows,pitch=32,12,.0055
    box('Flip display backing',(0,-.057,.119),(.187,.074,.001),'CompanionSteel','CompanionKeyboard')
    for x in [-.090,.090]:
        for y in [-.091,-.023]:rod('Display standoff',(x,y,.112),(x,y,.1185),.0015,'CompanionSteel','CompanionKeyboard',count=12)
    # Continuous rectangular bezel, with a true central opening.
    verts=[]
    for z in [.121,.124]:
        for w,h in [(.187,.074),(.179,.068)]:
            verts.extend((x,y-.057,z) for x,y in [(-w/2,-h/2),(w/2,-h/2),(w/2,h/2),(-w/2,h/2)])
    faces=[]
    for i in range(4):
        j=(i+1)%4
        faces.extend([(i,j,j+8,i+8),(i+4,i+12,j+12,j+4),(i,i+4,j+4,j),(i+8,j+8,j+12,i+12)])
    stock('Continuous flip display bezel',verts,faces,'CompanionBrass','CompanionKeyboard')
    body=box('Bistable square tile',(0,0,0),(.0047,.0047,.0012),'CompanionKeys','FlipTile')
    # A real vertical bore lets every square pivot independently on its column.
    bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=.00035,depth=.008,location=(0,0,0))
    cutter=bpy.context.object # Blender Z is Godot Y.
    bpy.context.view_layer.objects.active=body
    mod=body.modifiers.new('Tile spindle bore','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cutter
    bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cutter,do_unlink=True)
    bm=bmesh.new();bm.from_mesh(body.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    assert all(edge.is_manifold for edge in bm.edges),'open flip tile'
    volume=bm.calc_volume(signed=True);assert volume>0
    bm.to_mesh(body.data);bm.free()
    next(row for row in api['checks'] if row['name']=='Bistable square tile')['volume_m3']=volume
    box('Light tile face',(0,0,.00064),(.0045,.0045,.00008),'CompanionTileIvory','FlipTile')
    for column in range(cols):
        x=(column-(cols-1)*.5)*pitch
        rod('Column spindle',(x,-.091,.123),(x,-.023,.123),.00025,'CompanionSteel','CompanionKeyboard',count=8)
    return dict(columns=cols,rows=rows,pitch=pitch,center=list(center),
                dark_mesh='FlipTile__CompanionKeys',light_mesh='FlipTile__CompanionTileIvory')

def review_instances(api,data):
    exports,review,keyboard,coords=[api[k] for k in ['exports','review','keyboard','coords']]
    sources=[next(o for o in exports.objects if o.name==data[key]) for key in ['dark_mesh','light_mesh']]
    for source in sources:source.hide_render=True
    for row in range(data['rows']):
        for column in range(data['columns']):
            eye=(column in [10,11,20,21] and row in [3,4])
            smile=(row==8 and column in [9,22]) or (row==9 and column in [10,11,20,21]) or (row==10 and 12<=column<=19)
            for source in sources:
                obj=bpy.data.objects.new('Review flip tile',source.data);review.objects.link(obj)
                x=data['center'][0]+(column-(data['columns']-1)*.5)*data['pitch']
                y=data['center'][1]+((data['rows']-1)*.5-row)*data['pitch']
                transform=Matrix.Translation(coords((x,y,data['center'][2])))@Matrix.Rotation(0 if eye or smile else math.pi,4,'Z')
                obj.parent=keyboard;obj.matrix_world=transform
