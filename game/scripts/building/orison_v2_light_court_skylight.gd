extends RefCounted
## Source-fitted native curb, tee frame and six thick panes.
static func mount(root: Node3D) -> void:
    var model: Node3D=preload("res://assets/props/light_court_skylight.glb").instantiate()
    model.name="LightCourtSkylight"
    root.add_child(model)
    for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
        var key:=str(draw.mesh.surface_get_material(0).resource_name)
        if key=="glass":draw.material_override=root.architectural_materials.material_for("Glazing","core")
        else:draw.material_override=MatLib.get_mat(key)
        draw.create_trimesh_collision()
