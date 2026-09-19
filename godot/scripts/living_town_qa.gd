extends RefCounted
var observed: Array=[]
func run(game) -> void:
	await game.get_tree().create_timer(2).timeout
	game.start_journey(false)
	var town=game.town
	await game.get_tree().create_timer(12).timeout
	await game.take_photograph("town-arrival.png")
	game.qa_assert(town.actors.size()==21,"Twenty-one connected living citizens")
	game.qa_assert(town.catalog.size()>30,"Real speech library loaded")
	game.qa_assert(town.metrics.utterances>0,"Crier speech actually started in the audio player")
	for id in ["fisherman","elowen","resident_living"]:
		game.qa_assert(game.find_route(town.actors[id].home,town.actors.barkeep.home+Vector3(1.4,0,1.3)).size()>0,"Navigation route to tavern: "+id)
	game.qa_assert(town.speech_player is AudioStreamPlayer3D and town.speech_player.max_distance<=32,"Voices use spatial audio with bounded range")
	game.qa_assert(town.speech_player.stream.get_length()>3,"Loaded crier sound is real multi-second speech")
	game.qa_assert(town.ambience_duck<.2 and game.ambience.volume_db<-25,"Ocean audio ducks below nearby speech")
	game.qa_assert(game.get_viewport().get_visible_rect().encloses(town.subtitle.get_global_rect()),"Speaker subtitles stay inside the visible screen")
	game.qa_assert(town.subtitle.visible and town.subtitle.text.begins_with("Osric"),"Audible crier line displays an identifying subtitle")
	# Exercise a real player promise, inventory transfer and persistence.
	game.player.position=town.actors.barkeep.home+Vector3(0,.1,1)
	game.nearby=town.actors.barkeep.npc
	await town.player_speech("accept")
	game.qa_assert(town.world.player_promise,"Player acceptance creates a real commitment")
	game.fish=1;var gold: int=game.coins
	await town.player_speech("deliver fish")
	game.qa_assert(game.fish==0 and game.coins==gold+3 and town.world.player_deliveries==1,"Delivery conserves fish and pays the exact fixed reward")
	await town.player_speech("deliver fish")
	game.qa_assert(game.coins==gold+3,"A completed promise cannot be redeemed twice")
	game.save_journey()
	var saved=JSON.parse_string(FileAccess.get_file_as_string(game.save_path()))
	game.qa_assert(saved.town.world.player_deliveries==1,"Town state shares an atomic journey save")
	var memory_count: int=town.actors.barkeep.memory.size()
	town.world.player_deliveries=0;town.actors.barkeep.memory=[]
	town.load_state()
	game.qa_assert(town.world.player_deliveries==1 and town.actors.barkeep.memory.size()==memory_count,"Relevant encounters and fulfilled promises survive loading")
	if "--town-smoke" in OS.get_cmdline_user_args():
		FileAccess.open(game.qa_artifacts.path_join("town-smoke-report.json"),FileAccess.WRITE).store_string(JSON.stringify(game.qa_results,"  "))
		var smoke_failures: int=game.qa_results.filter(func(item):return not item.pass).size()
		print("TOWN_SMOKE_COMPLETE failures=",smoke_failures)
		await game.quit_demo(1 if smoke_failures else 0)
		return
	# Start a clean extended natural simulation, with live calls bounded by helper config.
	game.start_journey(false)
	var duration:=420
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--town-seconds="):duration=int(arg.trim_prefix("--town-seconds="))
	var began:=Time.get_ticks_msec()
	var last_photo:=-1
	while (Time.get_ticks_msec()-began)/1000.0<duration:
		var seconds: int=int((Time.get_ticks_msec()-began)/1000.0)
		var follow: String="crier" if seconds<35 else ("fisherman" if seconds<165 else ("elowen" if seconds<340 else "crier"))
		var actor=town.actors[follow]
		game.player.position=town.safe_point(actor.node.position+Vector3(2,0,2))+Vector3.UP*.12
		game.player.velocity=Vector3.ZERO;game.player.path.clear()
		if seconds/60!=last_photo:
			last_photo=seconds/60
			observed.append({"seconds":seconds,"world":town.world.duplicate(true),"actors":town.serialize().actors,"metrics":town.metrics.duplicate()})
			FileAccess.open(game.qa_artifacts.path_join("town-observation.json"),FileAccess.WRITE).store_string(JSON.stringify(observed,"  "))
			await game.take_photograph("town-%03d.png"%seconds)
			print("TOWN_OBSERVE seconds=",seconds," supplies=",town.world," routes=",town.metrics.failed_routes)
		await game.get_tree().create_timer(1).timeout
	game.qa_assert(town.world.fish_deliveries>0,"Fisherman physically delivered his caught fish")
	game.qa_assert(town.world.bread_deliveries>0,"Courier physically collected and delivered bread")
	game.qa_assert(town.world.courier_phase=="reported","Courier returned to report the completed delivery")
	game.qa_assert(town.world.meals>0,"A resident consumed supplies delivered by other citizens")
	game.qa_assert(town.metrics.arrivals>=6,"Multiple physical trips completed")
	game.qa_assert(town.metrics.failed_routes==0,"No citizen permanently stalled on an observed route")
	game.qa_assert(town.metrics.recoveries==0,"No citizen fell off the city during observation")
	game.qa_assert(town.metrics.max_queue<=8,"Conversation queue remains bounded")
	var overlapping:=false
	for index in range(1,town.speech_history.size()):
		var previous: Dictionary=town.speech_history[index-1];var current: Dictionary=town.speech_history[index]
		if current.time>previous.time and current.time<previous.time+previous.duration-.1:overlapping=true
	game.qa_assert(not overlapping,"Speech playback turns do not overlap")
	var factual:=true
	for line in town.speech_history:
		if str(line.id).begins_with("bread_news") and not town.events.any(func(e):return e.kind=="bread_report" and e.time<=line.time):factual=false
	game.qa_assert(factual,"Crier delivery announcements have a prior reported event")
	game.player.position=town.actors.barkeep.home+Vector3(0,.1,1);game.nearby=town.actors.barkeep.npc
	if not town.helper_url.is_empty():
		await town.speak_supplies()
		await game.get_tree().create_timer(12).timeout
		game.qa_assert(town.speech_history.any(func(line):return line.id=="live_supplies"),"Asynchronously generated live stock report plays in town")
		var original_url: String=town.helper_url;town.helper_url="http://127.0.0.1:1"
		var before: float=town.clock
		var result: Dictionary=await town.http_json("/decision",{"test":true})
		await game.get_tree().create_timer(1).timeout
		game.qa_assert(result.is_empty() and town.clock>before,"Unavailable helper does not freeze the simulation")
		town.helper_url=original_url
		await town.poll_status()
		game.qa_assert(town.helper_status.get("usage",{}).get("requests",999999)<=town.helper_status.get("request_limit",0),"Observed API usage stays inside its request limit")
	game.qa_assert(town.metrics.frame_ms_sum/maxf(1,town.metrics.frame_samples)<45,"Observed mean frame interval below 45 ms")
	town.developer.visible=true;town.refresh_developer()
	await game.take_photograph("town-developer.png")
	var report={"checks":game.qa_results,"duration_seconds":(Time.get_ticks_msec()-began)/1000.0,"metrics":town.metrics,"world":town.world,"events":town.events,"speech":town.speech_history,"decisions":town.decisions,"helper":town.helper_status}
	FileAccess.open(game.qa_artifacts.path_join("town-report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	var failures: int=game.qa_results.filter(func(item):return not item.pass).size()
	print("TOWN_QA_COMPLETE failures=",failures)
	await game.quit_demo(1 if failures else 0)
