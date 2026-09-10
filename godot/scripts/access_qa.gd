extends RefCounted
var tree: SceneTree

func wait(seconds: float) -> void:
	await tree.create_timer(seconds).timeout

func walk(game,target: Vector3,label: String,seconds:=12.0) -> void:
	game.player.set_physics_process(true)
	game.qa_assert(game.player.go_to(target),"Route exists: "+label)
	var deadline:=Time.get_ticks_msec()+int(seconds*1000)
	while game.player.position.distance_to(target)>.75 and Time.get_ticks_msec()<deadline:await wait(.1)
	var reached: bool=game.player.position.distance_to(target)<.75 and game.player.is_on_floor()
	game.qa_assert(reached,"Physical walk reaches "+label)
	if not reached:print("ACCESS_POSITION ",label," current=",game.player.position," target=",target," path=",game.player.path)
	game.player.path.clear();game.player.velocity=Vector3.ZERO;game.player.set_physics_process(false)

func shot(game,name: String,eye: Vector3,focus: Vector3,fov:=52.0) -> void:
	game.camera.projection=Camera3D.PROJECTION_PERSPECTIVE;game.camera.fov=fov;game.camera.position=eye;game.camera.look_at(focus)
	game.update_reflections();game.update_lights()
	await wait(.3)
	await game.take_photograph(name)

func run(game) -> void:
	tree=game.get_tree();await wait(2)
	game.start_journey(false);await wait(.5)
	game.set_process(false);game.player.set_physics_process(false);game.ui.visible=false
	game.music.stop();game.ambience.stop();game.set_time(1)
	var spawn:=Vector3(game.plan.spawn[0],2,game.plan.spawn[1])
	for b in game.plan.buildings:
		for door in b.doors:
			var yaw: float=door.get("yaw",0.0)
			var p:=Vector3(door.pos[0],2,door.pos[2])+Vector3(sin(yaw),0,cos(yaw))*3.2
			var query:=PhysicsRayQueryParameters3D.create(p+Vector3.UP*1.0,p-Vector3.UP*1.0)
			query.exclude=[game.player.get_rid()]
			var hit: Dictionary=game.get_world_3d().direct_space_state.intersect_ray(query)
			game.qa_assert(not hit.is_empty() and hit.position.y>1.9 and hit.position.y<2.4,"Solid ground outside "+door.id)
			game.qa_assert(game.find_route(spawn,p).size()>0,"Doorstep connects to the city: "+door.id)
	for id in ["canvas","oven","farm","ranger"]:
		var b: Dictionary=game.buildings[id]
		var target:=Vector3(b.doors[0].pos[0],2,b.doors[0].pos[2]+3.2)
		var start:=target+Vector3(-10,0,0) if id!="ranger" else Vector3(b.pos[0],2,b.pos[1]-b.depth/2-4)
		var cell: Vector2i=game.closest_cell(start)
		game.player.position=Vector3(cell.x,2.12,cell.y);game.player.last_safe=game.player.position;game.player.reset_physics_interpolation()
		await walk(game,target,id+" public approach",15)
	var bridge: Dictionary=game.plan.bridges[0]
	game.player.position=Vector3(bridge.b[0],2.12,bridge.b[1]+2);game.player.last_safe=game.player.position;game.player.reset_physics_interpolation()
	await walk(game,Vector3(bridge.a[0],2,bridge.a[1]-18),"north bridge onto the mainland",25)
	await shot(game,"access-north-mainland.png",Vector3(56,46,-132),Vector3(19,3,-187),55)
	for id in ["boat","fisher"]:
		var b: Dictionary=game.buildings[id]
		var front: Dictionary=b.doors[0];var back: Dictionary=b.doors[1]
		var a:=Vector3(front.pos[0],2,front.pos[2]);var c:=Vector3(back.pos[0],2,back.pos[2])
		var an:=Vector3(sin(front.yaw),0,cos(front.yaw));var cn:=Vector3(sin(back.yaw),0,cos(back.yaw))
		game.player.position=a+an*3.3+Vector3.UP*.12;game.player.last_safe=game.player.position;game.player.reset_physics_interpolation()
		await walk(game,a-an*1.6,id+" street entrance")
		await walk(game,c-cn*1.6,id+" interior passage")
		game.update_camera(.1)
		game.qa_assert(not game.roofs[id].visible,"Roof reveals the interior: "+id)
		await shot(game,"access-"+id+"-interior.png",Vector3(b.pos[0]+7,15,b.pos[1]+9),Vector3(b.pos[0],2,b.pos[1]),50)
		await walk(game,c+cn*3.3,id+" dock exit")
		await walk(game,a+an*3.3,id+" return through both doors")
		await walk(game,c+cn*3.3,id+" passage back to the waterfront")
		var dock: Dictionary=game.harbor.plan.lookouts[1 if id=="boat" else 0]
		await walk(game,Vector3(dock.pos[0],2,dock.pos[2]),id+" dock lookout",15)
		game.update_camera(.1)
		await shot(game,"access-"+id+"-dock.png",Vector3(b.pos[0]+24,13,b.pos[1]+20),Vector3(b.pos[0]+6,3,b.pos[1]),55)
	game.player.visible=false
	var trunk: MeshInstance3D
	for node in game.city.find_children("Tree_*","MeshInstance3D",true,false):
		for surface in range(node.mesh.get_surface_count()):
			var material=node.mesh.surface_get_material(surface)
			if material and material.resource_name=="island_tree_02":trunk=node;break
		if trunk:break
	game.qa_assert(trunk!=null and trunk.mesh.get_aabb().position.y<-.25,"Scanned tree ground is seated below the terrain")
	if trunk:
		var p:=trunk.global_position
		await shot(game,"access-tree-roots.png",p+Vector3(3.4,1.8,4.0),p+Vector3.UP*.6,48)
	FileAccess.open(game.qa_artifacts.path_join("access-qa-report.json"),FileAccess.WRITE).store_string(JSON.stringify(game.qa_results,"  "))
	var failures: int=game.qa_results.filter(func(item):return not item.pass).size()
	print("ACCESS_QA_COMPLETE failures=",failures)
	await game.quit_demo(1 if failures else 0)
