from pathlib import Path
import subprocess,hashlib,json
ROOT=Path('C:/ov/v2merge24')
OUT=Path(__file__).parent
def git(*args,input=None):
    return subprocess.run(['git',*args],cwd=ROOT,input=input,capture_output=True,check=True).stdout
rows=git('status','--porcelain=v1','-z','--untracked-files=no').split(b'\0')
paths=[r[3:].decode('utf8') for r in rows if r[:2]==b' M' and r.endswith(b'.import')]
raw=git('cat-file','--batch',input=''.join('HEAD:'+p+'\n' for p in paths).encode())
at=0;restore=[];preserve=[]
for path in paths:
    end=raw.index(b'\n',at);header=raw[at:end].split();size=int(header[-1]);at=end+1
    original=raw[at:at+size];at+=size+1
    current=(ROOT/path).read_bytes()
    if original.replace(b'\r\n',b'\n')==current.replace(b'\r\n',b'\n'):
        restore.append({'path':path,'working_sha256':hashlib.sha256(current).hexdigest(),'head_sha256':hashlib.sha256(original).hexdigest()})
    else:preserve.append(path)
if restore:
    git('restore','--worktree','--pathspec-from-file=-','--pathspec-file-nul',input=b'\0'.join(r['path'].encode() for r in restore)+b'\0')
(OUT/'import_eol_restore.json').write_text(json.dumps({'restored':restore,'semantic_changes_preserved':preserve},indent=2)+'\n',encoding='utf-8',newline='\n')
print('Restored',len(restore),'LF-identical sidecars; preserved',len(preserve),'semantic sidecars')
