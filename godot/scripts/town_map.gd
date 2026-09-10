extends Control

var game: Node3D
var expanded := false
var drag_hint := ""
var map_rect := Rect2()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func project_map(p: Vector2) -> Vector2:
	return map_rect.position + (p-Vector2(-150,-205))/Vector2(290,405)*map_rect.size

func unproject_map(p: Vector2) -> Vector2:
	return (p-map_rect.position)/map_rect.size*Vector2(290,405)+Vector2(-150,-205)

func _draw() -> void:
	if not is_instance_valid(game): return
	var margin := 20.0 if expanded else 10.0
	map_rect = Rect2(Vector2(margin,margin),size-Vector2(margin*2,margin*2))
	draw_style_box(game.panel_style(Color("b6b79820"),Color("806b4866")),Rect2(Vector2.ZERO,size))
	for island in game.plan.land:
		var points := PackedVector2Array()
		for p in island.points: points.append(project_map(Vector2(p[0],p[1])))
		draw_colored_polygon(points,Color("a9a38488"))
		points.append(points[0])
		draw_polyline(points,Color("746f51"),1.0,true)
	for bridge in game.plan.bridges:
		var a := project_map(Vector2(bridge.a[0],bridge.a[1]))
		var b := project_map(Vector2(bridge.b[0],bridge.b[1]))
		draw_line(a,b,Color("766649"),2.5 if expanded else 1.2,true)
	for dock in game.plan.docks:
		var p:=project_map(Vector2(dock.pos[0],dock.pos[1]))
		var extent:=Vector2(dock.size[0],dock.size[1])/Vector2(290,405)*map_rect.size
		draw_rect(Rect2(p-extent/2,extent),Color("766649"))
	for b in game.plan.buildings:
		var p := project_map(Vector2(b.pos[0],b.pos[1]))
		var extent := Vector2(b.width,b.depth)/Vector2(290,405)*map_rect.size
		if b.has("footprint"):
			var shape:=PackedVector2Array()
			for point in b.footprint:shape.append(project_map(Vector2(point[0],point[1])))
			draw_colored_polygon(shape,Color("a67858"))
		else:draw_rect(Rect2(p-extent/2,extent),Color("a67858"))
		if expanded and b.id in ["mint","museum","inn","boat","tavern","healer","carpenter","oven"]:
			var title: String=game.map_name(b.id)
			var width: float=game.serif.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,19).x
			var label_position:=p+Vector2(7,-7)
			if label_position.x+width>map_rect.end.x-6:label_position.x=p.x-width-7
			draw_string(game.serif,label_position,title,HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color("453825"))
	if game.player:
		var path: PackedVector3Array = game.player.path
		if path.size()>1:
			var pts := PackedVector2Array()
			for p in path: pts.append(project_map(Vector2(p.x,p.z)))
			draw_polyline(pts,Color("975031cc"),2,true)
		var p := project_map(Vector2(game.player.position.x,game.player.position.z))
		draw_circle(p,5 if expanded else 4,Color("376779"))
		draw_arc(p,8,0,TAU,20,Color("376779aa"),1,true)
	if game.harbor:
		for index in range(game.harbor.plan.lookouts.size()):
			var lookout: Dictionary=game.harbor.plan.lookouts[index]
			var p:=project_map(Vector2(lookout.pos[0],lookout.pos[2]))
			draw_circle(p,9 if expanded else 2.5,Color("376779"))
			if expanded:
				draw_string(game.sans,p+Vector2(-4,4),str(index+1),HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("f2e3c6"))
	var target: Vector3 = game.objective_position()
	if target != Vector3.ZERO:
		var p := project_map(Vector2(target.x,target.z))
		draw_polyline(PackedVector2Array([p+Vector2(0,-7),p+Vector2(6,0),p+Vector2(0,7),p+Vector2(-6,0),p+Vector2(0,-7)]),Color("993f26"),2,true)
	draw_string(game.serif,Vector2(size.x/2-7,17),"N",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("51452e"))
	if expanded: draw_string(game.sans,Vector2(22,size.y-12),"Click a street or a blue harbor marker to walk there",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("51452e"))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		if not expanded:
			game.toggle_map()
		else:
			var p := unproject_map(event.position)
			for lookout in game.harbor.plan.lookouts:
				var dock:=Vector2(lookout.pos[0],lookout.pos[2])
				if project_map(dock).distance_to(event.position)<12:p=dock;break
			if game.harbor.watching:game.harbor.toggle_watch()
			game.close_modal()
			if not game.player.go_to(Vector3(p.x,2,p.y)):
				game.toast("Choose a reachable street or bridge.")
