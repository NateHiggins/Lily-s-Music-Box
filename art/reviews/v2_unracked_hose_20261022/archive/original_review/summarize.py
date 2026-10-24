"""INERT measurements from retained original candidate records."""
from pathlib import Path
import gzip,json,math
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
def read(path):
    return json.loads(path.read_bytes() if path.exists() else gzip.decompress(Path(str(path)+'.gz').read_bytes()))
def percentile(values,fraction):
    values=sorted(values);index=(len(values)-1)*fraction
    lower=math.floor(index);upper=math.ceil(index)
    return values[lower]+(values[upper]-values[lower])*(index-lower)
def distribution(values):
    return {name:percentile(values,p) for name,p in [('p50',.5),('p95',.95),('p99',.99),('max',1.)]}
def without_timing(value):
    if isinstance(value,dict):return {k:without_timing(v) for k,v in value.items() if k!='profile_usec'}
    if isinstance(value,list):return [without_timing(v) for v in value]
    return value
def main():
    result=dict(evidence_class='INERT',scope='Separate unracked hose candidate. Input/geometry diagnostics only; no played-world frame-time, water, save or human acceptance.',payout={},controls={},native_poses=[])
    for folder in sorted(HERE.iterdir()):
        if not folder.is_dir():continue
        path=folder/'payout.json'
        if not path.exists() and not Path(str(path)+'.gz').exists():continue
        data=read(path);rows=data.get('steps',[])
        entry=dict(events=len(rows),failures=data.get('failures',[]))
        for key in ['input_ms','pose_latency_ms']:
            if rows and all(key in row for row in rows):entry[key]=distribution([row[key] for row in rows])
        if rows:entry.update(maximum_span_m=max(row.get('span_m',0.) for row in rows),events_with_pending_work=sum(row.get('pending_frames',0)>0 for row in rows))
        result['payout'][folder.name]=entry
    for kind in ['sparse','dense']:
        old=read(ROOT/'art/reviews/v2_hose_skin_20261022'/f'{kind}_control_final/gravity_trace.json')
        new=read(HERE/f'{kind}_control_final/gravity_trace.json')
        result['controls'][kind]=dict(all_non_timing_fields_identical=without_timing(old)==without_timing(new))
    for step in [0,64,128,192,256,272]:
        path=HERE/'native'/f'fast_native_{step}/deformed_geometry.json'
        if not path.exists():path=ROOT/'tmp/v2-unracked-hose-20261022'/f'fast_native_{step}/deformed_geometry.json'
        geometry=read(path)
        result['native_poses'].append(dict(step=step,crossings=geometry['self_crossing_pairs_without_shared_vertices'],nonmanifold=geometry['nonmanifold_edges'],volume_m3=geometry['signed_volume_m3'],known_crossing_control=geometry['known_crossing_control']))
    (HERE/'diagnostic_summary.json').write_text(json.dumps(result,indent=2)+'\n',newline='\n')
    print(json.dumps(dict(controls=result['controls'],before=result['payout']['guide_v6'],after=result['payout']['guide_v9'],native_poses=result['native_poses']),indent=2))
if __name__=='__main__':main()
