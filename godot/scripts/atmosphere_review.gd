extends SceneTree

# Same camera, time and capture procedure on the checkpoint and the visual update.
func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await create_timer(2).timeout
	game.start_journey(false)
	game.town.live_calls=false
	game.set_process(false)
	game.player.set_physics_process(false)
	game.player.visible=false
	game.ui.visible=false
	game.music.stop()
	game.ambience.stop()
	game.camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	game.camera.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	var specs: Array=[
		{"id":"square","focus":Vector3(-2,4,-118),"size":30.0,"inside":""},
		{"id":"plaster","focus":Vector3(26.88,5,-139.44),"size":22.0,"inside":""},
		{"id":"shipwright","focus":Vector3(100,4,-8.82),"size":29.0,"inside":""},
		{"id":"tavern","focus":Vector3(11.34,4,70.56),"size":23.0,"inside":"tavern"},
		{"id":"carpenter","focus":Vector3(26.04,4,-29.4),"size":24.0,"inside":""},
		{"id":"fisher","focus":Vector3(111,4,-42),"size":25.0,"inside":""}
	]
	for phase in [1,0,2]:
		game.set_time(phase)
		for spec in specs:
			for id in game.roofs:game.roofs[id].visible=id!=spec.inside
			for id in game.facades:game.facades[id].visible=id!=spec.inside
			for id in game.building_details:game.building_details[id].visible=id!=spec.inside
			game.player.position=spec.focus
			game.camera.size=spec.size
			game.camera.position=spec.focus+Vector3(26,32,26)
			game.camera.look_at(spec.focus)
			game.update_lights();game.update_reflections()
			await create_timer(.6).timeout
			await game.take_photograph("%s-%d.png"%[spec.id,phase])
	print("ATMOSPHERE_REVIEW_COMPLETE")
	await game.quit_demo(0)
