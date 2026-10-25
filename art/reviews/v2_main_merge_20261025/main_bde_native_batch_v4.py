from pathlib import Path
import json,runpy,traceback,time,sys,hashlib
import bpy
root=Path("C:/ov/v2merge24")
out=Path("C:/ov/reports/v2integration24/main_bde_native_v4")
out.mkdir(exist_ok=True)
plan=json.loads(Path("C:/ov/reports/v2integration24/main_bde_native_order_v4.json").read_text())
sys.path.insert(0,str(root/"art/blender/scripts"))
sys.argv=["blender","--"]
records=[]
for name in plan["order"]:
    source=root/f"art/blender/scripts/build_{name}.py"
    start=time.monotonic()
    print("RENEW START",name,flush=True)
    record={"family":name,"builder_sha256":hashlib.sha256(source.read_bytes().replace(b"\r\n",b"\n")).hexdigest()}
    try:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        runpy.run_path(str(source),run_name="__main__")
        record["completed"]=True
    except BaseException:
        record["completed"]=False
        record["failure"]=traceback.format_exc()
        print(record["failure"],flush=True)
    record["elapsed_s"]=round(time.monotonic()-start,3)
    records.append(record)
    (out/"renewal.json").write_text(json.dumps({"evidence_class":"INERT","scope":"Authoring-builder renewals only; not rendering, import or runtime qualification","plan":plan,"stages":records},indent=2)+"\n")
    print("RENEW END",name,record["completed"],record["elapsed_s"],flush=True)
if any(not record["completed"] for record in records):
    raise RuntimeError("One or more native renewals failed; original failures retained")
