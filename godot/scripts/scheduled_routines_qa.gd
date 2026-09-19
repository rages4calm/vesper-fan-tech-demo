extends SceneTree
func _initialize():call_deferred("run")
func run():
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	await create_timer(2).timeout
	game.start_journey(false);game.town.live_calls=false
	var town=game.town
	town.decision_due=99999.
	var histories: Array=[]
	for i in 220:
		await create_timer(1).timeout
		if i%30==0:
			print("ROUTINE_SECONDS ",i)
			histories.append({"second":i,"actors":town.serialize().actors})
	for a in town.actors.values():
		if a.id in ["fisherman","elowen","resident_living"]:continue
		game.qa_assert(a.trips>0,"Scheduled physical round even without AI: "+a.npc.name)
		game.qa_assert(town.neighbours.clear_at(a.node.position),"No furniture penetration after rounds: "+a.npc.name)
	game.qa_assert(town.metrics.failed_routes==0 and town.metrics.recoveries==0,"No stalled rounds or falls")
	var saved=town.serialize();town.world.reputation=3;game.save_journey()
	var disk=JSON.parse_string(FileAccess.get_file_as_string(game.save_path()))
	game.qa_assert(disk.town.world.reputation==3,"New reputation actually reaches the journey file")
	town.world.reputation=0;town.load_state()
	game.qa_assert(town.world.reputation==3,"Reputation loads from disk")
	game.music_level=0.;await create_timer(.2).timeout
	game.qa_assert(game.music.volume_db<-70,"Music mutes after the audio update")
	var failed=game.qa_results.filter(func(item):return not item.pass).size()
	FileAccess.open(game.qa_artifacts.path_join("scheduled-routines.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":game.qa_results,"observations":histories,"metrics":town.metrics},"  "))
	print("ROUTINES_COMPLETE failures=",failed)
	await game.quit_demo(1 if failed else 0)
