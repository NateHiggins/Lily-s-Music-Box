from pathlib import Path
import collections,json,hashlib
root=Path('C:/PleaseRemainOnTheLine');base=root/'tmp/v2-fire-hand-20261019'
records=[];traces=[]
for stem in ['stage30_profile1','stage30_native1']:
 path=base/stem/'gravity_trace.json';trace=json.loads(path.read_text());traces.append(trace)
 total=collections.Counter()
 for step in trace['steps']:total.update(step['profile_usec'])
 seconds={k:v/1e6 for k,v in total.items()};seconds['warm_start_and_bridge']=seconds['position_projection']-seconds['joint_projection']
 records.append({'run':stem,'trace_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'seconds':seconds,'projection_calls':sum(s['projection_calls'] for s in trace['steps'])})
def physical_steps(trace):return [{k:v for k,v in step.items() if k!='profile_usec'} for step in trace['steps']]
result={'evidence_class':'INERT','scope':'Diagnostic comparison only; no runtime contract or performance acceptance. Joint projection is a subtotal of position projection. Warm/bridge is their difference.','runs':records,'final_pose_equal':traces[0]['pose']==traces[1]['pose'],'physics_steps_equal':physical_steps(traces[0])==physical_steps(traces[1]),'initial_energy_equal':traces[0]['initial_energy']==traces[1]['initial_energy'],'final_energy_equal':traces[0]['final_energy']==traces[1]['final_energy']}
(base/'stage30_profile_comparison.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
