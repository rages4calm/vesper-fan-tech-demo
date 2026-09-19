extends SceneTree
func _initialize():call_deferred("run")
func run():
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	await create_timer(2).timeout
	game.start_journey(false)
	var town=game.town
	town.helper_url=OS.get_environment("VESPER_QA_DELAY_URL")
	if not town.helper_url.begins_with("http://127.0.0.1:"):
		push_error("Set VESPER_QA_DELAY_URL to a local test HTTP server that delays responses by two seconds.")
		await game.quit_demo(1);return
	town.helper_token="local-qa-only";town.live_calls=true
	town.actors.fisherman.inventory=3;town.actors.fisherman.path.clear();town.actors.fisherman.next_choice=0.;town.actors.fisherman.hold=0.
	town.request_decision("fisherman")
	town.speak_supplies()
	await create_timer(.1).timeout
	var pending:=0
	for node in town.get_children():
		if node is HTTPRequest:pending+=1
	print("SHUTDOWN_PENDING_REQUESTS=",pending)
	await game.quit_demo(0 if pending>=2 else 1)
	print("SHUTDOWN_QA_COMPLETE")
