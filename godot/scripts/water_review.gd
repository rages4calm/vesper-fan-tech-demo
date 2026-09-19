extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	await create_timer(2).timeout
	game.start_journey(false);game.set_process(false);game.player.set_physics_process(false)
	game.ui.visible=false;game.player.visible=false;game.music.stop();game.ambience.stop()
	game.harbor.set_process(false);game.harbor.update_world(8)
	game.camera.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	var views=[{"id":"harbor","eye":Vector3(139,12,45),"target":Vector3(117,1,21)}, {"id":"canal","eye":Vector3(81,32,-73),"target":Vector3(55,0,-99)}]
	var report=[]
	for high in [true,false]:
		game.set_quality(high)
		for phase in [1,0,2]:
			game.set_time(phase)
			for view in views:
				game.camera.projection=Camera3D.PROJECTION_PERSPECTIVE if view.id=="harbor" else Camera3D.PROJECTION_ORTHOGONAL
				game.camera.size=35;game.camera.fov=56;game.camera.position=view.eye;game.camera.look_at(view.target)
				game.player.position=view.target;game.update_lights();game.update_reflections()
				await create_timer(1).timeout
				var frames=[]
				for frame in 90:
					await process_frame
					frames.append(game.get_process_delta_time()*1000)
				frames.sort()
				report.append({"view":view.id,"high":high,"phase":phase,"median_frame_ms":frames[45],"p95_frame_ms":frames[85]})
				await game.take_photograph("water-%s-%s-%d.png"%[view.id,"high" if high else "low",phase])
	FileAccess.open(game.qa_artifacts.path_join("water-review.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("WATER_REVIEW_COMPLETE");await game.quit_demo(0)
