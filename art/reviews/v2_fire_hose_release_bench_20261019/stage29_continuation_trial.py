from pathlib import Path
import numpy as np,json
p=Path('tmp/v2-fire-hand-20261019/stage28_second_order_trial.py');scope={'__file__':str(p.resolve()),'__name__':'trial'}
exec(compile(p.read_text().split('trace=[]')[0],str(p),'exec'),scope)
initial=scope['x'].copy();final_offset=scope['off'].copy();norm=scope['norm'];ids=scope['ids'];eq=len(initial)-1
def metrics(x):
 j,g=scope['rows'](x);return [max(abs(g[:eq])),abs(sum(g[:eq])),max(0,-min(g[eq:]))]
def advance(x,budget):
 for iteration in range(budget):
  m=metrics(x)
  if m[0]<=1e-6 and m[1]<=5e-6 and m[2]<=1e-7:return x,iteration
  direction=scope['direction'](x);old=scope['merit'](x);a=1.
  while a>=1/4096 and scope['merit'](x+a*direction)>old*(1-.01*a):a*=.5
  if a<1/4096:return x,iteration
  x=x+a*direction
 return x,budget
out=[]
for stages in [1,8,32]:
 x=initial.copy();start_offset=np.minimum(final_offset,np.sum(norm*x[ids],axis=1)-.02)
 scope['off']=start_offset;x,it=advance(x,64);total=it
 print('start',stages,metrics(x),flush=True)
 for stage in range(1,stages+1):
  scope['off']=start_offset+(final_offset-start_offset)*(stage/stages);x,it=advance(x,64);total+=it
 print('stages',stages,'totaliterations',total,'metrics',metrics(x),flush=True);out.append({'stages':stages,'iterations':total,'metrics':metrics(x)})
Path('tmp/v2-fire-hand-20261019/stage29_continuation_trial.json').write_text(json.dumps({'evidence_class':'INERT','runs':out},indent=2))
