"""Pure closed trade-floor stocks for the existing arcade native producer.

Coordinates are PLAN (u,v,height). Replace each unfinished shop_deck; never
add these over it. Shader/UV binding, export and runtime admission stay external.
"""
import copy
import hashlib
import json
import math

CELLS=frozenset('shop_'+s for s in ('funeral_parlour','shoe_rebuilding','keys_cut','news_cigars','photo_supplies','otis_son','radio_service','pawnbroker','model_laundry','hardware_paint','luncheonette'))
FACES=[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)]


def _need(condition,message):
    if not condition:raise ValueError(message)


def _rect(value):
    _need(isinstance(value,list) and len(value)==4 and all(type(v) in (int,float) and math.isfinite(v) for v in value),'finite rectangle required')
    _need(value[2]>value[0] and value[3]>value[1],'positive rectangle required')
    return value


def _record(record,identity,batch):
    _need(record['id']==identity and record.get('batch')==batch and record.get('zone')=='PASSAGE','floor source ownership changed')
    _rect(record.get('rect'))
    _need(type(record.get('z0')) in (int,float) and math.isfinite(record['z0']) and type(record.get('h')) in (int,float) and math.isfinite(record['h']) and record['h']>0,'invalid original floor vertical bounds')
    _need(isinstance(record.get('mat'),str) and bool(record['mat'].strip()),'original floor material missing')
    return record


def _stock(cell,role,rect,layer,source):
    x0,y0,x1,y1=_rect(rect)
    vertices=[(x,y,z) for z in [-layer,0.] for y in [y0,y1] for x in [x0,x1]]
    return dict(name=cell+'_'+role,owner=cell,role=role,vertices=vertices,faces=list(FACES),
                material=source['mat']+'_b',material_family=source['mat'],
                source_record_id=source['id'],source_record=copy.deepcopy(source),
                source_record_sha256=hashlib.sha256(json.dumps(source,sort_keys=True,separators=(',',':'),allow_nan=False).encode()).hexdigest(),
                plan_rect_m=list(rect),bottom_m=-layer,top_m=0.,area_m2=(x1-x0)*(y1-y0),
                closed_volume_m3=(x1-x0)*(y1-y0)*layer,replaces_unfinished_deck=cell+'_deck',
                disposal_authorized=False,admission='SOURCE_GEOMETRY_ONLY_NOT_RUNTIME_OR_ART_ACCEPTANCE')


def stocks(plan,original_layout):
    """Return exactly22 closed stocks; source snapshots remain literal and intact."""
    shops=plan.get('shops',[])
    _need(len(shops)==11 and {s['id'] for s in shops}==CELLS,'eleven unique canonical shop cells required')
    layer=plan.get('finish_layer_m')
    _need(type(layer) in (int,float) and math.isfinite(layer) and layer>0,'positive finite finish layer required')
    floors=[f for f in original_layout.get('floors',[]) if f.get('id')=='F01']
    _need(len(floors)==1,'exactly one original F01 required')
    records={}
    for r in floors[0]['furniture']:
        records.setdefault(r['id'],[]).append(r)
    result=[]
    for shop in shops:
        cell=shop['id'];tag=cell.removeprefix('shop_')
        if tag=='otis_son':tag='otis___son'
        batch='shop_'+tag
        identities=['storm_shop_'+tag+'_floor','site_rear_'+tag+'_floor']
        _need(all(len(records.get(i,[]))==1 for i in identities),'missing or duplicate original floor source')
        sales,rear=[_record(records[i][0],i,batch) for i in identities]
        _need(rear['mat']=='concrete','original stock floor must retain concrete')
        rect=_rect(shop['rect_m']);partition=_rect(shop['partition_rect_m']);stock=_rect(shop['stock_rect_m'])
        x0,y0,x1,y1=rect;a,b,c,d=partition
        _need(x0<a<c<x1 and y0<b<d<y1,'partition must be inside shop envelope')
        front=shop['front']
        if front in ('east','west'):
            _need(d-b>c-a,'side-shop partition must be vertical')
            split=(a+c)*.5
            if front=='east':
                _need(stock[2]<=a and stock[0]>=x0 and stock[1]>=y0 and stock[3]<=y1,'west stock responsibility mismatch')
                sales_rect=[split,y0,x1,y1];rear_rect=[x0,y0,split,y1]
            else:
                _need(stock[0]>=c and stock[2]<=x1 and stock[1]>=y0 and stock[3]<=y1,'east stock responsibility mismatch')
                sales_rect=[x0,y0,split,y1];rear_rect=[split,y0,x1,y1]
        else:
            _need(front=='north' and c-a>d-b,'rear-shop partition must be horizontal')
            _need(stock[1]>=d and stock[3]<=y1 and stock[0]>=x0 and stock[2]<=x1,'rear stock responsibility mismatch')
            split=(b+d)*.5
            sales_rect=[x0,y0,x1,split];rear_rect=[x0,split,x1,y1]
        result.extend([_stock(cell,'sales_floor',sales_rect,layer,sales),_stock(cell,'stock_floor',rear_rect,layer,rear)])
    _need(len(result)==22 and len({r['name'] for r in result})==22,'floor stock identity ambiguity')
    return result
