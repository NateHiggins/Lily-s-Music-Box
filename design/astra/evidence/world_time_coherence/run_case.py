import argparse, datetime, hashlib, json, os, re, subprocess, time
from pathlib import Path

ROOT = Path(r'C:\PleaseRemainOnTheLine-astra')
BASE = Path(__file__).resolve().parent
PWSH = r'C:\Users\nate_\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe'
args = argparse.ArgumentParser()
args.add_argument('name')
args.add_argument('scene')
args.add_argument('--timeout',type=int,default=40)
args.add_argument('--legacy',default='')
args.add_argument('--expected-exit',type=int,default=0)
cfg = args.parse_args()
out = BASE / 'runtime' / cfg.name
out.mkdir(parents=True,exist_ok=False)
def sha(data): return hashlib.sha256(data).hexdigest()
def git(*values): return subprocess.check_output(['git','-C',str(ROOT),*values],stderr=subprocess.DEVNULL)
def snapshot(tag):
    diff=git('diff','HEAD','--binary','--','game','tools')
    (out/(tag+'.diff')).write_bytes(diff)
    rels=set(git('diff','HEAD','--name-only','--','game','tools').decode().splitlines()+git('ls-files','--others','--exclude-standard','game','tools').decode().splitlines())
    return {'head':git('rev-parse','HEAD').decode().strip(),'diff_sha256':sha(diff),'files':{p:sha((ROOT/p).read_bytes()) for p in sorted(rels) if (ROOT/p).is_file()}}
env=os.environ.copy()
profile=out/'userdata'
profile.mkdir()
env['APPDATA']=str(profile)
for key in ['ORISON_BUILDING_ROOT','DAYNIGHT','DAYNIGHT_FORCE','SCHEDULE','SCHEDULE_MINUTE','SCHEDULE_DAY','SCHEDULE_DOY','CAMPAIGN_TIME_FREEZE','SHOT_DIR']:
    env.pop(key,None)
env['WORLD_TIME_LEGACY_CONTROL']=cfg.legacy
env['WORLD_TIME_LEGACY_SOURCE_DIR']=str(BASE/'red_sources')
env['M11A_OBJECTIVE_RECEIPT']=str(out/'objective_receipt.json')
def q(value): return "'"+str(value).replace("'","''")+"'"
log=out/'stdout.log'
command='& '+q(ROOT/'tools/run_godot_serial.ps1')+' -Scene '+q(cfg.scene)+' -ProjectPath '+q(ROOT/'game')+' -LogPath '+q(log)+' -TimeoutSeconds '+str(cfg.timeout)+" -ExtraArgs @('--verbose')"
command += '\nexit $LASTEXITCODE'
argv=[PWSH,'-NoProfile','-ExecutionPolicy','Bypass','-Command',command]
receipt={'schema':'astra.world_time.runtime_case.v1','case':cfg.name,'scene':cfg.scene,'expected_exit':cfg.expected_exit,'legacy_control':cfg.legacy,'command':argv,'APPDATA':str(profile),'test_directory_precreated':False,'mode':'headless Godot4.7.1; RTX4080/i7-13700KF; elapsed is process wall time only','started_at_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'before':snapshot('source_before')}
start=time.perf_counter()
proc=subprocess.run(argv,cwd=ROOT,env=env,capture_output=True)
receipt['elapsed_seconds']=round(time.perf_counter()-start,3)
(out/'runner.stdout.log').write_bytes(proc.stdout)
(out/'runner.stderr.log').write_bytes(proc.stderr)
receipt['actual_exit']=proc.returncode
receipt['matches_expected_exit']=proc.returncode==cfg.expected_exit
receipt['after']=snapshot('source_after')
receipt['source_unchanged']=receipt['before']==receipt['after']
raw='\n'.join(p.read_text(encoding='utf-8-sig',errors='replace') for p in [log,Path(str(log)+'.stderr')] if p.exists())
receipt['diagnostic_headers']=[x for x in raw.splitlines() if re.search(r'WARNING:|ERROR:|SCRIPT ERROR:|Parse Error|leaked|resources still in use',x,re.I)]
receipt['summary_lines']=[x for x in raw.splitlines() if re.search(r'WORLD TIME|TEST:|RESULT:|MATRIX:|checks=|FIRST EXTERIOR CELL:',x)]
receipt['artifacts']={str(p.relative_to(out)):sha(p.read_bytes()) for p in out.iterdir() if p.is_file()}
(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps({k:receipt[k] for k in ['case','actual_exit','expected_exit','elapsed_seconds','source_unchanged','diagnostic_headers','summary_lines']},indent=2),flush=True)
