"""Compile same-ID shop actor and transaction anchors for the expanded arcade.

No installation or source retirement. Runtime patches alter spatial fields only;
full source/placement witnesses stay in the diagnostic fixture.
"""
from pathlib import Path
import argparse,copy,hashlib,json,math,struct
from prepare_arcade_native_projection import NativeGLB,mul
import prepare_arcade_door_frames as doors

ROOT=Path(__file__).resolve().parents[1]
RUNTIME=Path('game/data/orison_v2/arcade_actor_projection.json')
FIXTURE=Path('game/tests/fixtures/arcade_actor_projection.json')
RETAINED=Path('art/data/arcade_plaza/retained_equipment_placements.json')
KINDS={'passage_shop_hours','shop_sign','cage_bulb'}

def need(ok,message):
    if not ok:raise ValueError(message)

def sha(path):return hashlib.sha256(path.read_bytes().replace(b'\r\n',b'\n')).hexdigest()
def cell_suffix(cell):return 'OTIS___SON' if cell=='shop_otis_son' else cell[5:].upper()
def point(matrix,p):return [sum(matrix[i][j]*p[j] for j in range(3))+matrix[i][3] for i in range(3)]
def b2g(p):return [p[0],p[2],-p[1]]
def g2b(p):return [p[0],-p[2],p[1]]

def rooms(shop,depth):
    x0,y0,x1,y1=shop['rect_m'];a,b,c,d=shop['partition_rect_m']
    if shop['front']=='east':sales=[c,y0+depth,x1-depth,y1-depth]
    elif shop['front']=='west':sales=[x0+depth,y0+depth,a,y1-depth]
    else:sales=[x0+depth,y0+depth,x1-depth,b]
    return sales,shop['stock_rect_m']

def counter_bounds(root,retained,group,identity,family):
    declaration=next(f for f in retained['families'] if f['name']==family)
    asset=root/declaration['asset']
    need(hashlib.sha256(asset.read_bytes()).hexdigest()==declaration['asset_sha256'],'counter native asset changed')
    native=NativeGLB(asset);part=identity.removesuffix('_top')+'__countertop'
    need(part in native.names,'native transaction surface absent')
    pose=mul(group['delta_transform'],native.transform(native.names[part]));points=[]
    primitives=native.doc['meshes'][native.doc['nodes'][native.names[part]]['mesh']]['primitives']
    for primitive in primitives:
        accessor=native.doc['accessors'][primitive['attributes']['POSITION']]
        need(accessor['componentType']==5126 and accessor['type']=='VEC3' and not accessor.get('sparse'),'unsupported native counter positions')
        view=native.doc['bufferViews'][accessor['bufferView']];offset=view.get('byteOffset',0)+accessor.get('byteOffset',0)
        for i in range(accessor['count']):points.append(point(pose,struct.unpack_from('<3f',native.binary,offset+i*view.get('byteStride',12))))
    need(bool(points),'empty native counter')
    low=[min(p[i] for p in points) for i in range(3)];high=[max(p[i] for p in points) for i in range(3)]
    return low,high,dict(asset=declaration['asset'],asset_sha256=declaration['asset_sha256'],part=part)

def build(root=ROOT):
    plan=json.loads((root/doors.PLAN).read_text(encoding='utf-8'))
    layout=json.loads((root/doors.FABRICATION).read_text(encoding='utf-8'))
    need(sha(root/doors.PLAN)==doors.PLAN_SHA256_LF,'unreviewed shop plan')
    need(sha(root/doors.FABRICATION)==doors.FABRICATION_SHA256_LF,'fabrication changed')
    retained=json.loads((root/RETAINED).read_text(encoding='utf-8'))
    floor=next(f for f in layout['floors'] if f['id']=='F01');markers={m['id']:m for m in floor['markers']};furniture={m['id']:m for m in floor['furniture']}
    origin=plan['source_origin_blender_m'];depth=plan['wall_thickness_m'];entries=[];witnesses=[]
    for shop in plan['shops']:
        cell=shop['id'];suffix=cell_suffix(cell);name=cell[5:].replace('otis_son','otis___son')
        owned=[m for m in floor['markers'] if m['kind'] in KINDS and m['id'].endswith('_'+suffix) and m.get('zone')=='PASSAGE']
        need(len([m for m in owned if m['kind']=='shop_sign'])==1 and len([m for m in owned if m['kind']=='passage_shop_hours'])==1,'missing/duplicate shop authority')
        hours=markers['SITE_SHOP_HOURS_'+suffix];old=furniture['storm_shop_'+name+'_floor'];r=shop['rect_m'];front=shop['front'];sales,rear=rooms(shop,depth)
        along0,along1=(r[1],r[3]) if front!='north' else (r[0],r[2]);along=(along0+along1)*.5
        normal={'east':[1,0],'west':[-1,0],'north':[0,-1]}[front]
        centre=[r[2] if front=='east' else r[0] if front=='west' else along,along if front!='north' else r[1]]
        yaw={'east':270.,'west':90.,'north':180.}[front]
        inward_yaw={'east':90.,'west':270.,'north':0.}[front]
        for source in owned:
            patch={};role='';target=copy.deepcopy(source);p=source['pos'];kind=source['kind']
            if kind=='passage_shop_hours':
                u,v=[centre[i]-normal[i]*(depth+.04) for i in range(2)]
                patch=dict(pos=[origin[0]+u,origin[1]-v,p[2]-.01],yaw_deg=inward_yaw,w=along1-along0-.28);role='original_hours_grille'
            elif kind=='shop_sign':
                u,v=[centre[i]+normal[i]*.005 for i in range(2)]
                half=(along1-along0)/2
                patch=dict(pos=[origin[0]+u,origin[1]-v,p[2]],yaw_deg=yaw,half_width=half,blade_dx=max(0.,half-.46));role='original_authored_lettering'
            elif source['id'].startswith('SITE_SHOP_LT_'):
                door_along=shop['entrance_center_m'][1 if front!='north' else 0]
                edge=along0+depth*.5 if door_along<along else along1-depth*.5
                u,v=(centre[0],edge) if front!='north' else (edge,centre[1])
                patch=dict(pos=[origin[0]+u+normal[0]*.02,origin[1]-v-normal[1]*.02,p[2]-.01],yaw_deg=inward_yaw);role='original_fascia_fixture_corner_pier'
            elif source['id'].startswith('SITE_SHOP_DARKROOM_'):
                group=next(g for g in retained['groups'] if g['cell']==cell and g['id']=='all4_original_developing_trays_all3_tanks_and_print_dryer')
                q=point(group['delta_transform'],b2g(p))
                q[0]=min(origin[0]+rear[2]-.22,max(origin[0]+rear[0]+.22,q[0]))
                q[2]=-origin[1]+rear[1]+.02
                patch=dict(pos=g2b(q),yaw_deg=0.);role='original_safelight_north_stock_wall_process_group'
            else:
                need(source['id'].startswith(('SITE_SHOP_IN0_','SITE_SHOP_IN1_','SITE_SHOP_IN2_')),'unclassified shop light')
                a,b,c,d=old['rect'];old_west=float(hours['yaw_deg'])==90.
                lateral=(-p[1]+d)/(d-b);distance=(c-p[0])/(c-a) if old_west else (p[0]-a)/(c-a)
                need(-.001<=lateral<=1.001 and -.001<=distance<=1.001,'interior fixture outside original sales floor')
                x0,y0,x1,y1=sales
                if front=='east':u,v=x1-distance*(x1-x0),y0+lateral*(y1-y0)
                elif front=='west':u,v=x0+distance*(x1-x0),y0+lateral*(y1-y0)
                else:u,v=x0+lateral*(x1-x0),y0+distance*(y1-y0)
                patch=dict(pos=[origin[0]+u,origin[1]-v,p[2]-.01],yaw_deg=inward_yaw);role='original_sales_light_relative_floor_position'
            need(all(type(x) in (int,float) and math.isfinite(x) for x in patch['pos']),'invalid target position')
            target.update(patch);entries.append(dict(id=source['id'],kind=kind,patch=patch))
            witnesses.append(dict(id=source['id'],cell=cell,role=role,source_marker=copy.deepcopy(source),target_marker=target))
    need(len(entries)==61 and len({e['id'] for e in entries})==61,'61same-ID shop actors required')
    anchors=[];anchor_witness=[]
    for cell,identity in [('shop_hardware_paint','storm_shop_hardware_paint_counter_top'),('shop_news_cigars','storm_shop_news_cigars_counter_top')]:
        source=furniture[identity];base=identity.removesuffix('_top')
        matches=[g for g in retained['groups'] if g['cell']==cell and any(a['id']==base for a in g['native_assemblies'])]
        need(len(matches)==1,'counter owner ambiguity');group=matches[0];rect=source['rect']
        family='hardware_stock' if cell=='shop_hardware_paint' else 'news_fittings'
        lo,hi,native_source=counter_bounds(root,retained,group,identity,family)
        need(abs(hi[1]-lo[1]-source['h'])<2e-5,'counter native height differs from authored transaction surface')
        patch=dict(rect=[lo[0],-hi[2],hi[0],-lo[2]],z0=lo[1]);anchors.append(dict(id=identity,patch=patch))
        anchor_witness.append(dict(id=identity,cell=cell,group=group['id'],source_record=copy.deepcopy(source),delta_transform=group['delta_transform'],native_source=native_source,target_low=lo,target_high=hi,legacy_width_difference_m=(hi[0]-lo[0])-(rect[2]-rect[0]),target_record=dict(source,**patch)))
    runtime=dict(schema='orison.v2.arcade-actor-projection.v1',source_sha256_lf=sha(root/doors.FABRICATION),markers=entries,anchors=anchors)
    fixture=dict(evidence_class='INERT',scope='Same-ID spatial preparation only; no installed actors/service/save/source-retirement acceptance',source_bindings={p.as_posix():sha(root/p) for p in [doors.PLAN,doors.FABRICATION,RETAINED,Path('tools/prepare_arcade_actor_projection.py')]},markers=witnesses,anchors=anchor_witness,external_vantry_applied=False)
    return runtime,fixture

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--check',action='store_true');args=p.parse_args();docs=build()
    for rel,doc in zip([RUNTIME,FIXTURE],docs):
        text=json.dumps(doc,indent=1,allow_nan=False)+'\n';path=ROOT/rel
        if args.check:need(path.read_text(encoding='utf-8').replace('\r\n','\n')==text,'actor projection stale: '+str(rel))
        else:path.write_text(text,encoding='utf-8',newline='\n')
    print('ARCADE ACTOR PROJECTION OK:61markers/2transaction anchors; preparation only')
if __name__=='__main__':main()
