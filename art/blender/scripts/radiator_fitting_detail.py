"""Small machined edge breaks on retained radiator fitting stocks.

Owner frames, bores and mechanical authorities remain with the original kit.
Blender preparation calls this after the cast refinement, before export.
"""
import math
import bpy
import bmesh
from radiator_cast_detail import _charts
from fabrication_normals import stock_corner_normals

STOCKS = ('BlindHeaderPlug','VentHeaderReducer','ValveSphericalRetainer',
          'HeaderSphericalRetainer','PackedHeaderSocket')

def refine_fittings():
    result = {}
    for name in STOCKS:
        obj = bpy.data.objects[name]
        assert obj.type == 'MESH' and obj.data.shape_keys is None
        frame = obj.matrix_world.copy()
        bpy.ops.object.select_all(action='DESELECT')
        obj.hide_set(False)
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        before = len(obj.data.vertices)
        # The kit is already triangulated. Remove coplanar triangulation and
        # coincident Boolean slivers before adding a manufacturing edge break.
        clean = bmesh.new()
        clean.from_mesh(obj.data)
        bmesh.ops.remove_doubles(clean,verts=list(clean.verts),dist=1e-7)
        bmesh.ops.dissolve_limit(clean,angle_limit=math.radians(.05),
                                 verts=list(clean.verts),edges=list(clean.edges))
        clean.to_mesh(obj.data)
        clean.free()
        bevel = obj.modifiers.new('Machined edge break 0.45mm','BEVEL')
        bevel.width, bevel.segments = .00045, 3
        bevel.limit_method, bevel.angle_limit = 'ANGLE', math.radians(35)
        bevel.use_clamp_overlap = True
        bpy.ops.object.modifier_apply(modifier=bevel.name)
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6)
        bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-7)
        bmesh.ops.triangulate(bm, faces=list(bm.faces))
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        bm.normal_update()
        assert all(edge.is_manifold for edge in bm.edges), name
        volume = bm.calc_volume(signed=True)
        # The source stocks include mirrored axial solids. Recalculation can
        # retain their inward winding; choose the outward closed shell before
        # authoring corner normals and exporting the bevels.
        if volume < 0:
            bmesh.ops.reverse_faces(bm,faces=list(bm.faces))
            volume=bm.calc_volume(signed=True)
        assert volume > 0, (name,volume)
        bm.to_mesh(obj.data)
        bm.free()
        metric = _charts(obj)
        obj.data.normals_split_custom_set(stock_corner_normals(obj.data))
        assert obj.matrix_world == frame
        assert len(obj.data.vertices) > before, (name,'no edge break generated')
        result[name] = dict(edge_break_m=.00045, segments=3, closed=True,
                            volume_m3=volume, physical_charts=metric,
                            triangles=len(obj.data.loop_triangles))
    return result
