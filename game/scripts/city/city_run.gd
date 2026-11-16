# ABOUTME: CityRun is the playable city: map, crowd, player, HUD, and gates.
# ABOUTME: The city completes when the tower is off and the boss is cured.
class_name CityRun
extends Node2D

signal city_completed
signal east_road_taken

const CITY_MAP_SCENE := preload("res://scenes/city/city_map.tscn")
const BRIDGE_GATE_SCENE := preload("res://scenes/city/bridge_gate.tscn")
const VAN_SCENE := preload("res://scenes/van/mobile_cafe.tscn")
const MASTER_NPC_SCENE := preload("res://scenes/masters/master_npc.tscn")
const TUTORIAL_SCENE := preload("res://scenes/tutorial/tutorial_director.tscn")
const OUTRO_SCENE := preload("res://scenes/ending/outro_director.tscn")
const ADDRESS_AUDIO_SCENE := preload("res://scenes/audio/address_audio_director.tscn")
const DEX_CATALOG := preload("res://resources/dex/sleepy_dex.tres")
const MAIN_ROUTE := preload("res://resources/quests/main_route.tres")

const WALL_THICKNESS := 40.0
# The bridge deck east of the tower block; the paywall gate stands on it.
const BRIDGE_DECK_WIDTH := 240.0
# The travel trigger sits on the deck east of the open gate.
const ROAD_EAST_FRACTION := 0.85
const ROAD_EAST_RADIUS := 44.0

const DEATH_TEXT := "Your last wake-up is gone. The dream takes you."
const CITY_COMPLETE_TEXT := "%s is awake. The tower is silent and %s is up."
const WAKE_UP_RESTORED_TEXT := "WAKE-UP RESTORED"
const PAYWALL_TEXT := "THE BRIDGE IS LOCKED. ONE PAYMENT OPENS THE ROAD EAST."
const ROAD_OPEN_TEXT := "THE ROAD EAST IS OPEN."
const VAN_GIFT_TEXT := "THE SURVIVORS GIVE YOU THE VAN. LEVEL 1: TRANSPORT."
const VAN_KITCHEN_TEXT := "VAN LEVEL 2: THE KITCHEN. CARRY LIMIT %d. BREW OUTSIDE THE CAFE."
const VAN_FIELD_CAFE_TEXT := "VAN LEVEL 3: THE FIELD CAFE. PARK ANYWHERE."
const VAN_NEED_SCRAP_TEXT := "NOT ENOUGH SCRAP PARTS. THE NEXT LEVEL NEEDS %d."
const FIELD_BASE_OPEN_TEXT := "THE FIELD CAFE IS OPEN. THE SURVIVORS GATHER."
const FIELD_BASE_PACKED_TEXT := "THE FIELD CAFE IS PACKED."
const MOVING_DAY_TEXT := "MOVING DAY COMPLETE. ALL BELONGINGS ARE IN THE NEW CAFE."
const MASTER_LESSON_TEXT := "%s, LESSON %d OF %d. +%d SKILL."
const MASTER_RECIPE_TEXT := " NEW RECIPE: %s."
const MASTER_SCHOOL_DONE_TEXT := "%s HAS TAUGHT EVERY LESSON."

@export var definition: CityDefinition
@export var balance: CityBalance
# The position on the route: San Coffesco is city 1, Steamtle city 2. Every
# city after the first opens with the van already owned, section 10.
@export var city_index: int = 1
# The next city east. The road-east trigger travels there once this city is
# complete. Null in the last city of the version.
@export var east_city_scene: PackedScene
# Section 19: the first ten minutes ride the first run as a tutorial. Only the
# intro scene of San Coffesco turns this on; character creation (T046) stands
# before that run when it ships.
@export var run_tutorial := false

var progress := CityProgress.new()
var unlock_state := UnlockState.new()
var van_state: MobileCafe = null
var moving_day := MovingDay.new()
# The SleepyDex rides the run: every spawned sleepwalker feeds it, section 9.
var dex := SleepyDex.new(DEX_CATALOG)
# The quest state rides the run too: the main chain plus the side quests.
var quest_log := QuestLog.new()
# The signature quest of the city rides the run like the quest log,
# section 13: the Sleepvana stage of Steamtle. Null when the city has none.
var signature_quest: SignatureQuest = null
# The school of the city master rides the run, section 8: the lessons train
# the player skills and grant the master recipes.
var master_lessons: MasterLessons = null
# While a cinematic plays, the camera follows the director, not the player.
var cinematic_camera := false
# Section 21: the address loop rides the run. The director reads the poles,
# the crowd, and the tower, and mixes the loop by the sound rules.
var address_audio: AddressAudioDirector = null
# Section 18: the auto-save rides the run. It stays null in a headless test
# build until a test injects one; a player build owns the default slot.
var save_system: SaveSystem = null

var _map: CityMap = null
var _bridge_gate: BridgeGate = null
var _road_east: Area2D = null
var _boss: Node2D = null
var _van: MobileCafeVan = null
var _crowd: Node2D = null
var _markers: QuestMarkers = null
var _tutorial: TutorialDirector = null
# The version ending of section 16 rides the last city of the route. It waits
# dormant until the city completes.
var _outro: OutroDirector = null
# The end screen owns the screen: the play controls stand down behind it.
var _end_screen_shown := false

@onready var player: Player = $Player
@onready var hud: Hud = $Hud
@onready var camera: Camera2D = $Camera
@onready var touch_controls: TouchControls = $TouchControls
@onready var overlay: ColorRect = $UI/Overlay
@onready var status_label: Label = $UI/StatusLabel
@onready var restart_button: Button = $UI/RestartButton


func _ready() -> void:
	overlay.visible = false
	status_label.visible = false
	restart_button.visible = false
	restart_button.pressed.connect(_on_restart_pressed)
	touch_controls.player = player
	player.died.connect(_on_player_died)
	player.woke_in_cafe.connect(_on_player_woke_in_cafe)
	progress.city_completed.connect(_on_city_completed)
	moving_day.finished.connect(func() -> void: hud.show_toast(MOVING_DAY_TEXT))
	hud.bind_dex(dex, player.brewing_library)
	dex.keychain_awarded.connect(_on_dex_complete)
	# The road-east beat always hands the quest chain east; only the scene
	# travel needs a destination. The last city keeps the road closed by
	# itself: the chain there has no next city.
	east_road_taken.connect(_on_east_road_taken)
	master_lessons = MasterLessons.new(_definition_masters(), player.brewing_skills)
	if save_system == null and DisplayServer.get_name() != "headless":
		save_system = SaveSystem.new()
	if definition != null and balance != null:
		build()


func build() -> void:
	_map = CITY_MAP_SCENE.instantiate() as CityMap
	_map.definition = definition
	_map.balance = balance
	add_child(_map)
	var tower := _map.broadcast_tower()
	if tower != null:
		tower.switched_off.connect(_on_tower_switched_off)
		tower.birdsong.connect(_on_tower_birdsong)
	_build_walls()
	_build_bridge_gate()
	_build_road_east()
	_build_boss()
	_build_van()
	_build_masters()
	_build_signature_quest()
	_buildaddress_audio(tower)
	_spawn_crowd()
	_build_quest_markers()
	_apply_saved_tower_state()
	_build_outro()
	if run_tutorial and city_index == 1:
		_build_tutorial()
	player.global_position = _map.cafe_spawn().global_position
	camera.global_position = player.global_position
	var city_bounds := _map.city_size()
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(city_bounds.x + BRIDGE_DECK_WIDTH)
	camera.limit_bottom = int(city_bounds.y)


func _build_quest_markers() -> void:
	# The quest log holds the chain of this run, and the marker layer draws
	# its signals: the tower marker of section 19 step 7 comes first.
	quest_log.setup(MAIN_ROUTE, definition.city_id)
	_markers = QuestMarkers.new()
	_markers.name = "QuestMarkers"
	add_child(_markers)
	_markers.bind(quest_log, _map)


func _buildaddress_audio(tower: BroadcastTower) -> void:
	# Section 21: the address loop rides the run. The band boss and the
	# signature quest hand the director their diegetic songs when the city
	# holds them.
	address_audio = ADDRESS_AUDIO_SCENE.instantiate() as AddressAudioDirector
	address_audio.name = "AddressAudio"
	add_child(address_audio)
	address_audio.band = _boss as SleepJamBand
	address_audio.sleepvana = signature_quest as SleepvanaStage
	address_audio.setup(_map, player, tower, definition.city_id)


func _build_outro() -> void:
	# Section 16: the version ends after the last city of the main route. The
	# outro director waits dormant on that city until it completes.
	if not _is_last_city():
		return
	_outro = OUTRO_SCENE.instantiate() as OutroDirector
	_outro.name = "Outro"
	add_child(_outro)
	_outro.setup(self)


func _is_last_city() -> bool:
	# The route order of the main quest names the end of the version. When a
	# later version appends cities, the outro moves with the route.
	var city_ids := MAIN_ROUTE.city_ids()
	return not city_ids.is_empty() and city_ids.back() == definition.city_id


func _build_tutorial() -> void:
	# Section 19: the first ten minutes play inside this run. The director
	# rides the run as the "Tutorial" child; it hides the quest markers until
	# the survivor names the tower.
	_tutorial = TUTORIAL_SCENE.instantiate() as TutorialDirector
	_tutorial.name = "Tutorial"
	add_child(_tutorial)
	_tutorial.setup(self)


func _physics_process(_delta: float) -> void:
	if _map == null:
		return
	# The camera follows the player across the block row, unless a cinematic
	# holds it, like the finale pan of the tutorial.
	if not cinematic_camera:
		camera.global_position = player.global_position
	# Section 10, moving day: in every city after the first, the player walks
	# to the van by the new cafe and the belongings move in, once per city.
	if city_index > 1 and not moving_day.is_done() and _van != null:
		if _van.is_player_at_van():
			moving_day.unload()
	_update_touch_context()


func _update_touch_context() -> void:
	# The run opens the touch context buttons where their action works, so the
	# on-screen set matches the game rules, and it stands down while a screen-
	# owning overlay is up, like the SleepyDex phone or the end screen.
	touch_controls.set_button_available(TouchControls.ButtonKind.TOOL, player.toolbelt.has_any())
	touch_controls.set_button_available(TouchControls.ButtonKind.SWAP, player.toolbelt.has_any())
	touch_controls.set_button_available(TouchControls.ButtonKind.REFILL, _refill_available())
	touch_controls.set_button_available(
		TouchControls.ButtonKind.VAN, van_state != null and van_state.is_field_cafe()
	)
	touch_controls.set_button_available(TouchControls.ButtonKind.BREW, brewing_allowed_here())
	touch_controls.set_overlay_open(_end_screen_shown or hud.dex_app.is_open())


func _refill_available() -> bool:
	# The free refill works inside the cafe safe zone, section 11, and the
	# button hides once the pot has nothing left to fill.
	if _map == null:
		return false
	var cafe_block := _map.find_block_of_kind(CityBlock.Kind.CAFE)
	if cafe_block == null:
		return false
	var safe_zone := cafe_block.safe_zone()
	return (
		safe_zone != null
		and safe_zone.has_player_inside()
		and player.coffee_supply.cups < player.coffee_supply.carry_limit()
	)


func city_map() -> CityMap:
	return _map


func road_east() -> Area2D:
	# The travel trigger on the deck east of the gate. It listens only after
	# the city completes.
	return _road_east


func van() -> MobileCafeVan:
	return _van


func boss() -> Node2D:
	# The boss fight of the city on its arena block. Null until the city has
	# one, like San Coffesco before the Sam Oatman fight ships.
	return _boss


func quest_markers() -> QuestMarkers:
	return _markers


func brewing_allowed_here() -> bool:
	# Section 10: the city cafe brews. The van kitchen at level 2 or better
	# brews anywhere the van stands, outside the city cafe.
	if _map == null:
		return false
	var cafe_block := _map.find_block_of_kind(CityBlock.Kind.CAFE)
	if cafe_block != null:
		var safe_zone := cafe_block.safe_zone()
		if safe_zone != null and safe_zone.has_player_inside():
			return true
	return _van != null and _van.is_player_brewing_here()


func interact_with_van() -> MobileCafeVan.Interaction:
	# The interact key at the van upgrades it, or toggles the field base at
	# level 3. The van announces its own upgrade and field base beats.
	if _van == null:
		return MobileCafeVan.Interaction.NOT_AT_VAN
	var outcome := _van.interact(player)
	if outcome == MobileCafeVan.Interaction.NEED_SCRAP:
		hud.show_toast(VAN_NEED_SCRAP_TEXT % van_state.next_upgrade_cost())
	return outcome


func call_van() -> bool:
	# The call key, section 10: at level 3 the van parks where the player
	# stands and opens the field base there.
	if _van == null:
		return false
	return _van.call_to(player.global_position)


func crowd_count() -> int:
	if _crowd == null:
		return 0
	return _crowd.get_child_count()


func crowd_enemy(index: int) -> Sleepwalker:
	if _crowd == null:
		return null
	return _crowd.get_child(index) as Sleepwalker


func sleepy_dex() -> SleepyDex:
	return dex


func is_city_complete() -> bool:
	return progress.is_complete()


func is_moving_day_done() -> bool:
	return moving_day.is_done()


func road_east_active() -> bool:
	# The road east opens with the completion of the city. Before that, the
	# trigger stays deaf, open gate or not.
	return _road_east != null and _road_east.monitoring


func notify_boss_cured() -> void:
	# The boss fight beat calls this when the city boss drinks the cure.
	# The Sam Oatman fight wires itself here when backlog task T027 lands.
	progress.mark_boss_cured()
	quest_log.mark_boss_cured()


func refill_player_supply() -> int:
	# The free refill of the cup, section 11: it flows only inside the cafe.
	if _map == null:
		return 0
	var cafe_block := _map.find_block_of_kind(CityBlock.Kind.CAFE)
	if cafe_block == null:
		return 0
	var safe_zone := cafe_block.safe_zone()
	if safe_zone == null or not safe_zone.has_player_inside():
		return 0
	return player.refill_supply()


func _build_walls() -> void:
	# The city stands inside a hard boundary; the bridge deck reaches east.
	var walls := Node2D.new()
	walls.name = "Walls"
	add_child(walls)
	var city_bounds := _map.city_size()
	var total_width := city_bounds.x + BRIDGE_DECK_WIDTH
	var side_length := city_bounds.y + WALL_THICKNESS * 2.0
	_add_wall(
		walls,
		"Top",
		Vector2(total_width * 0.5, -WALL_THICKNESS * 0.5),
		Vector2(total_width + WALL_THICKNESS * 2.0, WALL_THICKNESS)
	)
	_add_wall(
		walls,
		"Bottom",
		Vector2(total_width * 0.5, city_bounds.y + WALL_THICKNESS * 0.5),
		Vector2(total_width + WALL_THICKNESS * 2.0, WALL_THICKNESS)
	)
	_add_wall(
		walls,
		"West",
		Vector2(-WALL_THICKNESS * 0.5, city_bounds.y * 0.5),
		Vector2(WALL_THICKNESS, side_length)
	)
	_add_wall(
		walls,
		"East",
		Vector2(total_width + WALL_THICKNESS * 0.5, city_bounds.y * 0.5),
		Vector2(WALL_THICKNESS, side_length)
	)


func _add_wall(parent: Node, wall_name: String, wall_position: Vector2, wall_size: Vector2) -> void:
	var wall := StaticBody2D.new()
	wall.name = wall_name
	wall.position = wall_position
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = wall_size
	shape_node.shape = shape
	wall.add_child(shape_node)
	parent.add_child(wall)


func _build_bridge_gate() -> void:
	# The road east ends at the bridge paywall, section 4. The gate reads the
	# unlock state; the purchase itself stays external.
	var city_bounds := _map.city_size()
	_bridge_gate = BRIDGE_GATE_SCENE.instantiate() as BridgeGate
	_bridge_gate.position = Vector2(city_bounds.x + BRIDGE_DECK_WIDTH * 0.5, city_bounds.y * 0.5)
	_bridge_gate.paywall_reached.connect(func() -> void: hud.show_toast(PAYWALL_TEXT))
	_bridge_gate.opened.connect(func() -> void: hud.show_toast(ROAD_OPEN_TEXT))
	add_child(_bridge_gate)
	_bridge_gate.bind_unlock_state(unlock_state)


func _build_road_east() -> void:
	# The road east opens when the city completes: the travel trigger stands on
	# the deck beyond the gate and waits for the player. A locked or missing
	# gate scene blocks the way on its own.
	_road_east = Area2D.new()
	_road_east.name = "RoadEast"
	_road_east.collision_layer = 0
	_road_east.collision_mask = 2
	_road_east.monitoring = false
	var shape_node := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = ROAD_EAST_RADIUS
	shape_node.shape = circle
	_road_east.add_child(shape_node)
	_road_east.body_entered.connect(_on_road_east_entered)
	var city_bounds := _map.city_size()
	_road_east.position = Vector2(
		city_bounds.x + BRIDGE_DECK_WIDTH * ROAD_EAST_FRACTION, city_bounds.y * 0.5
	)
	add_child(_road_east)


func _build_boss() -> void:
	# The boss of the city plays its fight on the arena landmark. The Sleep Jam
	# of Pourtland and the Fish Throwers of Steamtle ride the same hook; the
	# boss fights of the later cities reuse it when they ship.
	if definition.boss_scene == null:
		return
	var arena := _map.find_block_of_kind(CityBlock.Kind.BOSS_ARENA)
	if arena == null:
		return
	_boss = definition.boss_scene.instantiate() as Node2D
	add_child(_boss)
	_boss.global_position = arena.global_position + arena.size * 0.5
	var band := _boss as SleepJamBand
	if band != null:
		band.band_woke.connect(_on_band_woke)
	var throwers := _boss as FishThrowers
	if throwers != null:
		throwers.crew_woke.connect(_on_fish_crew_woke)


func _on_band_woke() -> void:
	# The cure landed: the song ends, the beat moves the chain, and the city
	# completes once the tower is off too, section 7.
	hud.show_toast(SleepJamBand.WAKE_TOAST)
	notify_boss_cured()


func _on_fish_crew_woke() -> void:
	# The cure landed in the apron: the last throw flies, the market cheers,
	# and the city completes once the tower is off too, section 7.
	hud.show_toast(FishThrowers.WAKE_TOAST)
	notify_boss_cured()


func _build_van() -> void:
	# Section 10: the van stands by the cafe. The survivors of the first city
	# hand it over when the player walks up. In every later city the player
	# arrives with the van, so the gift beat never plays there.
	var cafe_block := _map.find_block_of_kind(CityBlock.Kind.CAFE)
	if cafe_block == null or cafe_block.van_spot() == null:
		return
	_van = VAN_SCENE.instantiate() as MobileCafeVan
	add_child(_van)
	van_state = MobileCafe.new(_van.balance)
	if city_index > 1:
		van_state.load_state(MobileCafe.Level.VAN)
	_van.global_position = cafe_block.van_spot().global_position
	_van.bind_state(van_state)
	_van.bind_dex(dex)
	van_state.acquired.connect(func() -> void: hud.show_toast(VAN_GIFT_TEXT))
	van_state.upgraded.connect(_on_van_upgraded)
	_van.field_base_opened.connect(func() -> void: hud.show_toast(FIELD_BASE_OPEN_TEXT))
	_van.field_base_packed.connect(func() -> void: hud.show_toast(FIELD_BASE_PACKED_TEXT))
	van_state.apply_supply_level(player.coffee_supply)


func _on_van_upgraded(new_level: int) -> void:
	# The kitchen raises the carry limit at once, section 14.
	van_state.apply_supply_level(player.coffee_supply)
	match new_level:
		MobileCafe.Level.KITCHEN:
			hud.show_toast(VAN_KITCHEN_TEXT % player.supply_balance.mobile_cafe_level2_carry_limit)
		MobileCafe.Level.FIELD_CAFE:
			hud.show_toast(VAN_FIELD_CAFE_TEXT)


func _build_signature_quest() -> void:
	# Section 13: the signature side quest of the city plays at its named
	# sites. Sleepvana rides this hook; the Robotaxi Depot and the Aisle 7
	# follow when they ship.
	if definition.quest_scene == null:
		return
	var quest := definition.quest_scene.instantiate() as SignatureQuest
	if quest == null:
		return
	quest.name = "SignatureQuest"
	add_child(quest)
	quest.setup(self)
	signature_quest = quest


func bridge_gate() -> BridgeGate:
	return _bridge_gate


func _build_masters() -> void:
	# Section 8: the master of the city teaches at the cafe, where the awake
	# coffee experts gather. The masters stand side by side on the spot. A
	# quest can stand one more master later, like the Aisle 7 husband, so the
	# run finds its masters through the brewing-masters group.
	var cafe_block := _map.find_block_of_kind(CityBlock.Kind.CAFE)
	if cafe_block == null or cafe_block.master_spot() == null:
		return
	var spot := cafe_block.master_spot().global_position
	var count := definition.masters.size()
	for i: int in range(count):
		var master_data: BrewingMaster = definition.masters[i]
		var npc := MASTER_NPC_SCENE.instantiate() as MasterNpc
		npc.name = "Master" + master_data.master_id.capitalize()
		add_child(npc)
		npc.global_position = spot + Vector2(72.0 * float(i) - 36.0 * float(count - 1), 0.0)
		npc.bind_master(master_data, master_lessons)


func masters() -> Array[MasterNpc]:
	# The masters of this run, in tree order: the resident cafe masters first,
	# then any master a quest stood later.
	var found: Array[MasterNpc] = []
	for node: Node in get_tree().get_nodes_in_group(&"brewing_masters"):
		var npc := node as MasterNpc
		if npc != null and is_ancestor_of(npc):
			found.append(npc)
	return found


func interact_with_masters() -> bool:
	# One button at the master: a lesson while lessons remain, then only the
	# catchphrase. Returns false when no master stands at hand.
	for npc: MasterNpc in masters():
		if not npc.is_player_at_master():
			continue
		var outcome := npc.interact()
		if outcome == MasterNpc.Interaction.NOT_AT_MASTER:
			return false
		_announce_master_beat(npc, outcome)
		return true
	return false


func _announce_master_beat(npc: MasterNpc, outcome: MasterNpc.Interaction) -> void:
	# The chalkboard toast confirms the skill grant and every new recipe.
	var master_data := npc.master
	if outcome == MasterNpc.Interaction.SCHOOL_DONE:
		hud.show_toast(MASTER_SCHOOL_DONE_TEXT % master_data.display_name.to_upper())
		return
	var text := (
		MASTER_LESSON_TEXT
		% [
			master_data.display_name.to_upper(),
			master_lessons.lessons_taken(master_data.master_id),
			master_lessons.lessons_per_master(),
			player.brewing_balance.master_lesson_skill_gain,
		]
	)
	for recipe_id: String in npc.last_granted_recipes():
		var recipe := player.brewing_library.find_recipe(recipe_id)
		text += MASTER_RECIPE_TEXT % recipe.display_name.to_upper()
	if master_lessons.is_school_complete(master_data.master_id):
		text += " " + MASTER_SCHOOL_DONE_TEXT % master_data.display_name.to_upper()
	hud.show_toast(text)


func _definition_masters() -> Array[BrewingMaster]:
	if definition == null:
		return []
	return definition.masters


func _spawn_crowd() -> void:
	# Every block holds its budgeted sleepwalkers. The cafe block teaches the
	# basic throw, so it spawns only the first roster entry, the basic type.
	# Every later block cycles the full roster in order.
	_crowd = Node2D.new()
	_crowd.name = "Crowd"
	add_child(_crowd)
	var roster := definition.roster
	if roster.is_empty():
		return
	var global_marker := 0
	for i: int in range(_map.block_count()):
		var view := _map.block_view(i)
		for marker: Marker2D in view.crowd_spawn_markers():
			var entry := roster[0]
			if view.kind() != CityBlock.Kind.CAFE:
				entry = roster[global_marker % roster.size()]
			var enemy := entry.scene.instantiate() as Sleepwalker
			_crowd.add_child(enemy)
			enemy.global_position = marker.global_position
			# The first meeting with a type opens its SleepyDex entry,
			# section 9. The dex itself keeps the second meeting silent.
			enemy.first_met.connect(dex.meet)
			global_marker += 1


func _on_tower_switched_off() -> void:
	# Section 14: the switch restores 1 wake-up, up to the maximum. The city
	# map silences its own speaker poles, and the quest chain moves on.
	progress.mark_tower_off()
	quest_log.mark_tower_off()
	player.wake_ups.restore_one()
	_record_tower_save_point()


func _record_tower_save_point() -> void:
	# Save point of section 18: the tower switch writes the slot at once. The
	# phase travels as the plain number the tower save contract pins.
	if save_system == null:
		return
	var tower := _map.broadcast_tower()
	if tower == null:
		return
	save_system.record_tower_switch(definition.city_id, tower.save_state())


func _apply_saved_tower_state() -> void:
	# Section 18: the save holds the tower state, and a fresh run loads it
	# back into its tower. The intro tutorial is the fresh start of the game,
	# so a leftover slot from an earlier session must not darken its tower.
	# A loaded switch never replays its beat: the poles and the address go
	# quiet through the load path, the chain keeps its progress, and no
	# wake-up is granted again.
	if save_system == null or run_tutorial:
		return
	if not save_system.has_tower_state(definition.city_id):
		return
	var saved_phase := save_system.saved_tower_phase(
		definition.city_id, BroadcastTower.Phase.BROADCASTING
	)
	_map.load_tower_state(saved_phase)
	var tower := _map.broadcast_tower()
	if tower == null or not tower.is_switched_off():
		return
	progress.mark_tower_off()
	quest_log.mark_tower_off()
	address_audio.cut_address()


func _on_tower_birdsong() -> void:
	# The beat ends on birdsong; the toast confirms the restored wake-up.
	hud.show_toast(WAKE_UP_RESTORED_TEXT)


func _on_dex_complete() -> void:
	# Section 9: the completed dex says one line, and the line is the whole
	# reward. The keychain itself hangs on the van mirror, nothing more.
	hud.show_toast(SleepyDex.KEYCHAIN_LINE.to_upper())


func _on_player_woke_in_cafe() -> void:
	# The world stays as it is: only the player moves back to the cafe spawn.
	player.global_position = _map.cafe_spawn().global_position


func _on_player_died() -> void:
	_show_end_screen(DEATH_TEXT, true)


func _on_city_completed() -> void:
	city_completed.emit()
	if _outro != null:
		# Section 16: the version ends here. The Karen blocks the road east and
		# the credits catch her mid-sentence, so no completion screen shows and
		# the travel trigger never arms.
		_outro.begin()
		return
	if _road_east != null:
		_road_east.set_deferred(&"monitoring", true)
	_show_end_screen(CITY_COMPLETE_TEXT % [definition.display_name, definition.boss_name], false)


func _on_road_east_entered(body: Node2D) -> void:
	# The completed city hands the player to the next city east. The gate
	# before the trigger keeps the paywall, so this fires only past it.
	if not progress.is_complete() or not (body is Player):
		return
	east_road_taken.emit()


func _on_east_road_taken() -> void:
	# The scene travels east only when the city scene names the destination.
	# The last city of the version keeps the road closed with no destination.
	quest_log.travel_east()
	if east_city_scene != null:
		get_tree().change_scene_to_packed(east_city_scene)


func _show_end_screen(message: String, show_restart: bool) -> void:
	_end_screen_shown = true
	overlay.visible = true
	status_label.visible = true
	status_label.text = message
	restart_button.visible = show_restart


func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"refill_coffee"):
		refill_player_supply()
	elif event.is_action_pressed(&"interact"):
		# A quest overlay that holds the key, like the Aisle 7 Foam Watch,
		# consumes the press: its lift action shares the E key with interact.
		if signature_quest != null and signature_quest.holds_interact():
			return
		# The master at hand answers first; then the signature quest, like the
		# Sleepvana crowd at the van; the van takes the key otherwise.
		if not interact_with_masters():
			if signature_quest == null or not signature_quest.try_interact():
				interact_with_van()
	elif event.is_action_pressed(&"call_van"):
		call_van()
