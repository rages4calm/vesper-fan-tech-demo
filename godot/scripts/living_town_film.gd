extends RefCounted

# Only the camera is directed. NPC routes, transactions and speech are the real
# simulation. Record a fixed view of each place, then cut; never chase an actor.
var shots: Array=[]
func run(game) -> void:
	await game.get_tree().create_timer(2).timeout
	game.start_journey(false)
	game.town.live_calls=false
	game.player.visible=false
	game.cinematic_active=true
	game.town.subtitle.reparent(game.ui)
	game.hud.hide()
	game.set_time(1)
	game.camera_yaw=PI/4;game.camera_pitch=.72
	game.music_level=.19
	var title:=Label.new()
	title.position=Vector2(28,27);title.add_theme_font_size_override("font_size",22)
	title.add_theme_color_override("font_shadow_color",Color.BLACK)
	title.add_theme_constant_override("shadow_offset_x",2);title.add_theme_constant_override("shadow_offset_y",2)
	game.ui.add_child(title)
	var scenes: Array=[
		{"id":"crier","name":"The town square","duration":35.,"distance":43.},
		{"id":"fisherman","name":"Life along the quay","duration":22.,"distance":43.},
		{"id":"shipwright","name":"The Majestic Boat · work on the waterfront","duration":68.,"distance":44.},
		{"id":"barkeep","name":"The Marsh Hall · a kitchen supplied by neighbours","duration":120.,"distance":33.},
		{"id":"innkeeper","name":"The Ironwood Inn · an errand across the bridges","duration":85.,"distance":38.},
		{"id":"crier","name":"Word comes back to the square","duration":35.,"distance":43.}
	]
	for scene in scenes:
		var home: Vector3=game.town.actors[scene.id].home
		game.player.position=game.town.safe_point(home+Vector3(1,0,1));game.player.velocity=Vector3.ZERO;game.player.path.clear();game.player.reset_physics_interpolation()
		game.cinematic_focus=home+Vector3.UP*1.15
		game.camera_target_distance=scene.distance;game.camera_distance=scene.distance
		title.text="VESPER · "+scene.name
		var begin: float=game.town.clock
		var shot={"place":scene.id,"title":scene.name,"start":float(Engine.get_process_frames())/30.,"town_start":begin,"camera_movement":0.}
		await game.get_tree().process_frame
		await RenderingServer.frame_post_draw
		var camera_position: Vector3=game.camera.position
		if scene.id=="innkeeper":game.set_time(0)
		while game.town.clock-begin<scene.duration or (game.town.clock-begin<scene.duration+30 and (game.town.speech_player.playing or not game.town.active_group.is_empty())):
			shot.camera_movement=maxf(shot.camera_movement,game.camera.position.distance_to(camera_position))
			await game.get_tree().process_frame
		shot["end"]=float(Engine.get_process_frames())/30.;shots.append(shot)
		await game.take_photograph("film-"+scene.id+"-%d.png"%shots.size())
	var record={"mode":"Rules decisions; authored local Kokoro speech; actual simulation; stationary camera shots", "speech":game.town.speech_history,"events":game.town.events,"metrics":game.town.metrics,"shots":shots}
	FileAccess.open(game.qa_artifacts.path_join("film-events.json"),FileAccess.WRITE).store_string(JSON.stringify(record,"  "))
	print("TOWN_FILM_COMPLETE")
	await game.quit_demo(0)
