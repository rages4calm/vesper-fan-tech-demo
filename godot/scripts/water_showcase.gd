extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	await create_timer(2).timeout
	game.start_journey(false);game.set_process(false);game.player.set_physics_process(false)
	game.ui.visible=false;game.player.visible=false;game.music.stop()
	game.camera.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	var views=[{"eye":Vector3(139,12,45),"target":Vector3(117,1,21),"ortho":false,"phase":1},
		{"eye":Vector3(81,32,-73),"target":Vector3(55,0,-99),"ortho":true,"phase":0},
		{"eye":Vector3(139,12,45),"target":Vector3(117,1,21),"ortho":false,"phase":2}]
	game.set_quality(true)
	for view in views:
		game.set_time(view.phase)
		game.camera.projection=Camera3D.PROJECTION_ORTHOGONAL if view.ortho else Camera3D.PROJECTION_PERSPECTIVE
		game.camera.size=35;game.camera.fov=56;game.camera.position=view.eye;game.camera.look_at(view.target)
		game.player.position=view.target;game.player.reset_physics_interpolation()
		game.update_lights();game.update_reflections()
		for frame in 180:
			await process_frame
			game.elapsed+=1.0/30.0
			game.update_reflections()
	print("WATER_SHOWCASE_COMPLETE")
	await game.quit_demo(0)
