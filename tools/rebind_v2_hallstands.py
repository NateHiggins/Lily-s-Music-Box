#!/usr/bin/env python3
"""Strict provenance-only refresh for the two reviewed upper B hallstand relocations and explicit room functions.
Older unrelated fixture drift remains visible. Does not confer new acceptance.
"""
import argparse,copy,hashlib,json,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
LAYOUT="game/data/orison_v2_blockout.json"
IDS=("5B_hallstand","6B_hallstand")
def digest(data):return hashlib.sha256(data.replace(b"\r\n",b"\n")).hexdigest()
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument("--base",required=True);p.add_argument("--out",type=Path,required=True);p.add_argument("--apply",action="store_true");p.add_argument("--previous-layout",type=Path);a=p.parse_args()
 base=subprocess.check_output(["git","rev-parse",a.base],cwd=ROOT,text=True).strip()
 old_bytes=subprocess.check_output(["git","show",base+":"+LAYOUT],cwd=ROOT);new_bytes=(ROOT/LAYOUT).read_bytes()
 old=json.loads(old_bytes);new=json.loads(new_bytes);expected=copy.deepcopy(old)
 for identity in IDS:
  rows=[r for r in expected["anchors"] if r["id"]==identity];assert len(rows)==1
  assert rows[0]["position"]==[-6.72,0,1.85];rows[0]["position"]=[-6.72,0,2.65]
 layout_hashes={digest(old_bytes)}
 poses_only=copy.deepcopy(expected)
 previous_program=copy.deepcopy(expected)
 for row in previous_program["spaces"]:
  if row["id"] in ["F05_A_VESTIBULE","F05_B_VESTIBULE","F05_C_VESTIBULE","F06_A_VESTIBULE","F06_B_VESTIBULE","F06_C_VESTIBULE"]:row["purpose"]=row["purpose"].split(":")[0]+": private arrival, privacy and domestic room distribution; coat storage"
  elif row["id"]=="F05_C_BED1":row["purpose"]="Iris Bell: principal sleep and clothing storage"
  elif row["id"]=="F06_C_STUDIO":row["purpose"]="Mae Kessler: antique appraisal, records and clothing storage"
 if a.previous_layout:
  previous_bytes=a.previous_layout.read_bytes();assert json.loads(previous_bytes) in [poses_only,previous_program],"Previous layout must match one of the two exact reviewed predecessors";layout_hashes.add(digest(previous_bytes))
 program_edits={}
 for row in expected["spaces"]:
  if row["id"] in ["F05_A_VESTIBULE","F05_B_VESTIBULE","F05_C_VESTIBULE","F06_A_VESTIBULE","F06_B_VESTIBULE","F06_C_VESTIBULE"]:purpose=row["purpose"].split(":")[0]+": private arrival, privacy and domestic room distribution; coat hanging and shallow shelf"
  elif row["id"] in ["F05_A_BED","F05_B_ALCOVE","F06_A_BED","F06_B_ALCOVE"]:purpose=row["purpose"].replace("sleep and clothing","sleep and enclosed clothing storage")
  elif row["id"]=="F05_C_BED1":purpose="Iris Bell: principal sleep and clothing storage"
  elif row["id"]=="F06_C_STUDIO":purpose="Mae Kessler: antique appraisal, records and clothing storage"
  else:continue
  program_edits[row["id"]]={"from":row["purpose"],"to":purpose};row["purpose"]=purpose
 assert new==expected,"Only two anchor positions and twelve declared purpose clarifications may change"
 assets={}
 for path in ["game/assets/props/domestic_objects.glb","art/blender/domestic_objects.blend"]:
  before=subprocess.check_output(["git","show",base+":"+path],cwd=ROOT);after=(ROOT/path).read_bytes()
  assert before==after,("Native local geometry changed",path);assets[path]=hashlib.sha256(after).hexdigest()
 docs={};raw={}
 for directory in ["art/blender","game/tests/fixtures","game/data/orison_v2","art/data/orison_v2"]:
  for file in (ROOT/directory).glob("*.json"):
   value=json.loads(file.read_text(encoding="utf-8"))
   if isinstance(value,dict) and isinstance(value.get("source_bindings"),dict):
    path=file.relative_to(ROOT).as_posix();docs[path]=value;raw[path]=file.read_bytes()
 serialized={};active=set();updates=[];pending=[];stale=[]
 def resolve(path):
  if path in serialized:return serialized[path]
  assert path not in active,("Cyclic bindings",path);active.add(path)
  data=docs[path];changed=[]
  for literal,expected_hash in list(data["source_bindings"].items()):
   relative=literal.replace("\\","/");replacement=None;allowed=set()
   if relative==LAYOUT:replacement=digest(new_bytes);allowed.update(layout_hashes)
   elif relative in docs:
    replacement=digest(resolve(relative))
    if replacement!=digest(raw[relative]):allowed.add(digest(raw[relative]))
    else:replacement=None
   if replacement is None or expected_hash==replacement:continue
   if expected_hash not in allowed:
    stale.append({"fixture":path,"binding":literal,"reason":"Older/unrelated binding left unchanged"});continue
   data["source_bindings"][literal]=replacement;changed.append(literal)
  output=(json.dumps(data,indent=2)+"\n").encode() if changed else raw[path]
  if changed:
   original=json.loads(raw[path]);assert {k:v for k,v in original.items() if k!="source_bindings"}=={k:v for k,v in data.items() if k!="source_bindings"}
   pending.append((ROOT/path,output));updates.append({"path":path,"before_sha256":digest(raw[path]),"after_sha256":digest(output),"bindings_only":changed})
  serialized[path]=output;active.remove(path);return output
 for path in docs:resolve(path)
 if a.apply:
  for file,data in pending:file.write_bytes(data)
 result={"evidence_class":"INERT","base":base,"applied":a.apply,"source_diff":{"anchors":list(IDS),"from":[-6.72,0,1.85],"to":[-6.72,0,2.65],"purpose_clarifications":program_edits,"all_other_layout_values_identical":True},"native_assets_unchanged":assets,"updates":updates,"older_unrelated_drift":stale,"scope":"Rebind only current-base provenance after a typed two-anchor comparison. Existing local meshes, material recipes and texture coordinates remain byte-identical. Relocated installation acceptance requires new Blender fit review and composed-world walking/capture; old visual frames are not renewed by this tool."}
 a.out.parent.mkdir(parents=True,exist_ok=True);a.out.write_text(json.dumps(result,indent=2)+"\n",encoding="utf-8",newline="\n")
 print(json.dumps({"updated":len(updates),"older_unrelated":len(stale),"applied":a.apply}))
if __name__=="__main__":main()
