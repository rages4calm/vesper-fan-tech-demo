extends Node

# Code owns physical movement, supplies, commitments, and event provenance.
# Jev only selects one of the currently valid actions offered by this simulation.
var game: Node3D
var actors: Dictionary = {}
var catalog: Dictionary = {}
var events: Array = []
var conversations: Array = []
var decisions: Array = []
var world := {"fish":0,"bread":0,"fish_deliveries":0,"bread_deliveries":0,"meals":0,"player_deliveries":0,"player_promise":false,"courier_phase":"idle","reported_bread":0}
var clock := 0.0
var started := false
var enabled := true
var decision_due := 10.0
var decision_busy := false
var decision_cursor := 0
var helper_url := ""
var helper_token := ""
var helper_status: Dictionary = {}
var connection_mode := "Rules fallback — helper not connected"
var status_due := 0.0
var request_generation := 0
var next_crier := 7.0
var crier_index := 0
var announced: Array = []
var spoken_at: Dictionary = {}
var variants: Dictionary = {}
var groups: Array = []
var active_group: Dictionary = {}
var active_line: Dictionary = {}
var speech_player: AudioStreamPlayer3D
var speech_gap := 0.0
var subtitle: Label
var developer: PanelContainer
var developer_text: RichTextLabel
var developer_due := 0.0
var voice_level := .9
var voice_muted := false
var metrics := {"utterances":0,"conversations":0,"arrivals":0,"repaths":0,"recoveries":0,"failed_routes":0,"max_queue":0,"overlaps":0,"stale_decisions":0,"frame_max_ms":0.0,"frame_samples":0,"frame_ms_sum":0.0}
var speech_history: Array = []
var sim_speed := 1.0
var live_calls := true
var dynamic_voice_busy := false
var last_voice_mode := "Included Kokoro voice library"
var ambience_duck := 1.0
var neighbours: RefCounted

func setup(owner_game: Node3D) -> void:
	game=owner_game
	catalog=JSON.parse_string(FileAccess.get_file_as_string("res://data/voice_catalog.json"))
	helper_url=OS.get_environment("VESPER_HELPER_URL")
	helper_token=OS.get_environment("VESPER_HELPER_TOKEN")
	enabled=not game.qa_mode or "--qa-town" in OS.get_cmdline_user_args() or "--town-film" in OS.get_cmdline_user_args() or "--qa-living" in OS.get_cmdline_user_args()
	if not enabled:return
	# Keep the player out of the world-obstacle layer used by citizens.
	# Walking beside someone on a narrow bridge must not trap their route.
	game.player.collision_layer=2
	neighbours=load("res://scripts/neighbours.gd").new()
	neighbours.prepare(self)
	for npc in game.npcs:adopt(npc)
	# The old tavern spawn sat inside the imported counter. Use its clear aisle.
	actors.barkeep.home=safe_point(Vector3(10,2.08,70))
	actors.barkeep.node.position=actors.barkeep.home
	actors.barkeep.npc.home=actors.barkeep.home
	var square: Vector3=Vector3(game.plan.spawn[0]+3,2.1,game.plan.spawn[1]-4)
	spawn_person("crier","Osric","Town crier","mint",square,false)
	spawn_person("resident_living","Nessa","Net mender","mint",square+Vector3(-4,0,3),true)
	actors.crier.personality="Warm, measured, precise. Reports witnessed facts and attributed notices, never rumours as fact."
	actors.fisherman.personality="Patient, quietly humorous fisherman. Values a kept promise, hates wasting a catch."
	actors.elowen.personality="Helpful museum courier. Finishes an errand before accepting another; knows the bridges."
	actors.barkeep.personality="Generous but practical tavernkeeper. Keeps an honest kitchen and welcomes neighbours."
	actors.baker.personality="Cheerful, particular baker. Values fresh bread and reliable deliveries."
	actors.resident_living.personality="Sociable net mender. Works patiently, enjoys company and a warm meal."
	neighbours.setup()
	make_props()
	make_interface()
	speech_player=AudioStreamPlayer3D.new()
	if AudioServer.get_bus_index("TownSpeech")==-1:
		AudioServer.add_bus();AudioServer.set_bus_name(AudioServer.bus_count-1,"TownSpeech")
	speech_player.bus="TownSpeech"
	speech_player.name="TownVoice"
	speech_player.unit_size=13.0
	speech_player.max_distance=27.0
	speech_player.attenuation_model=AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	speech_player.max_db=2.0
	add_child(speech_player)
	load_voice_settings()

func safe_point(point: Vector3) -> Vector3:
	var cell: Vector2i=game.closest_cell(point)
	return Vector3(cell.x,2.08,cell.y) if cell.x!=-999 else point

func adopt(npc: Dictionary) -> void:
	var previous: Node3D=npc.node
	var body:=CharacterBody3D.new()
	body.name="Living_"+npc.id
	body.position=safe_point(previous.position)
	body.collision_layer=0
	body.collision_mask=1
	body.floor_snap_length=.5
	body.floor_max_angle=deg_to_rad(48)
	var shape:=CollisionShape3D.new()
	var capsule:=CapsuleShape3D.new();capsule.radius=.28;capsule.height=1.7
	shape.shape=capsule;shape.position.y=.9;body.add_child(shape)
	game.add_child(body)
	for child in previous.get_children():child.reparent(body,false)
	previous.queue_free()
	npc.node=body
	npc["living"]=true
	actors[npc.id]={"id":npc.id,"npc":npc,"node":body,"home":body.position,"target":body.position,"path":PackedVector3Array(),"action":"work","goal":"Tend the workplace","memory":[],"inventory":0,"fatigue":0.1,"hunger":0.2,"action_time":0.,"hold":0.,"wait":0.,"stuck":0.,"last":body.position,"retries":0,"personality":"Helpful citizen","decision_mode":"rules","next_social":35.,"revision":0,"trips":0,"cargo":"","next_choice":0.,"last_choice":0.}

func spawn_person(id: String,person_name: String,role: String,building: String,position: Vector3,female: bool) -> void:
	var node:=Node3D.new();node.position=safe_point(position);game.add_child(node)
	var model: Node3D=load("res://assets/citizen-female.glb" if female else "res://assets/citizen-male.glb").instantiate()
	node.add_child(model)
	var label:=Label3D.new();label.text=person_name+" · "+role;label.position.y=2.25;label.font_size=30;label.pixel_size=.0045;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.modulate=game.PAPER;node.add_child(label)
	var npc={"id":id,"name":person_name,"role":role,"building":building,"node":node,"body":model,"animation":game.prepare_citizen_animation(model),"label":label,"home":node.position}
	game.npcs.append(npc);adopt(npc)

func mesh_box(parent: Node3D,extent: Vector3,position: Vector3,color: Color) -> MeshInstance3D:
	var mesh:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=extent;mesh.mesh=box
	var mat:=StandardMaterial3D.new();mat.albedo_color=color;mat.roughness=.88;mesh.material_override=mat;mesh.position=position;parent.add_child(mesh);return mesh

func make_props() -> void:
	for id in ["fisherman","elowen"]:
		var basket:=Node3D.new();basket.name="DeliveryBasket";actors[id].npc.body.add_child(basket)
		mesh_box(basket,Vector3(.55,.22,.34),Vector3(0,.95,.43),Color("725136"))
		for x in [-.28,.28]:mesh_box(basket,Vector3(.035,.37,.37),Vector3(x,1,.43),Color("a08455"))
		for z in [.24,.62]:
			for y in [.91,1.,1.1]:mesh_box(basket,Vector3(.56,.045,.03),Vector3(0,y,z),Color("a08455"))
		basket.visible=false;actors[id]["basket"]=basket
	var angler: Node3D=load("res://assets/harbor/fisherman.glb").instantiate()
	actors.fisherman.node.add_child(angler);angler.visible=false;actors.fisherman["angler"]=angler
	var anim: AnimationPlayer=angler.find_child("AnimationPlayer",true,false)
	if anim:
		for clip in anim.get_animation_list():anim.get_animation(clip).loop_mode=Animation.LOOP_LINEAR
		if anim.get_animation_list().size():anim.play(anim.get_animation_list()[0])
	var crier_body: Node3D=actors.crier.npc.body
	mesh_box(crier_body,Vector3(.46,.62,.035),Vector3(0,1.22,.21),Color("28495c"))
	mesh_box(crier_body,Vector3(.055,.59,.045),Vector3(0,1.22,.23),Color("c7a75f"))
	var bell:=MeshInstance3D.new();var bell_mesh:=CylinderMesh.new();bell_mesh.top_radius=.055;bell_mesh.bottom_radius=.12;bell_mesh.height=.17;bell.mesh=bell_mesh;bell.position=Vector3(.34,1.04,.22)
	var brass:=StandardMaterial3D.new();brass.albedo_color=Color("b99549");brass.metallic=.65;brass.roughness=.4;bell.material_override=brass;crier_body.add_child(bell)
	var board:=Node3D.new();board.position=actors.crier.home+Vector3(1.5,0,0);game.add_child(board)
	mesh_box(board,Vector3(.12,2.25,.12),Vector3(0,1.1,0),Color("5b4632"))
	mesh_box(board,Vector3(1.4,1.0,.12),Vector3(0,1.7,0),Color("58432c"))
	mesh_box(board,Vector3(1.13,.74,.025),Vector3(0,1.7,.08),Color("ddcfad"))
	var title:=Label3D.new();title.text="VESPER\nTOWN NOTICES";title.font_size=34;title.pixel_size=.003;title.modulate=Color("382e22");title.position=Vector3(0,1.73,.102);board.add_child(title)

func make_interface() -> void:
	subtitle=Label.new();subtitle.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM);subtitle.position=Vector2(-460,-173);subtitle.size=Vector2(920,96);subtitle.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;subtitle.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;subtitle.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;subtitle.add_theme_font_size_override("font_size",21);subtitle.add_theme_color_override("font_color",Color("f5ecdb"));subtitle.add_theme_color_override("font_shadow_color",Color.BLACK);subtitle.add_theme_constant_override("shadow_offset_x",2);subtitle.add_theme_constant_override("shadow_offset_y",2);subtitle.mouse_filter=Control.MOUSE_FILTER_IGNORE;game.hud.add_child(subtitle)
	subtitle.anchor_left=.5;subtitle.anchor_right=.5;subtitle.anchor_top=1.;subtitle.anchor_bottom=1.
	subtitle.offset_left=-460;subtitle.offset_right=460;subtitle.offset_top=-260;subtitle.offset_bottom=-134
	subtitle.add_theme_font_size_override("font_size",26)
	subtitle.add_theme_constant_override("outline_size",3)
	subtitle.add_theme_color_override("font_outline_color",Color(0,0,0,.85))
	developer=PanelContainer.new();developer.position=Vector2(22,100);developer.size=Vector2(690,610);developer.visible=false;game.ui.add_child(developer)
	var style:=StyleBoxFlat.new();style.bg_color=Color(.025,.04,.05,.96);style.content_margin_left=16;style.content_margin_right=16;style.content_margin_top=12;style.content_margin_bottom=12;developer.add_theme_stylebox_override("panel",style)
	developer_text=RichTextLabel.new();developer_text.custom_minimum_size=Vector2(650,585);developer_text.bbcode_enabled=true;developer_text.add_theme_font_size_override("normal_font_size",16);developer.add_child(developer_text)

func begin(resume: bool) -> void:
	if not enabled:return
	started=true;request_generation+=1;decision_busy=false;clock=0;events.clear();conversations.clear();groups.clear();active_group.clear();announced.clear();spoken_at.clear();next_crier=7;decision_due=12
	speech_player.stop();active_line.clear();subtitle.text=""
	speech_history.clear();decisions.clear();speech_gap=0.;variants.clear();crier_index=0
	for key in metrics:metrics[key]=0
	world={"fish":0,"bread":0,"fish_deliveries":0,"bread_deliveries":0,"meals":0,"player_deliveries":0,"player_promise":false,"courier_phase":"idle","reported_bread":0}
	for a in actors.values():
		a.node.position=a.home;a.node.velocity=Vector3.ZERO;a.path=PackedVector3Array();a.action="work";a.action_time=0.;a.memory=[];a.inventory=0;a.fatigue=.1;a.hunger=.2;a.hold=0.;a.wait=0.;a.revision+=1
	actors.resident_living.hunger=.8
	remember("fisherman","Garrick's kitchen starts short of fish; he asked me for a catch.")
	add_event("shortage","The Marsh Hall kitchen needs fish.",["barkeep","fisherman","crier"])
	if resume:load_state()
	else:
		actors.elowen.node.position=safe_point(actors.crier.home+Vector3(-2,0,0))
		set_action("fisherman","fish")
	neighbours.begin(resume)

func remember(id: String,text: String) -> void:
	if not actors.has(id):return
	var memory: Array=actors[id].memory
	if not memory.is_empty() and memory[-1].text==text:return
	memory.append({"time":snappedf(clock,.1),"text":text})
	while memory.size()>12:memory.pop_front()

func add_event(kind: String,text: String,witnesses: Array) -> void:
	var event={"id":str(Time.get_ticks_usec())+"_"+str(events.size()),"time":snappedf(clock,.1),"kind":kind,"text":text,"witnesses":witnesses.duplicate()}
	events.append(event);while events.size()>60:events.pop_front()
	for id in witnesses:remember(id,text)

func _unhandled_input(event: InputEvent) -> void:
	if not enabled:return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_F3:developer.visible=not developer.visible;get_viewport().set_input_as_handled()
		elif event.physical_keycode==KEY_F4:voice_muted=not voice_muted;save_voice_settings();game.toast("Town voices muted" if voice_muted else "Town voices on");get_viewport().set_input_as_handled()
		elif event.physical_keycode==KEY_N and game.playing and not game.chatting and not game.modal_open:neighbours.show_notices();get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not enabled:return
	if game.quitting:return
	if not game.playing:
		if speech_player.playing:speech_player.stop()
		subtitle.text="";return
	metrics.frame_samples+=1;metrics.frame_ms_sum+=delta*1000;metrics.frame_max_ms=maxf(metrics.frame_max_ms,delta*1000)
	update_speech(delta)
	var heard: bool=speech_player.playing and not voice_muted and voice_level>.01 and speech_player.global_position.distance_to(game.player.global_position)<speech_player.max_distance
	ambience_duck=move_toward(ambience_duck,.12 if heard else 1.0,delta*(6.0 if heard else .8))
	game.ambience.volume_db=linear_to_db(maxf(.0001,game.ambience_level*.50*ambience_duck))
	game.music.volume_db=linear_to_db(maxf(.0001,game.music_level*lerpf(.35,1.,ambience_duck)))
	status_due-=delta
	if status_due<=0:status_due=12;poll_status()
	developer_due-=delta
	if developer.visible and developer_due<=0:developer_due=.5;refresh_developer()
	if game.modal_open:return
	clock+=delta*sim_speed
	neighbours.tick(delta)
	if clock>=decision_due and not decision_busy:
		decision_due=clock+10;request_decision()
	if clock>=next_crier:
		announce();next_crier=clock+65
	if world.courier_phase=="idle" and clock>17 and actors.elowen.node.position.distance_to(actors.crier.node.position)<5:
		world.courier_phase="collect";remember("elowen","Promised Osric to collect four loaves from Lysa and deliver them to Garrick.")
		queue_conversation(["courier_request","courier_accept"],["crier","elowen"])
		set_action("elowen","collect")
	if world.courier_phase=="delivered" and actors.elowen.node.position.distance_to(actors.crier.node.position)<4:
		world.courier_phase="reported";world.reported_bread=world.bread_deliveries
		add_event("bread_report","Elowen reported her completed bread delivery to Osric.",["elowen","crier"])
		queue_conversation(["courier_report","report_ack"],["elowen","crier"])
	if world.fish==0 and int(clock)%180==0 and not events.any(func(e):return e.kind=="shortage" and clock-e.time<170):add_event("shortage","The Marsh Hall kitchen needs fish.",["barkeep"])

func _physics_process(delta: float) -> void:
	if not enabled or not started or not game.playing or game.modal_open or game.quitting:return
	for a in actors.values():
		a.fatigue=clampf(a.fatigue+delta*.00065,0,1);a.hunger=clampf(a.hunger+delta*.0005,0,1)
		a.hold=maxf(0,a.hold-delta);a.wait=maxf(0,a.wait-delta)
		move_actor(a,delta)
		if a.path.is_empty() and a.hold<=0:
			a.action_time+=delta*sim_speed
			work(a)
		var near: bool=a.node.position.distance_to(game.player.position)<9
		a.npc.label.visible=near and game.ui_visible and not game.cinematic_active
		if a.has("basket"):a.basket.visible=a.inventory>0
		if a.id=="fisherman":
			var fishing: bool=a.action=="fish" and a.path.is_empty() and a.hold<=0
			a.angler.visible=fishing;a.npc.body.visible=not fishing

func move_actor(a: Dictionary,delta: float) -> void:
	var body: CharacterBody3D=a.node
	var direction:=Vector3.ZERO
	if a.hold<=0 and not a.path.is_empty():
		# Consume reached points without a one-frame Idle between every grid cell.
		while not a.path.is_empty() and Vector2(a.path[0].x-body.position.x,a.path[0].z-body.position.z).length()<.38:
			a.path.remove_at(0)
			if a.path.is_empty():a.action_time=0.;metrics.arrivals+=1;a.retries=0;a.trips+=1
		if not a.path.is_empty():
			var difference: Vector3=a.path[0]-body.position;difference.y=0
			direction=difference.normalized()
	if direction.length()>.1:
		# Soft avoidance and nonblocking character layers keep narrow bridges usable.
		for other in actors.values():
			if other.id==a.id:continue
			var away: Vector3=body.position-other.node.position;away.y=0
			if away.length()>.05 and away.length()<.75:
				var side:=direction.cross(Vector3.UP)*(.5 if str(a.id)<str(other.id) else -.5)
				var cell:=Vector2i(roundi(body.position.x+side.x),roundi(body.position.z+side.z))
				if game.nav.is_in_boundsv(cell) and not game.nav.is_point_solid(cell):direction=(direction+side).normalized()
		var speed: float=a.get("speed",2.4)
		body.velocity.x=direction.x*speed;body.velocity.z=direction.z*speed
		a.npc.body.rotation.y=lerp_angle(a.npc.body.rotation.y,atan2(direction.x,direction.z),1-exp(-delta*8))
	else:body.velocity.x=move_toward(body.velocity.x,0,delta*25);body.velocity.z=move_toward(body.velocity.z,0,delta*25)
	if not body.is_on_floor():body.velocity.y-=18*delta
	var horizontal:=Vector3(body.velocity.x,0,body.velocity.z)*delta
	if body.is_on_floor() and horizontal.length()>.01 and body.test_move(body.global_transform,horizontal):
		var raised:=body.global_transform;raised.origin.y+=.32
		if not body.test_move(raised,horizontal) and not body.test_move(body.global_transform,Vector3.UP*.32):body.position.y+=.2
	body.move_and_slide()
	if direction.length()>.1 and body.position.distance_to(a.last)<.006:a.stuck+=delta
	else:a.stuck=0.
	if a.stuck>2.5:
		var obstacle_names: Array=[]
		for collision_index in body.get_slide_collision_count():
			var collider=body.get_slide_collision(collision_index).get_collider()
			if collider:obstacle_names.append(str(collider.name))
		print("TOWN_ROUTE_RETRY actor=",a.id," position=",body.position," target=",a.target," obstacles=",obstacle_names)
		a.stuck=0;a.retries+=1;metrics.repaths+=1
		a.path=game.find_route(body.position,a.target)
		if a.retries>=3:
			# Retain the commitment and destination instead of silently abandoning it.
			a.hold=3.;a.retries=0;metrics.failed_routes+=1
	if body.position.y<0:
		body.position=safe_point(a.last if a.last.y>1 else a.home);body.velocity=Vector3.ZERO;metrics.recoveries+=1
	a.last=body.position
	var clip: String="Walk" if direction.length()>.1 else ("Idle_Talking" if a.hold>0 else "Idle")
	if a.id in ["baker","barkeep"] and a.hold<=0 and int(a.action_time)%18<3:clip="Interact"
	if a.npc.animation and a.npc.animation.has_animation(clip) and a.npc.animation.current_animation!=clip:a.npc.animation.play(clip,.2)
	if a.npc.animation:a.npc.animation.speed_scale=a.get("speed",2.4)/2.4 if clip=="Walk" else 1.

func go(a: Dictionary,target: Vector3) -> void:
	a.target=safe_point(target);a.path=game.find_route(a.node.position,a.target);a.action_time=0.;a.retries=0
	if a.path.is_empty() and a.node.position.distance_to(a.target)>2:metrics.failed_routes+=1;a.wait=20

func set_action(id: String,action: String) -> void:
	var a: Dictionary=actors[id];a.action=action;a.action_time=0.;a.revision+=1
	if neighbours.set_action(a,action):return
	match action:
		"fish":a.goal="Catch three fish for Garrick";go(a,a.home)
		"deliver":a.goal="Carry the catch to Garrick";go(a,actors.barkeep.home+Vector3(1.4,0,1.3));queue_conversation(["fish_promise"],[id])
		"collect":a.goal="Collect four loaves from Lysa";go(a,actors.baker.home+Vector3(1.3,0,0))
		"bread_delivery":a.goal="Keep the bread delivery promise";go(a,actors.barkeep.home+Vector3(-1.3,0,1.3))
		"report":a.goal="Report the completed delivery to Osric";go(a,actors.crier.home+Vector3(-2,0,0))
		"meal":a.goal="Visit the Marsh Hall for fish and bread";go(a,actors.barkeep.home+Vector3(1.5,0,-1.4))
		"visit":a.goal="Visit Elowen in the square";go(a,actors.crier.home+Vector3(-3,0,3))
		"rest":a.goal="Take a proper rest";a.path=PackedVector3Array()
		"work":a.goal="Tend the workplace";go(a,a.home)

func work(a: Dictionary) -> void:
	if a.wait>0:return
	if neighbours.work(a):return
	match a.action:
		"fish":
			if a.action_time>32 and a.inventory<3 and a.node.position.distance_to(a.home)<3:
				a.inventory=3;a.action_time=0.;remember(a.id,"Landed three fish at the quay.");add_event("catch","Corin landed three fish.",["fisherman"])
				if not decision_busy:request_decision("fisherman")
		"deliver":
			if a.inventory>=3 and a.node.position.distance_to(actors.barkeep.node.position)<3.8:
				a.inventory-=3;world.fish+=3;world.fish_deliveries+=1
				add_event("fish_delivery","Corin handed three fish to Garrick.",["fisherman","barkeep"])
				queue_conversation(["fish_offer","fish_thanks"],["fisherman","barkeep"])
				set_action(a.id,"rest");a.wait=15.
		"collect":
			if a.node.position.distance_to(actors.baker.node.position)<3.5 and a.inventory==0 and world.get("bakery_stock",4)>=4:
				a.inventory=4;world["bakery_stock"]=maxi(0,world.get("bakery_stock",4)-4);world.courier_phase="carrying";add_event("bread_collected","Lysa gave four loaves to Elowen.",["baker","elowen"])
				queue_conversation(["bread_pickup","bread_handover"],["elowen","baker"]);set_action(a.id,"bread_delivery")
		"bread_delivery":
			if a.inventory==4 and a.node.position.distance_to(actors.barkeep.node.position)<3.8:
				a.inventory=0;world.bread+=4;world.bread_deliveries+=1;world.courier_phase="delivered"
				world["last_bread_delivery"]=clock
				add_event("bread_delivery","Elowen handed four loaves to Garrick.",["elowen","barkeep"])
				queue_conversation(["bread_arrival","bread_thanks"],["elowen","barkeep"]);set_action(a.id,"report")
		"meal":
			if a.node.position.distance_to(actors.barkeep.node.position)<4 and a.action_time>2:
				if world.fish>0 and world.bread>0:
					world.fish-=1;world.bread-=1;world.meals+=1;a.hunger=0.;a.fatigue=maxf(0,a.fatigue-.3)
					add_event("meal","Nessa ate fish and bread at the Marsh Hall.",["resident_living","barkeep"])
					queue_conversation(["meal_order","meal_served","meal_thanks"],["resident_living","barkeep"])
				else:queue_conversation(["meal_empty"],["barkeep","resident_living"]);remember(a.id,"Garrick was waiting for supplies when I visited.")
				set_action(a.id,"rest");a.wait=40.
		"rest":
			if a.action_time>35:
				a.fatigue=maxf(0,a.fatigue-.45);a.wait=10.
				if a.id=="fisherman":set_action(a.id,"fish")
				elif a.id=="resident_living":set_action(a.id,"meal" if a.hunger>.45 else "visit")
		"visit":
			if a.action_time>15 and clock>a.next_social:
				if a.node.position.distance_to(actors.elowen.node.position)<5:queue_conversation(["social_hello","social_reply"],["resident_living","elowen"]);a.next_social=clock+150
		"work":
			pass # Workplace production uses the persistent town clock in neighbours.

func valid_actions(id: String) -> Dictionary:
	var a: Dictionary=actors[id];var options: Dictionary={}
	if not a.path.is_empty() or a.hold>0 or a.wait>0:return options
	if clock<a.next_choice:return options
	match id:
		"fisherman":
			options={"rest":"Rest briefly and reduce fatigue"}
			if a.inventory>=3:options["deliver"]="Honor Garrick's request: physically carry the three caught fish to his kitchen"
			else:options["fish"]="Fish at the quay to supply the tavern"
		"resident_living":
			options={"rest":"Rest in place instead of pacing","visit":"Visit the square and talk with Elowen if she is present"}
			if a.hunger>.35:options["meal"]="Visit Garrick and ask whether a meal is available; current supplies are unknown until arrival"
		"elowen":
			if world.courier_phase=="reported":options={"rest":"Rest after completing the delivery","work":"Return to the Mint to assist museum visitors"}
	options.merge(neighbours.options(a))
	return options

func request_decision(preferred: String="") -> void:
	if decision_busy:return
	var ids: Array=actors.keys()
	var id: String=preferred if not preferred.is_empty() else ids[decision_cursor%ids.size()]
	decision_cursor+=1
	if preferred.is_empty():
		var best_due:=-INF
		for offset in ids.size():
			var candidate: String=ids[(decision_cursor+offset)%ids.size()]
			if valid_actions(candidate).size()<2:continue
			var due: float=clock-actors[candidate].next_choice
			if candidate=="fisherman" and actors[candidate].inventory>=3:due+=1000
			if candidate=="resident_living" and actors[candidate].hunger>.45:due+=30
			if due>best_due:best_due=due;id=candidate
	var options:=valid_actions(id)
	if options.size()<2:return
	var a: Dictionary=actors[id]
	var fallback: String="rest"
	if id=="fisherman":fallback="deliver" if a.inventory>=3 else ("rest" if a.fatigue>.75 else "fish")
	elif id=="resident_living":fallback="meal" if options.has("meal") and a.hunger>.45 else "rest"
	elif id=="elowen":fallback="work" if a.node.position.distance_to(a.home)>3 else "rest"
	fallback=neighbours.fallback(a,options,fallback)
	if not options.has(fallback):fallback=str(options.keys()[0])
	var state={"name":a.npc.name,"personality":a.personality,"action":a.action,"carried_items":a.inventory,"needs":{"fatigue":snappedf(a.fatigue,.05),"hunger":snappedf(a.hunger,.05)},"memories":a.memory.slice(-4),"observations":[]}
	if a.node.position.distance_to(actors.barkeep.node.position)<7:state.observations.append({"kitchen_fish":world.fish,"kitchen_bread":world.bread})
	state["occupation"]=a.npc.role
	state["seconds_at_current_activity"]=int(a.action_time)
	state["recent_choices"]=decisions.filter(func(d):return d.actor==id).slice(-2)
	state["local_work"]=neighbours.observations(a)
	var generation:=request_generation;var revision: int=a.revision
	decision_busy=true
	var result: Dictionary={"choice":fallback,"mode":"rules fallback","reason":"No local helper"}
	if not helper_url.is_empty() and live_calls:result=await http_json("/decision",{"state":state,"options":options,"fallback":fallback})
	decision_busy=false
	if generation!=request_generation or revision!=a.revision:metrics.stale_decisions+=1;return
	var choice: String=result.get("choice",fallback)
	if not valid_actions(id).has(choice):metrics.stale_decisions+=1;return
	a.decision_mode=result.get("mode","rules fallback");connection_mode=a.decision_mode+" · "+str(result.get("reason",result.get("model","local")))
	decisions.append({"time":snappedf(clock,.1),"actor":id,"choice":choice,"mode":a.decision_mode,"latency_ms":result.get("latency_ms",0)})
	while decisions.size()>40:decisions.pop_front()
	if choice!=a.action:set_action(id,choice)
	a["routine_step"]=a.get("routine_step",0)+1
	a.last_choice=clock;a.next_choice=clock+55.+float(ids.find(id)%7)*4.

func http_json(path: String,data: Dictionary={}) -> Dictionary:
	if helper_url.is_empty() or game.quitting:return {}
	var request:=HTTPRequest.new();request.timeout=7.;add_child(request)
	var headers:=PackedStringArray(["Content-Type: application/json","X-Vesper-Token: "+helper_token])
	var error:=request.request(helper_url+path,headers,HTTPClient.METHOD_GET if data.is_empty() else HTTPClient.METHOD_POST,JSON.stringify(data) if not data.is_empty() else "")
	if error!=OK:request.queue_free();return {}
	var response: Array=await request.request_completed
	request.queue_free()
	if response[1]!=200:return {}
	var parsed=JSON.parse_string(response[3].get_string_from_utf8())
	return parsed if parsed is Dictionary else {}

func shutdown() -> void:
	# Resolve suspended coroutines before destroying their HTTPRequest children.
	# Deleting a pending request without a completion strands its function state.
	request_generation+=1;enabled=false;started=false
	for child in get_children():
		if child is HTTPRequest:
			child.cancel_request()
			if not child.is_queued_for_deletion():child.request_completed.emit(HTTPRequest.RESULT_CONNECTION_ERROR,0,PackedStringArray(),PackedByteArray())
	if speech_player:speech_player.stop()
	groups.clear();active_group.clear();active_line.clear()
	# Allow a local voice-poll timer (0.3 seconds) to observe game.quitting.
	await get_tree().create_timer(.35).timeout

func poll_status() -> void:
	if helper_url.is_empty():return
	var result:=await http_json("/status")
	if result.is_empty():connection_mode="Rules fallback — helper unavailable"
	else:helper_status=result

func queue_conversation(topics: Array,participants: Array,priority: bool=false) -> void:
	if topics.is_empty() or groups.size()>=8:return
	var first: String=topics[0]
	if not priority and clock-float(spoken_at.get(first,-1000))<110:return
	var near_player:=false
	for id in participants:
		if actors.has(id) and actors[id].node.position.distance_to(game.player.position)<25:near_player=true
	# World actions still happen offscreen; distant dialogue is not broadcast globally.
	if not near_player:
		conversations.append({"time":clock,"topics":topics,"participants":participants,"heard":false})
		while conversations.size()>40:conversations.pop_front()
		return
	var lines: Array=[]
	for topic in topics:
		if not catalog.has(topic):continue
		var choices: Array=catalog[topic];var index: int=int(variants.get(topic,0))%choices.size();variants[topic]=index+1
		lines.append(choices[index].duplicate())
	if lines.is_empty():return
	var group={"lines":lines,"participants":participants,"created":clock,"priority":priority,"topics":topics}
	if priority:groups.push_front(group)
	else:groups.append(group)
	for id in participants:
		if actors.has(id):actors[id].hold=maxf(actors[id].hold,lines.size()*9.)
	spoken_at[first]=clock;metrics.max_queue=maxi(metrics.max_queue,groups.size())

func update_speech(delta: float) -> void:
	speech_player.volume_db=linear_to_db(maxf(.0001,0. if voice_muted else voice_level))+2.0
	if speech_player.playing:
		var id: String=active_line.get("speaker","")
		if actors.has(id):
			speech_player.global_position=actors[id].node.global_position+Vector3.UP*1.5
			subtitle.visible=actors[id].node.position.distance_to(game.player.position)<speech_player.max_distance and game.ui_visible
		return
	if not active_line.is_empty():
		speech_gap=.55;active_line.clear();subtitle.text=""
	speech_gap-=delta
	if speech_gap>0:return
	if active_group.is_empty():
		if groups.is_empty():return
		active_group=groups.pop_front()
		if clock-active_group.created>45:release_group();return
		metrics.conversations+=1
		conversations.append({"time":clock,"topics":active_group.topics,"participants":active_group.participants,"heard":true})
		while conversations.size()>40:conversations.pop_front()
	if active_group.lines.is_empty():release_group();return
	active_line=active_group.lines.pop_front()
	var speaker: String=active_line.speaker
	var npc: Dictionary=actors[speaker].npc if actors.has(speaker) else game.qa_npc(speaker)
	if npc.is_empty():active_line.clear();return
	for participant in active_group.participants:
		if actors.has(participant):
			actors[participant].hold=20.
			var face: Vector3=npc.node.position-actors[participant].node.position;face.y=0
			if face.length()>.1:actors[participant].npc.body.rotation.y=atan2(face.x,face.z)
	speech_player.global_position=npc.node.position+Vector3.UP*1.5
	speech_player.max_distance=32. if speaker=="crier" else 24.
	speech_player.stream=active_line.get("stream",null) if active_line.has("stream") else load(active_line.file)
	if speech_player.stream:
		speech_player.play();metrics.utterances+=1
		subtitle.text=npc.name+"\n"+active_line.text;subtitle.visible=npc.node.position.distance_to(game.player.position)<speech_player.max_distance
		speech_history.append({"time":clock,"id":active_line.id,"speaker":speaker,"text":active_line.text,"duration":speech_player.stream.get_length(),"position":[npc.node.position.x,npc.node.position.y,npc.node.position.z]})
		while speech_history.size()>150:speech_history.pop_front()
	else:active_line.clear()

func release_group() -> void:
	for id in active_group.get("participants",[]):
		if actors.has(id):actors[id].hold=0.
	active_group.clear();active_line.clear();subtitle.text=""

func announce(force: bool=false) -> void:
	if not force and (not groups.is_empty() or not active_group.is_empty()):return
	var topic: String=""
	var eligible: Dictionary={}
	var provenance: Dictionary={}
	for event in events:
		if event.id in announced or "crier" not in event.witnesses:continue
		var candidate: String=""
		if event.kind=="bread_report" and world.reported_bread>0:candidate="bread_news"
		elif event.kind=="timber_delivery":candidate="timber_news"
		elif event.kind=="remedy_delivery":candidate="remedies_news"
		elif event.kind=="player_delivery":candidate="player_news"
		elif event.kind=="museum_delivery":candidate="museum_news"
		elif event.kind=="shortage" and world.fish==0 and clock>45:candidate="shortage"
		if not candidate.is_empty():eligible[candidate]=event.text;provenance[candidate]=event.id
	if not eligible.is_empty():topic=str(eligible.keys()[0])
	if topic.is_empty():
		var rotation: Array=["welcome","bank","flavor","bread_open"]
		topic=rotation[crier_index%rotation.size()];crier_index+=1
	# Pick among verified notices, never ask a model to invent town events.
	if not eligible.is_empty() and live_calls and not helper_url.is_empty() and not decision_busy and actors.crier.node.position.distance_to(game.player.position)<30:
		eligible["bank"]="Remind nearby visitors how to use the Mint"
		var generation:=request_generation
		decision_busy=true
		var result:=await http_json("/decision",{"state":{"name":"Osric","role":"town crier","known_notices":eligible,"recent_announcements":speech_history.filter(func(line):return line.speaker=="crier").slice(-2)},"instructions":"Choose the most useful, fresh verified notice for nearby travellers. Prefer practical news and avoid repeating a notice. Only these notices are known.","options":eligible,"fallback":topic})
		decision_busy=false
		if generation!=request_generation:return
		var selected: String=result.get("choice",topic)
		if eligible.has(selected):topic=selected
		decisions.append({"time":clock,"actor":"crier","choice":topic,"mode":result.get("mode","rules fallback"),"latency_ms":result.get("latency_ms",0)})
		while decisions.size()>40:decisions.pop_front()
	if topic=="shortage" and world.fish>0:topic="flavor"
	if provenance.has(topic):announced.append(provenance[topic])
	queue_conversation([topic],["crier"],force)

func greet(npc: Dictionary) -> void:
	if not enabled:return
	if neighbours.greet(npc):return
	var topic: String="greet_"+str(npc.id)
	if catalog.has(topic):queue_conversation([topic],[npc.id],true)

func player_speech(text: String) -> void:
	if not enabled or game.nearby.is_empty():return
	var id: String=game.nearby.id
	if not actors.has(id):return
	var words:=text.to_lower().strip_edges()
	if neighbours.player_speech(id,words):return
	if id=="barkeep" and ("supplies" in words or "stock" in words):
		if not dynamic_voice_busy:speak_supplies()
		return
	if words in ["bank","banker","balance","vendor buy","vendor sell","buy","sell"]:return
	var intent: String="unknown"
	if "news" in words:intent="news"
	elif "deliver fish" in words:intent="deliver"
	elif "accept" in words or "i will" in words:intent="accept"
	elif "work" in words or "help" in words:intent="work"
	elif "remember" in words or "promise" in words:intent="memory"
	elif "bank" in words or "service" in words:intent="services"
	elif "hello" in words or "hi"==words:intent="hello"
	var speaker: Dictionary=actors[id]
	if intent=="unknown" and not helper_url.is_empty() and not decision_busy and live_calls:
		var response:=await http_json("/decision",{"state":{"name":speaker.npc.name,"player_said":text,"occupation":speaker.npc.role},"instructions":"Select the player's conversational intent. Unknown is valid; do not treat requests for impossible actions as permission.","options":{"news":"Asks what has happened in town","services":"Asks about bank or shops","work":"Asks for a job or how to help","memory":"Asks about our previous encounter or promise","hello":"Greeting","unknown":"Anything else, ambiguous or unsupported"},"fallback":"unknown"})
		if game.player.position.distance_to(speaker.node.position)>5:return
		intent=response.get("choice","unknown")
	remember(id,"Traveller said: "+text.left(100))
	match intent:
		"news":
			if id=="crier":announce(true)
			else:greet(speaker.npc)
		"hello":greet(speaker.npc)
		"services":
			if id=="crier":queue_conversation(["bank"],[id],true)
			else:greet(speaker.npc)
		"work":
			if id=="barkeep":queue_conversation(["player_help"],[id],true);game.toast("Say accept to promise one fish. Bring it back and say deliver fish.")
			elif id=="crier":queue_conversation(["work_direction"],[id],true)
			else:greet(speaker.npc)
		"accept":
			if id=="barkeep" and not world.player_promise:
				world.player_promise=true;remember(id,"Traveller promised one fish for three gold.");queue_conversation(["player_accept"],[id],true);game.save_journey()
		"deliver":
			if id=="barkeep":
				if not world.player_promise:queue_conversation(["player_no_promise"],[id],true)
				elif game.fish<1:queue_conversation(["player_no_fish"],[id],true)
				else:
					game.fish-=1;game.coins+=3;world.fish+=1;world.player_deliveries+=1;world.player_promise=false
					neighbours.record_help("barkeep")
					add_event("player_delivery","Traveller delivered one fish to Garrick for three gold.",["barkeep"])
					queue_conversation(["player_delivered"],[id],true);game.update_quest();game.save_journey()
		"memory":
			if id=="barkeep":queue_conversation(["player_waiting" if world.player_promise else ("player_remember" if world.player_deliveries>0 else "greet_barkeep")],[id],true)
			else:greet(speaker.npc)
		_:
			if id=="crier":queue_conversation(["unknown"],[id],true)
			else:greet(speaker.npc)

func refresh_developer() -> void:
	var text: String="[b]LIVING VESPER · F3 to close[/b]\n"+connection_mode+"\nDialogue: authored, state-selected. Voice: "+last_voice_mode+"\n"
	if not helper_status.is_empty():text+="Requests: %s / %s · input tokens: %s · est. $%.6f\nFailures: %s · %s\n"%[helper_status.usage.requests,helper_status.request_limit,helper_status.usage.input_tokens,helper_status.usage.estimated_usd,helper_status.failures,helper_status.last_error]
	if not helper_status.get("latencies_ms",[]).is_empty():text+="Last network latency: %s ms\n"%helper_status.latencies_ms[-1]
	text+="Kitchen: %d fish / %d bread · meals %d · player promise %s\n"%[world.fish,world.bread,world.meals,str(world.player_promise)]
	text+="Neighbours: %d · timber %d · remedies %d · reputation %s\n"%[actors.size(),world.get("timber",0),world.get("remedies",0),neighbours.reputation_title()]
	for a in actors.values():
		text+="\n[b]%s[/b] · %s (%s)\n%s\n"%[a.npc.name,a.action,a.decision_mode,a.goal]
		if not a.memory.is_empty():text+="Memory: "+a.memory[-1].text+"\n"
	text+="\n[b]Recent events[/b]\n"
	for event in events.slice(-5):text+="%ds · %s\n"%[int(event.time),event.text]
	text+="\n[b]Recent conversations[/b]\n"
	for c in conversations.slice(-4):text+="%ds · %s · %s\n"%[int(c.time),", ".join(c.topics),"heard" if c.heard else "out of range"]
	developer_text.text=text

func voice_options() -> void:
	var panel: Control=game.open_modal("Voices of Vesper",620,365)
	game.make_label(panel,"Town voices",Vector2(35,115),Vector2(180,30),23,game.PAPER,true)
	var slider:=HSlider.new();slider.position=Vector2(245,123);slider.size=Vector2(330,26);slider.max_value=1;slider.step=.01;slider.value=voice_level;panel.add_child(slider);slider.value_changed.connect(func(value):voice_level=value;save_voice_settings())
	game.make_button(panel,"Unmute voices" if voice_muted else "Mute voices",Vector2(35,183),Vector2(545,45),func():voice_muted=not voice_muted;save_voice_settings();voice_options())
	game.make_label(panel,"F4 toggles voices. Subtitles remain available.\nSpeak near a citizen with Enter; ask Osric for news.",Vector2(35,242),Vector2(550,58),18)
	game.make_button(panel,"Back",Vector2(35,310),Vector2(545,38),game.show_pause)

func save_voice_settings() -> void:
	if game.qa_mode:return
	var config:=ConfigFile.new();config.set_value("voice","volume",voice_level);config.set_value("voice","muted",voice_muted);config.save("user://town_voice.cfg")

func load_voice_settings() -> void:
	var config:=ConfigFile.new()
	if not game.qa_mode and config.load("user://town_voice.cfg")==OK:voice_level=clampf(config.get_value("voice","volume",.9),0,1);voice_muted=config.get_value("voice","muted",false)

func serialize() -> Dictionary:
	var people: Dictionary={}
	for id in actors:
		var a: Dictionary=actors[id]
		people[id]={"position":[a.node.position.x,a.node.position.y,a.node.position.z],"action":a.action,"action_time":a.action_time,"inventory":a.inventory,"fatigue":a.fatigue,"hunger":a.hunger,"memory":a.memory,"target":[a.target.x,a.target.y,a.target.z],"cargo":a.cargo,"trips":a.trips,"routine_step":a.get("routine_step",0)}
	return {"schema":1,"clock":clock,"world":world.duplicate(true),"actors":people,"events":events.duplicate(true),"announced":announced.duplicate(),"variants":variants.duplicate(),"spoken_at":spoken_at.duplicate(),"next_crier":next_crier}

func restore(data: Dictionary) -> void:
	if data.get("schema",0)!=1:return
	request_generation+=1
	clock=maxf(0,data.get("clock",0));world.merge(data.get("world",{}),true)
	events=data.get("events",[]);announced=data.get("announced",[]);variants=data.get("variants",{});spoken_at=data.get("spoken_at",{});next_crier=maxf(clock+5,data.get("next_crier",clock+20));decision_due=clock+10
	for id in data.get("actors",{}):
		if not actors.has(id):continue
		var a: Dictionary=actors[id];var saved: Dictionary=data.actors[id];var pos: Array=saved.get("position",[])
		if pos.size()==3:a.node.position=safe_point(Vector3(pos[0],pos[1],pos[2]))
		for key in ["inventory","fatigue","hunger","memory","cargo","trips","routine_step"]:a[key]=saved.get(key,a.get(key,0))
		set_action(id,saved.get("action","work"));a.action_time=saved.get("action_time",0)
		var target: Array=saved.get("target",[])
		if target.size()==3 and a.action not in ["rest"]:go(a,Vector3(target[0],target[1],target[2]))

func load_state() -> void:
	if not FileAccess.file_exists(game.save_path()):return
	var data=JSON.parse_string(FileAccess.get_file_as_string(game.save_path()))
	if data is Dictionary and data.get("town") is Dictionary:restore(data.town)

func speak_supplies() -> void:
	if helper_url.is_empty():greet(actors.barkeep.npc);game.toast("Live speech helper is offline; Garrick uses the included voice library.");return
	dynamic_voice_busy=true
	var generation:=request_generation
	var line: String="At last count, I have %d fish and %d loaves in the kitchen. The number of meals served to our neighbours is %d."%[world.fish,world.bread,world.meals]
	var job:=await http_json("/voice",{"text":line,"voice":"am_michael"})
	if not job.has("id"):dynamic_voice_busy=false;greet(actors.barkeep.npc);return
	var ready:=false
	for attempt in range(50):
		await get_tree().create_timer(.3).timeout
		if game.quitting:return
		var state:=await http_json("/voice/"+str(job.id))
		if state.get("ready",false):ready=true;last_voice_mode="Local Kokoro · "+("cache hit" if state.get("cached",false) else "asynchronously generated");break
		if state.has("error"):break
	if ready and generation==request_generation:
		var request:=HTTPRequest.new();request.timeout=4;add_child(request)
		if request.request(helper_url+"/voice/"+str(job.id)+".wav",PackedStringArray(["X-Vesper-Token: "+helper_token]))==OK:
			var response: Array=await request.request_completed
			if response[1]==200:
				var stream:=AudioStreamWAV.load_from_buffer(response[3])
				if stream and actors.barkeep.node.position.distance_to(game.player.position)<8:
					groups.push_front({"lines":[{"id":"live_supplies","speaker":"barkeep","text":line,"stream":stream}],"participants":["barkeep"],"created":clock,"priority":true,"topics":["supplies"]})
		request.queue_free()
	dynamic_voice_busy=false
