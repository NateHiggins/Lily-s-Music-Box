"""Native cast contours, retaining the reviewed pressure and mounting datums.

Only the casting and shoe stocks are replaced. Valve, union, packing, vent,
wall supports, object frames and all mechanical authorities remain untouched.
No generated glTF is edited. Blender preparation calls refine_castings().
"""
import math

import bpy
import bmesh
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree


def _tube(name, a, b, radius):
    a, b = Vector(a), Vector(b)
    bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=radius,
                                      depth=(b-a).length, location=(a+b)/2)
    obj = bpy.context.object
    obj.name = name
    obj.rotation_euler = (b-a).to_track_quat('Z', 'Y').to_euler()
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return obj


def _ellipsoid(name, center, radii):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=48, ring_count=24, location=center)
    obj = bpy.context.object
    obj.name, obj.scale = name, radii
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return obj


def _boolean(body, other, operation):
    bpy.context.view_layer.objects.active = body
    mod = body.modifiers.new('Cast pressure solid '+operation, 'BOOLEAN')
    mod.operation, mod.solver, mod.object = operation, 'EXACT', other
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.data.objects.remove(other, do_unlink=True)


def _casting():
    outer, inner = [], []
    for depth in [-.075, 0, .075]:
        outer.append(_tube('DetailOuterColumn', (0, -depth, .055), (0, -depth, .615), .022))
        inner.append(_tube('DetailSteamColumn', (0, -depth, .050), (0, -depth, .620), .017))
    for height in [.055, .615]:
        outer.append(_ellipsoid('DetailHeader', (0, 0, height), (.040, .113, .055)))
        inner.append(_ellipsoid('DetailSteamGallery', (0, 0, height), (.034, .108, .050)))
    for height in [.085, .615]:
        outer.append(_tube('DetailPortBoss', (-.046, .055, height), (.046, .055, height), .034))
        inner.append(_tube('DetailOpenPort', (-.060, .055, height), (.060, .055, height), .027))
    outer.append(_tube('DetailIntegralBearing', (0, 0, 0), (0, 0, .032), .028))
    body, cavity = outer[0], inner[0]
    for obj in outer[1:]: _boolean(body, obj, 'UNION')
    for obj in inner[1:]: _boolean(cavity, obj, 'UNION')
    _boolean(body, cavity, 'DIFFERENCE')
    bpy.context.view_layer.objects.active = body
    # Cast transitions have small real radii; smooth normals cannot create
    # these silhouettes or round the open boss lips.
    bevel = body.modifiers.new('Cast junction radii 1.2mm', 'BEVEL')
    bevel.width, bevel.segments = .0012, 3
    bevel.limit_method, bevel.angle_limit = 'ANGLE', math.radians(35)
    bevel.use_clamp_overlap = True
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    bpy.ops.object.select_all(action='DESELECT')
    body.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bm = bmesh.new()
    bm.from_mesh(body.data)
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1e-7)
    bmesh.ops.dissolve_degenerate(bm, edges=list(bm.edges), dist=1e-8)
    bmesh.ops.triangulate(bm, faces=list(bm.faces))
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(body.data)
    bm.free()
    return body


def _pchip(x, y, sample):
    """Shape-preserving Hermite profile: no flare/bearing overshoot."""
    x, y = np.asarray(x), np.asarray(y)
    h, slope = np.diff(x), np.diff(y)/np.diff(x)
    tangent = np.zeros_like(y)
    for i in range(1, len(y)-1):
        if slope[i-1]*slope[i] > 0:
            w1, w2 = 2*h[i]+h[i-1], h[i]+2*h[i-1]
            tangent[i] = (w1+w2)/(w1/slope[i-1]+w2/slope[i])
    for i, j, k in [(0, 0, 1), (-1, -1, -2)]:
        t = ((2*h[j]+h[k])*slope[j]-h[j]*slope[k])/(h[j]+h[k])
        tangent[i] = 0 if t*slope[j] <= 0 else math.copysign(min(abs(t), 3*abs(slope[j])), t)
    values = []
    for at in sample:
        i = min(max(int(np.searchsorted(x, at))-1, 0), len(x)-2)
        t = (at-x[i])/h[i]
        values.append((2*t**3-3*t**2+1)*y[i]+(t**3-2*t**2+t)*h[i]*tangent[i]
                      +(-2*t**3+3*t**2)*y[i+1]+(t**3-t**2)*h[i]*tangent[i+1])
    return np.asarray(values)


def _shoe():
    profile = np.array([(0, .048, .082), (.006, .058, .095), (.015, .052, .088),
                        (.027, .038, .047), (.050, .032, .033),
                        (.085, .033, .034), (.105, .035, .035)])
    heights = np.unique(np.concatenate([np.linspace(a, b, 13) for a, b in zip(profile[:-1,0],profile[1:,0])]))
    rx = _pchip(profile[:,0], profile[:,1], heights)
    ry = _pchip(profile[:,0], profile[:,2], heights)
    n = 64
    vertices = [(float(a*math.cos(i*math.tau/n)), float(b*math.sin(i*math.tau/n)), float(z))
                for z, a, b in zip(heights, rx, ry) for i in range(n)]
    faces = []
    for row in range(len(heights)-1):
        for i in range(n):
            j = (i+1)%n
            faces.append((row*n+i,row*n+j,(row+1)*n+j,(row+1)*n+i))
    faces += [tuple(reversed(range(n))), tuple((len(heights)-1)*n+i for i in range(n))]
    mesh = bpy.data.meshes.new('RefinedCastShoe')
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new('DetailCastShoe', mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def _charts(obj):
    bpy.ops.object.select_all(action='DESELECT')
    obj.hide_set(False)
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    for layer in list(obj.data.uv_layers): obj.data.uv_layers.remove(layer)
    obj.data.uv_layers.new(name='Metres')
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(58), island_margin=.01)
    bpy.ops.uv.seams_from_islands(mark_seams=True, mark_sharp=False)
    bpy.ops.uv.unwrap(method='ANGLE_BASED', margin=.005)
    bpy.ops.uv.average_islands_scale()
    bpy.ops.object.mode_set(mode='OBJECT')
    mesh = obj.data
    mesh.calc_loop_triangles()
    uv = mesh.uv_layers.active.data
    area = sum(t.area for t in mesh.loop_triangles)
    chart_area = sum(abs((uv[t.loops[1]].uv-uv[t.loops[0]].uv).cross(uv[t.loops[2]].uv-uv[t.loops[0]].uv))*.5
                     for t in mesh.loop_triangles)
    assert area > 0 and chart_area > 0
    for loop in uv: loop.uv *= math.sqrt(area/chart_area)
    for face in mesh.polygons: face.use_smooth = True
    # Preserve continuous unwraps where their physical density is sound.
    # Small Boolean fillet triangles can otherwise acquire extreme local
    # stretch despite a correct total chart area. Cut only those local charts.
    points,singular = _chart_metric(mesh)
    repair = np.any((singular < .75) | (singular > 1.33),axis=1)
    if np.any(repair):
        from fabrication_chart_batch import triangle_charts
        _,_,charts,_ = triangle_charts(points[repair],np.zeros(3),1.)
        for tri,chart in zip([t for t,bad in zip(mesh.loop_triangles,repair) if bad],charts):
            for index,value in zip(tri.loops,chart): uv[index].uv=value
            for index in tri.loops: mesh.edges[mesh.loops[index].edge_index].use_seam=True
    _,singular = _chart_metric(mesh)
    assert np.all(singular >= .7499) and np.all(singular <= 1.3301), ('physical chart density',obj.name)
    return dict(local_metric_repairs=int(repair.sum()),minimum_metric_scale=float(singular.min()),
                maximum_metric_scale=float(singular.max()))


def _chart_metric(mesh):
    mesh.calc_loop_triangles()
    points = np.array([[mesh.vertices[i].co[:] for i in tri.vertices] for tri in mesh.loop_triangles])
    uv = np.array([[mesh.uv_layers.active.data[i].uv[:] for i in tri.loops] for tri in mesh.loop_triangles])
    a,b = points[:,1]-points[:,0],points[:,2]-points[:,0]
    g = np.zeros((len(a),2,2))
    g[:,0,0] = np.linalg.norm(a,axis=1)
    g[:,0,1] = np.sum(a*b,axis=1)/g[:,0,0]
    g[:,1,1] = np.sqrt(np.sum(b*b,axis=1)-g[:,0,1]**2)
    atlas = np.stack([uv[:,1]-uv[:,0],uv[:,2]-uv[:,0]],axis=2)
    singular = np.linalg.svd(atlas@np.linalg.inv(g),compute_uv=False)
    assert np.isfinite(singular).all()
    return points,singular


def _validate(obj, casting):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.normal_update()
    assert all(edge.is_manifold for edge in bm.edges), ('open casting', obj.name)
    volume = bm.calc_volume(signed=True)
    assert volume > 0
    tree = BVHTree.FromBMesh(bm)
    points = [v.co for v in bm.verts]
    bounds = [min(v[i] for v in points) for i in range(3)]+[max(v[i] for v in points) for i in range(3)]
    bm.free()
    if casting:
        assert bounds[0] >= -.046001 and bounds[3] <= .046001 and bounds[1] >= -.115001 and bounds[4] <= .115001, bounds
        assert abs(bounds[2]) < 1e-6 and abs(bounds[5]-.67) < 1e-6, bounds
        for z in [.085,.615]:
            for i in range(16):
                angle = i*math.tau/16
                start = Vector((-.07,.055+math.cos(angle)*.018,z+math.sin(angle)*.018))
                assert tree.ray_cast(start,Vector((1,0,0)),.14)[0] is None, ('blocked header port',z,i)
        for y in [-.075,0,.075,-.0375,.0375]:
            assert tree.ray_cast(Vector((0,y,.16)),Vector((0,0,1)),.34)[0] is None, ('blocked steam/convection column',y)
    else:
        assert abs(bounds[2]) < 1e-9 and abs(bounds[5]-.105) < 1e-6, bounds
        assert bounds[0] >= -.058001 and bounds[3] <= .058001 and bounds[1] >= -.095001 and bounds[4] <= .095001, bounds
    mesh = obj.data
    mesh.calc_loop_triangles()
    uv = mesh.uv_layers.active.data
    for tri in mesh.loop_triangles:
        assert tri.area > 0
        a,b,c = (uv[i].uv for i in tri.loops)
        assert all(math.isfinite(v) for p in [a,b,c] for v in p)
        assert abs((b-a).cross(c-a)) > 1e-14, ('collapsed metre chart',obj.name,tri.index)
    return dict(bounds_blender=bounds, volume_m3=volume, triangles=len(mesh.loop_triangles),
                closed=True, positive_volume=True, finite_metric_charts=True)


def refine_castings():
    report = {}
    for name, build, is_casting in [('CastSectionThreeColumnCandidate',_casting,True),
                                     ('CastShoeFoot',_shoe,False)]:
        owner = bpy.data.objects[name]
        materials = list(owner.data.materials)
        replacement = build()
        bm = bmesh.new()
        bm.from_mesh(replacement.data)
        bmesh.ops.triangulate(bm,faces=list(bm.faces))
        bm.to_mesh(replacement.data)
        bm.free()
        metric = _charts(replacement)
        from fabrication_normals import stock_corner_normals
        replacement.data.normals_split_custom_set(stock_corner_normals(replacement.data))
        report[name] = _validate(replacement,is_casting)
        report[name]['physical_charts'] = metric
        mesh = replacement.data
        mesh.materials.clear()
        for mat in materials: mesh.materials.append(mat)
        # The retained owner keeps its identity, transform, custom properties
        # and any outside references. Only its mesh stock is regenerated.
        previous = owner.data
        owner.data = mesh
        if previous.users == 0:
            bpy.data.meshes.remove(previous)
        else:
            previous.name += '_RetainedPreview'
        bpy.data.objects.remove(replacement,do_unlink=True)
        for face in mesh.polygons: face.material_index=0
    return report
