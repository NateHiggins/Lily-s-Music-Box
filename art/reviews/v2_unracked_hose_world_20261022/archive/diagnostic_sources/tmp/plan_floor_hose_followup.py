from pathlib import Path
import json,hashlib
root=Path(__file__).resolve().parents[1]
base=root/'art/reviews/v2_unracked_hose_20261022'
def key(path):
    data=json.loads(path.read_text())
    return hashlib.sha256(json.dumps({k:data[k] for k in ['frames','bind_frames']},sort_keys=True,separators=(',',':')).encode()).hexdigest()
qualified={key(p):p for p in (base/'world_coil_v4').glob('*_pose.json')}
plan=[];aliases=[]
for path in sorted((base/'world_coil_v5').glob('*_pose.json')):
    digest=key(path)
    if digest in qualified:
        aliases.append(dict(source=path.relative_to(root).as_posix(),identical_to=qualified[digest].relative_to(root).as_posix(),frames_sha256=digest));continue
    plan.append(dict(script='art/blender/scripts/review_deployed_hose.py',env={
        'ORISON_HOSE_POSE':str(path),'ORISON_HOSE_POSE_SOURCE':str(root/'art/blender/v2_unracked_hose/native_v1/blender/unracked_fire_hose.blend'),
        'ORISON_HOSE_POSE_OBJECT':'UnrackedHose','ORISON_HOSE_POSE_RINGS':'135',
        'ORISON_HOSE_POSE_REVIEW_OUT':str(root/'tmp/v2-unracked-hose-20261022'/('world_coil_v5_native_'+path.stem))}))
(base/'world_coil_v5/native_pose_aliases.json').write_text(json.dumps(dict(evidence_class='INERT',scope='Exact bind/current frame identity with previously reviewed native world poses.',aliases=aliases),indent=2)+'\n',newline='\n')
(root/'tmp/v2-unracked-hose-20261022/world_coil_v5_native_plan.json').write_text(json.dumps(dict(stages=plan),indent=2)+'\n',newline='\n')
print(len(plan),'changed native poses;',len(aliases),'exact reused poses')
