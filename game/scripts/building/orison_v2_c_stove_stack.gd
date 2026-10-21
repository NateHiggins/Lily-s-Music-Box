extends RefCounted
## Architecture/prop placement only. Existing propagation owner retains its lease.
const DATA="res://data/orison_v2/acoustic_flue.json"
var errors: Array[String]=[]
func _reject(message: String) -> bool:
	errors.append(message);return false

func mount(adapter: OrisonV2AnchorAdapter,layout: Dictionary) -> bool:
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DATA))
	var spec: Dictionary=data.stock;var shaft: Dictionary={}
	for row: Dictionary in layout.risers:
		if row.id==spec.riser:shaft=row
	if shaft.is_empty() or shaft.rect!=spec.rect or shaft.from_y!=spec.from_y or shaft.to_y!=spec.to_y:return _reject("Stove shaft differs from compiled stock")
	if FileAccess.get_sha256("res://assets/props/c_stove_stack.glb")!=spec.asset_sha256:return _reject("Stove fabrication differs from compiled asset")
	var proxy:=adapter.root.get_node_or_null(str(spec.riser)) as Node3D
	if proxy==null:return _reject("Missing stove reservation owner")
	# Preserve the reservation identity, but native masonry owns every visible
	# face and actual round contact. Generic rectangular proxy holes must retire.
	proxy.hide()
	for body: CollisionObject3D in proxy.find_children("*","CollisionObject3D",true,false):body.collision_layer=0;body.collision_mask=0
	var stock: Node3D=preload("res://scripts/building/c_stove_stack_stock.gd").build()
	stock.name="CStoveStack";adapter.root.add_child(stock)
	var mounted:=0
	for row: Dictionary in data.nodes:
		if row.physical_role!="thimble":continue
		var prop:=FlueBreastProp.new();prop.prop_type="flue_breast";prop.unit=str(row.unit);prop.graph_node_id=str(row.id)
		if not adapter.mount_consumer(str(row.id),prop):prop.free();return _reject("Unable to mount stove closure: "+str(row.id))
		if prop.resonance_origin().distance_to(AcousticGraphData.node_pos(str(row.id)))>.001:return _reject("Closure differs from compiled acoustic carrier")
		mounted+=1
	return mounted==5 or _reject("Five stove closures required")
