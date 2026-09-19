extends RefCounted

func run(game) -> void:
	await game.get_tree().create_timer(2).timeout
	game.start_journey(false)
	var town=game.town
	town.live_calls="--town-live" in OS.get_cmdline_user_args()
	game.qa_assert(town.actors.size()==21,"All 21 citizens share physical movement and town behaviour")
	for a in town.actors.values():game.qa_assert(town.neighbours.clear_at(a.node.position),"Clear starting capsule: "+a.npc.name)
	game.qa_assert(town.actors.barkeep.home.distance_to(Vector3(10,2.08,70))<.1,"Garrick starts in the aisle outside the counter")
	# Reproduce the reported animation bug across several path cells.
	var walker=town.actors.elowen
	town.go(walker,town.actors.baker.home)
	var maximum:=0.;var idle_frames:=0;var moving_frames:=0
	for frame in 420:
		await game.get_tree().physics_frame
		if walker.path.size()>2 and walker.hold<=0:
			moving_frames+=1
			maximum=maxf(maximum,walker.npc.animation.current_animation_position)
			if frame>5 and walker.npc.animation.current_animation=="Idle":idle_frames+=1
	game.qa_assert(maximum>.65 and moving_frames>200,"Elowen's gait advances beyond the formerly repeating first third of a second")
	game.qa_assert(idle_frames==0,"Crossing path cells never restarts walking with an Idle frame")
	game.start_journey(false)
	var duration:=480
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--town-seconds="):duration=int(arg.trim_prefix("--town-seconds="))
	var snapshots: Array=[];var last_photo:=-1
	var start:=Time.get_ticks_msec()
	while (Time.get_ticks_msec()-start)*.001<duration:
		var elapsed: int=int((Time.get_ticks_msec()-start)*.001)
		var focus: String="crier" if elapsed<40 else ("barkeep" if elapsed<160 else ("shipwright" if elapsed<270 else ("innkeeper" if elapsed<380 else "crier")))
		# Stationary listener at each scene; never chase a moving actor.
		game.player.position=town.safe_point(town.actors[focus].home+Vector3(2,0,2))
		game.player.velocity=Vector3.ZERO;game.player.path.clear()
		if elapsed/60!=last_photo:
			last_photo=elapsed/60
			snapshots.append({"seconds":elapsed,"world":town.world.duplicate(true),"actors":town.serialize().actors,"metrics":town.metrics.duplicate()})
			FileAccess.open(game.qa_artifacts.path_join("neighbours-observation.json"),FileAccess.WRITE).store_string(JSON.stringify(snapshots,"  "))
			print("NEIGHBOURS_OBSERVE ",elapsed," arrivals=",town.metrics.arrivals," fish=",town.world.fish_deliveries," bread=",town.world.bread_deliveries," timber=",town.world.timber_deliveries," remedies=",town.world.remedy_deliveries)
			if DisplayServer.get_name()!="headless":await game.take_photograph("neighbours-%03d.png"%elapsed)
		await game.get_tree().create_timer(1).timeout
	for a in town.actors.values():game.qa_assert(a.trips>0,"Completed physical trip: "+a.npc.name)
	for key in ["fish_deliveries","bread_deliveries","timber_deliveries","remedy_deliveries"]:game.qa_assert(town.world[key]>0,"Connected transaction completed: "+key)
	game.qa_assert(town.metrics.failed_routes==0,"No repeatedly stalled citizens during observation")
	game.qa_assert(town.metrics.recoveries==0,"No citizen fell into the water")
	game.qa_assert(town.conversations.any(func(c):return str(c.topics[0]).begins_with("chat_")),"People initiated conversations when they met")
	game.qa_assert(town.metrics.max_queue<=8,"Speech queue stayed bounded")
	var overlap:=false
	for index in range(1,town.speech_history.size()):
		var previous: Dictionary=town.speech_history[index-1];var current: Dictionary=town.speech_history[index]
		if current.time<previous.time+previous.duration-.1:overlap=true
	game.qa_assert(not overlap,"Nearby spoken turns never overlap")
	game.qa_assert(town.speech_player.max_distance<=32,"Spatial speech has a finite hearing range")
	var factual:=true
	for line in town.speech_history:
		var kind: String="timber_delivery" if str(line.id).begins_with("timber_news") else ("remedy_delivery" if str(line.id).begins_with("remedies_news") else "")
		if not kind.is_empty() and not town.events.any(func(e):return e.kind==kind and e.time<=line.time and "crier" in e.witnesses):factual=false
	game.qa_assert(factual,"Trade news is backed by completed deliveries reported to the crier")
	# Exact player contract, duplicate prevention, reputation and persistence.
	game.player.position=town.actors.joiner.node.position+Vector3(1,0,0);game.nearby=town.actors.joiner.npc
	var source: int=town.world.timber_source;var coins: int=game.coins
	town.neighbours.player_speech("joiner","accept parcel")
	game.qa_assert(town.world.player_parcel=="timber" and town.world.timber_source==source-1,"Player parcel reserves one real plank")
	town.neighbours.player_speech("joiner","accept parcel")
	game.qa_assert(town.world.timber_source==source-1,"Repeated acceptance cannot create another parcel")
	game.player.position=town.actors.shipwright.node.position+Vector3(1,0,0);game.nearby=town.actors.shipwright.npc
	town.neighbours.player_speech("shipwright","deliver parcel")
	town.neighbours.player_speech("shipwright","deliver parcel")
	game.qa_assert(game.coins==coins+5 and town.world.player_parcels==1 and town.world.reputation==1,"One delivery pays exactly once and earns remembered reputation")
	game.save_journey();var saved: Dictionary=town.serialize();town.world.reputation=0;town.restore(saved)
	game.qa_assert(town.world.reputation==1 and town.actors.shipwright.memory.any(func(m):return "traveller helped" in m.text),"Reputation and the witness's memory survive restore")
	if game.music.stream!=null:
		game.qa_assert(game.music.stream.get_length()>0,"Optional local soundtrack loaded with a valid duration")
	else:
		game.qa_assert(not game.music.playing,"Town runs normally without an optional personal soundtrack")
	game.music_level=0.;await game.get_tree().create_timer(.1).timeout
	game.qa_assert(game.music.volume_db<-70,"Music volume independently reaches silence")
	game.music_level=.28
	town.speech_player.stop();town.release_group();town.groups.clear();town.speech_gap=0
	game.player.position=town.actors.crier.node.position+Vector3(1,0,1);game.player.velocity=Vector3.ZERO
	town.queue_conversation(["welcome"],["crier"],true)
	var bus: int=AudioServer.get_bus_index("TownSpeech")
	# A single instant can land on a pause or quiet consonant. Measure an audible window.
	var near_peak: float=-200.0
	for sample in 30:
		await game.get_tree().create_timer(.1).timeout
		near_peak=maxf(near_peak,maxf(AudioServer.get_bus_peak_volume_left_db(bus,0),AudioServer.get_bus_peak_volume_right_db(bus,0)))
	var nearby_position: Vector3=game.player.position
	game.player.position=Vector3(600,2,600);game.player.velocity=Vector3.ZERO
	await game.get_tree().create_timer(.5).timeout
	var far_peak: float=AudioServer.get_bus_peak_volume_left_db(bus,0)
	game.qa_assert(near_peak>-60 and far_peak<near_peak-24,"Measured speech bus fades out beyond hearing range (near %.1f dB, far %.1f dB)"%[near_peak,far_peak])
	game.qa_assert(not town.subtitle.visible,"Out-of-range speech does not display a remote subtitle")
	game.player.position=nearby_position;game.player.velocity=Vector3.ZERO
	await town.poll_status()
	town.neighbours.show_notices()
	if DisplayServer.get_name()!="headless":await game.take_photograph("town-notices.png")
	game.close_modal()
	var report={"checks":game.qa_results,"duration_seconds":(Time.get_ticks_msec()-start)*.001,"metrics":town.metrics,"world":town.world,"actors":town.serialize().actors,"events":town.events,"speech":town.speech_history,"decisions":town.decisions,"animation_max_time":maximum,"walk_idle_frames":idle_frames,"helper":town.helper_status,"speech_near_db":near_peak,"speech_far_db":far_peak}
	FileAccess.open(game.qa_artifacts.path_join("neighbours-report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	var failures: int=game.qa_results.filter(func(item):return not item.pass).size()
	print("NEIGHBOURS_QA_COMPLETE failures=",failures)
	await game.quit_demo(1 if failures else 0)
