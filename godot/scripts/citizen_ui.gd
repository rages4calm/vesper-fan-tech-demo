extends RefCounted

var game: Node3D

func _init(owner_game: Node3D) -> void:
	game=owner_game

func label(p: Node,text: String,pos: Vector2,extent: Vector2,font_size:=22,heading:=false) -> Label:
	return game.make_label(p,text,pos,extent,font_size,game.PAPER,heading)

func button(p: Node,text: String,pos: Vector2,extent: Vector2,action: Callable) -> Button:
	return game.make_button(p,text,pos,extent,action)

func open_pack() -> void:
	if not game.playing:return
	game.play_effect("pack")
	var p=game.open_modal("Your backpack",690,570)
	game.texture_element(p,"res://assets/ui/pack.svg",Vector2(499,94),Vector2(136,136))
	label(p,"Carried through the city",Vector2(35,98),Vector2(410,40),26,true)
	label(p,"Gold coins\nFresh fish\nLoaves of bread",Vector2(40,171),Vector2(280,143),24,true).add_theme_constant_override("line_spacing",19)
	label(p,"%d\n%d\n%d"%[game.coins,game.fish,game.bread],Vector2(382,171),Vector2(88,143),24,true).add_theme_constant_override("line_spacing",19)
	var cargo: String=["No delivery cargo","Elowen’s sealed letter","A cedar case from Tomas","The carefully packed astrolabe","A token from the curator"][game.journal_stage]
	label(p,"Wrapped safely",Vector2(40,348),Vector2(550,30),24,true)
	label(p,cargo,Vector2(40,390),Vector2(570,38),22,true)
	if game.bread>0:
		button(p,"Eat a loaf",Vector2(38,467),Vector2(284,49),func():game.bread-=1;game.player.stamina=100;game.play_effect("eat");game.save_journey();open_pack())
	button(p,"Close the pack",Vector2(344,467),Vector2(310,49),game.close_modal)

func paperdoll() -> void:
	if not game.playing:return
	game.play_effect("page")
	var p=game.open_modal("The traveler",720,726)
	var container:=SubViewportContainer.new()
	container.position=Vector2(31,90)
	container.size=Vector2(316,527)
	container.stretch=true
	container.mouse_filter=Control.MOUSE_FILTER_IGNORE
	p.add_child(container)
	var view:=SubViewport.new()
	view.size=Vector2i(316,527)
	view.transparent_bg=true
	view.own_world_3d=true
	view.msaa_3d=Viewport.MSAA_4X
	container.add_child(view)
	var actor=load("res://assets/ranger.glb").instantiate()
	view.add_child(actor)
	actor.rotation.y=-.18
	var animation=actor.find_child("AnimationPlayer",true,false)
	if animation:animation.play("Idle")
	var world:=WorldEnvironment.new()
	world.environment=Environment.new()
	world.environment.background_mode=Environment.BG_CLEAR_COLOR
	world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color=Color("e2d6bd")
	world.environment.ambient_light_energy=.7
	view.add_child(world)
	var light:=DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-35,-30,0)
	light.light_energy=1.8
	view.add_child(light)
	var camera:=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=2.18
	camera.position=Vector3(0,1.03,4)
	view.add_child(camera)
	camera.look_at(Vector3(0,1.03,0))
	label(p,"A traveler of Britannia",Vector2(371,102),Vector2(310,55),28,true)
	label(p,"Ranger’s hood\nStudded leather\nLeather bracers\nTravel-worn boots",Vector2(374,182),Vector2(296,165),23,true).add_theme_constant_override("line_spacing",12)
	label(p,"Stamina  %d / 100"%int(game.player.stamina),Vector2(374,368),Vector2(288,38),23,true)
	var pack=game.texture_element(p,"res://assets/ui/pack.svg",Vector2(429,428),Vector2(142,142))
	pack.name="PaperdollBackpack"
	pack.mouse_filter=Control.MOUSE_FILTER_STOP
	pack.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	pack.tooltip_text="Double-click to open your backpack"
	pack.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.double_click:open_pack())
	label(p,"Double-click your backpack",Vector2(369,575),Vector2(310,30),20,true)
	button(p,"Journal",Vector2(35,648),Vector2(306,43),game.toggle_journal)
	button(p,"Return to the streets",Vector2(365,648),Vector2(318,43),game.close_modal)

func at_bank() -> bool:
	var b: Dictionary=game.buildings.mint
	return absf(game.player.position.x-b.pos[0])<b.width/2+8 and absf(game.player.position.z-b.pos[1])<b.depth/2+8

func bank() -> void:
	if not at_bank():
		game.toast("You must be near the Mint to open your bank box.")
		return
	game.play_effect("chest")
	show_bank()

func show_bank() -> void:
	var p=game.open_modal("The Mint · Your bank box",860,599)
	label(p,"In your pack",Vector2(45,107),Vector2(334,43),29,true)
	label(p,"Kept at the Mint",Vector2(461,107),Vector2(350,43),29,true)
	var keys=["coins","fish","bread"]
	var names=["Gold coins","Fresh fish","Bread"]
	for i in range(3):
		var key: String=keys[i]
		var y:=172.0+i*99
		label(p,names[i]+"  ·  "+str(game.get(key)),Vector2(46,y),Vector2(329,35),23,true)
		label(p,names[i]+"  ·  "+str(game.bank_items[key]),Vector2(461,y),Vector2(329,35),23,true)
		button(p,"Store all  →",Vector2(47,y+38),Vector2(332,34),func():transfer(key,true);show_bank())
		button(p,"←  Take all",Vector2(460,y+38),Vector2(354,34),func():transfer(key,false);show_bank())
	label(p,"Your bank box is saved with your journey. Delivery cargo stays in your pack.",Vector2(45,486),Vector2(769,42),17,true)
	button(p,"Close the bank box",Vector2(43,537),Vector2(773,39),game.close_modal)

func transfer(item: String,deposit: bool) -> void:
	if not at_bank() or item not in ["coins","fish","bread"]:return
	var amount: int=int(game.get(item)) if deposit else int(game.bank_items[item])
	var capacity:=100000 if item=="coins" else 9999
	amount=mini(amount,maxi(0,capacity-(int(game.bank_items[item]) if deposit else int(game.get(item)))))
	game.bank_items[item]+=amount if deposit else -amount
	game.set(item,int(game.get(item))+(-amount if deposit else amount))
	if amount>0:game.play_effect("coins" if item=="coins" else "pack")
	game.update_quest()
	game.save_journey()

func nearby_vendor() -> Dictionary:
	var nearest: Dictionary={}
	var distance:=8.0
	for npc in game.npcs:
		if npc.id not in ["baker","barkeep"]:continue
		var d: float=game.player.position.distance_to(npc.node.position)
		if d<distance:nearest=npc;distance=d
	return nearest

func vendor(selling: bool) -> void:
	var npc:=nearby_vendor()
	if npc.is_empty():
		game.toast("There is no trading vendor close enough to hear you.")
		return
	var p=game.open_modal(npc.name+" · "+("Sell" if selling else "Buy"),670,422)
	var message: String
	if selling:
		message="Fresh fish for the table. Three gold apiece." if npc.id=="barkeep" else "I bake bread, traveler. Garrick at the Marsh Hall buys fresh fish."
		if npc.id=="barkeep" and game.fish>0:
			button(p,"Sell %d fish · %d gold"%[game.fish,game.fish*3],Vector2(38,250),Vector2(594,47),func():game.coins+=game.fish*3;game.fish=0;game.play_effect("coins");game.update_quest();game.save_journey();vendor(true))
		elif npc.id=="barkeep":message+="\n\nYou have no fish in your backpack."
	else:
		message="Bread from The Twisted Oven. Two gold for a warm loaf." if npc.id=="baker" else "We buy the catch of the day. Lysa at The Twisted Oven sells bread."
		if npc.id=="baker":
			var buy=button(p,"Buy bread · 2 gold",Vector2(38,250),Vector2(594,47),func():
				if game.coins>=2:game.coins-=2;game.bread+=1;game.play_effect("coins");game.update_quest();game.save_journey();vendor(false))
			buy.disabled=game.coins<2 or game.bread>=9999
	var body=label(p,message,Vector2(38,103),Vector2(590,127),24,true)
	body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label(p,"Your purse: %d gold"%game.coins,Vector2(38,325),Vector2(330,40),22,true)
	button(p,"Farewell",Vector2(420,326),Vector2(214,44),game.close_modal)

func speech(text: String) -> void:
	var words:=text.strip_edges().to_lower()
	match words:
		"bank","banker","banco","banque":bank()
		"vendor buy","buy":vendor(false)
		"vendor sell","sell":vendor(true)
		"balance":
			if at_bank():game.toast("The Mint holds %d gold for you."%game.bank_items.coins)
			else:game.toast("You must be near the Mint to ask your balance.")
		"help":game.toast("Say bank near the Mint; vendor buy or vendor sell near a merchant.")
		_:pass
