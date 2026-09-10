extends RefCounted

# Pan by exact screen pixels so images can be registered and compared for flicker.
var tree: SceneTree
var root: Window

func create_timer(seconds: float) -> SceneTreeTimer:
	return tree.create_timer(seconds)

func run(game) -> void:
	tree=game.get_tree()
	root=tree.root
	await create_timer(2).timeout
	game.start_journey(false)
	await create_timer(.5).timeout
	game.set_process(false)
	game.harbor.set_process(false)
	game.player.set_physics_process(false)
	game.ui.visible=false
	game.player.visible=false
	game.music.stop()
	game.ambience.stop()
	for npc in game.npcs:npc.node.visible=false
	for particle in game.smoke:particle.emitting=false
	var sound_events: Array=[]
	game.door_sound_started.connect(func(id,opened):sound_events.append([id,opened]))
	for id in game.doors:
		var definition: Dictionary=game.door_definitions[id]
		var door_position:=Vector3(definition.pos[0],definition.pos[1],definition.pos[2])
		var yaw: float=definition.get("yaw",0.0)
		var outward:=Vector3(sin(yaw),0,cos(yaw))
		game.player.position=door_position+outward*7
		game.player.reset_physics_interpolation()
		await create_timer(.7).timeout
		sound_events.clear()
		game.player.position=door_position+outward*3.8
		game.player.reset_physics_interpolation()
		await create_timer(.4).timeout
		game.qa_assert(game.door_open_states[id] and game.doors[id].rotation.y>1.4,"Door opens on approach: "+id)
		game.qa_assert(sound_events.count([id,true])==1 and game.door_audio[id].playing,"Original opening audio plays once: "+id)
		for distance in [4.1,4.3,4.1,4.3]:
			game.player.position=door_position+outward*distance
			game.player.reset_physics_interpolation()
			await create_timer(.08).timeout
		game.qa_assert(game.door_open_states[id] and sound_events.count([id,true])==1 and sound_events.count([id,false])==0,"Door stays open without repeated audio at boundary: "+id)
		game.player.position=door_position+outward*6
		game.player.reset_physics_interpolation()
		await create_timer(.6).timeout
		game.qa_assert(not game.door_open_states[id] and is_zero_approx(game.doors[id].rotation.y) and sound_events.count([id,false])==1 and game.door_audio[id].playing,"Door shuts and plays original closing audio once: "+id)
	game.set_physics_process(false)
	for high in [false,true]:
		game.set_quality(high)
		for phase in range(3):
			game.set_time(phase)
			game.qa_assert(not game.environment.fog_enabled and not game.environment.volumetric_fog_enabled,"Clear air in lighting mode %d, quality %s"%[phase,str(high)])
	game.set_time(0)
	game.camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	game.camera.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	game.player.position=Vector3(0,2,0)
	var records: Array=[]
	for id in ["magic","tavern","healer","mint"]:
		var b: Dictionary=game.buildings[id]
		var focus:=Vector3(b.pos[0],5,b.pos[1])
		var offset:=Vector3(0,sin(.64)*48,cos(.64)*48).rotated(Vector3.UP,PI/4)
		for width in [18,32,52]:
			game.camera.size=width
			game.camera.position=focus+offset
			game.camera.look_at(focus)
			var camera_basis: Basis=game.camera.basis
			var pixel_size: float=width/float(root.size.y)
			for step in range(3):
				game.camera.position=focus+offset+camera_basis.x*pixel_size*step
				game.camera.basis=camera_basis
				await create_timer(.12).timeout
				var filename: String="pan-%s-%d-%d.png"%[id,width,step]
				await game.take_photograph(filename)
				var polygon: Array=[]
				for point in [Vector3(b.pos[0]-b.width/2+.35,2.4,b.pos[1]+b.depth/2+.21),Vector3(b.pos[0]+b.width/2-.35,2.4,b.pos[1]+b.depth/2+.21),Vector3(b.pos[0]+b.width/2-.35,2+b.height-.3,b.pos[1]+b.depth/2+.21),Vector3(b.pos[0]-b.width/2+.35,2+b.height-.3,b.pos[1]+b.depth/2+.21)]:
					var screen: Vector2=game.camera.unproject_position(point)
					polygon.append([screen.x,screen.y])
				records.append({"file":filename,"building":id,"size":width,"pan_pixels":step,"wall":polygon,"viewport":[root.size.x,root.size.y]})
	for phase in [1,2]:
		game.set_time(phase)
		game.update_lights()
		await create_timer(.5).timeout
		await game.take_photograph("lighting-"+str(phase)+".png")
	FileAccess.open(game.qa_artifacts.path_join("render-frames.json"),FileAccess.WRITE).store_string(JSON.stringify(records,"  "))
	FileAccess.open(game.qa_artifacts.path_join("render-qa-report.json"),FileAccess.WRITE).store_string(JSON.stringify(game.qa_results,"  "))
	var failures: int=game.qa_results.filter(func(item):return not item.pass).size()
	print("RENDER_QA_COMPLETE failures=",failures)
	tree.quit(1 if failures else 0)
