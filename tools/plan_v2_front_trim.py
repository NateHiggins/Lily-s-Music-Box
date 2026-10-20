"""Project bounded native trim splices from actual source-shell instances."""
import argparse,collections,hashlib,json,math
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
WIDTH=.14
SOURCES=('game/data/orison_v2_blockout.json','game/scripts/building/orison_v2_millwork.gd','game/scripts/building/orison_v2_blockout.gd')
def validate_source(root,snapshot):
    for relative in SOURCES:
        expected=snapshot.get('source_bindings_lf',{}).get(relative)
        if not expected or hashlib.sha256((root/relative).read_bytes().replace(b'\r\n',b'\n')).hexdigest()!=expected:
            raise ValueError('Source-shell discovery is stale or unbound: '+relative)
def dot(a,b):return sum(x*y for x,y in zip(a,b))
def sub(a,b):return [x-y for x,y in zip(a,b)]
def add(a,b):return [x+y for x,y in zip(a,b)]
def mul(a,s):return [x*s for x in a]
def unit(a):return mul(a,1/math.sqrt(dot(a,a)))
def pose(row):return [v for column in row['basis'] for v in column]+row['position']
def merge(intervals):
    result=[]
    for lo,hi in sorted(intervals):
        if hi<=lo:raise ValueError('Empty cut interval')
        if result and lo<=result[-1][1]+1e-8:result[-1][1]=max(result[-1][1],hi)
        else:result.append([lo,hi])
    return result

def plan(layout,snapshot,asset_hash,profile_hash):
    rooms={r['id']:r for r in layout['spaces']}
    records=collections.defaultdict(list)
    seen=set()
    for row in snapshot['records']:
        key=(row['room'],row['index'])
        if key in seen or not all(math.isfinite(v) for v in pose(row)) or any(dot(v,v)<1e-12 for v in row['basis']):
            raise ValueError('Invalid/duplicate source instance '+str(key))
        seen.add(key);records[row['room']].append(row)
    cuts={};fittings=[]
    def cut(row,center):
        basis=row['basis'];length=math.sqrt(dot(basis[0],basis[0]));delta=sub(center,row['position'])
        x=dot(delta,basis[0])/(length*length);half=WIDTH/2/length
        lo,hi=max(-.5,x-half),min(.5,x+half)
        if hi-lo<1e-7:return False
        key=(row['room'],row['index'])
        if key not in cuts:cuts[key]=dict(index=row['index'],source=row['source'],expected=pose(row),intervals=[])
        cuts[key]['intervals'].append([lo,hi]);return True
    # Eye-level switch rail retired by the owner. Only retained cornice stock
    # needs bored fittings; switches keep their original wall service owners.
    for port in layout.get('wall_service_openings',[]):
        if '_FRONT_LIGHT_PORT_' not in port['id']:continue
        room=rooms[port['space']]
        if room.get('no_ceiling') or not (room['class'] in ['public','private'] or 'PUBLIC_CORE' in room['id']):continue
        bounds=port['bounds'];center=[(bounds[i]+bounds[i+3])/2 for i in range(3)]
        normal={'north':[0,0,-1],'south':[0,0,1],'west':[1,0,0],'east':[-1,0,0]}[port['side']]
        face=add(center,mul(normal,layout['dimensions']['partition_wall']/2));matches=[]
        for row in records[port['space']]:
            b=row['basis'];z=unit(b[2]);depth=math.sqrt(dot(b[2],b[2]))
            if not center[1]-.076<row['position'][1]<center[1]+.051 or dot(z,normal)<.9999:continue
            if abs(dot(sub(sub(row['position'],mul(z,depth/2)),face),z))>1e-4:continue
            if cut(row,center):matches.append(row)
        if len(matches)<3:raise ValueError(f"{port['id']}: incomplete cornice seat ({len(matches)} fragments)")
        b=[unit(v) for v in matches[0]['basis']]
        fittings.append(dict(owner=port['id'],room=port['space'],variant='cornice',pose=[v for c in b for v in c]+face))
    groups=collections.defaultdict(list)
    for (room,index),row in sorted(cuts.items()):row['intervals']=merge(row['intervals']);groups[room].append(row)
    return dict(schema_version=1,asset='res://assets/props/front_lighting_trim.glb',asset_sha256=asset_hash,
        profile_asset='res://assets/props/millwork_profile.glb',profile_asset_sha256=profile_hash,catalog_key='trim',tile=1.2,
        parts=[dict(name=name,variant='cornice') for name in ['BoredCornice_0','BoredCornice_1','BoredCornice_2']],
        rooms=[dict(room=room,cuts=rows) for room,rows in sorted(groups.items())],fittings=fittings)

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--snapshot',type=Path,required=True);parser.add_argument('--export',type=Path,required=True);parser.add_argument('--out',type=Path,required=True);parser.add_argument('--check',action='store_true')
    args=parser.parse_args();layout=json.loads((ROOT/'game/data/orison_v2_blockout.json').read_text());snapshot=json.loads(args.snapshot.read_text());export=json.loads(args.export.read_text())
    validate_source(ROOT,snapshot)
    if hashlib.sha256((ROOT/'game/assets/props/front_lighting_trim.glb').read_bytes()).hexdigest()!=export['asset_sha256']:raise ValueError('Native trim export is stale')
    result=plan(layout,snapshot,export['asset_sha256'],hashlib.sha256((ROOT/'game/assets/props/millwork_profile.glb').read_bytes()).hexdigest())
    if args.check:
        if json.loads(args.out.read_text())!=result:raise ValueError('Runtime trim projection is stale')
    else:
        args.out.parent.mkdir(parents=True,exist_ok=True);args.out.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8',newline='\n')
    print(dict(fittings=collections.Counter(r['variant'] for r in result['fittings']),rooms=len(result['rooms']),source_instances=sum(len(r['cuts']) for r in result['rooms'])))
if __name__=='__main__':main()
