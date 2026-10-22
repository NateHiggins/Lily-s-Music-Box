"""Native binding profiles in book coordinates (X foreedge, Y up, Z faces).

Authoring math, not a running simulation. Stored books use the closed mesh;
opening selects authored deformation targets with the same physical envelope.
"""
import math

ANGLES=tuple(math.pi*i/8 for i in range(9))
KEYS=tuple('Opening%02d'%i for i in range(1,9))

def opening_span(thickness,angle,style='hardback'):
    flex={'hardback':0.,'paperback':.22,'pamphlet':.30}[style]
    return thickness*(1.-.06*math.sin(angle)-flex*math.sin(angle*.5)**2)

def left_translation(thickness,angle,style='hardback'):
    span=opening_span(thickness,angle,style)
    return (-span*math.sin(angle*.5)+thickness*.5*math.sin(angle),0.,
            -thickness*.5+span*math.cos(angle*.5)-thickness*.5*math.cos(angle))

def spine_profile(thickness,angle,style='hardback'):
    # Opening unfolds a strip of constant manufactured width. Its endpoints
    # rotate from a vertical spine to a horizontal bridge between the boards.
    start=(0.,-thickness*.5)
    span=opening_span(thickness,angle,style)
    end=(-span*math.sin(angle*.5),-thickness*.5+span*math.cos(angle*.5))
    chord=(end[0]-start[0],end[1]-start[1]);length=math.hypot(*chord)
    normal=(-chord[1]/length,chord[0]/length)
    def arc(height):
        n=48
        values=[math.hypot(length,4*height*(1-2*i/n)) for i in range(n+1)]
        return (values[0]+values[-1]+4*sum(values[1:-1:2])+2*sum(values[2:-1:2]))/(3*n)
    low=0.;high=thickness
    for _ in range(40):
        middle=(low+high)*.5
        if arc(middle)>thickness:high=middle
        else:low=middle
    return start,chord,normal,(low+high)*.5

def spine_point(point,thickness,profile):
    x,y,z=point;start,chord,normal,height=profile
    fraction=max(0.,min(1.,z/thickness+.5))
    bump=4*height*fraction*(1-fraction)
    tangent=(chord[0]+normal[0]*4*height*(1-2*fraction),chord[1]+normal[1]*4*height*(1-2*fraction))
    size=math.hypot(*tangent);out=(-tangent[1]/size,tangent[0]/size)
    return (start[0]+fraction*chord[0]+normal[0]*bump-out[0]*x,
            y,start[1]+fraction*chord[1]+normal[1]*bump-out[1]*x)

def trim_point(point,profile):
    x,y,z=point;start,chord,normal,height=profile
    length=math.hypot(*chord);tangent=(chord[0]/length,chord[1]/length)
    return (start[0]+chord[0]*.5+normal[0]*height-normal[0]*x+tangent[0]*z,
            y,start[1]+chord[1]*.5+normal[1]*height-normal[1]*x+tangent[1]*z)

def page_point(point,width,page_low,page_high,side,angle,thickness,style='hardback'):
    x,y,z=point
    u=max(0.,min(1.,(x-.004)/(width-.007)))
    q=(z-page_low)/(page_high-page_low) if side=='right' else (page_high-z)/(page_high-page_low)
    q=max(0.,min(1.,q));opened=math.sin(angle*.5)**2
    half=page_high-page_low
    # The sewn text block turns in toward the middle of the spine. The inner
    # leaves meet at the gutter instead of exposing a flat cloth bridge.
    span=opening_span(thickness,math.pi,style)
    shift=(.004+span*.5)*q*(1-u)**2*opened
    root_rise=half*(math.sin(q*math.pi*.5)-q)*(1-u)**2
    peak=.16 if style=='hardback' else .23
    arch=(u/peak)*math.exp(1.-u/peak)*(1-u)**.8
    amplitude=min(width*(.13 if style=='hardback' else .12),max(.006,half*.95))
    if style=='paperback':amplitude=min(width*.12,max(.008,half*1.3))
    if style=='pamphlet':amplitude=min(.003,max(.0006,half*1.5))
    cover_bow=soft_cover_lift(max(0.,min(1.,x/width)),width,style)
    lift=opened*(root_rise+amplitude*arch*q**1.65+cover_bow)
    return (x-shift,y,z+(lift if side=='right' else -lift))

def soft_cover_lift(u,width,style):
    return (min(.0015,width*.012) if style=='paperback' else (.00035 if style=='pamphlet' else 0.))*math.sin(math.pi*u)

def cover_point(point,width,side,angle,style):
    x,y,z=point;u=max(0.,min(1.,x/width))
    lift=soft_cover_lift(u,width,style)*math.sin(angle*.5)**2
    return (x,y,z+(lift if side=='right' else -lift))

def wrapper_point(point,width,thickness,style,angle,profile):
    x,y,z=point
    spine=spine_point(point,thickness,profile)
    if x<=0:return spine
    side='left' if z>0 else 'right'
    cover=cover_point(point,width,side,angle,style)
    if side=='left':
        tx,_,tz=left_translation(thickness,angle,style);c=math.cos(angle);s=math.sin(angle)
        cover=(c*cover[0]-s*cover[2]+tx,cover[1],s*cover[0]+c*cover[2]+tz)
    u=max(0.,min(1.,x/.004));mix=u*u*(3.-2.*u)
    return tuple(a+(b-a)*mix for a,b in zip(spine,cover))

def cover_contact_point(point,width,thickness,style,angle,profile,side):
    p=wrapper_point(point,width,thickness,style,angle,profile)
    if side=='right':return p
    tx,_,tz=left_translation(thickness,angle,style);x,y,z=p;x-=tx;z-=tz
    c=math.cos(angle);s=math.sin(angle)
    return (c*x+s*z,y,-s*x+c*z)

def frame_at(deform,point,normal,tangent):
    # Tangents and normals follow the same authored deformation as positions;
    # a bowed page must not retain the flat sheet's normal-map frame.
    import numpy as np
    epsilon=1e-6;p=np.asarray(point,dtype=float);columns=[]
    for axis in range(3):
        d=np.zeros(3);d[axis]=epsilon
        columns.append((np.asarray(deform(p+d))-np.asarray(deform(p-d)))/(2*epsilon))
    jacobian=np.column_stack(columns)
    n=np.linalg.solve(jacobian.T,np.asarray(normal));n/=np.linalg.norm(n)
    t=jacobian@np.asarray(tangent);t-=n*float(t@n);t/=np.linalg.norm(t)
    return n,t
