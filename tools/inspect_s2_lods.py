import bpy, glob, os

root=os.environ['S2_LOD_DIR']
for filepath in sorted(glob.glob(os.path.join(root,'*.glb'))):
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    try:
        bpy.ops.import_scene.gltf(filepath=filepath)
        vertices=sum(len(o.data.vertices) for o in bpy.context.scene.objects if o.type=='MESH')
        triangles=sum(len(o.data.polygons) for o in bpy.context.scene.objects if o.type=='MESH')
        print('[LOD CHECK] %s vertices=%d triangles=%d OK' % (os.path.basename(filepath),vertices,triangles))
    except Exception as error:
        print('[LOD CHECK] %s FAIL %s' % (os.path.basename(filepath),error))
