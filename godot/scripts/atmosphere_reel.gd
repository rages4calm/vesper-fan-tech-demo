extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await create_timer(2).timeout
	game.start_journey(false);game.town.live_calls=false
	game.set_process(false);game.player.set_physics_process(false);game.player.visible=false
	game.ui.visible=false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-music="):
			game.music.stream=AudioStreamOggVorbis.load_from_file(argument.trim_prefix("--capture-music="));game.music.play()
	game.music_level=.19
	game.camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	game.camera.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	var overlay:=CanvasLayer.new();root.add_child(overlay)
	game.town.subtitle.reparent(overlay)
	var title:=Label.new();title.position=Vector2(28,26);title.add_theme_font_size_override("font_size",22)
	title.add_theme_color_override("font_shadow_color",Color.BLACK);title.add_theme_constant_override("shadow_offset_x",2);title.add_theme_constant_override("shadow_offset_y",2);overlay.add_child(title)
	var shots: Array=[
		{"name":"The square · daylight","focus":Vector3(-2,4,-118),"size":30.0,"inside":"","time":1,"seconds":11.0},
		{"name":"Nets and the day's catch","focus":Vector3(111,4,-42),"size":25.0,"inside":"","time":1,"seconds":6.0},
		{"name":"The Majestic Boat · the working shop","focus":Vector3(100,4,-8.82),"size":24.0,"inside":"boat","time":0,"seconds":6.0},
		{"name":"The Marsh Hall · lantern night","focus":Vector3(11.34,4,70.56),"size":23.0,"inside":"tavern","time":2,"seconds":8.0},
		{"name":"Vesper · a personal fan tech demo","focus":Vector3(26.88,5,-139.44),"size":24.0,"inside":"","time":0,"seconds":6.0}
	]
	for shot in shots:
		for id in game.roofs:game.roofs[id].visible=id!=shot.inside
		for id in game.facades:game.facades[id].visible=id!=shot.inside
		for id in game.building_details:game.building_details[id].visible=id!=shot.inside
		game.player.position=shot.focus;game.player.reset_physics_interpolation()
		game.player.position.y=2.1
		game.camera.size=shot.size;game.camera.position=shot.focus+Vector3(26,32,26);game.camera.look_at(shot.focus)
		game.set_time(shot.time);title.text="VESPER  ·  "+shot.name
		if shot.name=="The square · daylight":
			game.town.next_crier=60
			game.town.queue_conversation(["welcome"],["crier"],true)
		game.listener.global_rotation.y=game.camera.global_rotation.y
		game.music.volume_db=linear_to_db(.19)
		game.update_lights();game.update_reflections()
		var elapsed:=0.0
		while elapsed<shot.seconds:
			await process_frame
			elapsed+=game.get_process_delta_time()
			game.elapsed+=game.get_process_delta_time()
			game.update_lights();game.update_reflections()
		await game.take_photograph("reel-"+shot.inside+"-"+str(shot.time)+".png")
	print("ATMOSPHERE_REEL_COMPLETE")
	await game.quit_demo(0)
