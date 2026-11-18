"""Original paired arcade leaf stocks in LOCAL GODOT metres (x,height,depth).

Both leaves have a local hinge at zero. Right is a true geometric mirror;
its frame-owned brass is also local, never baked at the pair's world width.
No mesh carries interaction, collision, inventory or door-state authority.
"""
import math

WIDTH = 1.0
HEIGHT = 2.30
BOTTOM = .020
TOP = 2.290
THICKNESS = .044
HINGE_HEIGHTS = (.30, 1.15, 2.01)
HINGE_Z = -.026
PULL_CENTRE_Y = 1.20


def _sub(a,b):return [x-y for x,y in zip(a,b)]
def _cross(a,b):return [a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]]
def _dot(a,b):return sum(x*y for x,y in zip(a,b))
def _unit(a):
    n=math.sqrt(_dot(a,a))
    if n<=1e-12:raise ValueError('zero axis')
    return [x/n for x in a]


def signed_volume(vertices,faces):
    origin=vertices[0]
    return sum(_dot(_sub(vertices[f[0]],origin),_cross(_sub(vertices[f[i]],origin),
        _sub(vertices[f[i+1]],origin)))/6 for f in faces for i in range(1,len(f)-1))


def stocks():
    result=[]
    def emit(name,vertices,faces,material,role,bevel=0,grain='vertical',fixed=False):
        if signed_volume(vertices,faces)<0:faces=[list(reversed(f)) for f in faces]
        if signed_volume(vertices,faces)<=1e-12:raise ValueError('nonpositive stock '+name)
        result.append(dict(name=name,vertices=vertices,faces=faces,material=material,
            role=role,bevel_m=bevel,grain=grain,fixed=fixed))
    def prism(name,outline,delta,material,role,bevel=0,grain='vertical',fixed=False):
        n=len(outline);verts=outline+[[p[i]+delta[i] for i in range(3)] for p in outline]
        faces=[list(reversed(range(n))),list(range(n,2*n))]
        faces += [[i,(i+1)%n,(i+1)%n+n,i+n] for i in range(n)]
        emit(name,verts,faces,material,role,bevel,grain,fixed)
    def box(name,low,high,role,material='door_oak',grain='vertical',fixed=False,bevel=.00045):
        x,y,z=low;a,b,c=high
        if not (a>x and b>y and c>z):raise ValueError('invalid stock box')
        prism(name,[[x,y,z],[a,y,z],[a,b,z],[x,b,z]],[0,0,c-z],material,role,bevel,grain,fixed)
    def cylinder(name,centre,radius,length,role,axis='y',fixed=False,inner=0,sides=16):
        if not 0<=inner<radius or length<=0:raise ValueError('invalid turned stock')
        axis_id={'x':0,'y':1,'z':2}[axis];others=[i for i in range(3) if i!=axis_id]
        verts=[]
        radii=[radius,inner] if inner else [radius]
        for r in radii:
            for end in [-1,1]:
                for i in range(sides):
                    p=list(centre);p[axis_id]+=end*length/2
                    p[others[0]]+=r*math.cos(2*math.pi*i/sides)
                    p[others[1]]+=r*math.sin(2*math.pi*i/sides);verts.append(p)
        faces=[]
        for i in range(sides):
            j=(i+1)%sides
            faces.append([i,j,sides+j,sides+i])
            if inner:
                faces += [[2*sides+j,2*sides+i,3*sides+i,3*sides+j],
                          [j,i,2*sides+i,2*sides+j],
                          [sides+i,sides+j,3*sides+j,3*sides+i]]
        if not inner:faces += [list(reversed(range(sides))),list(range(sides,2*sides))]
        emit(name,verts,faces,'door_brass',role,0,'vertical',fixed)
    def sweep(name,centres,radius,role):
        verts=[];sides=12
        for j,p in enumerate(centres):
            t=_unit(_sub(centres[min(j+1,len(centres)-1)],centres[max(j-1,0)]))
            a=[1,0,0];b=_unit(_cross(t,a))
            for k in range(sides):
                angle=2*math.pi*k/sides
                verts.append([p[i]+radius*(math.cos(angle)*a[i]+math.sin(angle)*b[i]) for i in range(3)])
        faces=[]
        for j in range(len(centres)-1):
            for i in range(sides):
                a=j*sides+i;b=j*sides+(i+1)%sides
                faces.append([a,b,b+sides,a+sides])
        faces += [list(reversed(range(sides))),list(range(len(verts)-sides,len(verts)))]
        emit(name,verts,faces,'door_brass',role)

    # Stiles and rails meet without an empty lower aperture; pane laps are real.
    box('HingeStile',[.01,BOTTOM,-.022],[.14,TOP,.022],'stile')
    box('MeetingStile',[.86,BOTTOM,-.022],[.99,TOP,.022],'stile')
    for name,lo,hi in [('BottomRail',BOTTOM,.15),('LockRail',.73,.86),('TopRail',2.17,TOP)]:
        box(name,[.14,lo,-.022],[.86,hi,.022],'rail',grain='horizontal')
    box('LowerPanel',[.13,.14,-.016],[.87,.74,.016],'opaque_lower_panel',bevel=.00035)
    for side in [-1,1]:
        lo,hi=sorted([side*.0155,side*.0205])
        box('RaisedPanel'+str(side),[.165,.175,lo],[.835,.705,hi],
            'opaque_panel_field',bevel=.001)
    box('UpperPane',[.13,.85,-.006],[.87,2.18,.006],'clear_upper_glazing',
        material='glass_drawn_expressive',bevel=.0002)
    # Glazing is physically retained by beads on both faces, not floating in a gap.
    for side in [-1,1]:
        low,high=sorted([side*.015,side*.022])
        for name,rect,grain in [('w',[.132,.85,.15,2.18],'vertical'),
                               ('e',[.85,.85,.868,2.18],'vertical'),
                               ('bottom',[.15,.85,.85,.868],'horizontal'),
                               ('top',[.15,2.162,.85,2.18],'horizontal')]:
            a,b,c,d=rect
            box('Bead'+str(side)+name,[a,b,low],[c,d,high],'glazing_bead',grain=grain,bevel=.0003)
    # Period bow pulls: a softly lobed escutcheon and actual bowed round stock.
    for face in [-1,1]:
        x=.925;outline=[]
        for i in range(32):
            a=2*math.pi*i/32;y=.221*math.cos(a)
            width=.020+.008*math.exp(-((abs(y)-.177)/.037)**2)
            outline.append([x+width*math.sin(a),PULL_CENTRE_Y+y,face*.0215])
        prism('PullPlate'+str(face),outline,[0,0,face*.0065],'door_brass','pull_plate',.0003)
        centres=[[x,PULL_CENTRE_Y-.158+.316*j/16,face*(.028+.063*math.sin(math.pi*j/16))] for j in range(17)]
        sweep('PullBow'+str(face),centres,.010,'pull_bow')
        for i,y in enumerate([PULL_CENTRE_Y-.198,PULL_CENTRE_Y+.198]):
            cylinder('PullScrew'+str(face)+'_'+str(i),[x,y,face*.030],.004,.004,
                     'pull_fastener',axis='z',sides=12)

    # Three five-knuckle hinges. Real annular moving/fixed barrels share the
    # local y-axis and alternate with finite axial seams around a separate pin.
    for i,y in enumerate(HINGE_HEIGHTS):
        for j,(a,b) in enumerate([(-.030,-.010),(.010,.030)]):
            cylinder('Hinge%dMoving%d'%(i,j),[0,y+(a+b)/2,HINGE_Z],.010,b-a,
                     'moving_hinge_barrel',inner=.0045)
        for j,(a,b) in enumerate([(-.050,-.031),(-.009,.009),(.031,.050)]):
            cylinder('Hinge%dFixed%d'%(i,j),[0,y+(a+b)/2,HINGE_Z],.010,b-a,
                     'fixed_hinge_barrel',fixed=True,inner=.0045)
        cylinder('Hinge%dPin'%i,[0,y,HINGE_Z],.0038,.108,'fixed_hinge_pin',fixed=True)
        for sign,fixed in [(1,False),(-1,True)]:
            # The barrel is4mm behind the timber face; plate has real contact
            # with both annular barrel and timber, without filling the pin bore.
            path=[[sign*.008,y-.033,-.024],[sign*.070,y-.033,-.024],
                  [sign*.070,y-.033,-.0205],[sign*.008,y-.033,-.0205]]
            prism('Hinge%dFlap%d'%(i,sign),path,[0,.066,0],'door_brass',
                  'fixed_hinge_flap' if fixed else 'moving_hinge_flap',.0002,fixed=fixed)
            for j,dy in enumerate([-.022,.022]):
                cylinder('Hinge%dFixing%d_%d'%(i,sign,j),[sign*.052,y+dy,-.0258],.0033,.004,
                         'fixed_hinge_fastener' if fixed else 'moving_hinge_fastener',
                         axis='z',fixed=fixed,sides=12)

    both=[]
    for side,sign in [('Left',1),('Right',-1)]:
        for stock in result:
            copy=dict(stock)
            copy['name']=side+'_'+stock['name']
            copy['side']=side
            copy['vertices']=[[sign*x,y,z] for x,y,z in stock['vertices']]
            copy['faces']=[list(reversed(f)) if sign<0 else list(f) for f in stock['faces']]
            suffix='FixedBrass' if stock['fixed'] else 'Wood' if stock['material']=='door_oak' else 'Glass' if stock['material']=='glass_drawn_expressive' else 'Brass'
            copy['group']=side+suffix
            both.append(copy)
    return both


def pull_collision_boxes(parts=None):
    """One tight actual-stock bound per face, never hinge-plus-pull brass hull."""
    parts=stocks() if parts is None else parts
    answer={}
    for side in ['Left','Right']:
        answer[side]=[]
        for face in [-1,1]:
            selected=[p for p in parts if p['side']==side and p['role'].startswith('pull_')
                      and (sum(v[2] for v in p['vertices'])/len(p['vertices']))*face>0]
            vertices=[v for p in selected for v in p['vertices']]
            answer[side].append({'face':face,'low':[min(v[i] for v in vertices) for i in range(3)],
                'high':[max(v[i] for v in vertices) for i in range(3)],
                'source_stocks':[p['name'] for p in selected]})
    return answer
