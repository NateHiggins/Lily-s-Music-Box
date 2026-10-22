"""INERT pose proposal, not a collision waiver or an installed asset."""
from pathlib import Path
import json,math,os
def add(a,b):return tuple(x+y for x,y in zip(a,b))
def sub(a,b):return tuple(x-y for x,y in zip(a,b))
def mul(a,k):return tuple(x*k for x in a)
def dot(a,b):return sum(x*y for x,y in zip(a,b))
def length(a):return math.sqrt(dot(a,a))
def unit(a):return mul(a,1/length(a))
def bez(a,b,c,d,t):
    s=1-t
    return add(add(mul(a,s**3),mul(b,3*s*s*t)),add(mul(c,3*s*t*t),mul(d,t**3)))
old=json.loads(Path('game/tests/fixtures/v2_unracked_fire_hose_placement.json').read_text())
tail=[(.340-p[0],p[1],p[2]) for p in old['points']]
goal=(-.048,.068,.312);join=127;neck=.015;segment=15.21/128
center=(-1.1,-1.177,float(os.environ.get('HOSE_FLOOR_Z','1.0')));outer=.82;pitch=.07
def path(turns):
    start=-math.pi/2;end=start-turns*math.tau
    inner=outer-pitch*turns
    point=add(center,(inner*math.cos(end),0,inner*math.sin(end)))
    # Reversed spiral runs outwards, counterclockwise.
    tangent=unit((-inner*math.sin(end)+pitch/math.tau*math.cos(end),0,inner*math.cos(end)+pitch/math.tau*math.sin(end)))
    result=[bez(goal,add(goal,(-.65,0,0)),sub(point,mul(tangent,.30)),point,i/300) for i in range(301)]
    for i in range(1,1801):
        t=i/1800;angle=end+(start-end)*t;radius=inner+(outer-inner)*t
        result.append(add(center,(radius*math.cos(angle),0,radius*math.sin(angle))))
    start_point=result[-1]
    result += [bez(start_point,add(start_point,(.4,0,0)),sub(tail[join],(.4,0,0)),tail[join],i/300) for i in range(1,301)]
    return result
def sample(turns):
    curve=path(turns);points=[add(goal,(-.005*i,0,0)) for i in range(4)]
    at=0
    for ring in range(4,join):
        previous=points[-1];found=False
        while at+1<len(curve):
            a=curve[at];b=curve[at+1]
            if length(sub(b,previous))>=segment:
                v=sub(b,a);w=sub(a,previous);aa=dot(v,v);bb=2*dot(v,w);cc=dot(w,w)-segment*segment
                disc=bb*bb-4*aa*cc
                if aa>1e-20 and disc>=0:
                    roots=[(-bb-math.sqrt(disc))/(2*aa),(-bb+math.sqrt(disc))/(2*aa)]
                    valid=[x for x in roots if -1e-9<=x<=1+1e-9]
                    if valid:
                        point=add(a,mul(v,max(valid)));points.append(point);curve[at]=point;found=True;break
            at+=1
        if not found:return -segment,[]
    return length(sub(tail[join],points[-1]))-segment,points+[tail[join]]+tail[join+1:]
lo=1.;hi=4.
assert sample(lo)[0]<0 and sample(hi)[0]>0
for _ in range(40):
    mid=(lo+hi)/2
    if sample(mid)[0]<0:lo=mid
    else:hi=mid
error,points=sample((lo+hi)/2)
assert len(points)==135 and abs(error)<1e-8,(len(points),error)
result=dict(evidence_class='INERT',scope='Compact floor layout proposal. Actual world/native/contact verification required.',points=[(.340-p[0],p[1],p[2]) for p in points],turns=(lo+hi)/2,residual_m=error)
out=Path('tmp/v2-unracked-hose-20261022')/os.environ.get('HOSE_FLOOR_FILE','floor_coil_candidate.json')
out.write_text(json.dumps(result,indent=2)+'\n',newline='\n')
print('turns',result['turns'],'residual',error,'segments',len(points)-1)
def closest(a,b,c,d):
    u=sub(b,a);v=sub(d,c);w=sub(a,c)
    aa=dot(u,u);bb=dot(u,v);cc=dot(v,v);dd=dot(u,w);ee=dot(v,w)
    den=aa*cc-bb*bb
    s=max(0,min(1,(bb*ee-cc*dd)/den)) if den>1e-20 else 0
    t=(bb*s+ee)/cc
    if t<0:t=0;s=max(0,min(1,-dd/aa))
    elif t>1:t=1;s=max(0,min(1,(bb-dd)/aa))
    return length(sub(add(a,mul(u,s)),add(c,mul(v,t))))
arc=[0.]
for i in range(134):arc.append(arc[-1]+length(sub(points[i+1],points[i])))
minimum=(math.inf,None)
for i in range(134):
    for j in range(i+2,134):
        if arc[j]-arc[i+1]<.084:continue
        distance=closest(points[i],points[i+1],points[j],points[j+1])
        if distance<minimum[0]:minimum=(distance,(i,j))
print('minimum nonlocal envelope clearance',minimum)
bends=[]
for i in range(1,134):
    a=sub(points[i],points[i-1]);b=sub(points[i+1],points[i])
    angle=math.acos(max(-1,min(1,dot(unit(a),unit(b)))))
    maximum=min(math.pi/2,2*math.atan(min(length(a),length(b))/(2*.02152)))
    if angle>maximum:bends.append((i,angle,maximum))
print('physical bend violations',bends)
