"""Vectorized metre charts, with the scalar export-precision fallback intact."""
import numpy as np
from fabrication_uvs import chart_for_triangle


def triangle_charts(points, origin, tile, rotations=None, long_grain=None):
    original=np.asarray(points,dtype=np.float64)
    count=len(original);points=original.copy();origins=np.broadcast_to(origin,(count,3)).copy()
    if rotations is not None:
        points=np.einsum('nij,nkj->nki',rotations,points)
        origins=np.einsum('nij,nj->ni',rotations,origins)
    n=np.cross(points[:,1]-points[:,0],points[:,2]-points[:,0]);length=np.linalg.norm(n,axis=1)
    assert np.all(length>0) and np.isfinite(points).all()
    n/=length[:,None]
    seed=np.zeros_like(n);side=np.abs(n[:,2])<.9;seed[side,2]=1;seed[~side,1]=1
    axial=seed-n*np.sum(seed*n,axis=1)[:,None];axial/=np.linalg.norm(axial,axis=1)[:,None]
    u=np.cross(axial,n);v=axial.copy()
    if long_grain is not None:
        u[long_grain]=axial[long_grain];v[long_grain]=np.cross(n[long_grain],u[long_grain])
    values=np.stack((np.einsum('nkj,nj->nk',points+origins[:,None],u),np.einsum('nkj,nj->nk',points+origins[:,None],v)),axis=2)
    values-=np.floor(values.min(axis=1)[:,None]/tile)*tile
    # Exactly the scalar float32 export check, evaluated for the whole draw.
    encoded=values.astype(np.float32);encoded[:,:,1]=np.float32(1)-encoded[:,:,1]
    first=encoded[:,1]-encoded[:,0];second=encoded[:,2]-encoded[:,0]
    det=first[:,0].astype(float)*second[:,1]-second[:,0].astype(float)*first[:,1]
    with np.errstate(divide='ignore',invalid='ignore'):
        expected=((points[:,1]-points[:,0]).astype(np.float32)*second[:,1,None]-(points[:,2]-points[:,0]).astype(np.float32)*first[:,1,None])/det[:,None]
        projected=expected-n*np.sum(expected*n,axis=1)[:,None];projected/=np.linalg.norm(projected,axis=1)[:,None]
    valid=(np.abs(det)>1e-12)&(np.sum(projected*u,axis=1)>.9995)
    for i in np.flatnonzero(~valid):
        n[i],u[i],values[i],_=chart_for_triangle(points[i],origins[i],tile,bool(long_grain[i]) if long_grain is not None else False)
    if rotations is not None:
        n=np.einsum('nji,nj->ni',rotations,n);u=np.einsum('nji,nj->ni',rotations,u)
    return n,u,values,int(np.count_nonzero(~valid))


def revolved_charts(points, normals, tangents, values, axes, centers, tile):
    """Develop each turned band as a cylinder or conical sector, in metres.

    One angular seam replaces the separate chart on every radial facet. Caps
    keep their planar charts. The polygon/chord approximation is checked by
    the ordinary mesh metric gate, not waived for these surfaces.
    """
    marked=np.linalg.norm(axes,axis=1)>.9
    ids=np.flatnonzero(marked)
    if not len(ids):return 0
    axis=axes[ids];p=points[ids]-centers[ids,None,:]
    seed=np.eye(3)[np.argmin(np.abs(axis),axis=1)]
    a=np.cross(axis,seed);a/=np.linalg.norm(a,axis=1)[:,None];b=np.cross(axis,a)
    x=np.einsum('nkj,nj->nk',p,a);y=np.einsum('nkj,nj->nk',p,b);z=np.einsum('nkj,nj->nk',p,axis)
    radius=np.hypot(x,y);lo=np.argmin(z,axis=1);hi=np.argmax(z,axis=1);ii=np.arange(len(ids));dz=z[ii,hi]-z[ii,lo]
    good=dz>1e-6
    ids=ids[good];x=x[good];y=y[good];z=z[good];radius=radius[good];lo=lo[good];hi=hi[good];dz=dz[good];ii=np.arange(len(ids))
    slope=(radius[ii,hi]-radius[ii,lo])/dz
    angle=np.arctan2(y,x)
    wrap=np.ptp(angle,axis=1)>np.pi;angle[wrap]=np.where(angle[wrap]<0,angle[wrap]+2*np.pi,angle[wrap])
    mapped=np.empty((len(ids),3,2));cylinder=np.abs(slope)<1e-4
    mapped[cylinder,:,0]=angle[cylinder]*radius[cylinder].mean(axis=1)[:,None];mapped[cylinder,:,1]=z[cylinder]
    cone=~cylinder;s=slope[cone]/np.sqrt(1+slope[cone]**2);distance=radius[cone]/s[:,None];phi=angle[cone]*s[:,None]
    mapped[cone,:,0]=distance*np.sin(phi);mapped[cone,:,1]=distance*(np.cos(phi)-1)+(radius[cone]-radius[cone].min(axis=1)[:,None])/s[:,None]
    # Keep texture phase constant around a band, then derive actual tangents.
    mapped-=np.floor(mapped.min(axis=1)[:,None]/tile)*tile
    edge1=points[ids,1]-points[ids,0];edge2=points[ids,2]-points[ids,0]
    du=mapped[:,1]-mapped[:,0];dv=mapped[:,2]-mapped[:,0];det=du[:,0]*dv[:,1]-dv[:,0]*du[:,1]
    flip=det<0;mapped[flip,:,1]*=-1
    du=mapped[:,1]-mapped[:,0];dv=mapped[:,2]-mapped[:,0];det=du[:,0]*dv[:,1]-dv[:,0]*du[:,1]
    # Near-axis tips can have no useful angular chart. Retain the already
    # verified planar chart for those individual triangles.
    valid=np.isfinite(mapped).all(axis=(1,2))&(det>1e-12)
    ids=ids[valid];mapped=mapped[valid];edge1=edge1[valid];edge2=edge2[valid];du=du[valid];dv=dv[valid];det=det[valid]
    tangent=(edge1*dv[:,1,None]-edge2*du[:,1,None])/det[:,None];tangent/=np.linalg.norm(tangent,axis=1)[:,None]
    tangents[ids]=tangent;values[ids]=mapped
    return len(ids)
