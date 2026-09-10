extends Control

var game: Node3D

func _ready() -> void:
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	tooltip_text="The islands of Vesper · M"

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var c:=size/2
	var r:=size.x*.44
	draw_circle(c+Vector2(0,4),r+4,Color("10191599"))
	draw_circle(c,r+3,Color("332a1c"))
	draw_circle(c,r,Color("b2985f"))
	draw_circle(c,r-3,Color("645534"))
	draw_circle(c,r-5,Color("e0c790"))
	draw_circle(c,r-7,Color("212d29"))
	draw_arc(c,r-9,0,TAU,96,Color("897a50"),1,true)
	for i in range(48):
		var a:=i*TAU/48.0
		var axis:=Vector2(sin(a),-cos(a))
		draw_line(c+axis*(r-10),c+axis*(r-(17 if i%4==0 else 13)),Color("c5b587"),1,true)
	for i in range(4):
		var a: float=i*PI/2-game.camera_yaw
		var p:=c+Vector2(sin(a),-cos(a))*(r-25)
		draw_string(game.serif,p+Vector2(-5,5),["N","E","S","W"][i],HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("e2c98e"))
	var north:=Vector2(sin(-game.camera_yaw),-cos(-game.camera_yaw))
	var side:=Vector2(-north.y,north.x)
	draw_colored_polygon(PackedVector2Array([c+north*23,c+side*5,c-north*7]),Color("bb5941"))
	draw_colored_polygon(PackedVector2Array([c-north*23,c-side*5,c+north*7]),Color("d5ccb0"))
	draw_circle(c,3,Color("e2c282"))
	var target: Vector3=game.objective_position()
	if target!=Vector3.ZERO:
		var direction:=Vector2(target.x-game.player.position.x,target.z-game.player.position.z).normalized().rotated(-game.camera_yaw)
		var marker:=c+direction*(r+2)
		draw_circle(marker,4,Color("ffd58a"))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:game.toggle_map()
