extends RefCounted
## Explicit substance assignments for retained V2 apparatus. Mutate the
## existing material's maps so state owners retain their exact references.
## Unlisted stock remains a surface-gate failure; there is no generic fallback.
const PALETTES := {
	"exterior_detail_pass": [[Color(1.,.32,.055),"milk_glass"]],
	"fuse_panel_prop": [
		[Color(0.26,0.25,0.24),"iron_neutral"],
		[Color(0.48,0.38,0.2),"brass_dull"],
		[Color(0.62,0.52,0.28),"brass"],
		[Color(0.2,0.16,0.13),"bakelite"],
		[Color(0.76,0.73,0.66),"porcelain_fixture"],
		[Color(0.3,0.22,0.14),"bakelite"],
		[Color(0.32,0.24,0.15),"bakelite"],
		[Color(0.8,0.78,0.66,0.34),"milk_glass"],
		[Color(0.5,0.3,0.15),"copper_aged"],
		[Color(0.88,0.62,0.24),"paper"],
		[Color(0.8,0.77,0.68),"paper"],
		[Color(0.64,0.3,0.16),"copper_aged"],
		[Color(0.34,0.3,0.24),"iron_neutral"],
		[Color(0.36,0.27,0.17),"bakelite"],
		[Color(0.3,0.29,0.27),"iron_neutral"],
		[Color(0.88,0.5,0.2),"bakelite"]],
	"mail_bank_prop": [
		[Color(0.47,0.325,0.185),"wood_dark"],
		[Color(0.62,0.58,0.5),"nickel_plated"],
		[Color(0.045,0.038,0.03),"iron_blackened"],
		[Color(0.06,0.05,0.04),"wood_dark"],
		[Color(0.09,0.075,0.055),"wood_dark"]],
	"orison_v2_native_signal_terminal": [
		[Color(0.015,0.035,0.025),"milk_glass"],
		[Color(0.2,0.045,0.025),"indicator_enamel"],
		[Color(0.24,0.18,0.12,0.72),"milk_glass"],
		[Color(0.16,0.07,0.02),"milk_glass"]],
	"arcade_cabinet_prop": [
		[Color(0.4784313738,0.1254902035,0.0941176489),"beacon_lacquer"],
		[Color(0.2274509817,0.4156862795,0.3450980484),"beacon_lacquer"],
		[Color(0.8,0.74,0.5),"brass_dull"],
		[Color(0.1,0.09,0.08),"bakelite_black"],
		[Color(0.09,0.07,0.06),"bakelite_black"],
		[Color(0.76,0.68,0.38),"brass"],
		[Color(0.12,0.11,0.1),"bakelite_black"],
		[Color(0.74,0.68,0.42),"brass"],
		[Color(0.78,0.7,0.4),"brass"]],
	"case_interactable": [
		[Color(0.16,0.31,0.36),"enamel_appliance"],
		[Color(0.18,0.21,0.19),"iron_neutral"],
		[Color(0.86,0.84,0.78),"paper"]],

	"watchman_clock_prop": [
		[Color(.29,.19,.11),"wood_dark"],
		[Color(.46,.46,.48),"iron_neutral"],
		[Color(.84,.81,.71),"paper"],
		# Graduations, punched paper marks and inked proof marks.
		[Color(.30,.24,.17),"paper"],[Color(.46,.40,.30),"paper"],
		[Color(.16,.13,.10),"paper"],[Color(.14,.11,.08),"paper"],
		[Color(.09,.07,.26),"paper"],[Color(.16,.13,.11),"paper"],
		[Color(.20,.16,.12),"iron_blackened"],
		[Color(.62,.68,.66,.20),"milk_glass"],
		[Color(.50,.40,.21),"brass_dull"],[Color(.56,.48,.26),"brass_dull"],
		[Color(.64,.56,.30),"brass_dull"],[Color(.60,.47,.21),"brass_dull"],
		[Color(.52,.40,.18),"brass_dull"],[Color(.78,.68,.30),"brass"]],
	"night_register_prop": [
		[Color(.33,.22,.14),"wood_dark"],[Color(.26,.17,.13),"wood_dark"],
		[Color(.62,.50,.24),"brass_dull"],[Color(.30,.24,.12),"brass_dull"],
		[Color(.78,.67,.33),"brass"],[Color(.16,.12,.05),"brass_dull"],
		[Color(.30,.25,.16),"brass_dull"],[Color(.44,.35,.16),"brass_dull"],
		[Color(.86,.74,.36),"brass"],[Color(.44,.44,.47),"iron_neutral"],
		[Color(.20,.20,.22),"iron_blackened"],
		[Color(.62,.58,.51),"paper"],[Color(.86,.83,.74),"paper"],
		[Color(.42,.36,.28),"paper"],[Color(.80,.76,.66),"paper"],
		[Color(.58,.54,.46),"paper"]],
	"watch_register_prop": [
		[Color(.31,.20,.13),"wood_dark"],
		[Color(.34,.28,.14),"brass_dull"],[Color(.62,.50,.24),"brass_dull"],
		[Color(.76,.63,.30),"brass"],[Color(.42,.34,.17),"brass_dull"],
		[Color(.36,.36,.38),"iron_neutral"],[Color(.09,.09,.11),"iron_blackened"],
		[Color(.19,.19,.21),"iron_blackened"],[Color(.14,.14,.16),"iron_blackened"],
		[Color(.83,.80,.73),"enamel_appliance"],
		[Color(.20,.42,.24),"indicator_enamel"],[Color(.63,.17,.11),"indicator_enamel"],
		[Color(.30,.16,.10),"copper_aged"],[Color(.88,.86,.80),"indicator_enamel"]],
	"tour_key_guard_prop": [
		[Color(.62,.50,.24),"brass_dull"],[Color(.78,.66,.32),"brass"],
		[Color(.66,.56,.26),"brass_dull"],[Color(.44,.44,.47),"iron_neutral"],
		[Color(.83,.80,.73),"enamel_appliance"],[Color(.19,.19,.21),"iron_blackened"]],
	"orison_v2_water_closet": [[Color(.59,.73,.78,.18),"water_clear"]],
	"washer_prop": [[Color(.18,.28,.31,.52),"water_clear"]],
	"orison_v2_medicine_cabinet": [[Color(.34,.20,.095),"wood_dark"]],
	"orison_v2_radio_prop": [[Color(.28,.20,.13),"bakelite"],[Color(.12,.12,.11),"rubber_aged"]],
	"house_switchboard_prop": [[Color(.18,.06,.02),"indicator_enamel"],[Color(.52,.37,.14),"brass_dull"]],
	"door_prop": [[Color(.16,.22,.20,.34),"milk_glass"]],
	"orison_v2_entry_door": [[Color(.66,.47,.20),"brass_dull"],[Color(.19,.14,.11),"wood_dark"]],
	"building_entry_sign": [[Color(.15,.105,.055),"wood_dark"]],
	"orison_v2_dumbwaiter_rope_visual": [[Color(.50,.42,.27),"linen"]],
	"photo_darkroom_light": [[Color(1.,.018,.009),"milk_glass"]],
	"orison_v2_blockout": [[Color(.76,.85,.89,.16),"milk_glass"]],
	"elevator": [
		[Color(.62,.52,.28),"brass_dull"],[Color(1.,1.,1.),"brass_dull"],
		[Color(.30,.36,.33),"enamel_appliance"],[Color(.18,.20,.19),"iron_blackened"],
		[Color(.55,.62,.65,.50),"milk_glass"],[Color(.90,.87,.80),"milk_glass"],
		[Color(.92,.88,.78),"milk_glass"],[Color(.45,.42,.38),"iron_neutral"],
		[Color(.92,.90,.84),"milk_glass"],[Color(.74,.75,.72),"mirror_aged"],
		[Color(.52,.09,.07),"indicator_enamel"]],
	"orison_v2_lift_mirror": [[Color(.74,.75,.72),"mirror_aged"]],
	"neon_sign_prop": [
		[Color(.30,.31,.30),"iron_neutral"],[Color(.74,.72,.66),"porcelain_fixture"],
		[Color(1.,.32,.44),"milk_glass"],[Color(1.,.86,.52),"milk_glass"],
		[Color(.42,.36,.20),"brass_dull"],[Color(.14,.14,.15),"iron_blackened"],
		[Color(.16,.16,.17),"iron_blackened"],[Color(.13,.13,.14),"iron_neutral"],
		[Color(1.,.93,.76),"milk_glass"],[Color(.20,.19,.17),"iron_blackened"],
		[Color(.24,.115,.052),"cast_iron"],[Color(.055,.055,.062),"iron_blackened"],
		[Color(.105,.105,.115),"iron_blackened"]],
	"orison_v2_marquee_dress": [
		[Color(.94,.90,.82),"milk_glass"],[Color(.42,.29,.11),"brass_dull"],
		[Color(.80,.78,.72),"porcelain_fixture"],[Color(1.,.93,.78),"milk_glass"]],
	"harukiya_signage_prop": [
		[Color(.85,.82,.72),"trim"],[Color(.95,.80,.55),"milk_glass"],
		[Color(.95,.85,.62),"milk_glass"],[Color(.35,.33,.30),"iron_neutral"],
		[Color(.72,.14,.08),"paper"]],
	"bodega_signage_prop": [[Color(.84,.73,.42),"milk_glass"],[Color(.93,.91,.84),"milk_glass"]],
	"otis_prop": [
		[Color(.30,.26,.16),"indicator_enamel"],[Color(.78,.74,.66),"indicator_enamel"],
		[Color(.48,.08,.055),"indicator_enamel"],[Color(.72,.70,.62),"porcelain_fixture"],
		[Color(.58,.44,.20),"brass_dull"]],
	"roof_tank_ballcock_prop": [
		[Color(.46,.37,.19),"brass_dull"],[Color(.27,.25,.23),"iron_neutral"],
		[Color(.44,.39,.32),"iron_neutral"],[Color(.30,.20,.12),"wood_dark"],
		[Color(.50,.46,.30),"brass_dull"],[Color(.62,.56,.36),"brass_dull"],
		[Color(.20,.19,.18),"iron_blackened"],[Color(.42,.33,.17),"brass_dull"],
		[Color(.58,.52,.30),"brass"],[Color(.46,.38,.25),"brass_dull"],
		[Color(.74,.82,.84,.72),"water_clear"],[Color(.62,.72,.74,.50),"water_clear"],
		[Color(.62,.55,.32),"wood_dark"]],
	"boiler_prop": [[Color(.42,.40,.37),"iron_neutral"],[Color(.70,.88,.90,.34),"milk_glass"],[Color(.28,.48,.52,.72),"water_clear"]],
	"dumbwaiter_prop": [
		[Color(.055,.045,.04),"iron_blackened"],[Color(.44,.35,.18),"brass_dull"],
		[Color(.50,.42,.27),"linen"],[Color(.20,.20,.22),"iron_neutral"],
		[Color(.32,.28,.23),"iron_neutral"],[Color(.128,.094,.086),"wood_dark"],[Color(.12790,.09368,.08572),"leather_worn"],
		[Color(.48,.39,.21),"brass_dull"]],
	"speaker_prop": [
		[Color(.10,.095,.09),"fabric_warm"],[Color(.16,.15,.14),"bakelite_black"],
		[Color(.30,.29,.27),"iron_neutral"],[Color(.05,.05,.05),"rubber_aged"]],
	"point_ball_prop": [[Color(.20,.34,.52),"billiard_resin"],[Color(.14,.24,.40),"billiard_resin"]],
	"darts_prop": [
		[Color(.55,.55,.60),"nickel_plated"],[Color(.72,.76,.74),"porcelain_fixture"],
		[Color(.72,.62,.28),"brass"],[Color(.7843137255,.2078431373,.168627451),"paper"],
		[Color(.1843137255,.5607843137,.5254901961),"paper"],[Color(.8901960784,.6901960784,.1843137255),"paper"]],
	"songbook_terminal_prop": [
		[Color(.72,.68,.58),"paper"],[Color(.62,.58,.44),"paper"],
		[Color(.035,.033,.032),"bakelite_black"],[Color(.235,.15,.09),"wood_dark"]],
}

static func apply(root: Node) -> int:
	var changed := 0
	var visited := {}
	for node: Node in root.find_children("*", "GeometryInstance3D", true, false):
		var mesh: Mesh
		if node is MeshInstance3D: mesh = node.mesh
		elif node is MultiMeshInstance3D and node.multimesh != null: mesh = node.multimesh.mesh
		if mesh == null: continue
		var owner: Node = node
		while owner != root and owner.get_script() == null: owner = owner.get_parent()
		var source: String = owner.get_script().resource_path.get_file().trim_suffix(".gd") if owner.get_script() != null else ""
		var palette: Array = PALETTES.get(source, [])
		if source == "orison_v2_blockout" and mesh.resource_path.begins_with("res://assets/props/roof_drainage_"):
			var key := "brick" if mesh.resource_path.contains("ports.glb") else "roof_bitumen"
			if node is MeshInstance3D:
				for index in mesh.get_surface_count(): node.set_surface_override_material(index,MatLib.get_mat(key))
			changed += 1
			continue
		for index in mesh.get_surface_count():
			var material: Material = node.material_override
			if material == null and node is MeshInstance3D: material = node.get_active_material(index)
			if material == null: material = mesh.surface_get_material(index)
			# Retire the V1 baked contact-shadow cards. Actual geometry and
			# runtime lighting own shadowing; keep the node for owner teardown.
			if node is MeshInstance3D and mesh.get_surface_count() == 1 and material is StandardMaterial3D and material.resource_name == "M_fx_shadow" and material.albedo_texture != null and material.albedo_texture.resource_path == "res://assets/building/textures/T_fx_fx_shadow.png":
				node.set_meta("retired_surface", "legacy_baked_contact_shadow")
				node.mesh = ArrayMesh.new()
				changed += 1
				continue
			if material is ShaderMaterial and material.shader.resource_path == "res://shaders/scope_screen.gdshader":
				var retained_parameters := {}
				for uniform in material.shader.get_shader_uniform_list():
					retained_parameters[uniform.name] = material.get_shader_parameter(uniform.name)
				material.shader = preload("res://shaders/v2_scope_screen.gdshader")
				for parameter in retained_parameters: material.set_shader_parameter(parameter,retained_parameters[parameter])
				var glass := MatLib.get_mat("milk_glass")
				material.set_shader_parameter("albedo_tex",glass.albedo_texture)
				material.set_shader_parameter("rough_tex",glass.roughness_texture)
				material.set_shader_parameter("normal_tex",glass.normal_texture)
				changed += 1
			if not material is StandardMaterial3D: continue
			var stock := material as StandardMaterial3D
			# Imported clear glass and inactive CRT stock have named roles,
			# independent of the owning shop's palette. Existing image/sign
			# albedo maps are retained when supplying their missing PBR companions.
			var recipes := palette
			if stock.resource_name in ["M_glassish", "M_screen"]:
				recipes = [[stock.albedo_color,"milk_glass"]]
			if visited.has(stock.get_instance_id()): continue
			if stock.albedo_texture != null and stock.roughness_texture != null and stock.normal_texture != null and stock.normal_enabled: continue
			for recipe: Array in recipes:
				if not stock.albedo_color.is_equal_approx(recipe[0]): continue
				var maps := MatLib.get_mat(recipe[1])
				var retained_surface_maps := stock.roughness_texture != null and stock.normal_texture != null
				if stock.albedo_texture == null: stock.albedo_texture = maps.albedo_texture
				if stock.roughness_texture == null: stock.roughness_texture = maps.roughness_texture
				if stock.normal_texture == null: stock.normal_texture = maps.normal_texture
				stock.normal_enabled = true
				if not retained_surface_maps:
					stock.normal_scale = .12
					stock.metallic = maps.metallic
				stock.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
				if not retained_surface_maps:
					stock.uv1_triplanar = true
					stock.uv1_scale = maps.uv1_scale
				stock.set_meta("v2_surface_stock", recipe[1])
				visited[stock.get_instance_id()] = true
				changed += 1
				break
	return changed
