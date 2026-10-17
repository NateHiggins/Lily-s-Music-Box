"""Small analytic support stock with metre charts and actual annular bores."""
import math
import bpy
import bmesh
from mathutils import Vector


def hanger(name, direction, drop, material):
    vertices=[];faces=[];charts=[];smooth=[]
    def sweep(profile,sides,axis,center):
        axis=Vector(axis).normalized();center=Vector(center)
        seed=Vector((0,0,1)) if abs(axis.z)<.9 else Vector((1,0,0))
        u=axis.cross(seed).normalized();v=axis.cross(u)
        start=len(vertices)
        for radius,z in profile:
            vertices.extend(center+axis*z+radius*(u*math.cos(j*math.tau/sides)+v*math.sin(j*math.tau/sides)) for j in range(sides))
        for k,(radius,z) in enumerate(profile):
            kn=(k+1)%len(profile);rn,zn=profile[kn]
            for j in range(sides):
                jn=(j+1)%sides
                faces.append((start+k*sides+j,start+k*sides+jn,start+kn*sides+jn,start+kn*sides+j))
                if abs(zn-z)<1e-9:
                    charts.append([(r*math.cos(a),r*math.sin(a)) for r,a in
                        [(radius,j*math.tau/sides),(radius,(j+1)*math.tau/sides),(rn,(j+1)*math.tau/sides),(rn,j*math.tau/sides)]])
                    smooth.append(False)
                else:
                    width=(radius+rn)*.5;length=math.hypot(zn-z,rn-radius)
                    charts.append([(j*math.tau/sides*width,0),((j+1)*math.tau/sides*width,0),
                                   ((j+1)*math.tau/sides*width,length),(j*math.tau/sides*width,length)])
                    smooth.append(True)
    # Outer rim chamfers are 0.1mm; retain the full 12.7mm nominal bore.
    out,inside,half,bevel=.0165,.0127,.009,.0001
    axis=Vector((direction[0],-direction[2],direction[1]))
    sweep([(out-bevel,-half),(out,-half+bevel),(out,half-bevel),(out-bevel,half),
           (inside,half),(inside,-half)],24,axis,(0,0,0))
    # Rod ends are inside the band and seat. Their twelve-sided silhouettes
    # differ from the 2.5mm radius circle by less than 0.086mm.
    low,high=.013,drop-.006
    axis=Vector((0,0,1));u=Vector((1,0,0));v=Vector((0,1,0));n=12;start=len(vertices)
    for z in [low,high]:vertices.extend((.0025*math.cos(j*math.tau/n),.0025*math.sin(j*math.tau/n),z) for j in range(n))
    for j in range(n):
        jn=(j+1)%n;faces.append((start+j,start+jn,start+n+jn,start+n+j));smooth.append(True)
        charts.append([(j*math.tau/n*.0025,0),((j+1)*math.tau/n*.0025,0),((j+1)*math.tau/n*.0025,high-low),(j*math.tau/n*.0025,high-low)])
    for ids in [tuple(start+j for j in reversed(range(n))),tuple(start+n+j for j in range(n))]:
        faces.append(ids);smooth.append(False);charts.append([(vertices[i][0],vertices[i][1]) for i in ids])
    # Flat seat retains the exact 45x45x6mm bearing, with no subpixel edge rings.
    start=len(vertices)
    vertices.extend((x,y,z) for z in [drop-.006,drop] for y in [-.0225,.0225] for x in [-.0225,.0225])
    for ids in [(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)]:
        face=tuple(start+i for i in ids);faces.append(face);smooth.append(False)
        pts=[Vector(vertices[i]) for i in face];normal=(pts[1]-pts[0]).cross(pts[2]-pts[0]);a=max(range(3),key=lambda i:abs(normal[i]));axes=[(1,2),(0,2),(0,1)][a]
        charts.append([(p[axes[0]],p[axes[1]]) for p in pts])
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update()
    uv=mesh.uv_layers.new(name='MetreStock')
    for face,values,flag in zip(mesh.polygons,charts,smooth):
        face.use_smooth=flag
        for loop,value in zip(face.loop_indices,values):uv.data[loop].uv=value
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
    mesh.materials.append(material)
    obj=bpy.data.objects.new(name,mesh);bpy.context.scene.collection.objects.link(obj)
    return obj
