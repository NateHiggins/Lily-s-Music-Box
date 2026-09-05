"""Add the authored F03 east route and 3B program without changing older records."""
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
path = ROOT/'game/data/orison_v2_blockout.json'
original = subprocess.check_output(['git','show','7e8377e7441e1e1c86cd73e67458fe5d2befd6d5:game/data/orison_v2_blockout.json'],cwd=ROOT).decode('utf-8')
source = json.loads(original)
current = json.loads(path.read_text(encoding='utf-8'))
prior_path = Path(__file__).parent/'additions.json'
if current != source:
    prior = json.loads(prior_path.read_text(encoding='utf-8'))
    expected = json.loads(original)
    for table, records in prior.items():
        expected[table] += records
    assert current == expected, 'Refusing to overwrite unrelated layout changes'
additions = {k: [] for k in ['spaces','doors','openings','windows','anchors','capsule_stations','route_edges','service_connections','envelopes','platforms']}

def space(identity, rect, purpose, cls='private', **extra):
    additions['spaces'].append(dict(id=identity, level='F03', rect=rect, purpose=purpose, **{'class':cls}, **extra))

space('F03_LANDING',[-2.2,-3.35,1.45,.6],'floor and unit decision','public',open_shell=True,no_floor=True,no_ceiling=True)
space('F03_EAST_HALL',[5.4,-3.85,8.3,-2.65],'public approach to Omar Bell at 3B','public')
space('F03_SERVICE_CROSSING',[8.3,-3.85,9.5,-2.65],'controlled public crossing of the service spine','service')
space('F03_SERVICE_HALL',[7.1,-2.65,9.5,9.25],'maintenance route with bypass and inspection clearance around continuous risers','service')
space('F03_SERVICE_HALL_SOUTH',[8.3,-9.25,9.5,-3.85],'kitchen service access without crossing sleeping rooms','service')
space('F03_B_VESTIBULE',[9.5,-3.85,11.5,-1.15],'3B privacy, coats and household distribution')
space('F03_B_MAIN',[11.5,-5.25,15.65,.3],'Omar Bell living, meals and categorized repair work',exterior_sides=['east'])
space('F03_B_KITCHEN',[9.5,-8.05,13.0,-5.25],'cooking, washing and service access; no sleeping-room through route')
space('F03_B_PRIVATE_HALL',[13.0,-9.8,15.65,-5.25],'independent access to sleeping alcove and bathroom')
space('F03_B_ALCOVE',[9.5,-12.35,13.0,-8.05],'Omar sleeping and clothes storage; retained canonical alcove identity',exterior_sides=['south'])
space('F03_B_BATH',[13.0,-12.35,15.65,-9.8],'complete private bathing and sanitation','wet',exterior_sides=['south','east'])

def door(identity, center, connects, axis='z', width=.81):
    additions['doors'].append(dict(id=identity,level='F03',center=center,width=width,height=2.13,
        yaw=1.5707963 if axis=='z' else 0.0,hinge='left',swing='in',connects=connects))

door('F03_DOOR_03',[9.5,-3.25],['F03_SERVICE_CROSSING','F03_B_VESTIBULE'],width=.91)
door('F03_SERVICE_CORE_DOOR',[9.5,5.5],['F03_SERVICE_HALL','F03_SERVICE_CORE'],width=.91)
door('F03_B_SERVICE_DOOR',[9.5,-6.8],['F03_SERVICE_HALL_SOUTH','F03_B_KITCHEN'],width=.91)
door('F03_B_ALCOVE_DOOR',[13.0,-9.15],['F03_B_PRIVATE_HALL','F03_B_ALCOVE'])
door('F03_B_BATH_DOOR',[14.2,-9.8],['F03_B_PRIVATE_HALL','F03_B_BATH'],'x')

def opening(identity, center, connects, axis='z', width=1.2):
    additions['openings'].append(dict(id=identity,level='F03',center=center,width=width,height=2.4,
        axis=axis,connects=connects,shared_wall_owner=connects[0]))

opening('F03_CORE_EAST_HALL_OPENING',[5.4,-3.25],['F03_PUBLIC_CORE','F03_EAST_HALL'])
opening('F03_EAST_CROSSING_OPENING',[8.3,-3.25],['F03_EAST_HALL','F03_SERVICE_CROSSING'])
opening('F03_SERVICE_NORTH_OPENING',[8.9,-2.65],['F03_SERVICE_CROSSING','F03_SERVICE_HALL'],'x')
opening('F03_SERVICE_SOUTH_OPENING',[8.9,-3.85],['F03_SERVICE_CROSSING','F03_SERVICE_HALL_SOUTH'],'x')
opening('F03_B_MAIN_OPENING',[11.5,-2.5],['F03_B_VESTIBULE','F03_B_MAIN'])
opening('F03_B_MAIN_HALL_OPENING',[14.2,-5.25],['F03_B_MAIN','F03_B_PRIVATE_HALL'],'x')
opening('F03_B_KITCHEN_OPENING',[13.0,-6.8],['F03_B_KITCHEN','F03_B_PRIVATE_HALL'])

for identity, room, center, axis, width, height, sill in [
    ('F03_B_MAIN_WINDOW_E','F03_B_MAIN',[15.65,-1.8],'z',1.8,1.7,.75),
    ('F03_B_ALCOVE_WINDOW_S','F03_B_ALCOVE',[11.15,-12.35],'x',1.5,1.7,.75),
    ('F03_B_BATH_WINDOW_E','F03_B_BATH',[15.65,-11.1],'z',.9,1.0,1.25)]:
    additions['windows'].append(dict(id=identity,level='F03',space=room,center=center,axis=axis,width=width,height=height,sill=sill))

for identity, room, position, yaw in [
    ('F03_B_ENTRY_STANCE','F03_SERVICE_CROSSING',[8.95,0,-3.25],-1.5707963),
    ('F03_B_REPAIR_STANCE','F03_B_MAIN',[13.65,0,-.85],0),
    ('F03_B_RADIATOR_01','F03_B_MAIN',[15.4,.75,-3.4],1.5707963),
    ('F03_B_RADIATOR_STANCE','F03_B_MAIN',[14.45,0,-3.4],-1.5707963),
    ('F03_B_KITCHEN_SERVICE_STANCE','F03_B_KITCHEN',[10.2,0,-6.8],1.5707963),
    ('F03_SERVICE_TRANSFER_STANCE','F03_SERVICE_HALL',[8.9,0,5.5],-1.5707963)]:
    additions['anchors'].append(dict(id=identity,level='F03',space=room,position=position,yaw=yaw,kind='interaction' if identity.endswith('_01') else 'clearance'))
for name, position in [('LANDING',[-1.5,.85,0]),('EAST_HALL',[6.8,.85,-3.25]),('CROSSING',[8.9,.85,-3.25]),
                       ('3B_ENTRY',[10.4,.85,-2.5]),('3B_MAIN',[13.1,.85,-2.5]),('3B_HALL',[14.2,.85,-6.3]),
                       ('3B_KITCHEN',[11.4,.85,-6.8]),('3B_ALCOVE',[11.3,.85,-9.15]),('3B_BATH',[14.2,.85,-10.6]),
                       ('SERVICE_RISER_BYPASS',[7.7,.85,.5]),('SERVICE_HALL',[8.9,.85,5.5]),
                       ('SERVICE_ENTRY',[10.0,.85,5.5])]:
    additions['capsule_stations'].append(dict(id='F03_CAPSULE_'+name,level='F03',position=position))
for identity, a, b, via in [
    ('ROUTE_PRIMARY_F02_F03','F02_PUBLIC_CORE','F03_PUBLIC_CORE','PRIMARY_F02_F03'),
    ('ROUTE_PRIMARY_F03_F04','F03_PUBLIC_CORE','F04_PUBLIC_CORE','PRIMARY_F03_F04'),
    ('ROUTE_F03_CORE_EAST','F03_PUBLIC_CORE','F03_EAST_HALL','F03_CORE_EAST_HALL_OPENING'),
    ('ROUTE_F03_EAST_CROSSING','F03_EAST_HALL','F03_SERVICE_CROSSING','F03_EAST_CROSSING_OPENING'),
    ('ROUTE_F03_3B_ENTRY','F03_SERVICE_CROSSING','F03_B_VESTIBULE','F03_DOOR_03'),
    ('ROUTE_F03_3B_MAIN','F03_B_VESTIBULE','F03_B_MAIN','F03_B_MAIN_OPENING'),
    ('ROUTE_F03_SERVICE_NORTH','F03_SERVICE_CROSSING','F03_SERVICE_HALL','F03_SERVICE_NORTH_OPENING'),
    ('ROUTE_F03_SERVICE_SOUTH','F03_SERVICE_CROSSING','F03_SERVICE_HALL_SOUTH','F03_SERVICE_SOUTH_OPENING'),
    ('ROUTE_F03_SERVICE_CORE','F03_SERVICE_HALL','F03_SERVICE_CORE','F03_SERVICE_CORE_DOOR'),
    ('ROUTE_F03_SERVICE_KITCHEN','F03_SERVICE_HALL_SOUTH','F03_B_KITCHEN','F03_B_SERVICE_DOOR')]:
    additions['route_edges'].append(dict(id=identity,**{'from':a,'to':b},via=via))
additions['service_connections'] += [
    dict(id='F03_B_HEAT_BRANCH',**{'from':'HEAT_STACK','to':'F03_B_RADIATOR_01'},system='heat'),
    dict(id='F03_B_KITCHEN_EXHAUST',**{'from':'F03_B_KITCHEN','to':'F03_SERVICE_CORE'},system='exhaust')]

# Clear use reservations, not substitute meshes or invented case apparatus.
additions['platforms'].append(dict(id='F03_SERVICE_ENTRY_PLATFORM',level='F03',rect=[9.5,5.0,10.55,6.05],**{'class':'core'}))
for identity, rect, purpose in [
    ('F03_B_REPAIR_USE',[12.4,-1.5,14.8,-.2],'categorized repair work and seated approach'),
    ('F03_B_KITCHEN_WORK_AISLE',[10.55,-7.8,11.65,-5.5],'1.10 m cooking work aisle'),
    ('F03_B_BATH_USE',[13.5,-11.9,14.6,-10.1],'basin and bathing approach'),
    ('F03_B_SLEEP_USE',[9.95,-11.8,12.2,-9.8],'sleep and bedside approach')]:
    additions['envelopes'].append(dict(id=identity,level='F03',rect=rect,height=.02,**{'class':'clearance'},purpose=purpose))

existing = {r['id'] for records in source.values() if isinstance(records,list) for r in records if isinstance(r,dict) and 'id' in r}
for table, records in additions.items():
    for record in records:
        assert record['id'] not in existing, record['id']
        existing.add(record['id'])
    start = original.index('  "'+table+'": [')
    end = original.index('\n  ]',start)
    original = original[:end].rstrip()+',\n'+',\n'.join('    '+json.dumps(r,separators=(',',':')) for r in records)+original[end:]
result = json.loads(original)
for table in additions:
    assert result[table][:len(source[table])] == source[table]
path.write_text(original,encoding='utf-8',newline='\n')
(Path(__file__).parent/'additions.json').write_text(json.dumps(additions,indent=2)+'\n',encoding='utf-8',newline='\n')
print({table:len(records) for table,records in additions.items()})
