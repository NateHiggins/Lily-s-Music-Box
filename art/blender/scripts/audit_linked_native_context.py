"""Run native inspectors with explicit linked-object updates and optional selected renders.

Read-only with respect to source/exports. Instrumented results are INERT triage,
not a replacement for the committed inspectors or their rendered acceptance.
"""
from pathlib import Path
import argparse,ast,contextlib,hashlib,json,os,re,sys,time,traceback
import bpy

ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())

def call_name(node):
 if isinstance(node,ast.Name):return node.id
 if isinstance(node,ast.Attribute):return call_name(node.value)+'.'+node.attr
 return ''

class Instrument(ast.NodeTransformer):
 def __init__(self,render=False):self.links=0;self.renders=0;self.render=render
 def visit_Expr(self,node):
  node=self.generic_visit(node)
  if isinstance(node.value,ast.Call) and call_name(node.value.func).endswith('.objects.link'):
   self.links+=1
   update=ast.parse('bpy.context.view_layer.update()').body[0]
   return [node,ast.copy_location(update,node)]
  return node
 def visit_Call(self,node):
  node=self.generic_visit(node)
  name=call_name(node.func)
  if name=='bpy.ops.render.render':
   self.renders+=1
   if self.render:node.func=ast.Name(id='__audit_render__',ctx=ast.Load());return node
   return ast.copy_location(ast.Set(elts=[ast.Constant('FINISHED')]),node)
  if name in ['bpy.ops.wm.save_as_mainfile','bpy.ops.wm.save_mainfile'] or name.startswith('bpy.ops.export_'):
   raise ValueError('Inspector contains source/export mutation: '+name)
  return node

def run_one(path,destination,render=False,view=None):
 source=path.read_bytes();tree=ast.parse(source.decode('utf-8'),filename=str(path));rewritten=0
 # Redirect only module-level output variables, preserving inspector input paths.
 output_variable={'inspect_orison_ground':'base','inspect_roof_drainage_bulkhead_weather':'O'}.get(path.stem,'out')
 file_output=path.stem in ['inspect_roof_drainage_provider_fits','inspect_roof_drainage_retained_clearance']
 for node in tree.body:
  if isinstance(node,ast.Assign) and any(isinstance(t,ast.Name) and t.id==output_variable for t in node.targets):
   node.value=ast.parse('Path(__audit_output__)').body[0].value;rewritten+=1
 if not rewritten:raise ValueError('No explicit top-level out assignment; review this inspector separately')
 transform=Instrument(render);tree=transform.visit(tree);ast.fix_missing_locations(tree)
 destination.mkdir(parents=True,exist_ok=True)
 instrumented=ast.unparse(tree)+'\n';(destination/'instrumented.py').write_text(instrumented,encoding='utf-8',newline='\n')
 started=time.monotonic();before_env=dict(os.environ);before_path=list(sys.path);before_args=list(sys.argv);before_cwd=Path.cwd()
 result={'script':path.relative_to(ROOT).as_posix(),'source_sha256':hashlib.sha256(source.replace(b'\r\n',b'\n')).hexdigest(),
  'instrumented_sha256':hashlib.sha256(instrumented.encode()).hexdigest(),'linked_update_sites':transform.links,'disabled_render_sites':0 if render else transform.renders,'output':destination.relative_to(ROOT).as_posix()}
 rendered=[];skipped=[]
 def render_view(**kwargs):
  target=Path(bpy.context.scene.render.filepath).resolve();assert target.is_relative_to(destination)
  if view and not re.search(view,target.name):skipped.append(target.name);return {'FINISHED'}
  result=bpy.ops.render.render(**kwargs);rendered.append(target.name);return result
 namespace={'__file__':str(path),'__name__':'__main__','__audit_output__':str(destination/'inspection.json' if file_output else destination),'__audit_render__':render_view}
 result['rendered_views']=rendered;result['skipped_views']=skipped
 try:
  bpy.ops.wm.read_factory_settings(use_empty=True);sys.argv=[str(path)];sys.path.insert(0,str(path.parent));os.chdir(ROOT)
  with (destination/'inspection.log').open('w',encoding='utf-8',newline='\n') as log,contextlib.redirect_stdout(log),contextlib.redirect_stderr(log):
   exec(compile(tree,str(path),'exec'),namespace)
  result['status']='PASS'
 except Exception as exc:
  result['status']='FAIL';result['error']=str(exc)
  (destination/'error.txt').write_text(traceback.format_exc(),encoding='utf-8',newline='\n')
  if namespace.get('all_errors'):
   (destination/'all_intersections.json').write_text(json.dumps(namespace['all_errors'],indent=2)+'\n',encoding='utf-8',newline='\n')
  elif 'actual_tree' in namespace:
   pairs=[];tree_for=namespace['actual_tree']
   for left in namespace.get('local_draws',namespace.get('draws',[])):
    for right in namespace.get('accepted',[]):
     intersections=tree_for(left).overlap(tree_for(right))
     if not intersections:continue
     def points(obj,indices):return [[float(x) for x in obj.matrix_world@obj.data.vertices[i].co] for i in indices]
     pairs.append({'left':left.name,'right':right.name,'count':len(intersections),'triangles':[{'left':points(left,left.data.polygons[a].vertices),'right':points(right,right.data.polygons[b].vertices)} for a,b in intersections[:16]]})
   (destination/'linked_intersections.json').write_text(json.dumps(pairs,indent=2)+'\n',encoding='utf-8',newline='\n')
 finally:
  sys.argv=before_args;sys.path[:]=before_path;os.environ.clear();os.environ.update(before_env);os.chdir(before_cwd)
 result['elapsed_s']=round(time.monotonic()-started,3)
 return result

def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--family',action='append');parser.add_argument('--out',type=Path,default=ROOT/'tmp/v2-finish-review/linked-context-audit')
 parser.add_argument('--render',action='store_true',help='Render requested views after geometry checks; output stays in tmp')
 parser.add_argument('--view',help='Regex selecting output image filenames; requires --render')
 args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
 if args.view and not args.render:parser.error('--view requires --render')
 output=args.out.resolve();assert output.is_relative_to(ROOT/'tmp'),'audit output must stay in repository tmp'
 output.mkdir(parents=True,exist_ok=True)
 paths=[ROOT/f'art/blender/scripts/inspect_{family}.py' for family in args.family] if args.family else [p for p in sorted((ROOT/'art/blender/scripts').glob('inspect_*.py')) if 'libraries.load' in p.read_text(encoding='utf-8')]
 results=[]
 for path in paths:
  try:result=run_one(path,output/path.stem.removeprefix('inspect_'),args.render,args.view)
  except Exception as exc:result={'script':path.relative_to(ROOT).as_posix(),'status':'UNSUPPORTED','error':str(exc)}
  results.append(result)
  (output/'audit.json').write_text(json.dumps({'evidence_class':'INERT','scope':'Instrumented native QA with explicit output redirection. Only rendered_views are new images; inspector view lists may include skipped views. No source edits, exports, runtime proof or acceptance.','results':results},indent=2)+'\n',encoding='utf-8',newline='\n')
  print('LINKED CONTEXT',result['status'],path.name,round(result.get('elapsed_s',0),2),str(result.get('error',''))[:200],flush=True)
 print('LINKED CONTEXT TOTAL',len(results),'passed',sum(r['status']=='PASS' for r in results),'failed',sum(r['status']=='FAIL' for r in results),'unsupported',sum(r['status']=='UNSUPPORTED' for r in results),flush=True)

if __name__=='__main__':main()
