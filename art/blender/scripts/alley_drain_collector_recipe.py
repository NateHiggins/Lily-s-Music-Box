"""INERT local cast-iron drainage construction; downstream connection is open.

The independent property collector ends at the registered public slab boundary
with a bolted blank awaiting the street main. No new simulation or live control.
"""
import math
import bpy
import bmesh
from mathutils import Vector

def build_collector(point,box,materials,drain_x,drain_z,window_z,well_floor,grade,public_front):
    main_outer=.0889;main_inner=.0762
    branch_outer=.0635;branch_inner=.0508
    rear=max(drain_z)+.15
    def main_y(z):return -2.60+.005*(z-window_z)
    def cylinder(name,a,b,radius,angles=None):
        a,b=point(a),point(b);axis=(b-a).normalized()
        u=Vector((1,0,0));v=axis.cross(u).normalized()
        angles=angles if angles is not None else [2*math.pi*i/32 for i in range(32)]
        n=len(angles)
        vertices=[at+radius*(u*math.cos(t)+v*math.sin(t)) for at in [a,b] for t in angles]
        faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]
        faces += [(i,(i+1)%n,n+(i+1)%n,n+i) for i in range(n)]
        mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update()
        obj=bpy.data.objects.new(name,mesh);bpy.context.scene.collection.objects.link(obj)
        obj['material_key']='cast_iron';mesh.materials.append(materials['cast_iron'])
        bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
        return obj
    def boolean(owner,tool,operation):
        bpy.context.view_layer.objects.active=owner
        modifier=owner.modifiers.new('Continuous source-owned drain '+operation,'BOOLEAN')
        modifier.operation=operation;modifier.solver='EXACT';modifier.object=tool
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    def join_solids(parts):
        owner=parts[0]
        for obj in parts[1:]:
            boolean(owner,obj,'UNION');bpy.data.objects.remove(obj,do_unlink=True)
        return owner
    def rect_angles(rect,cx,cz):
        a,b,c,d=rect
        # The vertical branch's cylinder basis maps sine to -Godot Z.
        return sorted({2*math.pi*i/24 for i in range(24)} |
                      {math.atan2(-(z-cz),x-cx)%(2*math.pi) for x,z in [(a,b),(c,b),(c,d),(a,d)]})
    outer=[cylinder('LocalCollectorClosedWall',
        (drain_x,main_y(public_front),public_front),
        (drain_x,main_y(rear),rear),main_outer)]
    air=[cylinder('CollectorInnerAir',
        (drain_x,main_y(public_front-.02),public_front-.02),
        (drain_x,main_y(rear-.005),rear-.005),main_inner)]
    branches=[]
    for i,z in enumerate(drain_z+[window_z]):
        top=well_floor-.05 if i==3 else -.65+grade(drain_x,z)
        rect=[15.93,window_z-.88,18,window_z+.88] if i==3 else [drain_x-.151,z-.258,drain_x+.151,z+.258]
        angles=rect_angles(rect,drain_x,z)
        # Both unions overlap inside the main bore. Neither air subtraction
        # protrudes through the collector's underside.
        outer.append(cylinder('Branch%dOuter'%i,(drain_x,main_y(z)-.015,z),(drain_x,top,z),branch_outer,angles))
        air.append(cylinder('Branch%dAir'%i,(drain_x,main_y(z)-.005,z),(drain_x,top+.01,z),branch_inner,angles))
        socket_top=top-(.12 if i==3 else .10)-.02
        outer.append(cylinder('Branch%dBell'%i,(drain_x,socket_top-.09,z),(drain_x,socket_top,z),.077,angles))
        branches.append({'id':'well' if i==3 else 'catch%d'%i,'centre':[drain_x,z],
                         'top_y':top,'collector_y':main_y(z),'bore_radius':branch_inner,'outer_radius':branch_outer,
                         'socket_y':[socket_top-.09,socket_top]})
    sockets=[]
    for i in range(math.ceil((rear-public_front)/1.50)):
        z=min(rear-.2,public_front+.12+i*1.50)
        outer.append(cylinder('CollectorBell%d'%i,(drain_x,main_y(z-.05),z-.05),
                              (drain_x,main_y(z+.05),z+.05),.104))
        sockets.append(z)
    outer_owner=join_solids(outer);air_owner=join_solids(air)
    boolean(outer_owner,air_owner,'DIFFERENCE');bpy.data.objects.remove(air_owner,do_unlink=True)
    bm=bmesh.new();bm.from_mesh(outer_owner.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    assert all(e.is_manifold for e in bm.edges),'Local collector must be a closed pipe wall'
    assert bm.calc_volume(signed=True)>0
    bm.to_mesh(outer_owner.data);bm.free()
    # A proper bolted blank makes the construction-stage downstream boundary
    # explicit. It must be replaced by the street connection before completion.
    flange=cylinder('PropertyBoundaryBlank',
        (drain_x,main_y(public_front-.025),public_front-.025),
        (drain_x,main_y(public_front),public_front),.110)
    for i in range(6):
        angle=2*math.pi*i/6
        x=drain_x+.097*math.cos(angle);y=main_y(public_front)+.097*math.sin(angle)
        cylinder('PropertyBlankBolt%d'%i,(x,y,public_front-.038),(x,y,public_front+.018),.006)
    beds=[]
    for i,z in enumerate(sockets):
        low=main_y(z)-.30;high=main_y(z)+.02
        bed=box('CollectorSaddleBed%d'%i,[drain_x-.19,low,z-.20,drain_x+.19,high,z+.20],'concrete')
        tool=cylinder('SaddleContactCut',(drain_x,main_y(z-.22),z-.22),(drain_x,main_y(z+.22),z+.22),.104)
        boolean(bed,tool,'DIFFERENCE');bpy.data.objects.remove(tool,do_unlink=True)
        beds.append({'id':bed.name,'z':z,'bottom_y':low,'contact_radius':.104})
    return {'classification':'ADAPTATION','owner':'LocalCollectorClosedWall',
            'main_axis':[[drain_x,main_y(public_front),public_front],[drain_x,main_y(rear),rear]],
            'main_bore_radius':main_inner,'main_outer_radius':main_outer,'main_fall':.005,
            'branches':branches,'socket_centres_z':sockets,'saddle_beds':beds,
            'downstream':{'owner':'PropertyBoundaryBlank','z':public_front,'state':'bolted construction-stage blank',
                          'open_work':'Replace blank with the physical street-main connection before infrastructure acceptance.'}}
