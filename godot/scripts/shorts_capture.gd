extends RefCounted
# Portrait capture only. Uses isolated QA saves and normal game assets/physics.
const FPS := 24
var tree: SceneTree
var counts: Dictionary = {}

func view(game, eye: Vector3, focus: Vector3, fov: float) -> void:
	game.camera.projection=Camera3D.PROJECTION_PERSPECTIVE
	game.camera.keep_aspect=Camera3D.KEEP_WIDTH
	game.camera.fov=fov
	game.camera.position=eye
	game.camera.look_at(focus)

func frame(game, time: float, folder: String, index: int) -> void:
	game.elapsed=time
	game.harbor.update_world(time)
	for npc in game.npcs:game.update_npc(npc,1.0/FPS)
	game.update_lights();game.update_reflections()
	await RenderingServer.frame_post_draw
	var capture: Image=game.get_viewport().get_texture().get_image()
	if capture.get_size()!=Vector2i(1080,1920):
		push_error("Portrait resolution mismatch: "+str(capture.get_size()))
		tree.quit(1);return
	var error:=capture.save_jpg(folder.path_join("frame-%04d.jpg"%index),.94)
	if error!=OK:push_error("Shorts frame write failed");tree.quit(1)

func output_folder(game, id: String) -> String:
	var folder: String=game.qa_artifacts.path_join(id)
	DirAccess.make_dir_recursive_absolute(folder)
	return folder

func run(game) -> void:
	tree=game.get_tree()
	var window:=tree.root
	window.content_scale_size=Vector2i(1080,1920)
	window.size=Vector2i(1080,1920)
	await tree.create_timer(2).timeout
	game.start_journey(false)
	game.music.stop();game.ambience.stop();game.ui.visible=false;game.ui_visible=false
	game.set_process(false);game.harbor.set_process(false);game.player.set_physics_process(false)
	game.player.visible=false
	var walk_only: bool="--short-only=waterfront" in OS.get_cmdline_user_args()
	if not walk_only:
		await capture_harbor(game)
		await capture_town(game)
	await capture_walk(game)
	var report:= "waterfront-capture.json" if walk_only else "capture.json"
	FileAccess.open(game.qa_artifacts.path_join(report),FileAccess.WRITE).store_string(JSON.stringify({"resolution":[1080,1920],"fps":FPS,"frames":counts,"physical_walk_passed":true},"  "))
	print("SHORTS_CAPTURE_COMPLETE ",counts)
	tree.quit()

func capture_harbor(game) -> void:
	game.set_time(0)
	var folder:=output_folder(game,"01-harbor")
	var index:=0
	for shot in range(3):
		var duration: int=[3,4,5][shot]
		for i in range(duration*FPS):
			var time: float=19.0+index/float(FPS)
			game.harbor.update_world(time)
			if shot==0:
				var angler: Node3D=game.harbor.fishers[0].body
				view(game,angler.to_global(Vector3(3.8,2.8,4.3)),angler.global_position+Vector3.UP*1.5,50)
			elif shot==1:
				view(game,Vector3(129,7,24),Vector3(116,2.8,14),50)
			else:
				var ship: Node3D=game.harbor.vessels[2].node
				view(game,ship.to_global(Vector3(18,8,-20)),ship.global_position+Vector3.UP*4.3,48)
			await frame(game,time,folder,index);index+=1
		print("SHORT_HARBOR_SHOT ",shot," frames=",index)
	counts.harbor=index

func capture_town(game) -> void:
	var folder:=output_folder(game,"02-town-tour")
	var index:=0
	var shots: Array=[
		{"id":"mint","seconds":4.5,"a":Vector3(19,26,-103),"b":Vector3(14,23,-105),"focus":Vector3(-11,5,-133),"fov":52.0,"phase":1},
		{"id":"canals","seconds":4.0,"a":Vector3(53,49,60),"b":Vector3(47,45,57),"focus":Vector3(8,3,10),"fov":58.0,"phase":1},
		{"id":"museum","seconds":4.0,"a":Vector3(63,25,164),"b":Vector3(58,22,163),"focus":Vector3(31.5,6,132.3),"fov":51.0,"phase":1},
		{"id":"lanterns","seconds":5.5,"a":Vector3(13,24,-102),"b":Vector3(7,22,-103),"focus":Vector3(-11,4,-131),"fov":53.0,"phase":2}
	]
	for shot in shots:
		game.set_time(shot.phase);game.player.position=Vector3(shot.focus.x,2,shot.focus.z)
		for i in range(int(shot.seconds*FPS)):
			var u: float=i/float(shot.seconds*FPS-1);u=u*u*(3-2*u)
			view(game,shot.a.lerp(shot.b,u),shot.focus,shot.fov)
			await frame(game,8+index/float(FPS),folder,index);index+=1
		print("SHORT_TOWN_SHOT ",shot.id," frames=",index)
	counts.town=index

func capture_walk(game) -> void:
	var folder:=output_folder(game,"03-waterfront-walk")
	var index:=0
	game.set_time(1);game.player.visible=true;game.player.model.visible=true
	game.player.position=Vector3(86.8,2.12,-8.82);game.player.last_safe=game.player.position
	game.player.velocity=Vector3.ZERO;game.player.reset_physics_interpolation()
	game.player.set_physics_process(true)
	var stages: Array=[
		{"seconds":3,"target":Vector3(94,2,-8.82),"eye":Vector3(79,10,0),"focus":Vector3(96,3,-8.82),"fov":50.0},
		{"seconds":3,"target":Vector3(102.5,2,-8.82),"eye":Vector3(94,17,-19),"focus":Vector3(99,2,-8.82),"fov":50.0},
		{"seconds":7,"target":Vector3(127.2,2,-8.82),"eye":Vector3(115,9,-23),"focus":Vector3(111,3,-8.82),"fov":62.0},
		{"seconds":3,"target":Vector3(127.2,2,-8.82),"eye":Vector3(127.2,4.1,-8.82),"focus":Vector3(114,3,23),"fov":54.0}
	]
	for stage_id in range(stages.size()):
		var stage: Dictionary=stages[stage_id]
		if not game.player.go_to(stage.target):push_error("Shorts route unavailable");tree.quit(1);return
		if stage_id==3:game.player.visible=false;game.set_time(0)
		for i in range(stage.seconds*FPS):
			game.update_camera(1.0/FPS)
			if stage_id==2:
				# Track the ranger across the entire dock, keeping him inside portrait framing.
				var center: Vector3=game.player.global_position+Vector3.UP
				view(game,center+Vector3(10,10,-18),center,62)
			else:view(game,stage.eye,stage.focus,stage.fov)
			await frame(game,8+index/float(FPS),folder,index);index+=1
		var reached: bool=game.player.position.distance_to(stage.target)<.9 and game.player.is_on_floor()
		print("SHORT_WALK_STAGE ",stage_id," reached=",reached," position=",game.player.position)
		if not reached:tree.quit(1);return
	counts.waterfront=index
