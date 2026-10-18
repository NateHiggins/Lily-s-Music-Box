"""Area-weighted corner normals with a crease cutoff for manufactured stock.

Geometry, charts and material partitions are unchanged. Named planar axes
optionally anchor manufactured flats and their adjacent bevel tangents;
other turned surfaces retain area-weighted interpolation within their fan.
"""
import math
import numpy as np

def stock_corner_normals(mesh, angle_degrees=40., planar_axes=()):
    count=len(mesh.polygons);normals=np.empty(count*3,dtype=np.float64);areas=np.empty(count,dtype=np.float64)
    sizes=np.empty(count,dtype=np.int32);vertices=np.empty(len(mesh.loops),dtype=np.int32)
    mesh.polygons.foreach_get('normal',normals);mesh.polygons.foreach_get('area',areas);mesh.polygons.foreach_get('loop_total',sizes);mesh.loops.foreach_get('vertex_index',vertices)
    normals=normals.reshape((-1,3));assert np.isfinite(normals).all() and np.all(areas>0),('degenerate stock face',mesh.name)
    face_ids=np.repeat(np.arange(count),sizes);assert len(face_ids)==len(vertices)
    degree=np.bincount(vertices,minlength=len(mesh.vertices));starts=np.cumsum(degree)-degree;order=np.argsort(vertices,kind='stable');result=np.empty((len(vertices),3),dtype=np.float64)
    cutoff=math.cos(math.radians(angle_degrees))
    planar=np.zeros(count,dtype=bool)
    if len(planar_axes):
        axes=np.asarray(planar_axes,dtype=np.float64)
        assert axes.ndim==2 and axes.shape[1]==3 and np.isfinite(axes).all()
        lengths=np.linalg.norm(axes,axis=1);assert np.all(lengths>0)
        axes/=lengths[:,None]
        planar=np.max(np.abs(normals@axes.T),axis=1)>=1.-1e-7
    # Group vertices by valence, then perform every pairwise fan comparison in
    # a vector batch. Crease decisions are identical to the scalar definition.
    for n in np.unique(degree):
        if n==0:continue
        group=np.flatnonzero(degree==n);corners=order[starts[group,None]+np.arange(n)]
        faces=face_ids[corners];directions=normals[faces]
        dots=np.einsum('vij,vkj->vik',directions,directions)
        weights=(dots>=cutoff)*areas[faces][:,None,:]
        if len(planar_axes):
            # A manufactured flat is the tangent at its bevel's inner edge.
            # Anchor its whole eligible fan, not just the cap-side corner:
            # otherwise the flat/bevel boundary acquires a false shading seam.
            anchors=weights*planar[faces][:,None,:]
            weights=np.where(np.any(anchors>0,axis=2)[:,:,None],anchors,weights)
        summed=np.einsum('vij,vjk->vik',weights,directions);lengths=np.linalg.norm(summed,axis=2)
        assert np.all(lengths>0)
        values=summed/lengths[:,:,None];assert np.all(np.einsum('vij,vij->vi',values,directions)>.7),('corner leaves face hemisphere',mesh.name)
        result[corners]=values
    return result.tolist()
