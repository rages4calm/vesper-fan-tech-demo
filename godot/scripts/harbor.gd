extends Node3D

var game: Node3D
var plan: Dictionary
var vessels: Array[Dictionary]=[]
var fishers: Array[Dictionary]=[]
var clock:=0.0
var watching:=false
var watch_id:=0
var watch_fov:=56.0
var line_material: StandardMaterial3D
var marker_labels: Array[Label3D]=[]
var lanterns: Array[OmniLight3D]=[]

func setup(owner_game: Node3D) -> void:
	game=owner_game
	physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	plan=JSON.parse_string(FileAccess.get_file_as_string("res://assets/harbor_plan.json"))
	line_material=StandardMaterial3D.new()
	line_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	line_material.albedo_color=Color("bfb798")
	var fisher_scene=load("res://assets/harbor/fisherman.glb")
	var mate_scene=load("res://assets/citizen-male.glb")
	var female_scene=load("res://assets/citizen-female.glb")
	for data in plan.vessels:
		var pivot:=Node3D.new()
		pivot.name=data.id
		add_child(pivot)
		var model: Node3D=load("res://assets/harbor/"+data.model).instantiate()
		pivot.add_child(model)
		for mesh in model.find_children("*","MeshInstance3D",true,false):
			mesh.lod_bias=100000.0
			for surface in range(mesh.mesh.get_surface_count()):
				var original=mesh.mesh.surface_get_material(surface)
				if not original:continue
				if mesh.name.begins_with("Sail_"):
					var sail:=ShaderMaterial.new()
					sail.shader=load("res://shaders/harbor_sail.gdshader")
					sail.set_shader_parameter("weave",load("res://assets/materials/fabric_pattern_07_diff.jpg"))
					sail.set_shader_parameter("cloth_color",Color("873f2e") if "Pennant" in mesh.name else Color("d1c6a2"))
					mesh.set_surface_override_material(surface,sail)
				elif original.resource_name in ["Hull timber","Tarred timber","Indigo paint","Ochre paint","Brightwork"]:
					var wood:=ShaderMaterial.new()
					wood.shader=load("res://shaders/harbor_wood.gdshader")
					wood.set_shader_parameter("grain",original.albedo_texture)
					wood.set_shader_parameter("grain_normal",original.normal_texture)
					var colors: Dictionary={"Hull timber":Color("8e7657"),"Tarred timber":Color("303b3b"),"Indigo paint":Color("315962"),"Ochre paint":Color("986035"),"Brightwork":Color("725337")}
					wood.set_shader_parameter("timber_color",colors[original.resource_name])
					mesh.set_surface_override_material(surface,wood)
				else:
					var mat: StandardMaterial3D=original.duplicate()
					mat.cull_mode=BaseMaterial3D.CULL_DISABLED
					mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
					mat.normal_scale=.38
					mesh.set_surface_override_material(surface,mat)
		var vessel: Dictionary={"data":data,"node":pivot,"wake":null}
		if not data.anchored:vessel.wake=make_wake(pivot,data.length*.35,data.beam)
		vessels.append(vessel)
		for crew in data.crew:
			var body: Node3D=(fisher_scene if crew.role=="angler" else (female_scene if crew.role=="mate" and data.id!="tern" else mate_scene)).instantiate()
			body.position=Vector3(crew.pos[0],crew.pos[1],crew.pos[2])
			body.rotation.y=crew.yaw
			pivot.add_child(body)
			if crew.role=="angler":
				var hair_colors: Array[Color]=[Color("c5ad89"),Color("735a40"),Color("40352e")]
				for mesh in body.find_children("*","MeshInstance3D",true,false):
					for surface in range(mesh.mesh.get_surface_count()):
						var source=mesh.mesh.surface_get_material(surface)
						if source is StandardMaterial3D and source.albedo_texture and "Hair" in source.albedo_texture.resource_path:
							var hair: StandardMaterial3D=source.duplicate();hair.albedo_color=hair_colors[fishers.size()%3]
							mesh.set_surface_override_material(surface,hair)
			var anim: AnimationPlayer=body.find_child("AnimationPlayer",true,false)
			if crew.role=="angler":
				anim.play("Fishing_Work")
				anim.pause()
				var string_mesh:=MeshInstance3D.new()
				string_mesh.mesh=ImmediateMesh.new()
				string_mesh.material_override=line_material
				string_mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				add_child(string_mesh)
				var bobber:=sphere(.07,Color("c88045"));add_child(bobber)
				var catch_model: Node3D=load("res://assets/harbor/fresh_catch.glb").instantiate()
				add_child(catch_model)
				var splash:=AudioStreamPlayer3D.new()
				splash.stream=load("res://assets/audio/demo-splash.wav")
				splash.unit_size=3;splash.max_distance=28
				add_child(splash)
				fishers.append({"body":body,"animation":anim,"tip":body.find_child("RodTip",true,false),"line":string_mesh,"bobber":bobber,"fish":catch_model,"phase":crew.phase,"last_cycle":-1,"splash":splash})
			elif anim:
				anim.get_animation("Idle").loop_mode=Animation.LOOP_LINEAR
				anim.play("Idle")
		# Three unshadowed local lanterns supplement the eight capped street lights.
		var lamp:=OmniLight3D.new()
		lamp.position=Vector3(-data.beam*.30,data.deck+.65,data.length*.28)
		lamp.light_color=Color("ffbd6a");lamp.omni_range=4.5;lamp.light_energy=.8
		pivot.add_child(lamp)
		lanterns.append(lamp)
		var nameplate:=Label3D.new()
		nameplate.text=data.name.to_upper();nameplate.font_size=40;nameplate.pixel_size=.0035 if data.anchored else .005
		nameplate.position=Vector3(0,data.deck-.15,(7.8 if data.id=="tern" else (10.4 if data.id=="wren" else 17.0))*.5+.055)
		nameplate.modulate=Color("ddd0a5");nameplate.outline_size=0;nameplate.no_depth_test=false;nameplate.shaded=true;nameplate.double_sided=false
		pivot.add_child(nameplate)
	for lookout in plan.lookouts:
		var post:=MeshInstance3D.new()
		var mesh:=CylinderMesh.new();mesh.top_radius=.10;mesh.bottom_radius=.13;mesh.height=.95
		post.mesh=mesh;post.position=Vector3(lookout.pos[0]+1.5,2.47,lookout.pos[2])
		var mat:=StandardMaterial3D.new();mat.albedo_color=Color("55472e");post.material_override=mat
		add_child(post)
		var cap:=sphere(.14,Color("b99b56"));cap.position=post.position+Vector3.UP*.52;add_child(cap)
		var label:=Label3D.new();label.text="Watch the harbor";label.font_size=28;label.pixel_size=.005
		label.position=post.position+Vector3.UP*1.0;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.modulate=Color("e6d7b4");label.visible=false
		add_child(label);marker_labels.append(label)
	update_world(0)

func sphere(radius: float,color: Color) -> MeshInstance3D:
	var node:=MeshInstance3D.new();var mesh:=SphereMesh.new();mesh.radius=radius;mesh.height=radius*2;mesh.radial_segments=12;mesh.rings=6
	node.mesh=mesh;var mat:=StandardMaterial3D.new();mat.albedo_color=color;mat.roughness=.65;node.material_override=mat
	return node

func make_wake(parent: Node3D,stern: float,beam: float) -> GPUParticles3D:
	var wake:=GPUParticles3D.new();wake.name="SternWake";wake.amount=90;wake.lifetime=5;wake.local_coords=false
	wake.position=Vector3(0,.12,stern);wake.visibility_aabb=AABB(Vector3(-20,-5,-30),Vector3(40,10,60))
	var process:=ParticleProcessMaterial.new();process.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_BOX;process.emission_box_extents=Vector3(beam*.32,.01,.15)
	process.direction=Vector3(0,0,1);process.spread=20;process.initial_velocity_min=.2;process.initial_velocity_max=.65;process.gravity=Vector3.ZERO
	process.scale_min=.45;process.scale_max=1.1
	var gradient:=Gradient.new();gradient.set_color(0,Color(1,1,1,.8));gradient.set_color(1,Color(1,1,1,0))
	var ramp:=GradientTexture1D.new();ramp.gradient=gradient;process.color_ramp=ramp;wake.process_material=process
	var quad:=PlaneMesh.new();quad.size=Vector2(1.3,1.8)
	var material:=ShaderMaterial.new();material.shader=load("res://shaders/harbor_foam.gdshader");quad.material=material
	wake.draw_pass_1=quad;wake.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(wake);return wake

func pose_at(data: Dictionary,time: float) -> Dictionary:
	var a: float=time/float(data.period)*TAU+data.phase
	var p:=Vector3(data.center[0]+data.radii[0]*cos(a),0,data.center[1]+data.radii[1]*sin(a))
	var yaw: float=data.yaw+.025*sin(a) if data.anchored else atan2(data.radii[0]*sin(a),-data.radii[1]*cos(a))
	return {"position":p,"yaw":yaw}

func _process(delta: float) -> void:
	clock+=delta
	update_world(clock)
	for lamp in lanterns:
		lamp.light_energy=.95 if game.day_phase==2 else .16
	for i in range(marker_labels.size()):
		marker_labels[i].visible=game.playing and game.ui_visible and not watching and game.player.position.distance_to(Vector3(plan.lookouts[i].pos[0],2,plan.lookouts[i].pos[2]))<8

func update_world(time: float) -> void:
	for vessel in vessels:
		var pose:=pose_at(vessel.data,time)
		vessel.node.position=pose.position+Vector3.UP*(sin(time*.70+vessel.data.phase)*.045)
		vessel.node.rotation=Vector3(sin(time*.46+vessel.data.phase)*.006,pose.yaw,sin(time*.62+vessel.data.phase)*.011)
	for fisher in fishers:
		var t: float=fposmod(time+fisher.phase,24.0)
		fisher.animation.seek(t,true)
		var tip: Vector3=fisher.tip.global_position
		var target: Vector3=fisher.body.to_global(Vector3(0,0,3.65));target.y=.13+sin(time*2.2)*.035
		if t<2.3:
			target=tip+Vector3(0,-.60,0)
		elif t<3.2:
			var u: float=(t-2.3)/.9
			target=(tip+Vector3(0,-.60,0)).lerp(target,u)+Vector3.UP*sin(u*PI)*.7
		elif t>17.0:
			var haul: float=smoothstep(17.0,20.5,t)*(1.0-smoothstep(22.0,24.0,t))
			target=target.lerp(tip+Vector3(0,-.75,0),haul)
		fisher.bobber.global_position=target
		fisher.bobber.visible=t<17.5 or t>22.0
		fisher.fish.visible=t>18.0 and t<22.0
		fisher.fish.global_position=target-Vector3.UP*.27
		fisher.fish.rotation=Vector3(PI/2,0,sin(time*11)*.12)
		var mesh: ImmediateMesh=fisher.line.mesh
		mesh.clear_surfaces();mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for i in range(15):
			var u: float=i/14.0
			var point: Vector3=tip.lerp(target,u)-Vector3.UP*sin(u*PI)*(.08 if t>15 else .18)
			mesh.surface_add_vertex(point)
		mesh.surface_end()
		var cycle: int=int(floor((time+fisher.phase-3.2)/24.0))
		if cycle!=fisher.last_cycle:
			if fisher.last_cycle>=0 and game.playing:
				fisher.splash.global_position=target;fisher.splash.volume_db=linear_to_db(maxf(game.ambience_level*.30,.0001));fisher.splash.play()
			fisher.last_cycle=cycle

func nearby_lookout() -> int:
	for i in range(plan.lookouts.size()):
		var p=plan.lookouts[i].pos
		if game.player.position.distance_to(Vector3(p[0],p[1],p[2]))<2.8:return i
	return -1

func toggle_watch() -> bool:
	if watching:watching=false;game.camera_initialized=false;return true
	var nearby:=nearby_lookout()
	if nearby<0:return false
	watch_id=nearby;watching=true;watch_fov=56
	game.player.path.clear();game.player.velocity=Vector3.ZERO
	return true

func update_camera() -> void:
	var view: Dictionary=plan.lookouts[watch_id]
	game.camera.projection=Camera3D.PROJECTION_PERSPECTIVE;game.camera.fov=watch_fov
	game.camera.position=Vector3(view.pos[0],view.pos[1]+2.1,view.pos[2])
	game.camera.look_at(Vector3(view.focus[0],view.focus[1],view.focus[2]))
	game.listener.global_rotation.y=game.camera.global_rotation.y
