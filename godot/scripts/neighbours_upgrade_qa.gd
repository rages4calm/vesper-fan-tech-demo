extends SceneTree
func _initialize():call_deferred("run")
func run():
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	await create_timer(2).timeout
	var original_path="user://journey.json"
	var original:=FileAccess.get_file_as_bytes(original_path)
	var previous=JSON.parse_string(original.get_string_from_utf8())
	if previous is Dictionary:
		FileAccess.open(game.save_path(),FileAccess.WRITE).store_buffer(original)
		game.start_journey(true)
		game.town.live_calls=false
		game.qa_assert(game.coins==int(previous.get("coins",20)) and game.fish==int(previous.get("fish",0)),"Prior normal journey inventory resumes in the isolated QA copy")
		game.qa_assert(game.town.actors.size()==21,"Old six-person town save expands to all 21 citizens")
		await create_timer(2).timeout
		game.qa_assert(game.town.neighbours.clear_at(game.town.actors.barkeep.node.position),"Resumed Garrick is clear of the counter")
		game.qa_assert(FileAccess.get_file_as_bytes(original_path)==original,"Original normal save remains byte-for-byte unchanged")
	else:
		game.start_journey(false);game.town.live_calls=false
	var town=game.town
	var old_world=town.world.duplicate(true)
	town.world.reputation=2;town.world.fish=2;town.world.bread=2;town.world.supper_claimed=false
	town.neighbours.player_speech("barkeep","supper")
	town.neighbours.player_speech("barkeep","supper")
	game.qa_assert(town.world.fish==1 and town.world.bread==1 and town.world.supper_claimed,"Thank-you supper consumes supplies once and cannot be redeemed twice")
	town.neighbours.show_notices()
	await game.take_photograph("notices-current.png")
	var scroll=game.modal.find_children("*","RichTextLabel",true,false)
	game.qa_assert(scroll.size()==1 and scroll[0].scroll_active,"Long town notices are contained in a scrollable reading area")
	game.close_modal();game.show_pause();await game.take_photograph("audio-options-current.png")
	game.close_modal();town.world=old_world
	FileAccess.open(game.qa_artifacts.path_join("upgrade-ui-report.json"),FileAccess.WRITE).store_string(JSON.stringify(game.qa_results,"  "))
	var failures=game.qa_results.filter(func(item):return not item.pass).size()
	print("UPGRADE_UI_COMPLETE failures=",failures)
	await game.quit_demo(1 if failures else 0)
