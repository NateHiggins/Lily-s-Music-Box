extends "res://tests/v2_nook_world_profile.gd"
## INERT strengthened external candidate: not installed, compiled or run.
## Same nearby route and actual Space/primary ownership as the original candidate.
var optics: Array[Dictionary]=[]
var lamp_controls: Array[Dictionary]=[]
var hand_observations: Array[Dictionary]=[]
var comparison_poses: Dictionary={}
const NATIVE_PIXELS := Vector2i(3440,1440)
const OWNER_SOURCES: Array[String]=[
	"res://scripts/props/v2_readable_book.gd",
	"res://scripts/props/v2_library_movable.gd",
	"res://scripts/building/v2_loose_library.gd",
	"res://scripts/building/v2_readable_bookshelf.gd",
	"res://scripts/device/companion_world_carrier.gd",
	"res://scripts/device/service_set_carrier.gd",
	"res://scripts/player/player_controller.gd",
	"res://scripts/player/constrained_grab.gd",
	"res://scripts/lamp/carried_lamp_optical_driver.gd",
	"res://scripts/lamp/lamp_optical_state.gd",
	"res://scripts/props/book_print_preparation.gd",
	"res://scripts/props/book_print_mesh.gd",
	"res://scripts/device/companion_motion.gd"]

func _inspect_stock_review(book: Node3D) -> void:
	profile_active=false # Readback, hashing and queries are not frame-budget proof.
	var sources_before: Dictionary=_optics_sources()
	var original_power: bool=player.lamp_is_enabled()
	await _observe_book("inspection",book)
	for pressed: bool in [true,false]:
		var key:=InputEventKey.new()
		key.keycode=KEY_SPACE;key.physical_keycode=KEY_SPACE;key.pressed=pressed
		player._unhandled_input(key)
	if not _require(not player.inspecting() and player._grab.holding_pickup() and player._grab.target.part==book,"optical comparison returns the same book through actual Space"):return
	for frame in 110:await get_tree().process_frame
	for treatment: Array in [["returned_hand",true],["lamp_off",false],["lamp_restored",true]]:
		if not await _optics_lamp_power(bool(treatment[1]),str(treatment[0])):break
		await _optics_hand(book,str(treatment[0]))
		await _observe_book(str(treatment[0]),book)
	var restored: bool=await _optics_lamp_power(original_power,"restore_original_switch")
	_require(restored and player.lamp_is_enabled()==original_power,"normal lamp input restores original logical power")
	_require(optics.size()==4 and _optics_same_subjects(),"all four optical phases retain the same book/camera/lamp/carrier/device/aperture identities")
	_click_library()
	var released: bool=_require(not player._grab.active() and not book._held,"optical diagnostic releases the same book through actual primary")
	var output: String=OS.get_environment("SHOT_DIR")
	var sources: Dictionary=_optics_sources()
	_require(sources==sources_before,"named optical observer/owner sources unchanged through controls")
	var report: Dictionary={"evidence_class":"INERT","kind":"book_lamp_geometry_diagnostic","frames":optics,"source_files_sha256":sources,"source_files_before_sha256":sources_before,"released_same_book":released,"lamp_controls":lamp_controls,"hand_observations":hand_observations,"original_lamp_power":original_power,"original_lamp_restored":restored,
		"independent_opaque_control":{"executed":false,"reason":"No independently operable opaque blocker is proven reachable by this preserved parent route. Existing first hits are observations, not an invented clear/blocked/restored control."},
		"scope":"Same installed book/native lamp, inspection and actual FPS hand; real polled on/off/restored power. Geometry/image-region observations only; no independent opaque control, readability acceptance, performance, save or artistic acceptance.","failures":failures}
	var file:=FileAccess.open(output.path_join("book_lamp_geometry.json"),FileAccess.WRITE)
	if not _require(file!=null,"book lamp diagnostic report opens"):return
	file.store_string(JSON.stringify(report,"\t"));file.close()

func _observe_book(phase: String,book: Node3D) -> void:
	await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	var light: SpotLight3D=player.flashlight
	var title: Label3D
	for label: Label3D in book.printed_labels:
		if label.name=="CoverTitle":title=label;break
	if not _require(title!=null and light!=null,"actual cover title anchor and lamp exist for diagnostic"):return
	var carrier: Node3D=player.carried_device
	var device: Node=carrier.get("device") as Node if carrier!=null else null
	var motion: Variant=carrier.get("motion") if carrier!=null else null
	var target: Variant=motion.light_target if motion!=null else null
	var lens: MeshInstance3D
	if device!=null and device.get("teletype")!=null:lens=device.teletype.torch_lens
	if not _require(carrier!=null and bool(carrier.get("world_ready")) and device!=null and motion!=null and lens!=null,"actual V2 world carrier/device/motion/native aperture hierarchy exists"):return
	var origin: Vector3=light.global_position
	var forward: Vector3=-light.global_basis.orthonormalized().z
	# CoverTitle is authored in OpeningGathering at z=thickness/2+60um.
	# Its local +Z is the printed front; inspect dot signs without assuming litness.
	var width: float=book.construction.width
	var height: float=book.construction.height
	var z: float=float(book.construction.thickness)*.5+.00006
	var samples: Array[Dictionary]=[]
	samples.append(_sample("title_anchor",title.global_position,title.global_basis.orthonormalized().z,origin,forward,light,book))
	for spec: Array in [["lower_left",.1,.1],["lower_right",.9,.1],["centre",.5,.5],["upper_left",.1,.9],["upper_right",.9,.9]]:
		var at: Vector3=book.left.to_global(Vector3(width*float(spec[1]),height*float(spec[2]),z))
		samples.append(_sample(str(spec[0]),at,book.left.global_basis.orthonormalized().z,origin,forward,light,book))
	var geometry: Dictionary=_optics_geometry(book,title)
	var draws: Array[Dictionary]=[]
	for draw: MeshInstance3D in book.find_children("*","MeshInstance3D",true,false):
		draws.append({"path":str(draw.get_path()),"layers":draw.layers,"visible":draw.is_visible_in_tree(),"lamp_layer_overlap":(draw.layers&light.light_cull_mask)!=0,"cast_shadow":draw.cast_shadow})
	var image: Image=get_viewport().get_texture().get_image()
	_require(image.get_size()==NATIVE_PIXELS and get_viewport().get_visible_rect().size==Vector2(NATIVE_PIXELS),"optical image and viewport are actual native3440x1440")
	var filename: String=phase+"_book_lamp.png"
	var output: String=OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(output)
	var png_path: String=output.path_join(filename)
	_require(image.save_png(png_path)==OK,"optical comparison frame saved: "+phase)
	var png_pixels: Vector2i=_optics_png_size(FileAccess.get_file_as_bytes(png_path))
	_require(png_pixels==NATIVE_PIXELS,"saved optical PNG has actual native IHDR dimensions: "+phase)
	var regions: Dictionary={}
	for key: String in geometry:regions[key]=_optics_region(image,geometry[key].get("roi",[]))
	var holding: bool=player._grab.holding_pickup() and player._grab.target.get("part")==book
	optics.append({"phase":phase,"file":filename,"stock_id":book.stock_id,"book_identity":_identity(book),"shelf_identity":_identity(book.shelf),
		"camera_identity":_identity(player.camera),"expected_title":str(book.entry.title),"expected_author":str(book.entry.author),"title_id":book.title_id,"matches_retained_dark_copy":book.stock_id=="nook_books__Volume0","opening":book.opening,
		"png_sha256":FileAccess.get_sha256(png_path),"actual_png_pixels":[png_pixels.x,png_pixels.y],"projected_final_geometry":geometry,"capture_region_observations":regions,"optical_power_state":_optics_lamp_snapshot(),"pose_deltas_to_returned_hand":_optics_pose_deltas(phase,book,light,lens),
		"viewport":var_to_str(get_viewport().get_visible_rect().size),"camera":var_to_str(player.camera.global_transform),"book":var_to_str(book.global_transform),
		"cover_title":{"identity":_identity(title),"layers":title.layers,"lamp_layer_overlap":(title.layers&light.light_cull_mask)!=0,"visible":title.is_visible_in_tree(),"shaded":title.shaded,"double_sided":title.double_sided,"no_depth_test":title.no_depth_test},
		"lamp":{"identity":_identity(light),"transform":var_to_str(light.global_transform),"visible":light.is_visible_in_tree(),"logical_player_enabled":player.lamp_is_enabled(),"logical_device_enabled":device.get("lamp_enabled") if device!=null else null,"energy":light.light_energy,"range":light.spot_range,"half_angle_deg":light.spot_angle,"light_cull_mask":light.light_cull_mask,"shadow_enabled":light.shadow_enabled},
		"carrier":{"identity":_identity(carrier),"device_identity":_identity(device),"beam_valid":carrier.get("beam_valid") if carrier!=null else null,"native_lens_identity":_identity(lens),"native_lens_transform":var_to_str(lens.global_transform) if lens!=null else "","native_aperture":var_to_str(lens.to_global(lens.mesh.get_aabb().get_center())) if lens!=null and lens.mesh!=null else "","reticle_target":var_to_str(target),"target_valid":motion.light_target_valid if motion!=null else null},
		"samples":samples,"book_draws":draws,"inspecting":player.inspecting(),"holding_same_book":holding,"current_hand_centre_error_m":(book.global_transform*book.pickup_centre()).distance_to(player.camera.global_transform*Vector3(.17,-.16,-.48)) if holding else null})

func _sample(label: String,at: Vector3,normal: Vector3,origin: Vector3,forward: Vector3,light: SpotLight3D,book: Node3D) -> Dictionary:
	var direction: Vector3=(at-origin).normalized()
	# Match the production body-only optical mask; record both raw and carrier-
	# excluded hits. Neither removes real opaque world stock or book collision.
	var query:=PhysicsRayQueryParameters3D.create(origin,at,1)
	var raw: Dictionary=player.get_world_3d().direct_space_state.intersect_ray(query)
	query.exclude=[player.get_rid()]
	var hit: Dictionary=player.get_world_3d().direct_space_state.intersect_ray(query)
	var angle: float=rad_to_deg(acos(clampf(forward.dot(direction),-1.,1.)))
	return {"sample":label,"position":var_to_str(at),"pixel":var_to_str(player.camera.unproject_position(at)),"behind_camera":player.camera.is_position_behind(at),"normal":var_to_str(normal),"normal_dot_toward_lamp":normal.dot(-direction),"angle_deg":angle,"inside_nominal_cone":angle<=light.spot_angle,"distance_m":origin.distance_to(at),"inside_range":origin.distance_to(at)<=light.spot_range,"unfiltered_hit":_hit_record(raw,book,at),"player_excluded_hit":_hit_record(hit,book,at)}

func _hit_record(hit: Dictionary,book: Node3D,sample_at: Vector3) -> Dictionary:
	var collider: Node=hit.get("collider") as Node
	return {"collider":_identity(collider),"position":var_to_str(hit.get("position")),"normal":var_to_str(hit.get("normal")),"shape":hit.get("shape"),"hit_to_sample_distance_m":sample_at.distance_to(hit.position) if not hit.is_empty() else null,"is_same_book":collider==book or (collider!=null and book.is_ancestor_of(collider))}

func _identity(node: Node) -> Dictionary:
	if node==null:return {}
	return {"path":str(node.get_path()),"instance_id":node.get_instance_id(),"script":node.get_script().resource_path if node.get_script()!=null else ""}

func _optics_lamp_snapshot() -> Dictionary:
	var light: SpotLight3D=player.flashlight
	var carrier: Node3D=player.carried_device
	var device: Node=carrier.get("device") as Node if carrier!=null else null
	var result: Dictionary={"ticks_usec":Time.get_ticks_usec(),"logical_player":player.lamp_is_enabled(),"logical_device":device.get("lamp_enabled") if device!=null else null,"energy":light.light_energy,"visible":light.is_visible_in_tree(),"legacy_phase":player._lamp_phase}
	var driver: Node=player.lamp_presentation
	if is_instance_valid(driver):
		result.presentation_owner=_identity(driver)
		result.output=driver.output.duplicate(true)
		result.filament_emission=float(driver.output.filament_emission)
		result.filament_temperature_k=float(driver.state.filament_temperature_k)
		result.intensity_rate=float(driver.state.intensity_rate)
	return result

func _optics_lamp_power(on: bool,phase: String) -> bool:
	var record: Dictionary={"phase":phase,"requested_on":on,"before":_optics_lamp_snapshot(),"action_delivered":false,"samples":[]}
	if player.lamp_is_enabled()!=on:
		if not _require(not is_instance_valid(player.text_input_owner) and not Input.is_action_pressed("lamp_toggle"),"lamp input is available without taking over another input owner: "+phase):return false
		Input.action_press("lamp_toggle")
		for frame in 2:await get_tree().process_frame
		Input.action_release("lamp_toggle")
		await get_tree().process_frame
		record.action_delivered=true
	var deadline: int=Time.get_ticks_msec()+8000
	var previous: Dictionary={}
	var steady: int=0
	while Time.get_ticks_msec()<deadline:
		await get_tree().create_timer(.1).timeout
		var sample: Dictionary=_optics_lamp_snapshot()
		record.samples.append(sample)
		var logical: bool=sample.logical_player==on and sample.logical_device is bool and bool(sample.logical_device)==on
		# Numerical convergence only, not a readability/contrast threshold.
		# The .001 dark boundary is the production presentation visibility floor.
		var dark: bool=not on and not sample.visible and float(sample.energy)<=.001
		var powered: bool=on and sample.visible and float(sample.energy)>0.
		var converged: bool=not previous.is_empty() and absf(float(sample.energy)-float(previous.energy))<=.001
		if sample.has("filament_emission") and previous.has("filament_emission"):
			converged=converged and absf(float(sample.filament_emission)-float(previous.filament_emission))<=.001
		else:converged=converged and float(sample.legacy_phase)<=0.
		steady=steady+1 if logical and (dark or powered) and converged else 0
		previous=sample
		if steady>=4:break
	var accepted: bool=steady>=4
	record.settled=accepted;record.after=previous
	lamp_controls.append(record)
	print("BOOK LAMP INPUT: ",JSON.stringify(record))
	return _require(accepted,"actual polled lamp input reaches matching logical/device and settled filament output: "+phase)

func _optics_hand(book: Node3D,phase: String) -> void:
	var samples: Array[Dictionary]=[]
	var previous: Transform3D=book.global_transform
	var same: bool=true
	for frame in 12:
		await get_tree().physics_frame
		var pose: Transform3D=book.global_transform
		var holding: bool=player._grab.holding_pickup() and player._grab.target.get("part")==book
		same=same and holding and book._held and book.freeze
		var collider: Variant=book._last_motion.get("collider")
		samples.append({"physics_frame":Engine.get_physics_frames(),"same_book_in_hand":holding,"held":book._held,"frozen":book.freeze,"centre_error_m":(pose*book.pickup_centre()).distance_to(player.camera.global_transform*Vector3(.17,-.16,-.48)),"successive_origin_drift_m":pose.origin.distance_to(previous.origin),"successive_basis_drift_rad":pose.basis.orthonormalized().get_rotation_quaternion().angle_to(previous.basis.orthonormalized().get_rotation_quaternion()),"successive_transform_approx_equal":pose.is_equal_approx(previous),"book_pose":var_to_str(pose),"camera_pose":var_to_str(player.camera.global_transform),"last_contact":var_to_str(book._last_motion),"contact_identity":_identity(collider) if collider is Node else {},"hold_blocked":book._hold_blocked})
		previous=pose
	var result: Dictionary={"phase":phase,"samples":samples,"same_hand_throughout":same,"final_centre_error_m":samples[-1].centre_error_m,"drift_is_observed_not_forced":true}
	hand_observations.append(result)
	print("BOOK HAND SETTLE OBSERVATION: ",JSON.stringify(result))
	# Keep the existing installed return route's .01m swept-hand bound.
	_require(same and float(result.final_centre_error_m)<.01,"same frozen/held book reaches existing installed FPS-hand error bound: "+phase)

func _optics_geometry(book: Node3D,title: Label3D) -> Dictionary:
	var cover_points:=PackedVector3Array()
	var cover_parts: Array[String]=[]
	for draw: MeshInstance3D in book._native_draws:
		if str(draw.get_meta("readable_library_part",""))!=str(book.stock_id)+"__left_board" or not draw.is_visible_in_tree():continue
		var mesh: Mesh=draw.mesh
		if draw.get_blend_shape_count()>0:
			# New temporary mesh only: never assign it to the production instance.
			mesh=draw.bake_mesh_from_current_blend_shape_mix()
		if mesh==null:continue
		cover_parts.append(str(draw.get_path()))
		cover_points.append_array(_optics_vertices(mesh.get_rid(),draw.global_transform))
	var result: Dictionary={"cover":_optics_project(cover_points)}
	result.cover.drawn_parts=cover_parts
	result.cover.geometry_source="actual loaded left-board mesh and current blend-shape mix; bounds, not occlusion/silhouette proof"
	for label: Label3D in book.printed_labels:
		if label!=title and label.name!="CoverAuthor":continue
		var mesh_rid: RID=label.get_base()
		var source: String="loaded Label3D glyph mesh"
		for printed: Dictionary in book._print_surfaces:
			if printed.node==label:
				mesh_rid=printed.mesh;source="current warped print instance mesh";break
		var bounds: Dictionary=_optics_project(_optics_vertices(mesh_rid,label.global_transform))
		bounds.geometry_source=source;bounds.mesh_rid=mesh_rid.get_id();bounds.label=_identity(label)
		bounds.expected_text=str(book.entry.title) if label==title else str(book.entry.author)
		bounds.authored_text=label.text;bounds.label_visible=label.is_visible_in_tree()
		bounds.em_m=label.font_size*label.pixel_size
		result["title" if label==title else "author"]=bounds
	_require(not cover_points.is_empty() and result.has("title") and int(result.title.vertices)>0,"loaded final cover and glyph geometry available")
	return result

func _optics_vertices(mesh_rid: RID,pose: Transform3D) -> PackedVector3Array:
	var points:=PackedVector3Array()
	if not mesh_rid.is_valid():return points
	for surface in RenderingServer.mesh_get_surface_count(mesh_rid):
		var arrays: Array=RenderingServer.mesh_surface_get_arrays(mesh_rid,surface)
		if arrays.is_empty() or arrays[Mesh.ARRAY_VERTEX]==null:continue
		for point: Vector3 in arrays[Mesh.ARRAY_VERTEX]:points.append(pose*point)
	return points

func _optics_project(points: PackedVector3Array) -> Dictionary:
	var low:=Vector2(INF,INF);var high:=Vector2(-INF,-INF);var behind: int=0
	for point: Vector3 in points:
		if player.camera.is_position_behind(point):behind+=1;continue
		var pixel: Vector2=player.camera.unproject_position(point)
		low=low.min(pixel);high=high.max(pixel)
	var result: Dictionary={"vertices":points.size(),"behind_vertices":behind,"all_behind":behind==points.size(),"roi":[],"bounds_are_not_visible_ink_mask":true}
	if behind==points.size():return result
	var size: Vector2i=get_viewport().get_visible_rect().size
	var x0: int=clampi(floori(low.x),0,size.x);var y0: int=clampi(floori(low.y),0,size.y)
	var x1: int=clampi(ceili(high.x),0,size.x);var y1: int=clampi(ceili(high.y),0,size.y)
	result.projected_bounds_px=[low.x,low.y,high.x,high.y]
	result.projected_width_px=high.x-low.x;result.projected_height_px=high.y-low.y
	result.frame_clipped=low.x<0. or low.y<0. or high.x>size.x or high.y>size.y or behind>0
	result.roi=[x0,y0,maxi(0,x1-x0),maxi(0,y1-y0)]
	return result

func _optics_region(image: Image,roi: Array) -> Dictionary:
	if roi.size()!=4 or int(roi[2])<=0 or int(roi[3])<=0:return {"sample_count":0,"valid_region":false}
	var stride: int=maxi(1,ceili(sqrt(float(int(roi[2])*int(roi[3]))/65536.)))
	var count: int=0;var black: int=0;var saturated: int=0
	var total: float=0.;var low: float=INF;var high: float=-INF
	for y in range(int(roi[1]),int(roi[1])+int(roi[3]),stride):
		for x in range(int(roi[0]),int(roi[0])+int(roi[2]),stride):
			var pixel: Color=image.get_pixel(x,y)
			var linear: Color=pixel.srgb_to_linear()
			var luma: float=.2126*linear.r+.7152*linear.g+.0722*linear.b
			total+=luma;low=minf(low,luma);high=maxf(high,luma);count+=1
			if pixel.r<=0. and pixel.g<=0. and pixel.b<=0.:black+=1
			if pixel.r>=1. or pixel.g>=1. or pixel.b>=1.:saturated+=1
	return {"valid_region":count>0,"roi":roi,"uniform_sample_stride":stride,"sample_count":count,"capture_rgb_linearized_luminance_mean":total/maxi(1,count),"luminance_min":low,"luminance_max":high,"black_endpoint_fraction":float(black)/maxi(1,count),"any_channel_saturated_endpoint_fraction":float(saturated)/maxi(1,count),"scope":"Exposure/tonemap-applied capture region includes paper/background. Not segmented ink contrast, physical irradiance, OCR or readability acceptance."}

func _optics_png_size(raw: PackedByteArray) -> Vector2i:
	if raw.size()<24 or raw.slice(0,8)!=PackedByteArray([137,80,78,71,13,10,26,10]) or raw.slice(12,16).get_string_from_ascii()!="IHDR":return Vector2i.ZERO
	return Vector2i((int(raw[16])<<24)|(int(raw[17])<<16)|(int(raw[18])<<8)|int(raw[19]),(int(raw[20])<<24)|(int(raw[21])<<16)|(int(raw[22])<<8)|int(raw[23]))

func _optics_same_subjects() -> bool:
	if optics.is_empty():return false
	var first: Dictionary=optics[0]
	for frame: Dictionary in optics:
		if frame.book_identity!=first.book_identity or frame.camera_identity!=first.camera_identity or frame.lamp.identity!=first.lamp.identity:return false
		for key: String in ["identity","device_identity","native_lens_identity"]:
			if frame.carrier[key]!=first.carrier[key] or frame.carrier[key].is_empty():return false
	return true

func _optics_pose_deltas(phase: String,book: Node3D,light: SpotLight3D,lens: Node3D) -> Dictionary:
	var current: Dictionary={"book":book.global_transform,"camera":player.camera.global_transform,"lamp":light.global_transform,"native_aperture_frame":lens.global_transform}
	if phase=="returned_hand":comparison_poses=current.duplicate()
	if comparison_poses.is_empty():return {"reference_available":false}
	var result: Dictionary={"reference_available":true,"reference_phase":"returned_hand","poses_not_forced":true}
	for key: String in current:
		var before: Transform3D=comparison_poses[key]
		var after: Transform3D=current[key]
		result[key]={"origin_delta_m":before.origin.distance_to(after.origin),"basis_delta_rad":before.basis.orthonormalized().get_rotation_quaternion().angle_to(after.basis.orthonormalized().get_rotation_quaternion())}
	return result

func _optics_sources() -> Dictionary:
	var result: Dictionary={get_script().resource_path:FileAccess.get_sha256(get_script().resource_path),"res://tests/V2BookLampDiagnostic.tscn":FileAccess.get_sha256("res://tests/V2BookLampDiagnostic.tscn")}
	for path: String in OWNER_SOURCES:result[path]=FileAccess.get_sha256(path)
	return result
