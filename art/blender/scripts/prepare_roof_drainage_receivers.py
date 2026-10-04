"""Source-owned Orison roof/drainage construction.

Retained gameplay authorities remain; geometry and material validation are
independent of this source recipe. No drainage capacity acceptance.
"""
from pathlib import Path
import json,math,hashlib
R=next(path for path in Path(__file__).resolve().parents if (path/'game/project.godot').is_file());O=R/'art/data/orison_roof_drainage';O.mkdir(parents=True,exist_ok=True)
leaders_path=R/'art/blender/roof_drainage_leaders_construction.json';leaders=json.loads(leaders_path.read_bytes())
front_path=R/'art/data/orison_roof_drainage/source_plan.json';front=json.loads(front_path.read_bytes())['front_property_z']
west_x=-16.28;east_x=17.3;south_z=-13.08;west_start_z=5.;east_start_z=14.;fall=.005;west_start_y=-2.6
corner_y=west_start_y-fall*(west_start_z-south_z);join_y=corner_y-fall*(east_x-west_x)
west_y=lambda z:corner_y+fall*(z-south_z)
south_y=lambda x:corner_y-fall*(x-west_x)
east_y=lambda z:join_y+fall*(z-south_z)
trunks=[{'id':'WEST_SOUTH_PROPERTY','path':[[west_x,west_y(west_start_z),west_start_z],[west_x,corner_y,south_z],[east_x,join_y,south_z],[east_x,east_y(front),front]],'bore_radius':.1524,'outer_radius':.1683,'fall':fall},
        {'id':'EAST','path':[[east_x,east_y(east_start_z),east_start_z],[east_x,join_y,south_z]],'bore_radius':.1524,'outer_radius':.1683,'fall':fall}]
branches=[]
for leader in leaders['leaders']:
 ident=leader['id'];x,_,z=leader['pipe_axis'][-1];top=[x,.23,z]
 if leader['side']=='west':
  end=[west_x,west_y(z),z];knee=[x,end[1]+(x-west_x),z];path=[top,knee,end]
 elif leader['side']=='south':
  end=[x,south_y(x),south_z];knee=[x,end[1]+(z-south_z),z];path=[top,knee,end]
 elif leader['side']=='east':
  end=[east_x,east_y(z),z];wye=[east_x-.18,end[1]+.18,z];knee=[x,wye[1]+.01*(wye[0]-x),z];path=[top,knee,wye,end]
 else:
  # Recessed north service wall remains its owner. This branch crosses the
  # outer rear court, beyond the existing service-core foundation stem.
  branch_z=11.;end=[east_x,east_y(branch_z),branch_z];wye=[east_x-.18,end[1]+.18,branch_z];knee_y=wye[1]+.01*(wye[0]-x+branch_z-z)
  path=[top,[x,knee_y,z],[x,knee_y-.01*(branch_z-z),branch_z],wye,end]
 for a,b in zip(path,path[1:]):
  assert a[1]>b[1],(ident,a,b)
 branches.append({'id':ident,'axis':path,'bore_radius':.0762,'outer_radius':.0889,'leader_toe_y':.30,'socket_y':[.23,.39],'socket_outer_radius':.105,'socket_inner_radius':.0804,'grade_contact_open_work':'Read actual retained native paving/ground height before authoring the collar and concrete seat.'})
for trunk in trunks:
 for a,b in zip(trunk['path'],trunk['path'][1:]):assert a[1]>b[1] and abs((a[1]-b[1])/math.hypot(a[0]-b[0],a[2]-b[2])-fall)<1e-9
report={'evidence_class':'INERT','classification':'ADAPTATION','status':'SOURCE-GENERATED CONSTRUCTION; INDEPENDENT VALIDATION REQUIRED','trunks':trunks,'branches':branches,'downstream':{'point':[east_x,east_y(front),front],'owner':'RoofDrainPropertyBlank','state':'bolted construction-stage blank at actual retained front property line','street_main':'Undefined in current sources; this study claims no live downstream drainage or capacity.'},'source_bindings':{p.relative_to(R).as_posix():hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest() for p in [leaders_path,front_path,Path(__file__)]},'open_work':['actual retained collider/neighbor/plant clearance','ground and paving source-owned ports','closed collector walls, branches, bells and bearing beds','actual source soil reservations','property blank and access inspection','production route and accepted textures']}
(O/'receiver_routes.json').write_text(json.dumps(report,indent=2)+'\n',newline='\n')
print('SOURCE ROOF RECEIVER ROUTES',len(branches),'branches;',len(trunks),'trunks; property',report['downstream']['point'])

