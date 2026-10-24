import json,statistics
from pathlib import Path
ROOT=Path(__file__).parent
runs={'before':ROOT.parent/'v2_device_hand_20261023/world_v2/profile.json','shadow_control':ROOT/'shadow_control_v1/profile.json','paired_views':ROOT/'paired_views_v1/profile.json','production_v1':ROOT/'production_v1/profile.json','production_v2':ROOT/'production_v2/profile.json','production_final':ROOT/'production_final/profile.json'}
def q(a,p):
 a=sorted(a);x=(len(a)-1)*p;i=int(x);return a[i]+(a[min(i+1,len(a)-1)]-a[i])*(x-i)
out={'evidence_class':'INERT','limits':['First partial sample excluded for each phase. Movement phases share 300 physics ticks,1280x720,Forward+,VSync off,uncapped.','Paired room refresh phases are still-eye diagnostics: six settled samples precede each refresh; image readbacks follow sampling.','No cold-driver claim. Render/process/physics monitors overlap and lag; asset loading/streaming not independently isolated.','Fixtures/weather can vary; compare lit/dark and oblique images as well as frame distributions. Mirror timings are meaningful only while the mirror is active.'],'runs':{}}
for name,path in runs.items():
 if not path.exists():continue
 d=json.loads(path.read_text(encoding='utf-8'));r={'settings':d['settings'],'phases':{}}
 for phase in sorted(set(s['phase'] for s in d['samples'])):
  a=[s for s in d['samples'] if s['phase']==phase][1:];v=[s['wall_ms'] for s in a]
  row={'frames':len(a),'wall_ms':{'p50':q(v,.5),'p95':q(v,.95),'p99':q(v,.99),'max':max(v)},'over_50ms':sum(x>50 for x in v),'over_100ms':sum(x>100 for x in v),'surface_delta':max(s['pipeline_surface'] for s in a)-min(s['pipeline_surface'] for s in a),'draw_calls_median':statistics.median(s['draw_calls'] for s in a)}
  for field in ['main_render_cpu_ms','main_render_gpu_ms','physics_ms','process_ms']:row[field+'_median']=statistics.median(s[field] for s in a)
  active=[s for s in a if s.get('mirror_active',False)];row['mirror_active_frames']=len(active)
  if active:
   row['mirror_cpu_ms_median']=statistics.median(s['mirror_cpu_ms'] for s in active);row['mirror_gpu_ms_median']=statistics.median(s['mirror_gpu_ms'] for s in active);row['mirror_occlusion']=active[0].get('mirror_occlusion',False)
  r['phases'][phase]=row
 out['runs'][name]=r
(ROOT/'comparison.json').write_text(json.dumps(out,indent=2)+'\n',encoding='utf-8',newline='\n')
for name,r in out['runs'].items():print(name,r['phases']['first_print']['wall_ms'])
