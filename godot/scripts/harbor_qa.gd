extends RefCounted

var tree: SceneTree

func wait(seconds: float) -> void:
	await tree.create_timer(seconds).timeout

func shot(game,filename: String,eye: Vector3,focus: Vector3,fov:=50.0) -> void:
	game.camera.projection=Camera3D.PROJECTION_PERSPECTIVE
	game.camera.fov=fov
	game.camera.position=eye
	game.camera.look_at(focus)
	game.update_reflections()
	await wait(.4)
	await game.take_photograph(filename)

func run(game) -> void:
	tree=game.get_tree()
	await wait(2)
	game.start_journey(false)
	game.music.stop();game.ambience.stop()
	await wait(.5)
	game.set_process(false);game.player.set_physics_process(false)
	game.harbor.set_process(false)
	game.ui.visible=false;game.player.visible=false
	game.set_time(0)
	var harbor=game.harbor
	game.qa_assert(harbor.vessels.size()==3,"Three detailed vessels are loaded")
	game.qa_assert(harbor.fishers.size()==3,"Three working anglers are on deck")
	for s in game.plan.ships:
		game.qa_assert(not game.city.find_child(s.name,true,false).visible,"Original overlapping placeholder is hidden: "+s.name)
	for fisher in harbor.fishers:
		game.qa_assert(fisher.animation.has_animation("Fishing_Work") and fisher.tip!=null,"Angler has a baked fishing loop and rod-tip attachment")
	var moving: Dictionary=harbor.vessels[2].data
	var first: Dictionary=harbor.pose_at(moving,0)
	var last: Dictionary=harbor.pose_at(moving,moving.period)
	game.qa_assert(first.position.distance_to(last.position)<.001 and absf(angle_difference(first.yaw,last.yaw))<.001,"Merchant route wraps without teleporting or turning abruptly")
	var forward_ok:=true
	for i in range(310):
		var t: float=i*.5
		var a: Dictionary=harbor.pose_at(moving,t)
		var b: Dictionary=harbor.pose_at(moving,t+.01)
		if Vector3.FORWARD.rotated(Vector3.UP,a.yaw).dot((b.position-a.position).normalized())<.999:forward_ok=false
	game.qa_assert(forward_ok,"Merchant bow follows its route through a full circuit")
	var tip_positions: Array[Vector3]=[]
	for t in [1.0,8.0,20.5]:
		harbor.update_world(t)
		await wait(.15)
		tip_positions.append(harbor.fishers[0].body.to_local(harbor.fishers[0].tip.global_position))
	game.qa_assert(tip_positions[0].distance_to(tip_positions[1])>1 and tip_positions[1].distance_to(tip_positions[2])>1,"Rod tip moves through distinct casting, waiting, and hauling poses")
	for i in range(harbor.plan.lookouts.size()):
		var view: Dictionary=harbor.plan.lookouts[i]
		var destination:=Vector3(view.pos[0],view.pos[1],view.pos[2])
		game.player.position=destination+(Vector3(0,.12,-7) if i==0 else Vector3(-8,.12,0))
		game.player.velocity=Vector3.ZERO;game.player.reset_physics_interpolation()
		game.player.set_physics_process(true)
		game.qa_assert(game.player.go_to(destination),"Navigation finds the dock lookout: "+view.id)
		var deadline:=Time.get_ticks_msec()+7000
		while game.player.position.distance_to(destination)>.8 and Time.get_ticks_msec()<deadline:await wait(.1)
		game.qa_assert(game.player.position.distance_to(destination)<.8 and game.player.is_on_floor(),"Traveler physically walks along the dock to lookout: "+view.id)
		game.player.set_physics_process(false);game.player.path.clear();game.player.velocity=Vector3.ZERO
		game.player.position=Vector3(view.pos[0],view.pos[1],view.pos[2]);game.player.reset_physics_interpolation()
		game.update_hud()
		await game.qa_key(KEY_E)
		await wait(.1)
		game.qa_assert(harbor.watching and harbor.watch_id==i,"E opens dock lookout: "+view.id)
		game.change_zoom(.87)
		game.qa_assert(harbor.watch_fov<56,"Mouse-wheel zoom works at lookout: "+view.id)
		harbor.watch_fov=56;harbor.update_camera()
		game.update_reflections()
		harbor.update_world(8)
		await wait(.5)
		await game.take_photograph("harbor-"+view.id+"-dock.png")
		await game.qa_key(KEY_E);await wait(.1)
		game.qa_assert(not harbor.watching,"E returns to ordinary walking: "+view.id)
	await game.qa_key(KEY_E)
	await game.qa_key(KEY_W)
	game.qa_assert(not harbor.watching,"Movement key leaves the anchored dock camera")
	game.update_camera(.1)
	game.qa_assert(game.camera.projection==Camera3D.PROJECTION_ORTHOGONAL and is_equal_approx(game.camera.fov,62.0),"Ordinary camera projection and field of view restore after watching")
	game.ui.visible=true
	game.toggle_map()
	await wait(.3)
	await game.take_photograph("harbor-map.png")
	for i in range(harbor.plan.lookouts.size()):
		if not game.modal_open:game.toggle_map();await wait(.15)
		game.player.position=Vector3(game.plan.spawn[0],2.12,game.plan.spawn[1]);game.player.reset_physics_interpolation()
		var button: Button=game.modal.find_child("HarborRoute"+str(i),true,false)
		var click:=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true;click.position=button.get_global_rect().get_center()
		game.get_viewport().push_input(click,true);await tree.process_frame
		click=click.duplicate();click.pressed=false;game.get_viewport().push_input(click,true);await wait(.15)
		var p=harbor.plan.lookouts[i].pos
		game.qa_assert(not game.modal_open and game.player.path.size()>2 and game.player.path[-1].distance_to(Vector3(p[0],2,p[2]))<1.6,"Map button routes from the Mint to the correct dock: "+harbor.plan.lookouts[i].id)
		game.player.path.clear()
	game.close_modal();game.ui.visible=false
	harbor.update_world(8)
	await shot(game,"harbor-working-launch.png",Vector3(107,5.1,-25),Vector3(101,1.5,-33),44)
	await shot(game,"harbor-fishing-cutter.png",Vector3(129,7.0,24),Vector3(116,2.8,14),48)
	var boat: Node3D=harbor.vessels[2].node
	await shot(game,"harbor-merchant.png",boat.to_global(Vector3(22,11,-22)),boat.global_position+Vector3.UP*5.3,48)
	var angler: Node3D=harbor.fishers[0].body
	await shot(game,"harbor-angler-wait.png",angler.to_global(Vector3(3.0,2.8,3.7)),angler.global_position+Vector3.UP*1.1,44)
	harbor.update_world(20.5)
	await shot(game,"harbor-angler-catch.png",angler.to_global(Vector3(3.8,2.8,4.3)),angler.global_position+Vector3.UP*1.8,48)
	game.set_time(2)
	harbor.update_world(8)
	await shot(game,"harbor-evening.png",Vector3(127.2,4.1,harbor.plan.lookouts[1].pos[2]),Vector3(114,2,23),56)
	if "--qa-harbor-video" in OS.get_cmdline_user_args():await record_motion(game)
	FileAccess.open(game.qa_artifacts.path_join("harbor-qa-report.json"),FileAccess.WRITE).store_string(JSON.stringify(game.qa_results,"  "))
	var failures: int=game.qa_results.filter(func(item):return not item.pass).size()
	print("HARBOR_QA_COMPLETE failures=",failures)
	await game.quit_demo(1 if failures else 0)

func record_motion(game) -> void:
	# Export actual viewport frames, with the same world update used in play.
	var folder: String=game.qa_artifacts.path_join("motion")
	DirAccess.make_dir_recursive_absolute(folder)
	game.set_time(0)
	game.harbor.watching=true;game.harbor.watch_id=1;game.harbor.watch_fov=56;game.harbor.update_camera()
	game.harbor.watching=false
	game.update_reflections()
	for frame in range(480):
		var time: float=frame/24.0
		game.harbor.update_world(8+time)
		if frame==240:
			var angler: Node3D=game.harbor.fishers[0].body
			game.camera.position=angler.to_global(Vector3(3.8,2.8,4.3))
			game.camera.look_at(angler.global_position+Vector3.UP*1.5);game.camera.fov=50
			game.update_reflections()
		await RenderingServer.frame_post_draw
		game.get_viewport().get_texture().get_image().save_jpg(folder.path_join("frame-%04d.jpg"%frame),.9)
		if frame%120==0:print("HARBOR_VIDEO_FRAME ",frame)
	print("HARBOR_VIDEO_FRAMES_COMPLETE ",480)
