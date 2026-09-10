extends SceneTree

# Controlled render comparisons. Run with -- --qa-diagnostic for save isolation.
func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await create_timer(2).timeout
	game.start_journey(false)
	await create_timer(.5).timeout
	game.set_process(false)
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	game.ui.visible=false
	game.player.visible=false
	for npc in game.npcs:npc.node.visible=false
	game.music.stop()
	game.ambience.stop()
	game.camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	game.camera.size=32
	game.camera.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	var b: Dictionary=game.buildings.magic
	var focus:=Vector3(b.pos[0],5,b.pos[1])
	var offset:=Vector3(0,sin(.64)*48,cos(.64)*48).rotated(Vector3.UP,PI/4)
	var meshes=game.city.find_children("*","MeshInstance3D",true,false)
	var variants: Array[String]=["baseline","no-shadows","no-ssao","no-lod","no-normal","clear-air"]
	for variant in variants:
		game.sun.shadow_enabled=variant!="no-shadows"
		game.environment.ssao_enabled=variant!="no-ssao"
		game.environment.fog_enabled=variant!="clear-air"
		game.environment.volumetric_fog_enabled=variant!="clear-air"
		for mesh in meshes:
			mesh.lod_bias=100000.0 if variant=="no-lod" else 1.0
			for surface in range(mesh.mesh.get_surface_count()):
				var mat=mesh.get_active_material(surface)
				if mat is BaseMaterial3D:mat.normal_scale=0 if variant=="no-normal" else .55
		for step in range(2):
			var shift:=Vector3(step*.12,0,0)
			game.camera.position=focus+offset+shift
			game.camera.look_at(focus+shift)
			await create_timer(.3).timeout
			await game.take_photograph("render-"+variant+"-"+str(step)+".png")
	print("RENDER_DIAGNOSTICS_COMPLETE")
	quit()
