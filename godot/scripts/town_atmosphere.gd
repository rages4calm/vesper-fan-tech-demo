extends Node3D

var game
var windows: Array[BaseMaterial3D]=[]
var dressed_sites: Array[String]=[]
var weathered_surfaces:=0
var interior_lamps: Array[OmniLight3D]=[]

func setup(owner_game) -> void:
	game=owner_game
	name="TownAtmosphere"
	var shader=load("res://shaders/weathered_surface.gdshader")
	var surfaces={
		"Weathered plaster":[Color("b5a68a"),.22,.40],
		"Quarried sandstone":[Color("aaa895"),.17,.32],
		"Mint masonry":[Color("a09e90"),.14,.30],
		"Old oak":[Color("857057"),.18,.19],
		"Clay tiles":[Color("9c7d68"),.18,.0],
		"Slate tiles":[Color("829397"),.19,.0],
		"Canal paving":[Color("76796e"),.17,.0],
		"Grass":[Color("929c70"),.30,.0]
	}
	var cache: Dictionary={}
	for node in game.city.find_children("*","MeshInstance3D",true,false):
		for i in node.mesh.get_surface_count():
			var original=node.get_active_material(i)
			if not original is BaseMaterial3D:continue
			var id: String=original.resource_name
			if id=="Window light":
				if original not in windows:windows.append(original)
			if not surfaces.has(id):continue
			var key: String=id+str(node.name) if id=="Weathered plaster" else id
			if not cache.has(key):
				var spec: Array=surfaces[id]
				var mat:=ShaderMaterial.new()
				mat.resource_name="Weathered · "+id;mat.shader=shader
				mat.set_shader_parameter("base_map",original.albedo_texture)
				mat.set_shader_parameter("normal_map",original.normal_texture)
				mat.set_shader_parameter("roughness_map",original.roughness_texture)
				var color: Color=spec[0]
				if id=="Weathered plaster":
					var weight: float=float(posmod(str(node.name).hash(),5))*.025
					color=color.lerp(Color("aca693"),weight*3.0)
				mat.set_shader_parameter("tint",color)
				mat.set_shader_parameter("variation",spec[1])
				mat.set_shader_parameter("damp_strength",spec[2])
				mat.set_shader_parameter("seed",float(posmod(str(node.name).hash(),61)))
				mat.set_shader_parameter("relief",.32 if id=="Grass" else .42)
				cache[key]=mat
			node.set_surface_override_material(i,cache[key]);weathered_surfaces+=1
	add_trade_dressing()

func add_trade_dressing() -> void:
	var manifest_path: String="res://art/trade_dressing.json"
	if not FileAccess.file_exists(manifest_path):return
	var entries: Array=JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	for entry in entries:
		var model: Node3D=load("res://art/"+str(entry.asset)+".glb").instantiate()
		model.name=entry.id
		model.position=Vector3(entry.position[0],entry.position[1],entry.position[2])
		model.rotation.y=entry.get("yaw",0.0)
		add_child(model);dressed_sites.append(entry.id)
		for item in model.find_children("*","MeshInstance3D",true,false):
			item.lod_bias=100000.0
			for index in item.mesh.get_surface_count():
				var material=item.get_active_material(index)
				if material is BaseMaterial3D:
					material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		for obstacle in entry.get("obstacles",[]):
			var center:=Vector3(obstacle[0],obstacle[1],obstacle[2]).rotated(Vector3.UP,model.rotation.y)+model.position
			var size:=Vector3(obstacle[3],obstacle[4],obstacle[5])
			var body:=StaticBody3D.new()
			var collision:=CollisionShape3D.new()
			var shape:=BoxShape3D.new();shape.size=size
			collision.shape=shape;body.add_child(collision)
			body.position=center;body.rotation.y=model.rotation.y
			add_child(body)
			var w: float=absf(cos(model.rotation.y))*size.x+absf(sin(model.rotation.y))*size.z
			var d: float=absf(sin(model.rotation.y))*size.x+absf(cos(model.rotation.y))*size.z
			game.plan.obstacles.append({"x":center.x,"z":center.z,"w":w,"d":d})

func set_time(phase: int) -> void:
	for material in windows:
		material.albedo_color=Color("64533c") if phase==1 else Color("bd914e")
		material.emission_energy_multiplier=.08 if phase==1 else (.36 if phase==0 else 1.1)

func finish_town() -> void:
	# Clothing uses quiet natural dye colours. Skin, eyes and hair remain unchanged.
	var palette: Array[Color]=[Color("a6aa91"),Color("aaa08b"),Color("879a9c"),Color("a39685"),Color("9a8790"),Color("b1a894")]
	for index in game.npcs.size():
		var npc: Dictionary=game.npcs[index]
		for mesh in npc.body.find_children("*","MeshInstance3D",true,false):
			for surface in mesh.mesh.get_surface_count():
				var current=mesh.get_active_material(surface)
				if current is BaseMaterial3D and "peasant" in current.resource_name.to_lower():
					var mat=current.duplicate()
					mat.albedo_color=palette[index%palette.size()]
					mat.roughness=.95;mat.metallic_specular=.12
					mesh.set_surface_override_material(surface,mat)
	# Warm localized interior light, capped by the existing nearest-lamp budget.
	for id in ["tavern","inn","boat","fisher","mint","museum"]:
		var b: Dictionary=game.buildings[id]
		var lamp:=OmniLight3D.new()
		lamp.position=Vector3(b.pos[0],4.7,b.pos[1]-b.depth*.25)
		lamp.light_color=Color("ffc476");lamp.omni_range=8.0
		lamp.omni_attenuation=1.3
		lamp.set_meta("interior",true)
		add_child(lamp);game.lamps.append(lamp);interior_lamps.append(lamp)
		# Visible suspended lantern, not an unexplained glowing room.
		var metal:=StandardMaterial3D.new();metal.albedo_color=Color("342c20");metal.metallic=.4;metal.roughness=.7
		var flame:=StandardMaterial3D.new();flame.albedo_color=Color("c98e3f");flame.emission_enabled=true;flame.emission=Color("ffb349");flame.emission_energy_multiplier=1.0
		for offset in [-.27,.27]:
			var cap:=MeshInstance3D.new();var shape:=CylinderMesh.new();shape.top_radius=.20;shape.bottom_radius=.23;shape.height=.07
			cap.mesh=shape;cap.material_override=metal;cap.position=lamp.position+Vector3.UP*offset;cap.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(cap)
		var core:=MeshInstance3D.new();var glass:=CylinderMesh.new();glass.top_radius=.13;glass.bottom_radius=.13;glass.height=.48
		core.mesh=glass;core.material_override=flame;core.position=lamp.position;core.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(core)
		var chain:=MeshInstance3D.new();var link:=CylinderMesh.new();link.top_radius=.018;link.bottom_radius=.018;link.height=2+b.height-lamp.position.y-.30
		chain.mesh=link;chain.material_override=metal;chain.position=lamp.position+Vector3.UP*(.30+link.height/2.0);chain.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(chain)
