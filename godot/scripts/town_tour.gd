extends RefCounted
var tree: SceneTree
const FPS:=24

func frame(game,time: float) -> void:
	game.elapsed=time
	game.harbor.update_world(time)
	for npc in game.npcs:game.update_npc(npc,1.0/FPS)
	game.update_lights();game.update_reflections()
	await RenderingServer.frame_post_draw

func save_frame(game,folder: String,index: int) -> void:
	game.get_viewport().get_texture().get_image().save_jpg(folder.path_join("frame-%04d.jpg"%index),.9)

func view(game,eye: Vector3,focus: Vector3,fov: float) -> void:
	game.camera.projection=Camera3D.PROJECTION_PERSPECTIVE;game.camera.fov=fov;game.camera.position=eye;game.camera.look_at(focus)

func run(game) -> void:
	tree=game.get_tree()
	await tree.create_timer(2).timeout
	game.start_journey(false)
	game.music.stop();game.ambience.stop();game.ui.visible=false;game.ui_visible=false
	game.set_process(false);game.harbor.set_process(false);game.player.set_physics_process(false)
	game.player.visible=false
	var shots: Array=[
		{"id":"mint","a":Vector3(25,30,-103),"b":Vector3(14,23,-105),"focus":Vector3(-11,5,-133),"fov":52.0,"phase":1},
		{"id":"islands","a":Vector3(63,58,66),"b":Vector3(47,45,57),"focus":Vector3(8,3,10),"fov":58.0,"phase":1},
		{"id":"north-road","a":Vector3(47,35,-206),"b":Vector3(36,29,-198),"focus":Vector3(8,4,-167),"fov":56.0,"phase":1},
		{"id":"museum","a":Vector3(70,29,164),"b":Vector3(58,22,163),"focus":Vector3(31.5,6,132.3),"fov":51.0,"phase":1},
		{"id":"harbor","a":Vector3(127.2,4.1,-8.82),"b":Vector3(127.2,4.1,-8.82),"focus":Vector3(114,3,23),"fov":54.0,"phase":0},
		{"id":"lanterns","a":Vector3(19,26,-102),"b":Vector3(7,22,-103),"focus":Vector3(-11,4,-131),"fov":53.0,"phase":2}
	]
	var folder: String=game.qa_artifacts.path_join("town-tour")
	DirAccess.make_dir_recursive_absolute(folder)
	var index:=0
	for shot in shots:
		game.set_time(shot.phase);game.player.position=Vector3(shot.focus.x,2,shot.focus.z)
		view(game,shot.a,shot.focus,shot.fov);game.update_reflections()
		await tree.create_timer(.3).timeout
		for i in range(6*FPS):
			var u: float=i/float(6*FPS-1);u=u*u*(3-2*u)
			view(game,shot.a.lerp(shot.b,u),shot.focus,shot.fov)
			await frame(game,8.0+i/float(FPS))
			save_frame(game,folder,index);index+=1
		print("TOWN_TOUR_SHOT ",shot.id)
	# This second film follows real character physics through the new workshop.
	folder=game.qa_artifacts.path_join("waterfront-walk")
	DirAccess.make_dir_recursive_absolute(folder)
	game.set_time(1);game.player.visible=true;game.player.model.visible=true
	game.player.position=Vector3(86.8,2.12,-8.82);game.player.last_safe=game.player.position;game.player.velocity=Vector3.ZERO;game.player.reset_physics_interpolation()
	game.player.set_physics_process(true)
	var stages: Array=[
		{"seconds":5,"target":Vector3(94,2,-8.82),"eye":Vector3(79,10,0),"focus":Vector3(96,3,-8.82),"fov":50.0},
		{"seconds":4,"target":Vector3(102.5,2,-8.82),"eye":Vector3(94,17,-19),"focus":Vector3(99,2,-8.82),"fov":50.0},
		{"seconds":8,"target":Vector3(127.2,2,-8.82),"eye":Vector3(115,9,-23),"focus":Vector3(111,3,-8.82),"fov":62.0},
		{"seconds":7,"target":Vector3(127.2,2,-8.82),"eye":Vector3(127.2,4.1,-8.82),"focus":Vector3(114,3,23),"fov":54.0}
	]
	index=0
	for stage_id in range(stages.size()):
		var stage: Dictionary=stages[stage_id]
		if not game.player.go_to(stage.target):push_error("Film route unavailable");tree.quit(1);return
		if stage_id==3:game.player.visible=false;game.set_time(0)
		for i in range(stage.seconds*FPS):
			game.update_camera(1.0/FPS)
			view(game,stage.eye,stage.focus,stage.fov)
			await frame(game,8+index/float(FPS))
			save_frame(game,folder,index);index+=1
		var reached: bool=game.player.position.distance_to(stage.target)<.9
		print("WATERFRONT_FILM_STAGE ",stage_id," reached=",reached," position=",game.player.position)
		if not reached:tree.quit(1);return
	print("TOUR_CAPTURE_COMPLETE town_frames=864 waterfront_frames=576")
	tree.quit()
