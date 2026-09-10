extends Node3D

const TravelerScript = preload("res://scripts/traveler.gd")
const MapScript = preload("res://scripts/town_map.gd")
const CompassScript = preload("res://scripts/compass.gd")
const CitizenUI = preload("res://scripts/citizen_ui.gd")
const HarborScript = preload("res://scripts/harbor.gd")
const GOLD = Color("dfbf7c")
const INK = Color("101e27")
const PAPER = Color("eee7d5")
const MUTED = Color("b5c0be")
const LANDMARKS = ["mint","carpenter","boat","tavern","museum","inn","healer","oven"]
const SAVE_VERSION = 1

var plan: Dictionary
var polygons: Array[PackedVector2Array] = []
var buildings: Dictionary = {}
var building_polygons: Dictionary={}
var door_definitions: Dictionary={}
var nav := AStarGrid2D.new()
var player: CharacterBody3D
var city: Node3D
var camera: Camera3D
var environment: Environment
var sun: DirectionalLight3D
var sky_material: ProceduralSkyMaterial
var playing := false
var modal_open := false
var camera_yaw := PI/4
var camera_pitch := .64
var camera_distance := 29.0
var camera_target_distance := 29.0
var overhead := true
var orbiting := false
var camera_initialized := false
var day_phase := 0
var elapsed := 0.0
var tick := 0.0
var autosave_time := 0.0
var quality := true
var ui_visible := true
var journal_stage := 0
var discoveries: Array = []
var coins := 20
var fish := 0
var bread := 0
var fishing := false
var fishing_clock := 0.0
var bite_time := 0.0
var catch_window := false
var nearby: Dictionary = {}
var npcs: Array = []
var lamps: Array[OmniLight3D] = []
var roofs: Dictionary = {}
var birds: Array[Node3D] = []
var harbor: Node3D
var smoke: Array[GPUParticles3D] = []
var music: AudioStreamPlayer
var ambience: AudioStreamPlayer
var steps: AudioStreamPlayer
var gull: AudioStreamPlayer
var bell: AudioStreamPlayer
var music_level := .50
var ambience_level := .55
var steps_sounds: Array[AudioStream] = []
var ui: CanvasLayer
var hud: Control
var menu: Control
var modal: Control
var menu_continue: Button
var location_label: Label
var compass_label: Label
var objective_label: Label
var objective_title: Label
var prompt_label: Label
var notification: Label
var notification_time := 0.0
var gold_label: Label
var stamina_bar: ProgressBar
var time_label: Label
var mini_map: Control
var objective_marker: Label
var serif: Font
var sans: Font
var button_theme: Theme
var save_exists := false
var qa_mode := false
var qa_artifacts := ""
var qa_results: Array = []
var pointer_marker: MeshInstance3D
var pointer_time := 0.0
var reflection_view: SubViewport
var reflection_camera: Camera3D
var water_material: ShaderMaterial
var compass: Control
var controls_hint: Label
var journey_time := 0.0
var chatting := false
var speech_line: LineEdit
var speech_bubble: Label3D
var speech_seconds := 0.0
var bank_items := {"coins":0,"fish":0,"bread":0}
var citizen_ui: RefCounted
var doors: Dictionary={}
var door_open_states: Dictionary={}
var door_audio: Dictionary={}
var listener: AudioListener3D
var render_qa_runner: RefCounted
var harbor_qa_runner: RefCounted
var access_qa_runner: RefCounted
var tour_runner: RefCounted
var shorts_runner: RefCounted
var quitting:=false
signal door_sound_started(id: String, opened: bool)
var facades: Dictionary={}
var building_details: Dictionary={}

func _ready() -> void:
	get_tree().auto_accept_quit=false
	qa_mode = "--qa" in OS.get_cmdline_user_args() or "--qa-route" in OS.get_cmdline_user_args() or "--qa-render" in OS.get_cmdline_user_args() or "--qa-harbor" in OS.get_cmdline_user_args() or "--qa-access" in OS.get_cmdline_user_args() or "--qa-tour" in OS.get_cmdline_user_args() or "--qa-shorts" in OS.get_cmdline_user_args() or "--qa-diagnostic" in OS.get_cmdline_user_args()
	qa_artifacts = ProjectSettings.globalize_path("res://").path_join("../artifacts")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="):qa_artifacts=arg.trim_prefix("--qa-output=")
	if qa_mode:DirAccess.make_dir_recursive_absolute(qa_artifacts)
	setup_inputs()
	plan = JSON.parse_string(FileAccess.get_file_as_string("res://assets/town_plan.json"))
	for island in plan.land:
		var poly := PackedVector2Array()
		for p in island.points: poly.append(Vector2(p[0],p[1]))
		polygons.append(poly)
	for b in plan.buildings:
		buildings[b.id]=b
		if b.has("footprint"):
			var polygon:=PackedVector2Array()
			for point in b.footprint:polygon.append(Vector2(point[0],point[1]))
			building_polygons[b.id]=polygon
	setup_environment()
	city = $City
	refine_materials()
	for shape in city.find_children("*","CollisionShape3D",true,false):
		if shape.shape is ConcavePolygonShape3D:shape.shape.set_backface_collision_enabled(true)
	for b in plan.buildings:
		var roof = city.find_child("Roof_"+b.id,true,false)
		if roof: roofs[b.id] = roof
		for definition in b.get("doors",[{"id":b.id,"pos":[b.pos[0],2,b.pos[1]+b.depth/2]}]):
			var door=city.find_child("Door_"+definition.id,true,false)
			if door:doors[definition.id]=door;door_definitions[definition.id]=definition
		var facade=city.find_child("Facade_"+b.id,true,false)
		if facade:facades[b.id]=facade
		var detail=city.find_child("Details_"+b.id,true,false)
		if detail:building_details[b.id]=detail
	for s in plan.ships:
		var ship = city.find_child(s.name,true,false)
		if ship: ship.visible=false
	setup_water()
	for tree in plan.get("trees",[]):
		var trunk:=StaticBody3D.new()
		trunk.position=Vector3(tree.x,3.1,tree.z)
		var shape:=CollisionShape3D.new()
		var cylinder:=CylinderShape3D.new()
		cylinder.radius=tree.radius
		cylinder.height=2.2
		shape.shape=cylinder
		trunk.add_child(shape)
		add_child(trunk)
	setup_navigation()
	player = CharacterBody3D.new()
	player.set_script(TravelerScript)
	player.game = self
	player.position = Vector3(plan.spawn[0],2.12,plan.spawn[1])
	add_child(player)
	listener=AudioListener3D.new()
	listener.position.y=1.5
	player.add_child(listener)
	listener.make_current()
	player.visible = false
	player.model.rotation.y = PI
	camera = Camera3D.new()
	camera.fov = 62
	camera.near = .12
	camera.far = 1300
	camera.current = true
	add_child(camera)
	setup_people()
	setup_effects()
	setup_audio()
	setup_door_audio()
	harbor=HarborScript.new()
	harbor.name="Harbor"
	add_child(harbor)
	harbor.setup(self)
	setup_interface()
	citizen_ui=CitizenUI.new(self)
	load_settings()
	set_time(day_phase)
	update_quest()
	print("VESPER_READY buildings=%d bridges=%d trees=%d" % [plan.buildings.size(),plan.bridges.size(),plan.tree_count])
	if "--qa" in OS.get_cmdline_user_args(): run_qa.call_deferred()
	elif "--qa-route" in OS.get_cmdline_user_args():
		qa_mode = true
		run_route_qa.call_deferred()
	elif "--qa-render" in OS.get_cmdline_user_args():
		render_qa_runner=load("res://scripts/render_regression.gd").new()
		render_qa_runner.run.call_deferred(self)
	elif "--qa-harbor" in OS.get_cmdline_user_args():
		harbor_qa_runner=load("res://scripts/harbor_qa.gd").new()
		harbor_qa_runner.run.call_deferred(self)
	elif "--qa-access" in OS.get_cmdline_user_args():
		access_qa_runner=load("res://scripts/access_qa.gd").new()
		access_qa_runner.run.call_deferred(self)
	elif "--qa-tour" in OS.get_cmdline_user_args():
		tour_runner=load("res://scripts/town_tour.gd").new()
		tour_runner.run.call_deferred(self)
	elif "--qa-shorts" in OS.get_cmdline_user_args():
		shorts_runner=load("res://scripts/shorts_capture.gd").new()
		shorts_runner.run.call_deferred(self)

func setup_inputs() -> void:
	var bindings = {"move_forward":[KEY_W,KEY_UP],"move_back":[KEY_S,KEY_DOWN],"move_left":[KEY_A,KEY_LEFT],"move_right":[KEY_D,KEY_RIGHT],"sprint":[KEY_SHIFT],"jump":[KEY_SPACE],"interact":[KEY_E],"town_map":[KEY_M],"journal":[KEY_J],"paperdoll":[KEY_C],"pack":[KEY_I],"speech":[KEY_ENTER],"view":[KEY_V],"pause":[KEY_ESCAPE],"photo":[KEY_H],"screenshot":[KEY_F12],"fullscreen":[KEY_F11],"time":[KEY_T]}
	for action in bindings:
		if not InputMap.has_action(action): InputMap.add_action(action)
		for key in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action,event)

func setup_environment() -> void:
	var world := WorldEnvironment.new()
	environment = Environment.new()
	world.environment = environment
	add_child(world)
	sky_material = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("4d788c")
	sky_material.sky_horizon_color = Color("d6c7ab")
	sky_material.ground_bottom_color = Color("32433f")
	sky_material.ground_horizon_color = Color("b3a588")
	sky_material.sky_curve = .18
	sky_material.sun_angle_max = 2.2
	environment.sky = Sky.new()
	environment.sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = .8
	environment.ambient_light_sky_contribution = .7
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.15
	environment.ssao_enabled = true
	environment.ssao_radius = .65
	environment.ssao_intensity = .9
	environment.ssil_enabled = false
	environment.ssil_intensity = .75
	environment.ssr_enabled = true
	environment.ssr_max_steps = 128
	environment.glow_enabled = true
	environment.glow_intensity = .25
	environment.glow_bloom = 0.0
	environment.fog_enabled = false
	environment.fog_density = .0014
	environment.fog_light_color = Color("8dafa9")
	environment.fog_sun_scatter = .13
	environment.volumetric_fog_enabled = false
	environment.volumetric_fog_density = .0015
	environment.volumetric_fog_length = 190
	environment.volumetric_fog_albedo = Color("bcc5bc")
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-32,-42,0)
	sun.light_color = Color("ffe2ac")
	sun.light_energy = 2.2
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 170
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.shadow_bias = .04
	sun.shadow_normal_bias = 1.5
	add_child(sun)

func refine_materials() -> void:
	var materials := {}
	for node in city.find_children("*","MeshInstance3D",true,false):
		# Simplifying thin architectural trim makes it intersect nearby walls.
		# Keep these inexpensive meshes intact in both main and reflection views;
		# detailed trees and downloaded furnishings retain adaptive mesh LOD.
		if not node.name.begins_with("Tree_") and not node.name.begins_with("Furnishing_"):
			node.lod_bias=100000.0
		for i in range(node.mesh.get_surface_count()):
			var original = node.mesh.surface_get_material(i)
			if not original: continue
			var id: String = original.resource_name
			if not materials.has(id):
				if id.begins_with("Leaf") or id=="Gold leaf":
					var leaf := ShaderMaterial.new()
					leaf.shader = load("res://shaders/leaves.gdshader")
					var colors = {"Leaf shadow":Color("33441b"),"Leaf middle":Color("506128"),"Leaf sun":Color("71843b"),"Gold leaf":Color("94783b")}
					leaf.set_shader_parameter("leaf_color",colors[id])
					materials[id]=leaf
				else:
					var mat = original.duplicate()
					mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
					if mat.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
						mat.alpha_antialiasing_mode=BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
						mat.alpha_antialiasing_edge=.3
					mat.cull_mode=BaseMaterial3D.CULL_DISABLED
					mat.normal_scale=.55
					mat.metallic_specular=.22
					if id=="Old oak":mat.albedo_color=Color(.42,.31,.21)
					if id=="Canal paving":mat.albedo_color=Color(.42,.46,.48)
					if id=="Quarried sandstone":mat.albedo_color=Color(.73,.75,.73)
					if id=="Mint masonry":mat.albedo_color=Color(.66,.68,.67)
					if id=="Clay tiles":mat.albedo_color=Color(.68,.59,.52)
					if id=="Crimson cloth":mat.albedo_color=Color(.18,.028,.035)
					if id=="Slate tiles":mat.albedo_color=Color(.57,.66,.73)
					if id=="Bark":mat.albedo_color=Color(.48,.36,.26)
					if id=="Window light":mat.emission_energy_multiplier=.28
					if id=="Grass":mat.albedo_color=Color(.68,.77,.56)
					materials[id]=mat
			node.set_surface_override_material(i,materials[id])

func setup_water() -> void:
	var water := MeshInstance3D.new()
	water.name = "CanalWater"
	var plane := PlaneMesh.new()
	plane.size = Vector2(1800,1800)
	plane.subdivide_width = 160
	plane.subdivide_depth = 160
	water.mesh = plane
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/water.gdshader")
	water.material_override = mat
	water.layers = 2
	water_material = mat
	mat.set_shader_parameter("ripples",load("res://assets/materials/water_normals.jpg"))
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)
	reflection_view = SubViewport.new()
	reflection_view.size = Vector2i(720,405)
	reflection_view.world_3d = get_world_3d()
	reflection_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	reflection_view.msaa_3d = Viewport.MSAA_DISABLED
	add_child(reflection_view)
	reflection_camera = Camera3D.new()
	reflection_camera.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	reflection_camera.current = true
	reflection_camera.cull_mask = 1
	reflection_camera.near = .3
	reflection_camera.far = 600
	reflection_view.add_child(reflection_camera)
	var reflection_environment = environment.duplicate()
	reflection_environment.ssr_enabled = false
	reflection_environment.ssao_enabled = false
	reflection_environment.ssil_enabled = false
	reflection_environment.volumetric_fog_enabled = false
	reflection_camera.environment = reflection_environment
	mat.set_shader_parameter("reflection_texture",reflection_view.get_texture())
	var marker_mesh := TorusMesh.new()
	marker_mesh.inner_radius = .45
	marker_mesh.outer_radius = .53
	var marker_mat := StandardMaterial3D.new()
	marker_mat.albedo_color = GOLD
	marker_mat.emission_enabled = true
	marker_mat.emission = GOLD
	marker_mat.emission_energy_multiplier = 1.1
	pointer_marker = MeshInstance3D.new()
	pointer_marker.mesh = marker_mesh
	pointer_marker.material_override = marker_mat
	pointer_marker.visible = false
	add_child(pointer_marker)

func is_walkable(p: Vector2,check_buildings := true) -> bool:
	var on_land := false
	for poly in polygons:
		if Geometry2D.is_point_in_polygon(p,poly):
			on_land = true
			break
	if not on_land:
		for b in plan.bridges:
			var a := Vector2(b.a[0],b.a[1])
			var end := Vector2(b.b[0],b.b[1])
			if p.distance_to(Geometry2D.get_closest_point_to_segment(p,a,end)) < b.width/2-.64:
				on_land = true
				break
	if not on_land:
		for d in plan.docks:
			if absf(p.x-d.pos[0])<d.size[0]/2-.35 and absf(p.y-d.pos[1])<d.size[1]/2-.35:
				on_land = true
	if not on_land: return false
	if check_buildings:
		for b in plan.buildings:
			if building_polygons.has(b.id):
				var polygon: PackedVector2Array=building_polygons[b.id]
				var inside:=Geometry2D.is_point_in_polygon(p,polygon)
				var edge_distance:=INF
				for i in range(polygon.size()):edge_distance=minf(edge_distance,p.distance_to(Geometry2D.get_closest_point_to_segment(p,polygon[i],polygon[(i+1)%polygon.size()])))
				if inside and not b.enterable:return false
				if edge_distance<.60:
					var passage:=false
					for door in b.doors:
						if in_door_passage(p,door):passage=true
					if not passage:return false
				continue
			var dx: float = absf(p.x-b.pos[0])
			var dz: float = absf(p.y-b.pos[1])
			if dx < b.width/2+.58 and dz < b.depth/2+.58:
				if not b.enterable: return false
				# Door clearance follows each entrance's actual wall orientation.
				var interior: bool = dx<b.width/2-.62 and dz<b.depth/2-.62
				var passage:=false
				for door in b.doors:
					if in_door_passage(p,door):passage=true
				if not interior and not passage: return false
	return true

func in_door_passage(p: Vector2,door: Dictionary) -> bool:
	var yaw: float=door.get("yaw",0.0)
	var delta:=p-Vector2(door.pos[0],door.pos[2])
	return absf(delta.dot(Vector2(cos(yaw),-sin(yaw))))<.70 and absf(delta.dot(Vector2(sin(yaw),cos(yaw))))<.95

func setup_navigation() -> void:
	var low:=Vector2(INF,INF);var high:=Vector2(-INF,-INF)
	for island in plan.land:
		for p in island.points:
			low=low.min(Vector2(p[0],p[1]));high=high.max(Vector2(p[0],p[1]))
	var origin:=Vector2i(floori(low.x)-2,floori(low.y)-2)
	nav.region = Rect2i(origin,Vector2i(ceili(high.x)+3,ceili(high.y)+3)-origin)
	nav.cell_size = Vector2.ONE
	nav.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	nav.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	nav.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	nav.update()
	for x in range(nav.region.position.x,nav.region.end.x):
		for z in range(nav.region.position.y,nav.region.end.y):
			if not is_walkable(Vector2(x,z)): nav.set_point_solid(Vector2i(x,z))
	# Crates, barrels, market posts and interior furniture are real navigation obstacles.
	for obstacle in plan.get("obstacles",[]):
		var half_width: float=obstacle.w/2+.45
		var half_depth: float=obstacle.d/2+.45
		for x in range(ceili(obstacle.x-half_width),floori(obstacle.x+half_width)+1):
			for z in range(ceili(obstacle.z-half_depth),floori(obstacle.z+half_depth)+1):
				if nav.is_in_boundsv(Vector2i(x,z)):nav.set_point_solid(Vector2i(x,z))
	# Reserve the open door leaf beside the passage, so routes do not turn
	# through the hinged panel immediately after crossing the threshold.
	for definition in door_definitions.values():
		var yaw: float=definition.get("yaw",0.0)
		var hinge:=Vector2(definition.pos[0],definition.pos[2])-Vector2(cos(yaw),-sin(yaw))*.98
		var leaf_end:=hinge-Vector2(sin(yaw),cos(yaw))*1.95
		for x in range(ceili(minf(hinge.x,leaf_end.x)-.60),floori(maxf(hinge.x,leaf_end.x)+.60)+1):
			for z in range(ceili(minf(hinge.y,leaf_end.y)-.60),floori(maxf(hinge.y,leaf_end.y)+.60)+1):
				if Vector2(x,z).distance_to(Geometry2D.get_closest_point_to_segment(Vector2(x,z),hinge,leaf_end))<.60 and nav.is_in_boundsv(Vector2i(x,z)):nav.set_point_solid(Vector2i(x,z))

func closest_cell(p: Vector3) -> Vector2i:
	var cell := Vector2i(roundi(p.x),roundi(p.z))
	if nav.is_in_boundsv(cell) and not nav.is_point_solid(cell): return cell
	for radius in range(1,5):
		for dx in range(-radius,radius+1):
			for dz in range(-radius,radius+1):
				var c := cell + Vector2i(dx,dz)
				if nav.is_in_boundsv(c) and not nav.is_point_solid(c): return c
	return Vector2i(-999,-999)

func find_route(start: Vector3,end: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array()
	if not is_walkable(Vector2(end.x,end.z),false): return out
	var a := closest_cell(start)
	var b := closest_cell(end)
	if a.x == -999 or b.x == -999: return out
	var path := nav.get_id_path(a,b)
	for p in path: out.append(Vector3(p.x,2,p.y))
	return out

func setup_people() -> void:
	var people = [
		["elowen","Elowen","Museum courier","mint",Vector2(5.2,8.8)],
		["joiner","Tomas","Master carpenter","carpenter",Vector2(0,7.6)],
		["shipwright","Maren","Shipwright","boat",Vector2(-1.5,-3.8)],
		["curator","Aldren","Museum curator","museum",Vector2(0,5.0)],
		["innkeeper","Sella","Innkeeper","inn",Vector2(-4,2)],
		["barkeep","Garrick","Tavernkeeper","tavern",Vector2(-4,0)],
		["baker","Lysa","Baker","oven",Vector2(2.5,7.6)],
		["healer","Anwen","Healer","healer",Vector2(0,8)],
		["fisherman","Corin","Fisherman","fisher",Vector2(2.1,14)],
		["banker","Theodric","Banker","mint",Vector2(5,-4.5)]
	]
	var male_citizen=load("res://assets/citizen-male.glb")
	var female_citizen=load("res://assets/citizen-female.glb")
	for item in people:
		var b: Dictionary = buildings[item[3]]
		var npc := Node3D.new()
		npc.name = item[0]
		npc.position = Vector3(b.pos[0]+item[4].x,2.04,b.pos[1]+item[4].y)
		add_child(npc)
		var body: Node3D = (female_citizen if item[0] in ["elowen","shipwright","innkeeper","baker","healer"] else male_citizen).instantiate()
		body.scale = Vector3.ONE*1.03
		body.rotation.y = randf_range(-.3,.3)
		npc.add_child(body)
		var color := Color.from_hsv(fmod(npcs.size()*.16+.03,1),.20,.90)
		for node in body.find_children("*","MeshInstance3D",true,false):
			for i in range(node.mesh.get_surface_count()):
				var mat = node.mesh.surface_get_material(i)
				if mat and "peasant" in mat.resource_name.to_lower():
					var m = mat.duplicate()
					m.albedo_color = color
					node.set_surface_override_material(i,m)
		var nameplate := Label3D.new()
		nameplate.text = item[1]
		nameplate.position.y = 2.15
		nameplate.font_size = 34
		nameplate.pixel_size = .0045
		nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		nameplate.modulate = PAPER
		nameplate.outline_modulate = INK
		nameplate.no_depth_test = false
		nameplate.visible = false
		npc.add_child(nameplate)
		var animation=prepare_citizen_animation(body)
		npcs.append({"id":item[0],"name":item[1],"role":item[2],"building":item[3],"node":npc,"body":body,"animation":animation,"label":nameplate,"home":npc.position})
	# Residents walk between nearby points using the same navigation grid as the player.
	for i in range(9):
		var b: Dictionary = buildings[["mint","canvas","music","champion","hostel","boat","tavern","inn","gadget"][i]]
		var npc := Node3D.new()
		var pos = Vector3(b.pos[0]-b.width/2-1.7,2.06,b.pos[1]+b.depth/2+2.1)
		if not is_walkable(Vector2(pos.x,pos.z)): pos = Vector3(b.interaction[0],2.05,b.interaction[2])
		npc.position = pos
		add_child(npc)
		var body: Node3D = (female_citizen if i%2==0 else male_citizen).instantiate()
		npc.add_child(body)
		var destination = pos+Vector3(randf_range(-4,4),0,-4)
		var route := find_route(pos,destination)
		var animation=prepare_citizen_animation(body)
		npcs.append({"id":"resident","name":"Resident","role":"Citizen of Vesper","building":b.id,"node":npc,"body":body,"animation":animation,"home":pos,"route":route,"route_index":0,"forward":true,"walk":0.0})

func prepare_citizen_animation(body: Node3D) -> AnimationPlayer:
	var animation: AnimationPlayer=body.find_child("AnimationPlayer",true,false)
	if animation:
		for clip in animation.get_animation_list():animation.get_animation(clip).loop_mode=Animation.LOOP_LINEAR
		animation.play("Idle")
	return animation

func setup_effects() -> void:
	# Local lights are capped to the nearest eight at runtime.
	for p in plan.lanterns:
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(p[0],p[1],p[2])
		lamp.light_color = Color("ffb653")
		lamp.light_energy = 1.3
		lamp.omni_range = 7.0
		lamp.visible = false
		add_child(lamp)
		lamps.append(lamp)
	var bird_material := StandardMaterial3D.new()
	bird_material.albedo_color = Color("e3dcc9")
	bird_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in range(14):
		var pivot := Node3D.new()
		add_child(pivot)
		for side in [-1,1]:
			var wing := MeshInstance3D.new()
			var mesh := PrismMesh.new()
			mesh.size = Vector3(.65,.06,.20)
			wing.mesh = mesh
			wing.position.x = side*.32
			wing.material_override = bird_material
			pivot.add_child(wing)
		birds.append(pivot)
	for b in plan.buildings:
		if b.id not in ["inn","oven","ironworks","tavern","brew"]: continue
		var particles := GPUParticles3D.new()
		particles.position = Vector3(b.chimney[0],b.chimney[1],b.chimney[2])
		particles.amount = 16
		particles.lifetime = 5.0
		particles.visibility_aabb = AABB(Vector3(-12,-2,-12),Vector3(24,24,24))
		var process := ParticleProcessMaterial.new()
		process.direction = Vector3(.3,1,.1)
		process.spread = 15
		process.initial_velocity_min = .5
		process.initial_velocity_max = .9
		process.gravity = Vector3(.15,.08,.05)
		process.scale_min = .35
		process.scale_max = .8
		var grad := Gradient.new()
		grad.set_color(0,Color(.42,.43,.40,.12))
		grad.set_color(1,Color(.45,.47,.46,0))
		var ramp := GradientTexture1D.new()
		ramp.gradient = grad
		process.color_ramp = ramp
		particles.process_material = process
		var mesh := SphereMesh.new()
		mesh.radius = .55
		mesh.height = 1.1
		mesh.radial_segments = 8
		mesh.rings = 5
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.vertex_color_use_as_albedo = true
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mesh.material = mat
		particles.draw_pass_1 = mesh
		add_child(particles)
		smoke.append(particles)

func setup_audio() -> void:
	music = AudioStreamPlayer.new()
	music.volume_db = linear_to_db(music_level)
	add_child(music)
	if not qa_mode:
		for extension in ["ogg","wav"]:
			var local_path: String="user://music."+extension
			if FileAccess.file_exists(local_path):
				if install_local_music(ProjectSettings.globalize_path(local_path),false):break
	ambience = AudioStreamPlayer.new()
	var air: AudioStreamWAV = load("res://assets/audio/canal-air.wav")
	air.loop_mode = AudioStreamWAV.LOOP_FORWARD
	air.loop_end = 22050*48
	ambience.stream = air
	ambience.volume_db = linear_to_db(ambience_level)
	add_child(ambience)
	steps = AudioStreamPlayer.new()
	steps.volume_db = -11
	add_child(steps)
	for i in range(4): steps_sounds.append(load("res://assets/audio/step-%d.wav"%i))
	gull = AudioStreamPlayer.new()
	gull.stream = load("res://assets/audio/gull.wav")
	gull.volume_db = -20
	add_child(gull)
	bell = AudioStreamPlayer.new()
	bell.stream = load("res://assets/audio/bell.wav")
	bell.volume_db = -15
	add_child(bell)

func install_local_music(path: String, announce: bool=true) -> bool:
	var extension:=path.get_extension().to_lower()
	if extension not in ["ogg","wav"] or not FileAccess.file_exists(path):return false
	var input:=FileAccess.open(path,FileAccess.READ)
	if input==null or input.get_length()>100*1024*1024:return false
	var data:=input.get_buffer(input.get_length())
	input.close()
	var stream: AudioStream
	if extension=="ogg":stream=AudioStreamOggVorbis.load_from_buffer(data)
	else:stream=AudioStreamWAV.load_from_buffer(data)
	if stream==null or stream.get_length()<=0:return false
	if stream is AudioStreamOggVorbis:stream.loop=true
	elif stream is AudioStreamWAV:
		stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin=0
		stream.loop_end=int(stream.get_length()*stream.mix_rate)
	var destination: String="user://"+("qa_music." if qa_mode else "music.")+extension
	var output:=FileAccess.open(destination,FileAccess.WRITE)
	if output==null:return false
	output.store_buffer(data)
	output.close()
	# Keep a single chosen format so the previous choice cannot win at startup.
	var other: String="user://"+("qa_music." if qa_mode else "music.")+("wav" if extension=="ogg" else "ogg")
	if FileAccess.file_exists(other):DirAccess.remove_absolute(ProjectSettings.globalize_path(other))
	music.stop()
	music.stream=stream
	music.play()
	if announce:toast("Your local soundtrack is ready.")
	return true

func choose_local_music() -> void:
	var picker:=FileDialog.new()
	picker.title="Choose your local soundtrack"
	picker.file_mode=FileDialog.FILE_MODE_OPEN_FILE
	picker.access=FileDialog.ACCESS_FILESYSTEM
	picker.use_native_dialog=true
	picker.filters=PackedStringArray(["*.ogg ; Ogg Vorbis audio","*.wav ; WAV audio"])
	add_child(picker)
	picker.file_selected.connect(func(path):
		if not install_local_music(path):toast("Could not read that audio file. Choose an OGG or WAV under 100 MB.")
		picker.queue_free())
	picker.canceled.connect(picker.queue_free)
	picker.popup_centered_ratio(.7)

func footstep() -> void:
	if not playing or modal_open: return
	steps.stream = steps_sounds[randi()%4]
	steps.pitch_scale = randf_range(.87,1.12)
	steps.volume_db = linear_to_db(ambience_level*.35)
	steps.play()

func play_effect(id: String) -> void:
	var path: String="res://assets/audio/demo-"+id+".wav"
	if not ResourceLoader.exists(path):return
	var sound:=AudioStreamPlayer.new()
	sound.stream=load(path)
	sound.volume_db=linear_to_db(maxf(ambience_level*.55,.0001))
	add_child(sound)
	sound.finished.connect(sound.queue_free)
	sound.play()

func setup_door_audio() -> void:
	for id in doors:
		var definition: Dictionary=door_definitions[id]
		var sound:=AudioStreamPlayer3D.new()
		sound.name="DoorAudio_"+id
		sound.position=Vector3(definition.pos[0],definition.pos[1]+1.2,definition.pos[2])
		sound.unit_size=4.0
		sound.max_distance=18.0
		sound.max_db=0.0
		add_child(sound)
		door_audio[id]=sound
		door_open_states[id]=false

func play_door_sound(id: String, opened: bool) -> void:
	var sound: AudioStreamPlayer3D=door_audio[id]
	sound.stream=load("res://assets/audio/demo-door-"+("open" if opened else "close")+".wav")
	sound.volume_db=linear_to_db(maxf(ambience_level*.65,.0001))
	sound.play()
	door_sound_started.emit(id,opened)

func open_pack() -> void:
	citizen_ui.open_pack()

func open_paperdoll() -> void:
	citizen_ui.paperdoll()

func begin_speech() -> void:
	chatting=true
	player.path.clear()
	speech_line.text=""
	speech_line.visible=true
	speech_line.grab_focus()

func end_speech(text: String="") -> void:
	chatting=false
	speech_line.visible=false
	speech_line.release_focus()
	text=text.strip_edges().left(120)
	if text.is_empty():return
	speech_bubble.text=text
	speech_bubble.visible=true
	speech_seconds=5
	citizen_ui.speech(text)

func panel_style(bg: Color=Color("14252fee"),border: Color=Color("a7916055")) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style

func make_label(parent: Node,text: String,pos: Vector2,extent: Vector2,font_size:=20,color: Color=PAPER,display:=false) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.size = extent
	label.add_theme_font_override("font",serif if display else sans)
	label.add_theme_font_size_override("font_size",font_size)
	var on_paper: bool=parent.get_meta("paper",false)
	label.add_theme_color_override("font_color",(Color("754625") if color==GOLD else Color("493827")) if on_paper else color)
	label.add_theme_color_override("font_shadow_color",Color(0,0,0,0) if on_paper else Color(0,0,0,.8))
	label.add_theme_constant_override("shadow_offset_x",1)
	label.add_theme_constant_override("shadow_offset_y",2)
	if not on_paper:
		label.add_theme_color_override("font_outline_color",Color("151d18"))
		label.add_theme_constant_override("outline_size",1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	label.set_deferred("size",extent)
	return label

func make_button(parent: Node,text: String,pos: Vector2,extent: Vector2,action: Callable,primary:=false) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = extent
	b.theme = button_theme
	if parent.get_meta("paper",false):
		var normal:=StyleBoxFlat.new()
		normal.bg_color=Color("8f5d2412") if primary else Color.TRANSPARENT
		normal.border_color=Color("96744a88")
		normal.border_width_bottom=1
		var hover:=normal.duplicate()
		hover.bg_color=Color("98704133")
		b.add_theme_stylebox_override("normal",normal)
		b.add_theme_stylebox_override("hover",hover)
		b.add_theme_stylebox_override("pressed",hover)
		b.add_theme_color_override("font_color",Color("4e3020"))
		b.add_theme_color_override("font_hover_color",Color("8a3924"))
		b.add_theme_color_override("font_pressed_color",Color("8a3924"))
		b.add_theme_color_override("font_focus_color",Color("4e3020"))
		b.add_theme_font_override("font",serif)
		b.add_theme_font_size_override("font_size",24)
	elif primary:
		b.add_theme_stylebox_override("normal",panel_style(Color("59432aeb"),Color("cfb77a")))
		b.add_theme_color_override("font_color",Color("ffedbd"))
	b.pressed.connect(action)
	parent.add_child(b)
	return b

func texture_element(parent: Node,path: String,pos: Vector2,extent: Vector2) -> TextureRect:
	var texture:=TextureRect.new()
	texture.texture=load(path)
	texture.position=pos
	texture.size=extent
	texture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	texture.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(texture)
	return texture

func shade_caption(label: Label) -> void:
	var backing:=StyleBoxFlat.new()
	backing.bg_color=Color("201d17c9")
	backing.border_color=Color("b59a624a")
	backing.border_width_bottom=1
	backing.content_margin_left=14
	backing.content_margin_right=14
	backing.content_margin_top=5
	backing.content_margin_bottom=5
	label.add_theme_stylebox_override("normal",backing)
	label.add_theme_constant_override("outline_size",0)
	label.add_theme_constant_override("shadow_offset_x",0)
	label.add_theme_constant_override("shadow_offset_y",0)

func kit_button(path: String,pos: Vector2,extent: Vector2,tip: String,action: Callable) -> void:
	var b:=TextureButton.new()
	b.texture_normal=load(path)
	b.ignore_texture_size=true
	b.stretch_mode=TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	b.position=pos
	b.size=extent
	b.tooltip_text=tip
	b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	b.mouse_entered.connect(func():b.modulate=Color(1.2,1.15,1.03))
	b.mouse_exited.connect(func():b.modulate=Color.WHITE)
	b.pressed.connect(action)
	hud.add_child(b)

func make_scrim(parent: Node,alpha: float) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = Color(0.025,.045,.057,alpha)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(rect)
	return rect

func setup_interface() -> void:
	var book_font:=FontVariation.new()
	book_font.base_font=load("res://assets/fonts/CormorantGaramond.ttf")
	book_font.variation_opentype={"wght":600.0}
	serif=book_font
	sans = SystemFont.new()
	sans.font_names = PackedStringArray(["Segoe UI","Arial"])
	button_theme = Theme.new()
	button_theme.default_font = serif
	button_theme.default_font_size = 24
	button_theme.set_stylebox("normal","Button",panel_style(Color("30281dcc"),Color("a7916077")))
	button_theme.set_stylebox("hover","Button",panel_style(Color("5d4a2eef"),GOLD))
	button_theme.set_stylebox("pressed","Button",panel_style(Color("775c36ef"),GOLD))
	button_theme.set_stylebox("focus","Button",panel_style(Color(0,0,0,0),GOLD))
	button_theme.set_color("font_color","Button",PAPER)
	button_theme.set_color("font_hover_color","Button",Color.WHITE)
	ui = CanvasLayer.new()
	add_child(ui)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)
	# Full-screen, restrained vignette keeps text legible without covering the city.
	var vignette := ColorRect.new()
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment(){vec2 uv=UV;float d=distance(uv,vec2(.5));float a=smoothstep(.28,.78,d)*.34;COLOR=vec4(.015,.029,.034,a);}"
	var vm := ShaderMaterial.new()
	vm.shader = shader
	vignette.material = vm
	root.add_child(vignette)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)
	hud.visible = false
	location_label = make_label(hud,"The Mint of Vesper",Vector2(470,28),Vector2(660,42),31,PAPER,true)
	location_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shade_caption(location_label)
	compass_label = make_label(hud,"N",Vector2(640,69),Vector2(320,24),14,GOLD,true)
	compass_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective_title = make_label(hud,"A parcel across the water",Vector2(27,31),Vector2(350,27),21,GOLD,true)
	objective_label = make_label(hud,"Speak to Elowen near the Mint.",Vector2(28,64),Vector2(285,65),16,PAPER,true)
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_title.visible=false
	objective_label.visible=false
	mini_map = Control.new()
	hud.add_child(mini_map)
	mini_map.visible=false
	kit_button("res://assets/ui/pack.svg",Vector2(22,762),Vector2(112,112),"Open your pack · I",open_pack)
	kit_button("res://assets/ui/book.svg",Vector2(133,777),Vector2(78,94),"Traveler’s journal · J",toggle_journal)
	gold_label = make_label(hud,"20 gold",Vector2(223,831),Vector2(185,24),17,GOLD,true)
	shade_caption(gold_label)
	shade_caption(make_label(hud,"Traveler",Vector2(222,785),Vector2(185,32),25,PAPER,true))
	stamina_bar = ProgressBar.new()
	stamina_bar.position = Vector2(225,866)
	stamina_bar.size = Vector2(135,4)
	stamina_bar.show_percentage = false
	var stamina_bg := StyleBoxFlat.new()
	stamina_bg.bg_color=Color("172729")
	var stamina_fill := StyleBoxFlat.new()
	stamina_fill.bg_color=Color("8fa88a")
	stamina_bar.add_theme_stylebox_override("background",stamina_bg)
	stamina_bar.add_theme_stylebox_override("fill",stamina_fill)
	hud.add_child(stamina_bar)
	stamina_bar.set_deferred("size",Vector2(135,4))
	compass=Control.new()
	compass.set_script(CompassScript)
	compass.game=self
	compass.position=Vector2(1436,739)
	compass.size=Vector2(134,134)
	hud.add_child(compass)
	var zoom_in=make_button(hud,"+",Vector2(1457,698),Vector2(40,33),func():change_zoom(.82))
	zoom_in.name="ZoomIn"
	zoom_in.tooltip_text="Zoom in · mouse wheel"
	var zoom_out=make_button(hud,"−",Vector2(1510,698),Vector2(40,33),func():change_zoom(1.22))
	zoom_out.name="ZoomOut"
	zoom_out.tooltip_text="Zoom out · mouse wheel"
	time_label = make_label(hud,"Golden hour",Vector2(1410,868),Vector2(182,24),17,GOLD,true)
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls_hint=make_label(hud,"WASD walk · Shift run · E speak · Enter say · C paperdoll · Wheel zoom",Vector2(398,867),Vector2(830,26),16,PAPER)
	controls_hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	shade_caption(controls_hint)
	prompt_label = make_label(hud,"",Vector2(480,804),Vector2(640,42),26,PAPER,true)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shade_caption(prompt_label)
	prompt_label.visible = false
	notification = make_label(root,"",Vector2(440,120),Vector2(720,55),24,PAPER,true)
	notification.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shade_caption(notification)
	notification.visible = false
	objective_marker = make_label(hud,"◇",Vector2.ZERO,Vector2(160,50),34,GOLD)
	objective_marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective_marker.visible = false
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(menu)
	var menu_shader := Shader.new()
	menu_shader.code = "shader_type canvas_item;void fragment(){float a=(1.0-smoothstep(.06,.69,UV.x))*.89;COLOR=vec4(.025,.052,.062,a);}"
	var menu_mat := ShaderMaterial.new()
	menu_mat.shader = menu_shader
	var shade := make_scrim(menu,1)
	shade.material = menu_mat
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var crest := TextureRect.new()
	crest.texture = load("res://assets/crest.svg")
	crest.position = Vector2(85,172)
	crest.size = Vector2(44,50)
	crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	menu.add_child(crest)
	make_label(menu,"VESPER",Vector2(78,244),Vector2(580,130),110,PAPER,true)
	make_label(menu,"City of Bridges",Vector2(86,367),Vector2(410,55),36,GOLD,true)
	var introduction := make_label(menu,"The water remembers.\nThe bridges are waiting.\nWelcome back to Britannia.",Vector2(87,445),Vector2(390,95),23,PAPER,true)
	introduction.add_theme_constant_override("line_spacing",5)
	save_exists = FileAccess.file_exists(save_path())
	menu_continue = make_button(menu,"Continue your journey" if save_exists else "Enter Vesper",Vector2(87,579),Vector2(315,58),func():start_journey(save_exists),true)
	menu_continue.grab_focus()
	make_button(menu,"About this journey",Vector2(87,653),Vector2(208,43),show_credits)
	make_button(menu,"Quit",Vector2(307,653),Vector2(95,43),quit_demo)
	if save_exists: make_button(menu,"Begin again",Vector2(87,711),Vector2(315,38),confirm_new_journey)
	make_label(menu,"An unofficial Ultima Online fan tech demo",Vector2(88,790),Vector2(600,27),16,MUTED)
	make_label(menu,"Made for nostalgia and fun. This will never become a complete game.",Vector2(88,823),Vector2(850,24),14,MUTED)
	make_label(menu,"Fan tech demo  /  0.3.2",Vector2(1260,39),Vector2(300,22),14,PAPER).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	modal = Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.visible = false
	root.add_child(modal)
	speech_line=LineEdit.new()
	speech_line.position=Vector2(437,812)
	speech_line.size=Vector2(790,48)
	speech_line.placeholder_text="Speak…  bank / vendor buy / vendor sell"
	speech_line.max_length=120
	speech_line.add_theme_font_override("font",serif)
	speech_line.add_theme_font_size_override("font_size",24)
	speech_line.add_theme_stylebox_override("normal",panel_style(Color("181e19ef"),GOLD))
	speech_line.text_submitted.connect(end_speech)
	speech_line.gui_input.connect(func(event):
		if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:end_speech();get_viewport().set_input_as_handled())
	root.add_child(speech_line)
	speech_line.visible=false
	speech_bubble=Label3D.new()
	speech_bubble.font=serif
	speech_bubble.font_size=40
	speech_bubble.pixel_size=.005
	speech_bubble.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	speech_bubble.no_depth_test=true
	speech_bubble.position.y=2.3
	speech_bubble.modulate=Color("e9dcac")
	speech_bubble.outline_size=10
	player.add_child(speech_bubble)
	speech_bubble.visible=false

func open_modal(title: String,width:=640.0,height:=580.0) -> Panel:
	for node in modal.get_children():node.queue_free()
	modal.visible = true
	modal_open = true
	orbiting = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	make_scrim(modal,.48)
	var p := Panel.new()
	p.position = Vector2((1600-width)/2,(900-height)/2)
	p.size = Vector2(width,height)
	p.set_meta("paper",true)
	var parchment:=StyleBoxTexture.new()
	var page:=AtlasTexture.new()
	page.atlas=load("res://assets/ui/journal.png")
	page.region=Rect2(70,58,670,810)
	parchment.texture=page
	parchment.texture_margin_left=34
	parchment.texture_margin_right=34
	parchment.texture_margin_top=34
	parchment.texture_margin_bottom=34
	p.add_theme_stylebox_override("panel",parchment)
	modal.add_child(p)
	make_label(p,title,Vector2(34,25),Vector2(width-108,60),42,PAPER,true)
	make_button(p,"×",Vector2(width-67,27),Vector2(38,36),close_modal)
	return p

func close_modal() -> void:
	modal_open = false
	modal.visible = false
	for node in modal.get_children():node.queue_free()
	if playing: save_journey()

func start_journey(resume: bool) -> void:
	harbor.watching=false
	close_modal()
	if resume: load_journey()
	else:
		journal_stage = 0
		discoveries.clear()
		coins = 20
		fish = 0
		bread = 0
		bank_items={"coins":0,"fish":0,"bread":0}
		player.position = Vector3(plan.spawn[0],2.12,plan.spawn[1])
		player.velocity = Vector3.ZERO
		player.path.clear()
		camera_yaw=PI/4
		camera_pitch=.64
		camera_target_distance=29
		overhead=true
		player.model.rotation.y=PI
	playing = true
	journey_time=0
	player.visible = true
	player.last_safe = player.position
	menu.visible = false
	hud.visible = true
	camera_initialized = false
	update_quest()
	if not music.playing: music.play()
	if not ambience.playing: ambience.play()
	toast("Welcome to Vesper. Elowen is waiting by the Mint.")
	save_journey()

func confirm_new_journey() -> void:
	var p := open_modal("Begin a new journey",540,300)
	make_label(p,"Your current local journey will be replaced.",Vector2(34,111),Vector2(480,35),19)
	make_button(p,"Keep my journey",Vector2(34,210),Vector2(218,46),close_modal)
	make_button(p,"Begin again",Vector2(269,210),Vector2(236,46),func():start_journey(false),true)

func show_pause() -> void:
	var p := open_modal("A moment by the water",640,644)
	make_button(p,"Return to Vesper",Vector2(34,106),Vector2(572,49),close_modal,true).grab_focus()
	make_label(p,"Music",Vector2(35,184),Vector2(160,30),22,PAPER,true)
	make_button(p,"Choose local music",Vector2(34,216),Vector2(220,30),choose_local_music)
	var music_slider := HSlider.new()
	music_slider.position = Vector2(287,194)
	music_slider.size = Vector2(315,26)
	music_slider.max_value = 1
	music_slider.step = .01
	music_slider.value = music_level
	music_slider.value_changed.connect(func(v):music_level=v;music.volume_db=linear_to_db(maxf(v,.0001));save_settings())
	p.add_child(music_slider)
	make_label(p,"City ambience",Vector2(35,263),Vector2(215,30),22,PAPER,true)
	var air_slider := HSlider.new()
	air_slider.position = Vector2(287,274)
	air_slider.size = Vector2(315,26)
	air_slider.max_value = 1
	air_slider.step = .01
	air_slider.value = ambience_level
	air_slider.value_changed.connect(func(v):ambience_level=v;ambience.volume_db=linear_to_db(maxf(v,.0001));save_settings())
	p.add_child(air_slider)
	make_button(p,"Light: "+["Golden hour","Daylight","Lantern night"][day_phase],Vector2(34,333),Vector2(278,46),func():set_time((day_phase+1)%3);show_pause())
	make_button(p,"Details: "+("High" if quality else "Performance"),Vector2(328,333),Vector2(278,46),func():set_quality(not quality);show_pause())
	make_button(p,"Traveler’s journal",Vector2(34,397),Vector2(278,46),toggle_journal)
	make_button(p,"About & controls",Vector2(328,397),Vector2(278,46),show_credits)
	make_button(p,"Save and return to title",Vector2(34,464),Vector2(572,46),return_to_title)
	make_button(p,"Save and quit",Vector2(34,527),Vector2(572,46),quit_demo)
	make_label(p,"F11  Fullscreen      H  Hide interface      F12  Save a photograph",Vector2(35,597),Vector2(570,24),14,MUTED)

func return_to_title() -> void:
	harbor.watching=false
	save_journey()
	close_modal()
	playing = false
	player.visible = false
	player.path.clear()
	player.velocity = Vector3.ZERO
	hud.visible = false
	menu.visible = true
	menu_continue.text = "Continue your journey"
	save_exists = true
	menu_continue.grab_focus()

func toggle_map() -> void:
	if not playing:return
	if modal_open: close_modal()
	var p := open_modal("The islands of Vesper",1050,820)
	var big_map := Control.new()
	big_map.set_script(MapScript)
	big_map.game = self
	big_map.expanded = true
	big_map.position = Vector2(40,100)
	big_map.size = Vector2(555,680)
	p.add_child(big_map)
	make_label(p,"Across the canals",Vector2(630,125),Vector2(350,44),31,GOLD,true)
	var text: String = "The Mint lies to the north, the artisans work on the central islands, and the museum stands at the southern edge.\n\n◇  Your next delivery\n●  You are here\n\nThe blue numbered markers lead to the docks. Walk to a brass-capped post and press E to watch the harbor."
	var label := make_label(p,text,Vector2(630,191),Vector2(350,318),19,PAPER)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for i in range(harbor.plan.lookouts.size()):
		var index: int=i
		var dock_button:=make_button(p,("1   Fishing wharf" if i==0 else "2   Harbor lookout"),Vector2(630,540+i*58),Vector2(354,48),func():walk_to_harbor(index))
		dock_button.name="HarborRoute"+str(i)
	make_button(p,"Return to the streets",Vector2(630,693),Vector2(354,49),close_modal,true)

func walk_to_harbor(index: int) -> void:
	close_modal()
	if harbor.watching:harbor.toggle_watch()
	var point=harbor.plan.lookouts[index].pos
	if player.go_to(Vector3(point[0],point[1],point[2])):toast("Walking to the "+("fishing wharf" if index==0 else "harbor lookout"))
	else:toast("The dock cannot be reached from here.")

func toggle_journal() -> void:
	if not playing:return
	play_effect("page")
	var p := open_modal("",1180,785)
	for child in p.get_children():child.queue_free()
	var cover:=StyleBoxTexture.new()
	cover.texture=load("res://assets/ui/journal.png")
	p.add_theme_stylebox_override("panel",cover)
	make_label(p,"The traveler’s journal",Vector2(80,62),Vector2(455,54),35,GOLD,true)
	make_label(p,"A parcel across the water",Vector2(82,142),Vector2(443,42),27,GOLD,true)
	var tasks = ["Meet Elowen, the museum’s courier, beside the Mint.","Collect a cedar case from Tomas at The Hammer and Nail.","Bring the case to Maren at The Majestic Boat for the astrolabe.","Deliver the packed astrolabe to Aldren inside Vesper Museum.","The astrolabe is safe in the museum. Vesper remembers your kindness."]
	var body := make_label(p,tasks[journal_stage],Vector2(83,207),Vector2(423,132),26,PAPER,true)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var previous=""
	for i in range(journal_stage):previous+="✓  "+["Elowen entrusted me with her letter.","Tomas made the cedar case.","Maren packed the astrolabe.","Aldren welcomed the instrument home."][i]+"\n\n"
	var history:=make_label(p,previous,Vector2(83,365),Vector2(428,212),21,PAPER,true)
	history.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	make_label(p,"Places remembered",Vector2(655,67),Vector2(445,53),34,GOLD,true)
	make_label(p,"%d of %d familiar places"%[discoveries.size(),LANDMARKS.size()],Vector2(660,133),Vector2(427,34),23,PAPER,true)
	var names := ""
	for id in LANDMARKS:
		names += ("✓   " if id in discoveries else "·    ")+map_name(id)+"\n"
	make_label(p,names,Vector2(661,200),Vector2(419,350),25,PAPER,true).add_theme_constant_override("line_spacing",12)
	make_button(p,"Open your pack",Vector2(82,604),Vector2(426,42),open_pack)
	make_button(p,"Unfold the town map",Vector2(658,571),Vector2(429,42),toggle_map)
	make_button(p,"Close the journal",Vector2(659,624),Vector2(427,42),close_modal)
	make_label(p,"I",Vector2(286,656),Vector2(30,28),18,MUTED,true)
	make_label(p,"II",Vector2(858,678),Vector2(30,28),18,MUTED,true)

func show_credits() -> void:
	var p := open_modal("A return to Vesper",920,764)
	var text := "A personal nostalgia project by Carl Prewitt Jr. (rages4calm), built with OpenAI Codex assistance. This is a fan tech demo for fun. It will never become a complete game, MMO, or official remake.\n\nVesper and Ultima Online originate with Origin Systems and the original UO creators. Geography references: The Second Age manual, Stratics, UOGuide, and the UO community. This project is not endorsed by or affiliated with EA or its licensors.\n\nCharacters and base animations: Quaternius (CC0). Trees, furnishings, and photographed materials: Poly Haven (CC0). Type: Cormorant Garamond (SIL OFL). Engine: Godot. Asset preparation: Blender. Journal artwork: OpenAI image generation.\n\nThis public download includes original synthesized effects and ambience. Original UO music and extracted effects are not bundled. Choose your own local OGG or WAV in the pause menu. See CREDITS.md for individual asset links and licenses."
	var label := make_label(p,text,Vector2(36,108),Vector2(848,415),19,PAPER)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	make_label(p,"Your controls",Vector2(36,536),Vector2(400,36),29,GOLD,true)
	make_label(p,"WASD / arrows  Move     Shift  Run     Space  Jump     E  Talk / use\nRight-drag  Orbit     Wheel / + / −  Zoom     V  Change camera\nEnter  Say bank / vendor buy / vendor sell     C  Paperdoll     I  Pack\nM  Map     J  Journal     T  Light     H  Hide HUD     F12  Photograph\nF11  Fullscreen     Esc  Pause / close",Vector2(36,580),Vector2(850,120),17)
	make_button(p,"Return",Vector2(36,701),Vector2(848,39),close_modal,true)

func map_name(id: String) -> String:
	return {"mint":"The Mint","museum":"Vesper Museum","inn":"Ironwood Inn","tavern":"The Marsh Hall","boat":"The Majestic Boat","healer":"Healer of Vesper","carpenter":"Hammer and Nail","oven":"The Twisted Oven"}.get(id,buildings.get(id,{}).get("name",id))

func objective_position() -> Vector3:
	var id: String = ["elowen","joiner","shipwright","curator",""][journal_stage]
	for npc in npcs:
		if npc.id == id: return npc.node.position
	return Vector3.ZERO

func update_quest() -> void:
	if not objective_label: return
	objective_title.text = "A parcel across the water" if journal_stage<4 else "A friend of Vesper"
	objective_label.text = ["Speak to Elowen beside the Mint.","Find Tomas at The Hammer and Nail. Collect a cedar case.","Take the case to Maren at The Majestic Boat.","Bring the astrolabe to Aldren inside Vesper Museum.","Delivery complete. The bridges are yours to wander."][journal_stage]
	gold_label.text = "%d gold  ·  %d fish"%[coins,fish]

func toast(text: String) -> void:
	if not notification: return
	notification.text = text
	notification.visible = true
	notification.modulate.a = 1
	notification_time = 4.5

func advance_quest() -> void:
	journal_stage = mini(journal_stage+1,4)
	if journal_stage==4:
		coins += 75
		toast("Delivery complete · 75 gold and the curator’s thanks")
	else:toast(["","Elowen’s letter added to your pack","Cedar case received · Next: The Majestic Boat","Astrolabe packed · Next: Vesper Museum"][journal_stage])
	bell.play()
	update_quest()
	save_journey()

func dialogue(npc: Dictionary) -> void:
	var p := open_modal(npc.name,740,465)
	make_label(p,npc.role+"  ·  "+map_name(npc.building),Vector2(36,85),Vector2(666,27),16,GOLD)
	var text := ""
	var choices: Array = []
	match npc.id:
		"elowen":
			if journal_stage==0:
				text = "You have the look of someone who knows these bridges. The museum is waiting on a mariner’s astrolabe, but I cannot leave the Mint.\n\nTomas at The Hammer and Nail has made a cedar case. Take this letter to him, then ask Maren at The Majestic Boat to pack the instrument. Aldren will receive it at the museum."
				choices.append(["I’ll carry it across the city.",func():advance_quest();close_modal()])
			elif journal_stage<4:text = "One island at a time, traveler. Your journal and town map will show the way. The museum stands on the southernmost civic island."
			else:text = "The curator sent word. The astrolabe has a home again. Thank you for giving a little of your day to Vesper."
		"joiner":
			if journal_stage==1:
				text = "Elowen’s seal! Yes, the cedar case is ready. I shaped the lining to hold the instrument snugly.\n\nFind Maren at The Majestic Boat, across the healer’s island to the east. A wet crossing is no excuse for a damaged astrolabe."
				choices.append(["Take the cedar case",func():advance_quest();close_modal()])
			else:text = "Minoc sends us good timber. We give it a second life: a merchant’s counter, a ship’s ribs, a cradle. Vesper is held together by a great deal more than stone."
		"shipwright":
			if journal_stage==2:
				text = "A fine case. Tomas knows his work. The astrolabe was brought ashore this morning, still smelling of salt.\n\nThere. Well packed. Take it south, past the Youth Hostel and Customs, to the museum. Aldren is waiting inside."
				choices.append(["Pack the astrolabe",func():advance_quest();close_modal()])
			else:text = "The Minoc Wayfarer is making her rounds in the bay. Timber in the hold, a steady hand on the tiller. She will come past again.\n\nWalk out onto our dock. The brass-capped post has a fine view of her and the fishing cutter."
		"curator":
			if journal_stage==3:
				text = "At last. See the wear around the sighting arm? Someone carried this through years of long crossings.\n\nYou have brought us more than an instrument. You have brought us a piece of a life. Please accept seventy-five gold, and the museum’s thanks."
				choices.append(["Deliver the astrolabe",func():advance_quest();close_modal()])
			elif journal_stage==4:text = "Our newest exhibit has a small line beneath it: Carried home by a friend of Vesper.\n\nStay as long as you wish. There is always something else to discover between these canals."
			else:text = "Welcome to Vesper Museum. Our city trades in many things, but memory is what we keep here.\n\nElowen, near the Mint, could use a traveler’s help with an incoming exhibit."
		"innkeeper":
			text = "The Ironwood Inn has a room, a warm fire, and no questions about the mud on your boots. You are welcome to rest a while.\n\nTake your time. Those bridges will still be here tomorrow."
			choices.append(["Rest and recover",func():player.stamina=100;close_modal();toast("Rested at the Ironwood Inn. Stamina restored.")])
		"barkeep":
			text = "A good evening to you. You will hear more about the city in the Marsh Hall than in any council chamber.\n\nBring us fresh fish and I will pay you three gold apiece. The patrons are partial to a good supper."
			if fish>0:choices.append(["Sell %d fish for %d gold"%[fish,fish*3],func():coins+=fish*3;fish=0;play_effect("coins");update_quest();save_journey();close_modal();toast("Fresh fish sold to the Marsh Hall.")])
		"baker":
			text = "Nothing improves a long walk like a loaf from The Twisted Oven. Two gold, fresh this morning.\n\nKeep it in your backpack, and eat it when you need your strength back."
			if coins>=2 and bread<9999:choices.append(["Buy a loaf · 2 gold",func():coins-=2;bread+=1;play_effect("coins");update_quest();save_journey();close_modal();toast("A warm loaf added to your pack.")])
			else:text += "\nYou will need two gold for a loaf."
		"healer":
			text = "The healer’s island is a place to catch your breath. People hurry over these bridges so often that they forget to watch the water.\n\nSit a moment. There is no charge for a little kindness."
			choices.append(["Rest at the healer’s",func():player.stamina=100;close_modal();toast("Your stamina is restored.")])
		"fisherman":
			text = "The trick is patience. Cast from the wharf, wait until the float dips, then press E to strike. Too soon, and you only frighten them. Too late, and they take the bait.\n\nBorrow my spare rod. Garrick at the Marsh Hall buys a fresh catch."
			choices.append(["Cast a line",func():close_modal();start_fishing()])
		"banker":
			text = "The Mint keeps the wheels of Vesper turning. Traders arrive from Minoc by road and from distant ports by sea.\n\nYour purse holds %d gold. Say ‘bank’ when you are near us, and I will open your box."%coins
			choices.append(["Open my bank box",citizen_ui.bank])
		_:text = "The city is quieter at this hour. A good time to walk, and a good time to listen."
	var body := make_label(p,text,Vector2(36,139),Vector2(668,224),21,PAPER,true)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if choices.size()>0:
		make_button(p,choices[0][0],Vector2(36,382),Vector2(514,47),choices[0][1],true).grab_focus()
		make_button(p,"Farewell",Vector2(566,382),Vector2(138,47),close_modal)
	else:make_button(p,"Farewell",Vector2(36,382),Vector2(668,47),close_modal,true).grab_focus()

func interact() -> void:
	if modal_open:return
	if fishing:
		finish_fishing(catch_window)
		return
	if harbor.toggle_watch():return
	if nearby.is_empty() or modal_open: return
	dialogue(nearby)

func start_fishing() -> void:
	play_effect("splash")
	fishing = true
	fishing_clock = 0
	catch_window = false
	bite_time = 2.8 if qa_mode else randf_range(2.4,5.0)
	player.path.clear()
	player.velocity = Vector3.ZERO
	player.model.rotation.y = PI/2
	toast("Line cast. Wait for the float to dip…")
	var line := MeshInstance3D.new()
	line.name = "FishingRod"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = .009
	cylinder.bottom_radius = .028
	cylinder.height = 2.8
	line.mesh = cylinder
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("896d44")
	line.material_override = mat
	line.position = player.position + Vector3(.8,1.5,.1)
	line.rotation.z = -1.0
	add_child(line)
	var float_mesh := MeshInstance3D.new()
	float_mesh.name = "FishingFloat"
	var sphere := SphereMesh.new()
	sphere.radius = .10
	sphere.height = .24
	float_mesh.mesh = sphere
	var float_mat := StandardMaterial3D.new()
	float_mat.albedo_color = Color("edb162")
	float_mat.emission_enabled = true
	float_mat.emission = Color("a86532")
	float_mesh.material_override = float_mat
	float_mesh.position = player.position+Vector3(4,-1.85,0)
	add_child(float_mesh)

func finish_fishing(success: bool) -> void:
	fishing = false
	catch_window = false
	for id in ["FishingRod","FishingFloat"]:
		var obj = get_node_or_null(id)
		if obj: obj.queue_free()
	if success:
		fish+=1
		toast("A fine catch! Fresh fish added to your pack.")
		bell.play()
	else:toast("The fish slipped away. Speak to Corin to try again.")
	update_quest()
	save_journey()

func _unhandled_input(event: InputEvent) -> void:
	if chatting:return
	if event.is_action_pressed("fullscreen"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("screenshot"):
		take_photograph()
		return
	if event.is_action_pressed("pause"):
		if harbor.watching:harbor.toggle_watch()
		elif fishing:finish_fishing(false)
		elif modal_open:close_modal()
		elif playing:show_pause()
		return
	if not playing or modal_open:return
	if harbor.watching and (event.is_action_pressed("move_forward") or event.is_action_pressed("move_back") or event.is_action_pressed("move_left") or event.is_action_pressed("move_right") or event.is_action_pressed("view")):
		harbor.toggle_watch()
	if event.is_action_pressed("speech"):begin_speech();get_viewport().set_input_as_handled();return
	if event.is_action_pressed("paperdoll"):open_paperdoll();return
	if event.is_action_pressed("pack"):open_pack();return
	if event.is_action_pressed("photo"):
		ui_visible = not ui_visible
		hud.visible = ui_visible
	if event.is_action_pressed("town_map"):toggle_map()
	if event.is_action_pressed("journal"):toggle_journal()
	if event.is_action_pressed("interact"):interact()
	if event.is_action_pressed("view"):
		overhead = not overhead
		camera_pitch = .64 if overhead else .35
		camera_target_distance = 29 if overhead else 6.5
		toast("Classic elevated view" if overhead else "Traveler view")
	if event.is_action_pressed("time"):set_time((day_phase+1)%3)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			orbiting = event.pressed
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:change_zoom(.87)
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:change_zoom(1.15)
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not fishing and not harbor.watching:
			var origin := camera.project_ray_origin(event.position)
			var end := origin+camera.project_ray_normal(event.position)*900
			var query := PhysicsRayQueryParameters3D.create(origin,end)
			query.exclude = [player.get_rid()]
			var hit := get_world_3d().direct_space_state.intersect_ray(query)
			if hit and player.go_to(hit.position):
				pointer_marker.position = hit.position+Vector3.UP*.1
				pointer_marker.visible = true
				pointer_time = 2.5
	if event is InputEventMouseMotion and orbiting:
		camera_yaw -= event.relative.x*.005
		camera_pitch = clampf(camera_pitch+event.relative.y*.004,.12,1.25)

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:
		orbiting = false
		if playing and not qa_mode and not modal_open: show_pause()
	if what==NOTIFICATION_WM_CLOSE_REQUEST:quit_demo()

func quit_demo(exit_code: int=0) -> void:
	if quitting:return
	quitting=true
	if playing:save_journey()
	playing=false
	set_process(false)
	set_physics_process(false)
	if player:player.set_physics_process(false)
	if harbor:harbor.set_process(false)
	for node in find_children("*","",true,false):
		if node is AudioStreamPlayer or node is AudioStreamPlayer3D or node is AudioStreamPlayer2D:
			node.stop()
			node.stream=null
	# Let the audio server release all looped playback before shutdown.
	await get_tree().create_timer(.2).timeout
	get_tree().quit(exit_code)

func change_zoom(factor: float) -> void:
	if harbor.watching:
		harbor.watch_fov=clampf(harbor.watch_fov*factor,35,70)
		return
	camera_target_distance=clampf(camera_target_distance*factor,7 if overhead else 3,85 if overhead else 52)

func _process(delta: float) -> void:
	if not camera:return
	elapsed+=delta
	if playing and not modal_open:journey_time+=delta
	if speech_seconds>0:
		speech_seconds-=delta
		speech_bubble.visible=speech_seconds>0
	update_camera(delta)
	update_reflections()
	for i in range(birds.size()):
		var angle: float=elapsed*(.025+i*.001)+i*.73
		birds[i].position=Vector3(30+cos(angle)*(65+i*3),28+sin(angle*2)*3+i*.7,-35+sin(angle)*(88+i*2))
		birds[i].rotation.y=-angle
		for j in range(2): birds[i].get_child(j).rotation.z=(1 if j==0 else -1)*(sin(elapsed*3+i)*.19+.10)
	for npc in npcs:
		update_npc(npc,delta)
	if notification_time>0:
		notification_time-=delta
		notification.modulate.a=minf(notification_time,1)
		if notification_time<=0:notification.visible=false
	if pointer_time>0:
		pointer_time-=delta
		pointer_marker.visible=pointer_time>0
	if fishing and not modal_open:
		fishing_clock+=delta
		catch_window=fishing_clock>=bite_time and fishing_clock<=bite_time+1.7
		var float_mesh = get_node_or_null("FishingFloat")
		if float_mesh: float_mesh.position.y = .12+sin(elapsed*(18 if catch_window else 2))*(.07 if catch_window else .025)
		if fishing_clock>bite_time+1.7:finish_fishing(false)
	tick+=delta
	if tick>.12:
		tick=0
		update_hud()
		update_lights()
	if playing and not modal_open:
		autosave_time+=delta
		if autosave_time>20:
			autosave_time=0
			save_journey()
	if playing and not gull.playing and randf()<delta*.045:
		gull.pitch_scale=randf_range(.9,1.2)
		gull.volume_db=linear_to_db(maxf(ambience_level*.12,.0001))
		gull.play()

func update_camera(delta: float) -> void:
	camera.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	if not playing:
		camera.projection=Camera3D.PROJECTION_PERSPECTIVE
		camera.position=Vector3(-39+sin(elapsed*.025)*6,29,-74+cos(elapsed*.025)*3)
		camera.look_at(Vector3(5,4,-116))
		return
	if harbor.watching:
		harbor.update_camera()
		return
	camera.fov=62
	camera_distance=lerpf(camera_distance,camera_target_distance,1-exp(-delta*7))
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL if overhead else Camera3D.PROJECTION_PERSPECTIVE
	camera.size=camera_distance*.62
	var focus: Vector3=player.get_global_transform_interpolated().origin+Vector3.UP*1.1
	var offset := Vector3(0,sin(camera_pitch)*camera_distance,cos(camera_pitch)*camera_distance).rotated(Vector3.UP,camera_yaw)
	var desired: Vector3=focus+offset
	# Roofs lift away on entering a building; walls and furniture retain collision.
	for b in plan.buildings:
		if roofs.has(b.id):
			var inside: bool=b.enterable and absf(player.position.x-b.pos[0])<b.width/2+.3 and absf(player.position.z-b.pos[1])<b.depth/2+.3
			if building_polygons.has(b.id):inside=Geometry2D.is_point_in_polygon(Vector2(player.position.x,player.position.z),building_polygons[b.id])
			roofs[b.id].visible=not inside
			if facades.has(b.id):facades[b.id].visible=not (inside and overhead)
			if building_details.has(b.id):building_details[b.id].visible=not (inside and overhead)
	var query := PhysicsRayQueryParameters3D.create(focus,desired)
	query.exclude=[player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit and not overhead: desired=hit.position+(focus-hit.position).normalized()*.35
	if not camera_initialized or camera.position.distance_to(desired)>22:
		camera.position=desired
		camera_initialized=true
	else:camera.position=camera.position.lerp(desired,1-exp(-delta*24))
	# A second check keeps the smoothed camera from passing through a wall.
	query.to=camera.position
	var smooth_hit := get_world_3d().direct_space_state.intersect_ray(query)
	if smooth_hit and not overhead:camera.position=smooth_hit.position+(focus-smooth_hit.position).normalized()*.32
	if camera.position.distance_to(focus)>.03:camera.look_at(focus)
	listener.global_rotation.y=camera.global_rotation.y
	player.model.visible=camera.position.distance_to(focus)>1

func _physics_process(delta: float) -> void:
	if not player or not playing:return
	for id in doors:
		var definition: Dictionary=door_definitions[id]
		var door_position:=Vector3(definition.pos[0],definition.pos[1],definition.pos[2])
		var was_open: bool=door_open_states.get(id,false)
		# A wider closing distance prevents boundary jitter and repeated creaks.
		var opened: bool=player.position.distance_to(door_position)<(5.4 if was_open else 4.2)
		if opened!=was_open:
			door_open_states[id]=opened
			if opened:play_door_sound(id,true)
		var previous_angle: float=doors[id].rotation.y
		doors[id].rotation.y=move_toward(doors[id].rotation.y,1.52 if opened else 0.0,delta*4.5)
		if not opened and previous_angle>0.0 and is_zero_approx(doors[id].rotation.y):
			play_door_sound(id,false)

func _exit_tree() -> void:
	# Release the shared-world reflection reference before the scene is destroyed.
	if water_material:water_material.set_shader_parameter("reflection_texture",null)
	if is_instance_valid(reflection_view):reflection_view.world_3d=null

func update_npc(npc: Dictionary,delta: float) -> void:
	if npc.id=="resident":
		var route: PackedVector3Array=npc.route
		if route.size()<2:return
		var node: Node3D=npc.node
		if playing and node.position.distance_to(player.position)<2.1:
			if npc.animation.current_animation!="Idle":npc.animation.play("Idle",.2)
			return
		var point: Vector3=route[npc.route_index]
		point.y=2.04
		var d := point-node.position
		if d.length()<.3:
			npc.route_index += 1 if npc.forward else -1
			if npc.route_index>=route.size():npc.route_index=route.size()-2;npc.forward=false
			if npc.route_index<0:npc.route_index=1;npc.forward=true
		else:
			node.position+=d.normalized()*delta*.85
			npc.body.rotation.y=lerp_angle(npc.body.rotation.y,atan2(d.x,d.z),1-exp(-delta*7))
			if npc.animation.current_animation!="Walk":npc.animation.play("Walk",.2)
	else:
		var near: bool=playing and player.position.distance_to(npc.node.position)<7
		npc.label.visible=near and ui_visible
		if near:
			var d: Vector3=player.position-npc.node.position
			npc.body.rotation.y=lerp_angle(npc.body.rotation.y,atan2(d.x,d.z),1-exp(-delta*2))

func update_reflections() -> void:
	if not reflection_camera:return
	var origin: Vector3=camera.global_position
	var target: Vector3=origin-camera.global_basis.z*30
	origin.y=-origin.y
	target.y=-target.y
	reflection_camera.global_position=origin
	reflection_camera.look_at(target)
	reflection_camera.fov=camera.fov
	reflection_camera.projection=camera.projection
	reflection_camera.size=camera.size
	var matrix: Projection=reflection_camera.get_camera_projection()*Projection(reflection_camera.global_transform.affine_inverse())
	water_material.set_shader_parameter("reflection_matrix",matrix)

func update_hud() -> void:
	if not playing:return
	nearby={}
	var dist:=3.2
	for npc in npcs:
		if npc.id=="resident":continue
		var d: float=player.position.distance_to(npc.node.position)
		if d<dist:nearby=npc;dist=d
	if fishing:
		prompt_label.text="E   Strike!" if catch_window else "Wait for the float to dip…"
		prompt_label.visible=true
	else:
		prompt_label.visible=not nearby.is_empty() and not modal_open and not chatting
		if not nearby.is_empty():prompt_label.text="E   Speak to "+nearby.name
	if not fishing and not modal_open and not chatting and (harbor.watching or harbor.nearby_lookout()>=0):
		prompt_label.visible=true
		prompt_label.text="E   Return to the dock     ·     Wheel to zoom" if harbor.watching else "E   Watch the harbor"
	var nearest_name: String="The canals of Vesper"
	var nearest_distance:=22.0
	for b in plan.buildings:
		var d: float=Vector2(player.position.x-b.pos[0],player.position.z-b.pos[1]).length()
		if d<nearest_distance:nearest_name=b.name;nearest_distance=d
		if b.id in LANDMARKS and d<maxf(b.width,b.depth)*.5+5 and b.id not in discoveries:
			discoveries.append(b.id)
			toast("Discovered · "+b.name)
			save_journey()
	location_label.text=nearest_name
	var heading: float=fposmod(rad_to_deg(camera_yaw),360)
	var direction: String=["N","NW","W","SW","S","SE","E","NE"][int((heading+22.5)/45)%8]
	compass_label.text="—  "+direction+"  —"
	stamina_bar.value=player.stamina
	stamina_bar.visible=player.stamina<99
	controls_hint.visible=journey_time<18
	mini_map.queue_redraw()
	for child in modal.find_children("*","Control",true,false):
		if child.get_script()==MapScript:child.queue_redraw()
	var target:=objective_position()
	objective_marker.visible=false
	if target!=Vector3.ZERO:
		var p: Vector3=target+Vector3.UP*3
		if not camera.is_position_behind(p):
			var screen:=camera.unproject_position(p)
			if screen.x>330 and screen.x<1350 and screen.y>130 and screen.y<700:
				objective_marker.position=screen-Vector2(80,30)
				objective_marker.text="◇  %d m"%int(player.position.distance_to(target))
				objective_marker.visible=true

func update_lights() -> void:
	var pos: Vector3=player.position if playing else camera.position
	var ordered: Array=lamps.duplicate()
	ordered.sort_custom(func(a,b):return a.position.distance_squared_to(pos)<b.position.distance_squared_to(pos))
	for i in range(ordered.size()):
		ordered[i].visible=i<8 and ordered[i].position.distance_to(pos)<55
		if ordered[i].visible:ordered[i].light_energy=(2.4 if day_phase==2 else .65)*(1+sin(elapsed*3+ordered[i].position.x)*.035)

func set_time(value: int) -> void:
	day_phase=posmod(value,3)
	match day_phase:
		0:
			sun.rotation_degrees=Vector3(-32,-42,0)
			sun.light_color=Color("ffe2ac")
			sun.light_energy=1.5
			sky_material.sky_top_color=Color("4d788c")
			sky_material.sky_horizon_color=Color("d6c7ab")
			environment.ambient_light_energy=.85
			environment.tonemap_exposure=1.0
			environment.fog_light_color=Color("8dafa9")
		1:
			sun.rotation_degrees=Vector3(-62,-28,0)
			sun.light_color=Color("fffcf4")
			sun.light_energy=1.55
			sky_material.sky_top_color=Color("4e8da9")
			sky_material.sky_horizon_color=Color("c6d6d1")
			environment.ambient_light_energy=.85
			environment.tonemap_exposure=1.0
			environment.fog_light_color=Color("97b7be")
		2:
			sun.rotation_degrees=Vector3(-44,18,0)
			sun.light_color=Color("9abbe9")
			sun.light_energy=.45
			sky_material.sky_top_color=Color("0a192e")
			sky_material.sky_horizon_color=Color("394957")
			environment.ambient_light_energy=.5
			environment.tonemap_exposure=1.3
			environment.fog_light_color=Color("263849")
	if time_label:time_label.text=["Golden hour","Daylight","Lantern night"][day_phase]
	if playing:save_settings()

func set_quality(high: bool) -> void:
	quality=high
	environment.ssao_enabled=high
	environment.ssil_enabled=false
	environment.ssr_enabled=high
	environment.fog_enabled=false
	environment.volumetric_fog_enabled=false
	sun.directional_shadow_max_distance=170 if high else 90
	get_viewport().scaling_3d_scale=1.0
	if reflection_view:
		reflection_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS if high else SubViewport.UPDATE_DISABLED
		water_material.set_shader_parameter("reflection_strength",.55 if high else 0.0)
	save_settings()

func save_path() -> String:
	if "--qa-route" in OS.get_cmdline_user_args():return "user://qa_route_journey.json"
	return "user://qa_journey.json" if qa_mode else "user://journey.json"

func save_journey() -> void:
	if not playing:return
	var data={"version":SAVE_VERSION,"position":[player.position.x,player.position.y,player.position.z],"quest":journal_stage,"discoveries":discoveries,"coins":coins,"fish":fish,"bread":bread,"camera_yaw":camera_yaw,"camera_pitch":camera_pitch,"camera_distance":camera_target_distance}
	data["bank"]=bank_items
	data["overhead"]=overhead
	data["camera_revision"]=3
	var file=FileAccess.open(save_path()+".tmp",FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data,"  "))
		file.close()
		DirAccess.rename_absolute(save_path()+".tmp",save_path())

func load_journey() -> void:
	if not FileAccess.file_exists(save_path()):return
	var data=JSON.parse_string(FileAccess.get_file_as_string(save_path()))
	if not data is Dictionary or data.get("version",0)!=SAVE_VERSION:return
	journal_stage=clampi(int(data.get("quest",0)),0,4)
	coins=clampi(int(data.get("coins",20)),0,100000)
	fish=clampi(int(data.get("fish",0)),0,9999)
	bread=clampi(int(data.get("bread",0)),0,9999)
	var bank: Dictionary=data.get("bank",{}) if data.get("bank",{}) is Dictionary else {}
	for key in bank_items:bank_items[key]=clampi(int(bank.get(key,0)),0,100000 if key=="coins" else 9999)
	discoveries=[]
	for id in data.get("discoveries",[]):
		if id in LANDMARKS and id not in discoveries:discoveries.append(id)
	var pos=data.get("position",[])
	if pos is Array and pos.size()==3:
		var p:=Vector3(float(pos[0]),float(pos[1]),float(pos[2]))
		if p.is_finite() and is_walkable(Vector2(p.x,p.z),false):player.position=Vector3(p.x,clampf(p.y,2.05,8),p.z)
	if data.get("camera_revision",0)==3:
		camera_yaw=float(data.get("camera_yaw",PI/4))
		camera_pitch=clampf(float(data.get("camera_pitch",.64)),.12,1.25)
		camera_target_distance=clampf(float(data.get("camera_distance",29)),3,85)
		overhead=bool(data.get("overhead",true))
	else:camera_yaw=PI/4;camera_pitch=.64;camera_target_distance=29;overhead=true
	if not is_walkable(Vector2(player.position.x,player.position.z)):
		var safe:=closest_cell(player.position)
		if safe.x!=-999:player.position=Vector3(safe.x,2.15,safe.y)
	player.reset_physics_interpolation()

func save_settings() -> void:
	if qa_mode:return
	var cfg:=ConfigFile.new()
	cfg.set_value("audio","music",music_level)
	cfg.set_value("audio","ambience",ambience_level)
	cfg.set_value("view","time",day_phase)
	cfg.set_value("view","quality",quality)
	cfg.save("user://settings.cfg")

func load_settings() -> void:
	if qa_mode:return
	var cfg:=ConfigFile.new()
	if cfg.load("user://settings.cfg")!=OK:return
	music_level=clampf(float(cfg.get_value("audio","music",.50)),0,1)
	ambience_level=clampf(float(cfg.get_value("audio","ambience",.55)),0,1)
	day_phase=clampi(int(cfg.get_value("view","time",0)),0,2)
	quality=bool(cfg.get_value("view","quality",true))
	music.volume_db=linear_to_db(maxf(music_level,.0001))
	ambience.volume_db=linear_to_db(maxf(ambience_level,.0001))
	set_quality(quality)

func take_photograph(filename: String="") -> void:
	var folder: String=qa_artifacts if qa_mode else OS.get_user_data_dir().path_join("photographs")
	DirAccess.make_dir_recursive_absolute(folder)
	if filename.is_empty():filename="Vesper-"+Time.get_datetime_string_from_system().replace(":","-")+".png"
	await RenderingServer.frame_post_draw
	var image:=get_viewport().get_texture().get_image()
	var path:=folder.path_join(filename)
	var error:=image.save_png(path)
	if error==OK:
		print("PHOTOGRAPH "+path)
		if not qa_mode:toast("Photograph saved to "+folder)
	else:push_error("Could not save photograph: "+str(error))

func qa_assert(condition: bool,message: String) -> void:
	qa_results.append({"pass":condition,"check":message})
	print(("QA PASS " if condition else "QA FAIL ")+message)

func qa_npc(id: String) -> Dictionary:
	for npc in npcs:
		if npc.id==id:return npc
	return {}

func qa_key(key: Key) -> void:
	var event:=InputEventKey.new()
	event.physical_keycode=key
	event.keycode=key
	event.pressed=true
	get_viewport().push_input(event,true)
	await get_tree().process_frame
	event=event.duplicate()
	event.pressed=false
	get_viewport().push_input(event,true)
	await get_tree().process_frame

func run_qa() -> void:
	# Checks run through the shipped movement, interaction, and state code.
	# QA saves use a separate file and never touch the player's journey.
	await get_tree().create_timer(2).timeout
	await take_photograph("01-title.png")
	start_journey(false)
	await get_tree().create_timer(1).timeout
	qa_assert(player.is_on_floor(),"Traveler stands on the imported city collision")
	qa_assert(music.stream==null and ambience.playing,"Public build starts with original ambience and no bundled UO soundtrack")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--qa-music="):
			qa_assert(install_local_music(argument.trim_prefix("--qa-music="),false) and music.playing,"User supplied soundtrack imports and plays")
	qa_assert(not install_local_music("missing-audio-file.ogg",false),"Missing soundtrack is handled without replacing current audio")
	await take_photograph("02-traveler.png")
	var zoom_before:=camera_target_distance
	var wheel:=InputEventMouseButton.new()
	wheel.button_index=MOUSE_BUTTON_WHEEL_UP
	wheel.pressed=true
	wheel.position=Vector2(800,450)
	get_viewport().push_input(wheel,true)
	await get_tree().create_timer(.35).timeout
	qa_assert(camera_target_distance<zoom_before and camera.size<zoom_before*.62,"Mouse wheel zooms the elevated camera in")
	hud.get_node("ZoomOut").pressed.emit()
	await get_tree().create_timer(.35).timeout
	qa_assert(camera_target_distance>zoom_before,"Visible zoom-out control expands the view")
	camera_target_distance=15
	await get_tree().create_timer(.7).timeout
	await take_photograph("13-close-view.png")
	camera_target_distance=62
	await get_tree().create_timer(.9).timeout
	await take_photograph("14-wide-view.png")
	camera_target_distance=36
	var initial: Vector3=player.position
	Input.action_press("move_back")
	await get_tree().create_timer(.8).timeout
	Input.action_release("move_back")
	qa_assert(player.position.distance_to(initial)>1.5,"WASD moves the physical character")
	# Verify reachability of every destination from the initial town square.
	for npc in npcs:
		if npc.id=="resident":continue
		qa_assert(find_route(initial,npc.node.position).size()>0,"Route to "+npc.name+" at "+map_name(npc.building))
	# Walk an actual bridge end to end under physics, not a teleport to success.
	var bridge: Dictionary=plan.bridges[6]
	player.position=Vector3(bridge.a[0],2.3,bridge.a[1]+1)
	player.velocity=Vector3.ZERO
	player.last_safe=player.position
	var goal:=Vector3(bridge.b[0],2,bridge.b[1]-1)
	player.go_to(goal)
	var t:=0.0
	while player.path.size()>0 and t<15:
		await get_tree().create_timer(.1).timeout
		t+=.1
	qa_assert(Vector2(player.position.x-goal.x,player.position.z-goal.z).length()<2,"Click-to-walk crosses an arched stone bridge")
	await take_photograph("03-bridge.png")
	# Dialogue UI and canonical quest transitions; travel was checked separately.
	for id in ["elowen","joiner","shipwright","curator"]:
		var npc:=qa_npc(id)
		player.position=npc.node.position+Vector3(0,.1,1.2)
		player.velocity=Vector3.ZERO
		player.path.clear()
		await get_tree().create_timer(.35).timeout
		update_hud()
		interact()
		qa_assert(modal_open,"Dialogue opens for "+npc.name)
		if id=="elowen":await take_photograph("04-dialogue.png")
		var action_buttons=modal.find_children("*","Button",true,false)
		if action_buttons.size()>1:action_buttons[1].pressed.emit()
		await get_tree().process_frame
	qa_assert(journal_stage==4 and coins==95,"Full delivery quest awards 75 gold exactly once")
	await take_photograph("05-museum.png")
	var fisherman:=qa_npc("fisherman")
	player.position=fisherman.node.position+Vector3(0,.2,1)
	player.velocity=Vector3.ZERO
	start_fishing()
	await get_tree().create_timer(3.1).timeout
	qa_assert(catch_window,"Fishing presents the timed bite window")
	interact()
	qa_assert(fish==1 and not fishing,"A timely strike adds a fish to the pack")
	var saved_coins:=coins
	save_journey()
	coins=0
	journal_stage=0
	load_journey()
	qa_assert(coins==saved_coins and journal_stage==4 and fish==1,"Save and reload preserve inventory and quest completion")
	qa_assert(player.animation.has_animation("Jog_Fwd") and player.animation.has_animation("Idle"),"Rigged ranger has idle and locomotion animations")
	qa_assert(npcs.all(func(npc):return npc.animation!=null and npc.animation.has_animation("Idle") and npc.animation.has_animation("Walk")),"Every townsperson has rigged idle and walking animations")
	toggle_journal()
	await get_tree().create_timer(.3).timeout
	await take_photograph("09-journal.png")
	close_modal()
	await get_tree().process_frame
	await qa_key(KEY_C)
	qa_assert(modal_open and modal.find_child("PaperdollBackpack",true,false)!=null,"C opens the paperdoll through the input system")
	await get_tree().create_timer(.5).timeout
	await take_photograph("10-paperdoll.png")
	var paper_pack=modal.find_child("PaperdollBackpack",true,false)
	if paper_pack:
		var double_click:=InputEventMouseButton.new()
		double_click.position=paper_pack.get_global_rect().get_center()
		double_click.button_index=MOUSE_BUTTON_LEFT
		double_click.pressed=true
		double_click.double_click=true
		get_viewport().push_input(double_click,true)
		await get_tree().process_frame
		qa_assert(modal.find_children("*","Label",true,false).any(func(l):return l.text=="Your backpack"),"Double-clicking the paperdoll backpack opens inventory")
		await take_photograph("15-backpack.png")
	close_modal()
	var mint: Dictionary=buildings.mint
	player.position=Vector3(mint.pos[0],2.12,mint.pos[1]+mint.depth/2+3)
	player.reset_physics_interpolation()
	await get_tree().process_frame
	await qa_key(KEY_ENTER)
	qa_assert(chatting and speech_line.has_focus(),"Enter focuses the speech entry")
	speech_line.text="bank"
	await qa_key(KEY_ENTER)
	await get_tree().process_frame
	qa_assert(modal_open,"Spoken bank opens a bank box from outside the Mint")
	var before_deposit:=coins
	citizen_ui.transfer("coins",true)
	qa_assert(coins==0 and bank_items.coins==before_deposit,"Bank deposit conserves gold")
	citizen_ui.transfer("fish",true)
	save_journey()
	bank_items={"coins":0,"fish":0,"bread":0}
	load_journey()
	qa_assert(bank_items.coins==before_deposit and bank_items.fish==1,"Bank contents survive saving and loading")
	citizen_ui.show_bank()
	await get_tree().create_timer(.2).timeout
	await take_photograph("11-bank.png")
	citizen_ui.transfer("coins",false)
	citizen_ui.transfer("fish",false)
	qa_assert(coins==before_deposit and fish==1 and bank_items.coins==0,"Bank withdrawal conserves gold and items")
	close_modal()
	player.position=Vector3(mint.pos[0]+6,2.12,mint.pos[1]+8)
	player.reset_physics_interpolation()
	camera_target_distance=49
	camera_pitch=.72
	camera_yaw=PI/4
	await get_tree().create_timer(1).timeout
	await take_photograph("16-mint-exterior.png")
	player.position=qa_npc("banker").node.position+Vector3(0,.1,1)
	player.reset_physics_interpolation()
	camera_target_distance=38
	await get_tree().create_timer(1).timeout
	qa_assert(not roofs.mint.visible,"The L-shaped Mint roof lifts while inside")
	citizen_ui.speech("bank")
	qa_assert(modal_open,"Bank command also works inside the L-shaped Mint")
	close_modal()
	await take_photograph("17-mint-interior.png")
	player.position=Vector3(mint.pos[0]+6,2.12,mint.pos[1]+6)
	player.reset_physics_interpolation()
	player.model.rotation.y=PI/4
	overhead=false
	camera_pitch=.23
	camera_target_distance=4.8
	hud.visible=false
	ui_visible=false
	speech_seconds=0
	speech_bubble.visible=false
	await get_tree().create_timer(1).timeout
	await take_photograph("18-world-ranger.png")
	hud.visible=true
	ui_visible=true
	overhead=true
	camera_pitch=.64
	camera_target_distance=29
	player.position=qa_npc("baker").node.position+Vector3(0,.1,2)
	player.reset_physics_interpolation()
	citizen_ui.speech("vendor buy")
	await get_tree().process_frame
	var buy_buttons=modal.find_children("*","Button",true,false)
	if buy_buttons.size()>1:buy_buttons[1].pressed.emit()
	qa_assert(bread==1 and coins==before_deposit-2,"Vendor buy purchases bread for two gold")
	await get_tree().process_frame
	await take_photograph("12-vendor.png")
	close_modal()
	player.position=qa_npc("barkeep").node.position+Vector3(0,.1,2)
	player.reset_physics_interpolation()
	citizen_ui.speech("vendor sell")
	await get_tree().process_frame
	var sell_buttons=modal.find_children("*","Button",true,false)
	if sell_buttons.size()>1:sell_buttons[1].pressed.emit()
	qa_assert(fish==0 and coins==before_deposit+1,"Vendor sell pays three gold for the fish")
	close_modal()
	player.position=qa_npc("fisherman").node.position+Vector3(0,.1,1)
	player.reset_physics_interpolation()
	citizen_ui.speech("bank")
	qa_assert(not modal_open,"Bank command refuses a distant request")
	toggle_map()
	await get_tree().create_timer(.4).timeout
	await take_photograph("06-map.png")
	close_modal()
	player.position=Vector3(-6.7,2.1,-112.5)
	camera_pitch=.74
	camera_target_distance=35
	camera_yaw=.75
	await get_tree().create_timer(1).timeout
	await take_photograph("07-city.png")
	set_time(2)
	await get_tree().create_timer(1).timeout
	await take_photograph("08-night.png")
	var report=FileAccess.open(qa_artifacts.path_join("qa-report.json"),FileAccess.WRITE)
	if report:report.store_string(JSON.stringify(qa_results,"  "));report.close()
	var failures: int=qa_results.filter(func(r):return not r.pass).size()
	print("QA_COMPLETE failures="+str(failures))
	print("QA_RENDER fps="+str(Engine.get_frames_per_second()))
	await quit_demo(1 if failures else 0)

func run_route_qa() -> void:
	await get_tree().create_timer(.5).timeout
	start_journey(false)
	music.volume_db=-80
	ambience.volume_db=-80
	Input.action_press("sprint")
	var destinations=["elowen","banker","joiner","shipwright","curator","fisherman","barkeep","innkeeper","baker"]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-route-from="):
			var index:=destinations.find(arg.trim_prefix("--qa-route-from="))
			if index>0:
				player.position=qa_npc(destinations[index-1]).node.position+Vector3(0,.12,1)
				player.reset_physics_interpolation()
				destinations=destinations.slice(index)
	for id in destinations:
		var target: Vector3=qa_npc(id).node.position
		player.go_to(target)
		var time:=0.0
		var stalled:=0.0
		var last: Vector3=player.position
		while player.position.distance_to(target)>2.6 and time<110 and stalled<4:
			player.stamina=100
			await get_tree().create_timer(.2).timeout
			time+=.2
			stalled=stalled+.2 if last.distance_to(player.position)<.09 else 0.0
			last=player.position
		var passed: bool=player.position.distance_to(target)<2.6
		qa_assert(passed,"Physical journey to "+id+" in %.1fs"%time)
		if not passed:
			print("QA_ROUTE_BLOCKED at "+str(player.position)+" target "+str(target)+" path "+str(player.path.slice(0,6)))
			for i in range(player.get_slide_collision_count()):
				var collision=player.get_slide_collision(i)
				print("QA_COLLIDER "+str(collision.get_collider().get_path())+" normal "+str(collision.get_normal()))
			if DisplayServer.get_name()!="headless":await take_photograph("route-blocked-"+id+".png")
			break
		player.path.clear()
	Input.action_release("sprint")
	var report=FileAccess.open(qa_artifacts.path_join("route-report.json"),FileAccess.WRITE)
	if report:report.store_string(JSON.stringify(qa_results,"  "));report.close()
	var failures: int=qa_results.filter(func(r):return not r.pass).size()
	print("QA_ROUTES_COMPLETE failures="+str(failures))
	await quit_demo(1 if failures else 0)
