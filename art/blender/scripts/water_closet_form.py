"""Authored casting profiles; photographs inform form only, never surface data."""
import math
from mathutils import Vector
N=64

def oval(rx,rz,y,z,cx=0.,round=False,back=.88):
    points=[]
    for i in range(N):
        a=math.tau*i/N;c=math.cos(a);s=math.sin(a)
        x=c if round else math.copysign(abs(c)**.95,c)*(1.-.08*s)
        q=math.copysign(abs(s)**.95,s)
        depth=s if round else (q if q<=0 else back-math.log1p(math.exp(18.*(back-q)))/18.)
        points.append((cx+rx*x,y,z+rz*depth))
    return points

def rect(hx,hz,y,z,r):
    return [(math.copysign(hx-r,math.cos(a))+r*math.cos(a),y,z+math.copysign(hz-r,math.sin(a))+r*math.sin(a)) for a in [math.tau*i/N for i in range(N)]]

def solid(name,loops,material,parent,make_mesh):
    vertices=[p for loop in loops for p in loop];faces=[]
    n=len(loops[0]);assert all(len(row)==n for row in loops)
    for j in range(len(loops)):
        for i in range(n):faces.append((j*n+i,j*n+(i+1)%n,((j+1)%len(loops))*n+(i+1)%n,((j+1)%len(loops))*n+i))
    return make_mesh(name,vertices,faces,material,parent)

def bowl(parent,glaze,make_mesh):
    # Inner wash-down well continues into an open, rear-curving throat.
    profiles=[oval(.164,.231,.407,-.13),oval(.150,.211,.377,-.13),oval(.112,.159,.295,-.108),
        oval(.071,.091,.224,-.072,round=True),oval(.044,.052,.176,-.045,round=True),
        oval(.040,.047,.139,-.021,round=True),oval(.040,.047,.108,.012,round=True),
        oval(.040,.047,.089,.052,round=True),oval(.051,.058,.089,.052,round=True),
        oval(.053,.063,.153,-.021,round=True),oval(.066,.081,.185,-.045,round=True),
        oval(.134,.188,.211,-.08),oval(.184,.239,.300,-.12),oval(.201,.267,.389,-.13),
        oval(.199,.264,.403,-.13),oval(.185,.249,.412,-.13),oval(.171,.235,.412,-.13)]
    return solid('HollowWashDownBowl',profiles,glaze,parent,make_mesh)

def pedestal(parent,glaze,make_mesh):
    # Hollow support leaves the drain passage open; no solid plug beneath it.
    rows=[(.135,.205,.009),(.140,.210,.025),(.128,.194,.046),(.118,.177,.060),(.095,.135,.238),
        (.075,.112,.238),(.096,.151,.060),(.119,.184,.025),(.116,.180,.009)]
    return solid('ClosetPedestal',[oval(rx,rz,y,-.075,round=True) for rx,rz,y in rows],glaze,parent,make_mesh)

def seat(parent,wood,make_mesh):
    return solid('PolishedWoodSeat',[oval(.143,.192,.412,-.157,back=.82),oval(.197,.259,.412,-.13),
        oval(.204,.267,.420,-.13),oval(.201,.264,.433,-.13),oval(.193,.255,.438,-.13),
        oval(.137,.186,.433,-.157,back=.82)],wood,parent,make_mesh)

def lid(parent,wood,make_mesh):
    # Separate closed cap, with the same D/oval perimeter as the seat.
    loops=[oval(.193,.256,.448,-.13),oval(.201,.264,.456,-.13),oval(.193,.256,.464,-.13)]
    vertices=[p for row in loops for p in row]+[(0,.448,-.13),(0,.464,-.13)];faces=[]
    for j in range(len(loops)-1):
        for i in range(N):faces.append((j*N+i,j*N+(i+1)%N,(j+1)*N+(i+1)%N,(j+1)*N+i))
    for i in range(N):
        faces.append((len(vertices)-2,(i+1)%N,i))
        faces.append((len(vertices)-1,2*N+i,2*N+(i+1)%N))
    return make_mesh('Lid',vertices,faces,wood,parent)

def curved_pipe(name,path,outer,inner,material,parent,make_mesh):
    path=[Vector(p) for p in path];centres=[];sides=32
    for j in range(len(path)-1):
        a=path[j-1] if j else 2*path[0]-path[1];b=path[j];c=path[j+1];d=path[j+2] if j+2<len(path) else 2*c-b
        for i in range(4):
            t=i/4.;centres.append(.5*(2*b+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t))
    centres.append(path[-1]);frames=[]
    for j,at in enumerate(centres):
        tangent=(centres[min(j+1,len(centres)-1)]-centres[max(j-1,0)]).normalized()
        if name=='DrainTrap' and j==0:tangent=Vector((0,-1,0))
        x=Vector((1,0,0));x=(x-tangent*x.dot(tangent)).normalized();frames.append((at,x,tangent.cross(x),j/(len(centres)-1)))
    loops=[]
    for radius,rows in [(outer,frames),(inner,list(reversed(frames)))]:
        for at,x,z,t in rows:
            rx,rz=radius(t)
            loops.append([tuple(at+rx*x*math.cos(math.tau*i/sides)+rz*z*math.sin(math.tau*i/sides)) for i in range(sides)])
    obj=solid(name,loops,material,parent,make_mesh)
    for index,face in enumerate(obj.data.polygons):
        if name=='DrainTrap' or index//sides in [len(frames)-1,len(loops)-1]:face.use_smooth=False
    return obj

def flush_connection(parent,glaze,make_mesh):
    return curved_pipe('FlushConnection',[(.075,.478,.205),(.075,.410,.205),(.055,.345,.185),(.025,.302,.140),(0,.292,.110)],
        lambda t:(.029+.021*math.sin(math.pi*t)**.4,)*2,lambda t:(.023,.023),glaze,parent,make_mesh)

def drain_trap(parent,iron,make_mesh):
    return curved_pipe('DrainTrap',[(0,.089,.052),(0,.065,.100),(0,.080,.156),(0,.140,.197),(0,.200,.235),(0,.180,.300),(0,.105,.330),(0,-.020,.330)],
        lambda t:(.041+.010*(1-t)**8,.041+.017*(1-t)**8),lambda t:(.031+.009*(1-t)**8,.031+.016*(1-t)**8),iron,parent,make_mesh)

def cistern(parent,glaze,make_mesh):
    # Recessed lower field, a rounded plinth bead, rim and real outlet bore.
    rows=[(.208,.090,.498,.023),(.224,.106,.504,.025),(.230,.112,.514,.027),
        (.230,.112,.526,.027),(.224,.106,.537,.027),(.2275,.110,.558,.028),
        (.2275,.110,.805,.028),(.2115,.094,.805,.012),(.2115,.094,.526,.012)]
    loops=[rect(hx,hz,y,.235,r) for hx,hz,y,r in rows]
    loops += [oval(.029,.029,.526,.205,.075,round=True),oval(.029,.029,.498,.205,.075,round=True)]
    return solid('HollowCistern',loops,glaze,parent,make_mesh)
