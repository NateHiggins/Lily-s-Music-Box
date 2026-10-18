"""Verify modelled radiator rim breaks, retained seats and an old-stock control.

Blender --python-exit-code 1 --python this_file -- --native FILE --before FILE --out FILE
INERT fabrication diagnostic; no pressure certification or runtime proof.
"""
from pathlib import Path
import argparse,json,math,sys
import bpy,bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--native',required=True,type=Path)
parser.add_argument('--before',required=True,type=Path)
parser.add_argument('--out',required=True,type=Path)
a=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
checks=[]
def check(ok,label,**details):checks.append(dict(passed=bool(ok),label=label,**details))
def inspect(path,negative):
 bpy.ops.wm.open_mainfile(filepath=str(path.resolve()))
 obj=bpy.data.objects['CastSectionThreeColumnCandidate'];mesh=obj.data
 bm=bmesh.new();bm.from_mesh(mesh);bm.normal_update()
 check(all(e.is_manifold for e in bm.edges) and bm.calc_volume(signed=True)>0,'closed positive source casting',negative=negative)
 tree=BVHTree.FromBMesh(bm);bm.free();gaps=[];rims=[]
 for z in [.085,.615]:
  for sign in [-1,1]:
   for i in range(32):
    angle=i*math.tau/32;radial=Vector((0,math.cos(angle),math.sin(angle)))
    centre=Vector((sign*.04599,.055,z));hit=tree.ray_cast(centre+radial*.05,-radial,.03)[0]
    radius=(hit-centre).length if hit is not None else 0
    rims.append(radius)
    # Ideal quarter-circle at 10 microns from the end, plus polygonal
    # interpolation tolerance. Old full-radius sleeves must fail this bound.
    expected=.0332+math.sqrt(.0008**2-(.04599-.0452)**2)
    if not negative:check(hit is not None and abs(radius-expected)<.00014,'real quarter-round near the joining face',height=z,side=sign,angle=i,radius_m=radius)
    for r in [.030,.032]:
     origin=Vector((sign*.06,.055,z))+radial*r
     result=tree.ray_cast(origin,Vector((-sign,0,0)),.02)
     if not negative:check(result[0] is not None and abs(result[0].x-sign*.046)<.0000002 and result[1].x*sign>.9999,'retained flat sealing annulus',height=z,side=sign,radius_m=r)
    origin=Vector((sign*.046+sign*.000001,.055,z))+radial*.0338
    hit=tree.ray_cast(origin,Vector((-sign,0,0)),.002)[0]
    gap=abs(hit.x-sign*.046) if hit is not None else -1
    gaps.append(gap)
    if not negative:check(hit is not None and .00010<gap<.00050,'outer joint recess is actual geometry',height=z,side=sign,angle=i,recess_m=gap)
   for i in range(16):
    angle=i*math.tau/16
    origin=Vector((-.07,.055+.023*math.cos(angle),z+.023*math.sin(angle)))
    if not negative:check(tree.ray_cast(origin,Vector((1,0,0)),.14)[0] is None,'retained open 54 mm port',height=z,angle=i)
 if not negative:
  worst=0.;faces=0
  for face in mesh.polygons:
   if abs(face.normal.x)<1.-1e-7 or not all(abs(abs(mesh.vertices[j].co.x)-.046)<1e-7 for j in face.vertices):continue
   for loop in face.loop_indices:worst=max(worst,math.degrees(math.acos(min(1.,abs(mesh.corner_normals[loop].vector.x)))))
   faces+=1
  check(faces>0 and worst<.05,'machined faces retain their actual plane normals',triangles=faces,maximum_degrees=worst)
 return dict(minimum_outer_recess_m=min(gaps),maximum_outer_recess_m=max(gaps),minimum_rim_radius_m=min(rims),maximum_rim_radius_m=max(rims))
before=inspect(a.before,True);after=inspect(a.native,False)
check(before['maximum_outer_recess_m']<.000001 and before['minimum_rim_radius_m']>.0338,'old-stock negative control reproduces absent rim break',before=before)
result=dict(evidence_class='INERT',scope='Native closed solid, visible rim breaks, retained port/seat datums and old-stock negative control. No pressure simulation, runtime or appearance acceptance.',before=before,after=after,checks=checks,failures=[r for r in checks if not r['passed']])
a.out.parent.mkdir(parents=True,exist_ok=True);a.out.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8',newline='\n')
print('RADIATOR SECTION JOINTS:',len(checks),'checks;',len(result['failures']),'failures',flush=True)
assert not result['failures'],result['failures'][:4]
