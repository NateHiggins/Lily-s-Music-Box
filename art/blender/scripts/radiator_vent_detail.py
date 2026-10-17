"""Finer native vent contours and a machined cap edge; keep all service datums.

The original 24-sided float/body spheres visibly facet at inspection distance.
Rebuild their actual closed shells, including the nested sealed float cavity.
No smoothing proxy, generated-glTF edit or mechanical frame change is used.
"""
import math
import bpy
import bmesh
from mathutils import Vector
from radiator_cast_detail import _charts
from fabrication_normals import stock_corner_normals


def _ellipsoid(name, at, scale):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=64, ring_count=32, location=at)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return obj


def _tube(name, a, b, radius):
    a, b = Vector(a), Vector(b)
    bpy.ops.mesh.primitive_cylinder_add(vertices=64, radius=radius,
                                      depth=(b-a).length, location=(a+b)/2)
    obj = bpy.context.object
    obj.name = name
    obj.rotation_euler = (b-a).to_track_quat('Z', 'Y').to_euler()
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return obj


def _boolean(obj, cutter, operation):
    bpy.context.view_layer.objects.active = obj
    modifier = obj.modifiers.new('Native service ' + operation, 'BOOLEAN')
    modifier.operation, modifier.solver, modifier.object = operation, 'EXACT', cutter
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    bpy.data.objects.remove(cutter, do_unlink=True)


def refine_vent():
    x = .043
    originals = {name: bpy.data.objects[name] for name in ('VentBody', 'FloatAndNeedle')}
    body = _ellipsoid('RefinedVentBody', (x,0,.02), (.024,.024,.044))
    _boolean(body, _tube('TopNeck', (x,0,.05), (x,0,.066), .018), 'UNION')
    _boolean(body, _tube('ThreadedInlet', (-.018,0,0), (x,0,0), .01), 'UNION')
    _boolean(body, _ellipsoid('AirChamber', (x,0,.025), (.019,.019,.035)), 'DIFFERENCE')
    _boolean(body, _tube('CapSocket', (x,0,.045), (x,0,.07), .014), 'DIFFERENCE')
    _boolean(body, _tube('SteamAirInlet', (-.024,0,0), (x,0,0), .0065), 'DIFFERENCE')
    bell = _ellipsoid('RefinedFloat', (x,0,.022), (.008,.008,.017))
    _boolean(bell, _tube('NeedleStem', (x,0,.035), (x,0,.054), .001), 'UNION')
    bpy.ops.mesh.primitive_cone_add(vertices=64, radius1=.0015, radius2=0,
                                  depth=.006, location=(x,0,.0565))
    _boolean(bell, bpy.context.object, 'UNION')
    _boolean(bell, _ellipsoid('SealedFloatCavity', (x,0,.022), (.0074,.0074,.0164)), 'DIFFERENCE')
    for name, rebuilt in (('VentBody', body), ('FloatAndNeedle', bell)):
        bpy.ops.object.select_all(action='DESELECT')
        rebuilt.select_set(True)
        bpy.context.view_layer.objects.active = rebuilt
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        original = originals[name]
        materials = [mat for mat in original.data.materials if mat is not None]
        original.data = rebuilt.data
        original.data.materials.clear()
        for material in materials: original.data.materials.append(material)
        for face in original.data.polygons: face.material_index=0
        bpy.data.objects.remove(rebuilt, do_unlink=True)
    cap = bpy.data.objects['VentCap']
    bpy.context.view_layer.objects.active = cap
    bevel = cap.modifiers.new('Cap edge break 0.2mm', 'BEVEL')
    bevel.width, bevel.segments = .0002, 3
    bevel.limit_method, bevel.angle_limit = 'ANGLE', math.radians(35)
    bevel.use_clamp_overlap = True
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    result = {}
    for obj in [*originals.values(), cap]:
        frame = obj.matrix_world.copy()
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1e-7)
        bmesh.ops.dissolve_degenerate(bm, edges=list(bm.edges), dist=1e-7)
        bmesh.ops.triangulate(bm, faces=list(bm.faces))
        # Exact sphere/cone intersections can leave sub-micron-altitude
        # slivers. Collapse only their microscopic shortest edge, rather than
        # weakening UV precision or merging the whole needle/seat envelope.
        collapsed = 0
        for _ in range(16):
            edges = {min(face.edges,key=lambda e:e.calc_length()) for face in bm.faces
                     if face.calc_area()*2/max(e.calc_length() for e in face.edges)<1e-7}
            if not edges: break
            assert all(edge.calc_length()<1e-5 for edge in edges), obj.name
            collapsed += len(edges)
            bmesh.ops.collapse(bm,edges=list(edges),uvs=False)
            bmesh.ops.triangulate(bm,faces=list(bm.faces))
        bm.normal_update()
        assert all(edge.is_manifold for edge in bm.edges), obj.name
        assert bm.calc_volume(signed=True)>0, obj.name
        bm.to_mesh(obj.data)
        bm.free()
        try:
            metric = _charts(obj)
        except AssertionError:
            from radiator_cast_detail import _chart_metric
            import numpy as np
            points, singular = _chart_metric(obj.data)
            bad = np.flatnonzero(np.any((singular < .7499) | (singular > 1.3301),axis=1))
            print('VENT CHART DIAGNOSTIC',obj.name,[(int(i),points[i].tolist(),singular[i].tolist()) for i in bad[:8]],flush=True)
            raise
        obj.data.normals_split_custom_set(stock_corner_normals(obj.data))
        assert obj.matrix_world == frame
        result[obj.name] = dict(contour_segments=64, closed=True,
                                physical_charts=metric, microscopic_edges_collapsed=collapsed,
                                cap_edge_break_m=.0002 if obj==cap else 0)
    return result
