extends RefCounted

# Authored routines and exact transactions. Jev chooses between eligible goals;
# neither a model nor dialogue can mint items, pay rewards, or claim an arrival.
var town: Node
var game: Node3D
var social_due := 24.0
var dispatch_due := 9.0
const RESIDENTS = [
	["Rowan","Apprentice scribe","bm_fable","Collect stories at the Mint and visit the museum"],
	["Wren","Cloth merchant","bf_emma","Check the cloth stall and visit neighbouring trades"],
	["Hobb","Music student","bm_daniel","Practise at the music shop and seek company in the square"],
	["Mira","Bridge warden","af_heart","Walk the public crossings and keep doorways clear"],
	["Oren","Travelling bookbinder","bm_george","Visit the museum and rest at the hostel"],
	["Jory","Dockhand","am_michael","Carry timber from Tomas to Maren when the yard is short"],
	["Tessa","Potter","bf_isabella","Visit the tavern and inspect wares at the market"],
	["Bram","Inn porter","bm_fable","Carry Anwen's remedies to Sella at the inn"],
	["Ada","Clockmaker's apprentice","bf_emma","Work at the gadget shop and visit the square"]
]

func prepare(owner_town: Node) -> void:
	town=owner_town;game=town.game
	var index:=0
	for npc in game.npcs:
		if npc.id!="resident":continue
		var spec: Array=RESIDENTS[index]
		npc.id="neighbour_%d"%index;npc.name=spec[0];npc.role=spec[1]
		var label:=Label3D.new();label.text=npc.name;label.position.y=2.15;label.font_size=32;label.pixel_size=.0045;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.modulate=game.PAPER;label.visible=false
		npc.node.add_child(label);npc["label"]=label
		index+=1

func setup() -> void:
	for index in RESIDENTS.size():
		var a: Dictionary=town.actors["neighbour_%d"%index]
		a.personality=RESIDENTS[index][3]+". Finish commitments before accepting another errand."
	for id in town.actors:
		var a: Dictionary=town.actors[id]
		a["speed"]=2.3+float(town.actors.keys().find(id)%4)*.12
		if id not in ["fisherman","elowen","barkeep","baker","crier","resident_living"] and not id.begins_with("neighbour_"):
			a.personality="A conscientious "+a.npc.role+". Tend the workplace; take short local breaks and greet neighbours."
		# Distinguishable occupational colours, shared coherent clothing assets.
		if id in ["neighbour_5","neighbour_7"]:
			var parcel:=Node3D.new();a.npc.body.add_child(parcel)
			town.mesh_box(parcel,Vector3(.6,.3,.35),Vector3(0,1,.4),Color("866240"))
			town.mesh_box(parcel,Vector3(.055,.32,.37),Vector3(0,1,.4),Color("c9b489"))
			a["parcel"]=parcel;parcel.visible=false

func begin(resume: bool) -> void:
	social_due=town.clock+24.;dispatch_due=town.clock+9.
	var defaults={"timber":0,"remedies":0,"timber_deliveries":0,"remedy_deliveries":0,"player_parcel":"","player_parcels":0,"reputation":0,"reported_help":0,"supper_claimed":false,"gathering":false,"timber_source":6,"remedy_source":4}
	for key in defaults:
		if not resume or not town.world.has(key):town.world[key]=defaults[key]
	if not town.world.has("next_bake"):town.world["next_bake"]=town.clock+130
	for id in town.actors:
		var a: Dictionary=town.actors[id]
		a.next_choice=town.clock+18.+float(town.actors.keys().find(id))*2.
		if not resume:a.cargo="";a.trips=0;a["routine_step"]=0
		if not clear_at(a.home):
			var corrected: Vector3=local_stop(a,3)
			if clear_at(corrected):a.home=corrected;a.npc.home=corrected;a.node.position=corrected
	town.actors.neighbour_5.next_choice=town.clock+10
	town.actors.neighbour_7.next_choice=town.clock+18
	# Repair old saves that preserved a resting bartender in the counter.
	var bartender: Dictionary=town.actors.barkeep
	if not clear_at(bartender.node.position):bartender.node.position=bartender.home;bartender.path=PackedVector3Array()

func clear_at(point: Vector3) -> bool:
	var query:=PhysicsShapeQueryParameters3D.new()
	var shape:=CapsuleShape3D.new();shape.radius=.29;shape.height=1.35
	query.shape=shape;query.transform=Transform3D(Basis.IDENTITY,point+Vector3.UP*1.02);query.collision_mask=1
	return game.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func local_stop(a: Dictionary,seed: int) -> Vector3:
	# Search clear, reachable floor outside the footprint of furniture.
	for i in 16:
		var angle: float=(seed+i)*2.39996
		var point: Vector3=town.safe_point(a.home+Vector3(cos(angle)*3.1,0,sin(angle)*3.1))
		if point.distance_to(a.home)>1.8 and clear_at(point) and game.find_route(a.home,point).size()>1:return point
	return a.home

func options(a: Dictionary) -> Dictionary:
	if not a.cargo.is_empty() or a.action in ["collect_timber","carry_timber","collect_remedies","carry_remedies","report_trade"]:return {}
	if a.id=="neighbour_5" and town.world.timber<3 and town.world.timber_source>=3:
		return {"collect_timber":"Maren's boatyard needs timber: collect three planks from Tomas and physically carry them to Maren","work":"Finish today's dockside work first"}
	if a.id=="neighbour_7" and town.world.remedies<2 and town.world.remedy_source>=2:
		return {"collect_remedies":"Sella's inn needs remedies: collect two jars from Anwen and carry them to Sella","work":"Check the inn before taking the errand"}
	if a.id in ["fisherman","resident_living"]:return {}
	if a.id=="elowen" and town.world.courier_phase!="reported":return {}
	if a.id in ["barkeep","baker","banker","crier","shipwright","joiner","healer","innkeeper","curator"]:
		return {"work":"Return to the workplace to serve customers and receive deliveries","rounds":"Take a short local inspection, then return to work; remain in the neighbourhood"}
	return {"work":"Return to your own workplace and attend to your occupation","square":"Visit the Mint square, meet a neighbour and listen to the crier","harbor_visit":"Walk to the shipyard and inspect the waterfront","museum_visit":"Visit the museum and its curator","tavern_visit":"Visit the tavern for company; meals require actual fish and bread"}

func fallback(a: Dictionary,choices: Dictionary,previous: String) -> String:
	if choices.has("collect_timber"):return "collect_timber"
	if choices.has("collect_remedies"):return "collect_remedies"
	if choices.has("rounds"):return "rounds" if a.action=="work" else "work"
	if choices.has("square"):
		var sequence: Array=["square","work","harbor_visit","work","museum_visit","tavern_visit"]
		return sequence[(a.get("routine_step",0)+town.actors.keys().find(a.id))%sequence.size()]
	return previous

func observations(a: Dictionary) -> Dictionary:
	var observation: Dictionary={"carried_parcel":a.cargo,"completed_trips":a.trips}
	if a.id=="neighbour_5":observation["known_request"]="Maren asked for three planks";observation["timber_delivered"]=town.world.get("timber_deliveries",0)
	if a.id=="neighbour_7":observation["known_request"]="Sella requested two jars of remedies";observation["remedies_delivered"]=town.world.get("remedy_deliveries",0)
	return observation

func set_action(a: Dictionary,action: String) -> bool:
	var target: Vector3=a.home
	match action:
		"rounds":target=local_stop(a,a.trips);a.goal="Inspect the neighbourhood, then return to "+a.npc.role.to_lower()+" duties"
		"square":target=town.actors.crier.home+Vector3(-5+(a.trips%3)*2,0,4);a.goal="Visit the square and listen for news"
		"harbor_visit":target=town.actors.shipwright.home+Vector3(2,0,2);a.goal="Visit the waterfront and the shipwright"
		"museum_visit":target=town.actors.curator.home+Vector3(2,0,0);a.goal="Visit the museum and meet Aldren"
		"tavern_visit":target=town.actors.barkeep.home+Vector3(1,0,3);a.goal="Visit the Marsh Hall for company"
		"collect_timber":target=town.actors.joiner.home+Vector3(1,0,1);a.goal="Collect three planks for Maren"
		"carry_timber":target=town.actors.shipwright.home+Vector3(1,0,1);a.goal="Keep the promise: deliver three planks to Maren"
		"collect_remedies":target=town.actors.healer.home+Vector3(1,0,1);a.goal="Collect two jars for Sella"
		"carry_remedies":target=town.actors.innkeeper.home+Vector3(1,0,1);a.goal="Keep the promise: deliver two jars to Sella"
		"report_trade":target=town.actors.crier.home+Vector3(-2,0,0);a.goal="Tell Osric about the completed delivery"
		_:return false
	town.go(a,target)
	return true

func work(a: Dictionary) -> bool:
	match a.action:
		"collect_timber","collect_remedies":
			var timber: bool=a.action=="collect_timber"
			var provider: String="joiner" if timber else "healer"
			var key: String="timber_source" if timber else "remedy_source"
			var count: int=3 if timber else 2
			if a.node.position.distance_to(town.actors[provider].node.position)<4 and town.world[key]>=count and a.cargo.is_empty():
				town.world[key]-=count;a.cargo="timber" if timber else "remedies"
				town.remember(a.id,"Collected a parcel from "+town.actors[provider].npc.name+" and promised to carry it safely.")
				town.queue_conversation(["timber_collect","timber_give"] if timber else ["remedies_collect","remedies_give"],[a.id,provider])
				town.set_action(a.id,"carry_timber" if timber else "carry_remedies")
			return true
		"carry_timber","carry_remedies":
			var timber: bool=a.action=="carry_timber"
			var recipient: String="shipwright" if timber else "innkeeper"
			if not a.cargo.is_empty() and a.node.position.distance_to(town.actors[recipient].node.position)<4:
				town.world["timber" if timber else "remedies"]+=3 if timber else 2
				town.world["timber_deliveries" if timber else "remedy_deliveries"]+=1;a.cargo=""
				town.add_event("timber_delivery" if timber else "remedy_delivery",("Jory delivered three planks to Maren." if timber else "Bram delivered two jars of remedies to Sella."),[a.id,recipient])
				town.queue_conversation(["timber_arrival","timber_thanks"] if timber else ["remedies_arrival","remedies_thanks"],[a.id,recipient])
				town.set_action(a.id,"report_trade");a.next_choice=town.clock+100
			return true
		"report_trade":
			if a.node.position.distance_to(town.actors.crier.node.position)<4.2:
				share_news(a,town.actors.crier);town.set_action(a.id,"work");a.next_choice=town.clock+100
			return true
		"rounds":
			if a.action_time>18:town.set_action(a.id,"work");a.next_choice=town.clock+70
			return true
		"square","harbor_visit","museum_visit","tavern_visit":
			if a.action=="tavern_visit" and a.hunger>.25 and town.world.fish>0 and town.world.bread>0 and a.action_time>4:
				town.world.fish-=1;town.world.bread-=1;town.world.meals+=1;a.hunger=0
				town.add_event("meal",a.npc.name+" ate fish and bread at the Marsh Hall.",[a.id,"barkeep"])
			if a.action_time>40:town.set_action(a.id,"work");a.next_choice=town.clock+55
			return true
	return false

func tick(delta: float) -> void:
	var baker: Dictionary=town.actors.baker
	if town.clock>=town.world.get("next_bake",130) and baker.node.position.distance_to(baker.home)<2 and baker.action=="work":
		town.world["bakery_stock"]=town.world.get("bakery_stock",4)+4;town.world.next_bake=town.clock+150
		town.add_event("baked","Lysa baked four fresh loaves.",["baker"]);town.queue_conversation(["baking"],["baker"]);baker.action_time=0.
	if town.world.courier_phase=="reported" and town.world.bread<3 and town.clock-town.world.get("last_bread_delivery",0)>180 and town.world.get("bakery_stock",4)>=4:
		town.world.courier_phase="idle";town.set_action("elowen","report")
	for a in town.actors.values():
		if a.has("parcel"):a.parcel.visible=not a.cargo.is_empty()
		# A routine break is a world rule, not an AI claim. Staggered local
		# inspections ensure "keep working" cannot immobilize someone forever.
		var interval: float=70.+float(town.actors.keys().find(a.id))*4.
		if a.action=="work" and a.action_time>interval and a.path.is_empty() and a.hold<=0 and a.cargo.is_empty() and a.id not in ["fisherman","resident_living","elowen"]:
			town.set_action(a.id,"rounds");a.decision_mode="Scheduled workplace round";a.next_choice=town.clock+45.
	if town.clock<social_due:return
	social_due=town.clock+8
	for a in town.actors.values():
		if town.clock<a.next_social or a.hold>0 or not a.path.is_empty():continue
		for b in town.actors.values():
			if a.id==b.id or town.clock<b.next_social or b.hold>0:continue
			if a.action in ["collect","bread_delivery","report","deliver"] or b.action in ["collect","bread_delivery","report","deliver"]:continue
			if a.node.position.distance_to(b.node.position)>4.2:continue
			if not clear_sight(a.node.position,b.node.position):continue
			# Everyone gets meaningful memory, even when the player is elsewhere.
			a.next_social=town.clock+150;b.next_social=town.clock+150
			town.remember(a.id,"Met "+b.npc.name+" near "+game.map_name(a.npc.building)+".")
			town.remember(b.id,"Spoke with "+a.npc.name+" while crossing town.")
			share_news(a,b)
			if town.catalog.has("chat_"+a.id) and town.catalog.has("reply_"+b.id):town.queue_conversation(["chat_"+a.id,"reply_"+b.id],[a.id,b.id])
			return

func clear_sight(a: Vector3,b: Vector3) -> bool:
	var query:=PhysicsRayQueryParameters3D.create(a+Vector3.UP*1.4,b+Vector3.UP*1.4,1)
	return game.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func share_news(a: Dictionary,b: Dictionary) -> void:
	if "crier" not in [a.id,b.id]:return
	var witness: String=b.id if a.id=="crier" else a.id
	for event in town.events.duplicate():
		if witness in event.witnesses and "crier" not in event.witnesses and event.kind in ["timber_delivery","remedy_delivery","player_delivery"]:
			event.witnesses.append("crier")
			town.remember("crier",town.actors[witness].npc.name+" reported: "+event.text)

func record_help(witness: String) -> void:
	town.world.reputation+=1
	town.remember(witness,"The traveller helped us. I will remember that kindness.")
	game.toast("Vesper remembers · "+reputation_title())

func reputation_title() -> String:
	return "Friend of Vesper" if town.world.get("reputation",0)>=3 else ("A helping hand" if town.world.get("reputation",0)>0 else "New arrival")

func greet(npc: Dictionary) -> bool:
	var known: bool=town.actors[npc.id].memory.any(func(m):return "traveller helped" in m.text)
	if known and town.catalog.has("friend_"+npc.id):town.queue_conversation(["friend_"+npc.id],[npc.id],true);return true
	return false

func player_speech(id: String,words: String) -> bool:
	if words in ["notices","jobs","town","reputation"]:show_notices();return true
	if words=="share news" and id=="crier":
		for event in town.events:
			if event.kind=="player_delivery" and "crier" not in event.witnesses:event.witnesses.append("crier")
		town.announce(true);return true
	if words=="accept parcel" and id=="joiner":
		if town.world.player_parcel.is_empty() and town.world.timber_source>0:
			if town.world.timber>=6:game.toast("The boatyard has enough timber for now.");return true
			town.world.timber_source-=1;town.world.player_parcel="timber"
			town.remember(id,"Traveller promised to take one plank to Maren for five gold.")
			town.queue_conversation(["parcel_accept"],[id],true);game.save_journey()
		else:game.toast("Finish your current parcel, or wait for supplies.")
		return true
	if words=="deliver parcel" and id=="shipwright":
		if town.world.player_parcel=="timber":
			town.world.player_parcel="";town.world.timber+=1;town.world.player_parcels+=1;game.coins+=5;record_help(id)
			town.add_event("player_parcel","Traveller delivered a plank to Maren for five gold.",[id]);town.queue_conversation(["parcel_delivered"],[id],true);game.save_journey()
		else:game.toast("You are not carrying a parcel for Maren.")
		return true
	if words=="supper" and id=="barkeep":
		if town.world.reputation>=2 and not town.world.supper_claimed and town.world.fish>0 and town.world.bread>0:
			town.world.fish-=1;town.world.bread-=1;town.world.meals+=1;town.world.supper_claimed=true
			town.add_event("supper","Garrick served the helpful traveller a thank-you supper.",[id]);town.queue_conversation(["friend_supper"],[id],true);game.toast("A supper on the house · Your kindness is remembered.");game.save_journey()
		else:game.toast("Help twice around town; Garrick offers one supper when the kitchen is supplied.")
		return true
	return false

func show_notices() -> void:
	var panel: Control=game.open_modal("Life between the bridges",740,580)
	game.make_label(panel,reputation_title(),Vector2(32,103),Vector2(670,32),25,game.GOLD,true)
	var carrying: String="A plank for Maren — say deliver parcel near the shipwright." if town.world.player_parcel=="timber" else "No town parcel carried."
	var text: String="THE NEIGHBOURS NEED A HAND\nTomas, Hammer and Nail: say accept parcel, then carry it to Maren. Five gold.\nGarrick, Marsh Hall: ask for work. One fish earns three gold.\nOsric, Mint square: say news or share news after helping Garrick.\n\n"+carrying+"\n\nTHE TOWN TODAY\n%d fish deliveries · %d bread baskets · %d timber loads · %d remedy parcels\n%d meals shared · %d favours by you\n\nHelp twice, then ask Garrick for supper when his kitchen is supplied.\nPeople travel physically; the town carries on beyond your hearing."%[town.world.fish_deliveries,town.world.bread_deliveries,town.world.timber_deliveries,town.world.remedy_deliveries,town.world.meals,town.world.reputation]
	var notice:=RichTextLabel.new();notice.position=Vector2(32,151);notice.size=Vector2(675,325)
	notice.add_theme_font_override("normal_font",game.sans);notice.add_theme_font_size_override("normal_font_size",19)
	notice.add_theme_color_override("default_color",Color("493827"));notice.text=text
	notice.scroll_active=true;panel.add_child(notice)
	game.make_button(panel,"Back to the streets",Vector2(32,510),Vector2(675,43),game.close_modal,true)
