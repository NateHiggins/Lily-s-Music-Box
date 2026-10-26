"""Require portable source settings for the meshes bound by physical receipts.

Retention only: does not qualify geometry, textures or runtime behavior. A
derived, ignored .import cannot supply a reproducible physical fingerprint.
"""
from pathlib import Path
import argparse,json,re,subprocess

ROOT=Path(__file__).resolve().parents[1]
IMPORTED_MODELS={'.glb','.gltf','.obj'}

def evaluate(root=ROOT):
    root=Path(root)
    def names(*args):
        return set(subprocess.check_output(['git','ls-files','-z',*args],cwd=root).decode().split('\0'))-{''}
    tracked=names('--cached')
    sources=sorted(p for p in names('--cached','--others','--exclude-standard','--','game/assets') if Path(p).suffix in IMPORTED_MODELS)
    missing=[];wrong=[];imports=[]
    for source in sources:
        relative=source+'.import';path=root/relative
        if source not in tracked:wrong.append(source+': model is untracked')
        if not path.is_file():missing.append(relative);continue
        if relative not in tracked:wrong.append(relative+': settings are untracked')
        text=path.read_text(encoding='utf8')
        if not all(section in text for section in ['[remap]','[deps]','[params]']):wrong.append(relative+': incomplete import source')
        match=re.search(r'^source_file="([^"]+)"',text,re.M)
        expected='res://'+source.removeprefix('game/')
        if not match or match[1]!=expected:wrong.append(relative+': source binding differs')
        imports.append(relative)
    if imports or sources:
        # The full physical inventory exceeds Windows' command-line limit.
        # NUL-delimited stdin also preserves paths containing whitespace.
        fields=subprocess.check_output(['git','check-attr','-z','--stdin','text'],
            input=('\0'.join(imports+sources)+'\0').encode(),cwd=root).decode().split('\0')
        for path,_,value in zip(fields[0::3],fields[1::3],fields[2::3]):
            if value!='unset':wrong.append(path+': hash-bound physical source requires -text')
    return {'scope':'physical_import_source_retention','referenced':len(sources),'missing':missing,'wrong':wrong}

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--root',type=Path,default=ROOT)
    result=evaluate(parser.parse_args().root);print(json.dumps(result))
    return int(bool(result['missing'] or result['wrong']))

if __name__=='__main__':raise SystemExit(main())
