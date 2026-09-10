extends CharacterBody3D

var game: Node3D
var model: Node3D
var arms: Array[Node3D] = []
var legs: Array[Node3D] = []
var cloak: Node3D
var walk_time := 0.0
var stamina := 100.0
var foot_time := 0.0
var path := PackedVector3Array()
var last_safe := Vector3.ZERO
var moving := false
var is_running := false
var animation: AnimationPlayer

func _ready() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.30
	capsule.height = 1.75
	shape.shape = capsule
	shape.position.y = 0.90
	add_child(shape)
	floor_snap_length = 0.5
	floor_max_angle = deg_to_rad(48)
	model = load("res://assets/ranger.glb").instantiate()
	add_child(model)
	var silhouette:=ShaderMaterial.new()
	silhouette.shader=load("res://shaders/traveler_silhouette.gdshader")
	for mesh in model.find_children("*","MeshInstance3D",true,false):mesh.material_overlay=silhouette
	animation=model.find_child("AnimationPlayer",true,false)
	if animation:
		for clip in animation.get_animation_list():
			if clip!="Interact":animation.get_animation(clip).loop_mode=Animation.LOOP_LINEAR
		animation.play("Idle")
	last_safe = position
	add_to_group("player")

func _physics_process(delta: float) -> void:
	if not is_instance_valid(game): return
	var direction := Vector3.ZERO
	is_running = false
	if game.playing and not game.modal_open and not game.fishing and not game.chatting and not (game.harbor and game.harbor.watching):
		var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if input.length() > .01:
			path.clear()
			direction = Vector3(input.x, 0, input.y).rotated(Vector3.UP, game.camera_yaw)
		elif path.size() > 0:
			var destination := path[0]
			var flat := Vector3(destination.x-position.x,0,destination.z-position.z)
			if flat.length() < .45:
				path.remove_at(0)
			else:
				direction = flat.normalized()
		is_running = Input.is_action_pressed("sprint") and stamina > 1 and direction.length() > .1
		if Input.is_action_just_pressed("jump") and is_on_floor(): velocity.y = 5.6
	var speed := 8.2 if is_running else 5.2
	stamina = clampf(stamina + (-16.0 if is_running else 11.0)*delta,0,100)
	var acceleration:=65.0 if direction.length()>.01 else 95.0
	velocity.x = move_toward(velocity.x, direction.x*speed,delta*acceleration)
	velocity.z = move_toward(velocity.z, direction.z*speed,delta*acceleration)
	if not is_on_floor(): velocity.y -= 18*delta
	# A short curb should not stop a walking traveler or an automatic route.
	var horizontal:=Vector3(velocity.x,0,velocity.z)*delta
	if is_on_floor() and horizontal.length()>.01 and test_move(global_transform,horizontal):
		var raised:=global_transform
		raised.origin.y+=.32
		if not test_move(global_transform,Vector3.UP*.32) and not test_move(raised,horizontal):
			var ahead: Vector3=global_position+horizontal.normalized()*.45
			var query:=PhysicsRayQueryParameters3D.create(ahead+Vector3.UP*.38,ahead-Vector3.UP*.05)
			query.exclude=[get_rid()]
			var hit:=get_world_3d().direct_space_state.intersect_ray(query)
			if hit and hit.normal.y>.72 and hit.position.y-global_position.y>.05:
				position.y=hit.position.y+.01
	move_and_slide()
	moving = Vector2(velocity.x,velocity.z).length() > .25
	if moving:
		model.rotation.y = lerp_angle(model.rotation.y,atan2(velocity.x,velocity.z),1-exp(-delta*14))
		walk_time += delta*(11 if is_running else 8)
		foot_time += delta
		if is_on_floor() and foot_time > (.25 if is_running else .39):
			foot_time = 0
			game.footstep()
	var amplitude: float = (0.72 if is_running else .48) if moving else 0.0
	if animation:
		var clip: String="Jump" if not is_on_floor() else (("Sprint" if is_running else "Jog_Fwd") if moving else "Idle")
		if animation.current_animation!=clip:animation.play(clip,.12)
	if is_on_floor() and position.y > 1.5 and game.is_walkable(Vector2(position.x,position.z),false): last_safe = position
	if position.y < -3.5:
		position = last_safe + Vector3.UP*.2
		velocity = Vector3.ZERO
		path.clear()
		game.toast("The tide is strong. You return to the quay.")

func go_to(target: Vector3) -> bool:
	path = game.find_route(position,target)
	return path.size() > 0
