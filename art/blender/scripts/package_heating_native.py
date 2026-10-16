"""Save an inspected native assembly at its final path with portable image links."""
import argparse
from array import array
import hashlib
import json
from pathlib import Path
import sys
import bpy

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--source',type=Path,required=True)
parser.add_argument('--inspection',type=Path,required=True)
parser.add_argument('--destination',type=Path,required=True)
parser.add_argument('--report',type=Path,required=True)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
inspection=json.loads(args.inspection.read_text())
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
if inspection['failures'] or sha(args.source)!=inspection['blend_sha256']:
    raise ValueError('Native source has no matching successful inspection')
bpy.ops.wm.open_mainfile(filepath=str(args.source.resolve()))

def geometry_digest():
    digest=hashlib.sha256()
    def values(collection,name,kind,width=1):
        data=array(kind,[0])*(len(collection)*width)
        collection.foreach_get(name,data);digest.update(data.tobytes())
    for obj in sorted((o for o in bpy.context.scene.objects if o.type=='MESH'),key=lambda o:o.name):
        digest.update((obj.name+'\0'+str(obj.get('level',''))+'\0').encode())
        digest.update(array('f',[v for row in obj.matrix_world for v in row]).tobytes())
        mesh=obj.data
        values(mesh.vertices,'co','f',3);values(mesh.loops,'vertex_index','i')
        values(mesh.polygons,'loop_start','i');values(mesh.polygons,'loop_total','i')
        values(mesh.polygons,'use_smooth','b');values(mesh.polygons,'material_index','i')
        for layer in mesh.uv_layers:
            digest.update((layer.name+'\0').encode());values(layer.data,'uv','f',2)
    return digest.hexdigest()

before=geometry_digest()
used={m for obj in bpy.context.scene.objects if obj.type=='MESH' for m in obj.data.materials if m}
images={node.image for mat in used if mat.use_nodes for node in mat.node_tree.nodes if node.type=='TEX_IMAGE' and node.image}
image_hashes={image.name:sha(Path(bpy.path.abspath(image.filepath))) for image in images}
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(args.destination.resolve()),relative_remap=True)
bpy.ops.file.make_paths_relative();bpy.ops.wm.save_mainfile()
bpy.ops.wm.open_mainfile(filepath=str(args.destination.resolve()))
after=geometry_digest()
if before!=after:raise ValueError('Packaging changed geometry, UVs, smoothing or placement')
resolved=[]
for name,digest in image_hashes.items():
    image=bpy.data.images[name];path=Path(bpy.path.abspath(image.filepath))
    if not image.filepath.startswith('//') or sha(path)!=digest:
        raise ValueError('Packaged material path is not portable: '+name)
    resolved.append({'image':name,'relative_path':image.filepath,'sha256':digest})
report={'evidence_class':'INERT','scope':'Native packaging only; exact semantic mesh comparison and image-link rebasing, not new runtime acceptance.',
        'source_sha256':sha(args.source),'native_sha256':sha(args.destination),
        'geometry_sha256_before':before,'geometry_sha256_after':after,'images':resolved,'failures':[]}
args.report.parent.mkdir(parents=True,exist_ok=True);args.report.write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({'geometry_unchanged':True,'portable_images':len(resolved)}))
