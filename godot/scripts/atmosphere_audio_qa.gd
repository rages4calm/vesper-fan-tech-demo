extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await create_timer(2).timeout
	game.start_journey(false)
	var town=game.town
	town.live_calls=false
	game.set_process(false);game.player.set_physics_process(false);town.set_process(false)
	town.speech_player.stop()
	town.speech_player.stream=load("res://assets/voices/welcome_0.wav")
	town.speech_player.global_position=town.actors.crier.node.global_position+Vector3.UP*1.5
	town.speech_player.volume_db=2.0
	game.music.stop();game.ambience.stop()
	var levels: Dictionary={}
	var bus:=AudioServer.get_bus_index("TownSpeech")
	for distance in [2.0,12.0,60.0]:
		game.player.position=town.actors.crier.node.position+Vector3(distance,0,0)
		game.player.reset_physics_interpolation()
		town.speech_player.play()
		await create_timer(.3).timeout
		var peak: float=-200.0
		for sample in 30:
			await create_timer(.1).timeout
			peak=maxf(peak,maxf(AudioServer.get_bus_peak_volume_left_db(bus,0),AudioServer.get_bus_peak_volume_right_db(bus,0)))
		levels[str(distance)]=peak
		town.speech_player.stop()
		await create_timer(.3).timeout
	game.qa_assert(levels["2.0"]>-40,"Nearby spoken sentence is audible across a three-second window")
	game.qa_assert(levels["12.0"]<levels["2.0"]-2,"Speech fades with distance")
	game.qa_assert(levels["60.0"]<-70,"Speech is silent beyond its hearing range")
	FileAccess.open(game.qa_artifacts.path_join("audio-window-report.json"),FileAccess.WRITE).store_string(JSON.stringify({"peak_db":levels,"checks":game.qa_results},"  "))
	print("AUDIO_WINDOW_QA ",levels)
	await game.quit_demo(0 if game.qa_results.all(func(c):return c.pass) else 1)
