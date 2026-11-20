# ABOUTME: CityRun is the playable city: map, crowd, player, HUD, and gates.
# ABOUTME: The city completes when the tower is off and the boss is cured.
class_name CityRun
extends Node2D

signal city_completed
signal east_road_taken
signal west_road_taken

const CITY_MAP_SCENE := preload("res://scenes/city/city_map.tscn")
const BRIDGE_GATE_SCENE := preload("res://scenes/city/bridge_gate.tscn")
const VAN_SCENE := preload("res://scenes/van/mobile_cafe.tscn")
# The tutorial scene stays a path, never a preload: the director script holds
# CityRun type hints, so a preload made this parse depend on the tutorial
# graph. When the director compiled first, that load rode a resource cycle
# and the city kit resolved its sleep zone scene empty (T102).
const TUTORIAL_SCENE_PATH := "res://scenes/tutorial/tutorial_director.tscn"
const MORGEN_REPLAY_SCENE := preload("res://scenes/tutorial/morgen_replay.tscn")
const OUTRO_SCENE := preload("res://scenes/ending/outro_director.tscn")
const MOONWALKER_MYSTERY_SCENE := preload("res://scenes/city/moonwalker_mystery.tscn")
const ADDRESS_AUDIO_SCENE := preload("res://scenes/audio/address_audio_director.tscn")
const DEX_CATALOG := preload("res://resources/dex/sleepy_dex.tres")
# Section 18: the saved bag resolves its item ids back to stacks through the
# catalog, so the reload rebuilds beans, gear, materials, and appliances.
const ITEM_CATALOG := preload("res://resources/items/catalog.tres")
const MAIN_ROUTE := preload("res://resources/quests/main_route.tres")
const FIELD_BASE_QUEST_BALANCE := preload("res://resources/balance/field_base_quest.tres")
const FIELD_BASE_QUEST_DEFINITION := preload("res://resources/quests/side/field_kitchen_stock.tres")
# The cold brew steep of the run, section 8: the tuned timer of the fridge.
const COLD_BREW_BALANCE := preload("res://resources/balance/cold_brew.tres")

# The bridge deck east of the tower block; the paywall gate stands on it.
# The tutorial and the outro directors read it through their run handle
# (run.BRIDGE_DECK_WIDTH), never by class name, so their compiles stay out
# of this script's graph (T112).
const BRIDGE_DECK_WIDTH := 240.0
# The wake line of a boss floats above its raised stage, higher than the
# crowd line rides above a sleeper body.
const STAGE_WAKE_LINE_OFFSET := Vector2(0.0, -170.0)

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
# Section 9, hardcore mode: the first sleep ends the game and deletes the slot.
const HARDCORE_DEATH_TEXT := "HARDCORE: THE FIRST SLEEP TOOK YOU. THE SAVE IS GONE."
# The hardcore way back runs through the menu and its mode select.
const MENU_SCENE_PATH := "res://scenes/main/menu.tscn"

@export var definition: CityDefinition
@export var balance: CityBalance
# The position on the route: San Coffesco is city 1, Steamtle city 2. Every
# city after the first opens with the van already owned, section 10.
@export var city_index: int = 1
# The next city east. The road-east trigger travels there once this city is
# complete. Null in the last city of the version.
@export var east_city_scene: PackedScene
# The city west of this one, section 23, as a scene path. The road-west
# trigger travels there once this city completes, so the finished route stays
# open both ways. The west stays a path, never an ext_resource of this scene:
# the east links already chain the city scenes, and a west link would close a
# load cycle the engine cannot resolve (T096). Empty in the first city.
@export var west_city_path := ""
# Section 19: the first ten minutes ride the first run as a tutorial. Only the
# intro scene of San Coffesco turns this on. The character creation screen of
# section 5 stands between the menu and this run.
@export var run_tutorial := false

var progress := CityProgress.new()
var unlock_state := UnlockState.new()
# The stubbed purchase interface of the paywall, T049: the one payment of
# section 4 lands through it; the real billing of T053 answers the same call.
var purchase_gateway := PurchaseGateway.new()
var van_state: MobileCafe = null
var moving_day := MovingDay.new()
# The SleepyDex rides the run: every spawned sleepwalker feeds it, section 9.
var dex := SleepyDex.new(DEX_CATALOG)
# Section 24: the Moonwalker mystery rides the run in every city of the
# route, its hint speakers and, in Pourtland, the dawn haunt itself.
var moonwalker_mystery: MoonwalkerMystery = null
# The quest state rides the run too: the main chain plus the side quests.
var quest_log := QuestLog.new()
# The signature quest of the city rides the run like the quest log,
# section 13: the Sleepvana stage of Steamtle. Null when the city has none.
var signature_quest: SignatureQuest = null
# Section 10, van level 3: the survivors that gather at the field base give
# small side quests. The giver rides the run beside the van and answers the
# interact key at the open base.
var field_base_quests: FieldBaseQuestGiver = null
# The brewing station of the run, section 8: it owns the brew stand overlay
# that turns the minigames into brewed cups.
var brew_pot: BrewPot = null
# The cold brew fridge of the run, section 8: the player starts the steep at
# the stand, the pot ticks it while he plays, and the save holds it, section 18.
var cold_fridge: ColdBrewFridge = null
# The school of the city master rides the run, section 8: the lessons train
# the player skills and grant the master recipes.
var master_lessons: MasterLessons = null
# The resident masters of the city at the cafe, section 8, built once by the
# school component and answered through the interact key.
var master_school: MasterSchool = null
# While a cinematic plays, the camera follows the director, not the player.
var cinematic_camera := false
# Section 21: the address loop rides the run. The director reads the poles,
# the crowd, and the tower, and mixes the loop by the sound rules.
var address_audio: AddressAudioDirector = null
# Section 18: the auto-save rides the run. It stays null in a headless test
# build until a test injects one; a player build owns the default slot.
var save_system: SaveSystem = null
# The travel triggers of the city, built once in build: the road east over the
# bridge deck and the road west back along the route, section 23.
var roads: CityRoads = null

var _map: CityMap = null
var _bridge_gate: BridgeGate = null
var _boss: Node2D = null
var _van: MobileCafeVan = null
var _crowd: Node2D = null
var _markers: QuestMarkers = null
var _tutorial: TutorialDirector = null
# The run state of the last save point, read once at build. Empty when this
# scene has no save of its own: only the writing scene reloads a slot.
var _saved_state: Dictionary = {}
# The world state the build restores: this scene's own save point, or the
# stored city world when a road just returned the player to a finished city,
# section 23. Empty on a first visit.
var _world_state: Dictionary = {}
# The traveler that a road just parked, taken once at build. Empty when no
# travel landed here, like a fresh start or a plain reload.
var _arriving_traveler: Dictionary = {}
var _has_saved_position := false
var _saved_position := Vector2.ZERO
# The cafe-entry poll of the first save point, section 18. The player starts
# inside the zone, so the flag starts false and the spawn is an entry.
var _player_was_in_cafe := false
# The replay of the Dr. Morgen video on the cafe television, section 22. It
# spawns on the first press at the set and plays every city's cafe.
var _television_replay: MorgenReplayPlayer = null
# The version ending of section 16 rides the last city of the route. It waits
# dormant until the city completes.
var _outro: OutroDirector = null
# The end screen owns the screen: the play controls stand down behind it.
var _end_screen_shown := false
var _end_screen_goes_to_menu := false

@onready var player: Player = $Player
@onready var hud: Hud = $Hud
@onready var camera: Camera2D = $Camera
@onready var touch_controls: TouchControls = $TouchControls
@onready var overlay: ColorRect = $UI/Overlay
@onready var status_label: Label = $UI/StatusLabel
@onready var restart_button: Button = $UI/RestartButton
@onready var continue_button: Button = $UI/ContinueButton


func _ready() -> void:
	overlay.visible = false
	status_label.visible = false
	restart_button.visible = false
	restart_button.pressed.connect(_on_restart_pressed)
	continue_button.visible = false
	continue_button.pressed.connect(_on_continue_pressed)
	touch_controls.player = player
	player.died.connect(_on_player_died)
	player.woke_in_cafe.connect(_on_player_woke_in_cafe)
	progress.city_completed.connect(_on_city_completed)
	# The payment writes the slot at once: a closed app never loses the bridge.
	unlock_state.unlocked.connect(func() -> void: _record_save_point(SaveData.POINT_PURCHASE))
	moving_day.finished.connect(func() -> void: hud.show_toast(MOVING_DAY_TEXT))
	hud.bind_dex(dex, player.brewing_library)
	dex.keychain_awarded.connect(_on_dex_complete)
	# The road-east beat always hands the quest chain east; only the scene
	# travel needs a destination. The last city keeps the road closed by
	# itself: the chain there has no next city. The road west hands the chain
	# back the same way, section 23.
	east_road_taken.connect(_on_east_road_taken)
	west_road_taken.connect(_on_west_road_taken)
	if save_system == null:
		# A system parked through a scene change arrives first: the death
		# reload and the menu continue hand the slot to the scene they load,
		# so headless and player builds reload through one path. A run that
		# arrives without one builds the default slot outside headless tests.
		save_system = SaveSystem.take_after_scene_change()
		if save_system == null and DisplayServer.get_name() != "headless":
			save_system = SaveSystem.new()
	if save_system != null:
		player.wake_ups.set_hardcore(save_system.saved_game_mode() == SaveData.MODE_HARDCORE)
	if definition != null and balance != null:
		build()


func build() -> void:
	# Section 8: the school of the city masters rides the run.
	master_lessons = MasterLessons.new(definition.masters, player.brewing_skills)
	# Section 18: a fresh run reloads the last save point, but only a slot this
	# very scene wrote. The intro tutorial stays the fresh start of the game
	# against any other slot, and a save of another city never bleeds in.
	if save_system != null:
		_saved_state = save_system.saved_run_state_for(scene_file_path)
	# Section 23: a road just landed here when a traveler waits. The world to
	# restore comes from this scene's own save point or, on a return trip,
	# from the city world the route saved in this city. A slot another scene
	# wrote never hands its world over: the intro tutorial stays the fresh
	# start of the game against it, like against any foreign run state.
	_arriving_traveler = MoveHandoff.take_arriving()
	_world_state = _saved_state
	if _world_state.is_empty() and not _arriving_traveler.is_empty() and save_system != null:
		_world_state = save_system.city_world(definition.city_id)
	# The purchase flag lands before the gate builds, so an unlocked bridge
	# opens at bind time instead of one frame later. A returning traveler paid
	# the bridge west of here, so its flag lands the same way.
	if not _saved_state.is_empty():
		unlock_state.load_state(bool(_saved_state.get("unlock", false)))
	elif not _arriving_traveler.is_empty():
		unlock_state.load_state(bool(_arriving_traveler.get("unlock", false)))
	# Section 5: the created look rides the save slot. The creation screen
	# before this run wrote it; a run without a slot keeps the placeholder.
	if save_system != null:
		player.appearance = save_system.saved_appearance(player.appearance_catalog)
	_map = CITY_MAP_SCENE.instantiate() as CityMap
	_map.definition = definition
	_map.balance = balance
	add_child(_map)
	var tower := _map.broadcast_tower()
	if tower != null:
		tower.switched_off.connect(_on_tower_switched_off)
		tower.birdsong.connect(_on_tower_birdsong)
	CityWalls.build(self, _map.city_size(), BRIDGE_DECK_WIDTH)
	_build_bridge_gate()
	# The road east opens with the completion of the city, section 4. The road
	# west, section 23, opens with it; the first city of the route names no
	# city west and builds no road west.
	var west_entered := Callable()
	if not west_city_path.is_empty():
		west_entered = _on_road_west_entered
	roads = CityRoads.build(
		self, _map.city_size(), BRIDGE_DECK_WIDTH, _on_road_east_entered, west_entered
	)
	_build_boss()
	_build_van()
	_build_master_school()
	_build_signature_quest()
	if definition.moonwalker_haunts or not definition.mystery_hints.is_empty():
		moonwalker_mystery = MOONWALKER_MYSTERY_SCENE.instantiate() as MoonwalkerMystery
		moonwalker_mystery.name = "MoonwalkerMystery"
		add_child(moonwalker_mystery)
		moonwalker_mystery.setup(self)
	_buildaddress_audio(tower)
	_spawn_crowd()
	_build_quest_markers()
	_build_field_base_quests()
	cold_fridge = ColdBrewFridge.new(COLD_BREW_BALANCE)
	brew_pot = BrewPot.new()
	brew_pot.name = "BrewPot"
	add_child(brew_pot)
	brew_pot.setup(self, cold_fridge)
	_apply_saved_state()
	# The scene authors the player at tree index 0 while this method adds the
	# map and the crowd after it, so the opaque block floor would draw over the
	# player sprite in every city. The player rides above the world children
	# instead. The outro and the tutorial stay after it in the tree: they are
	# CanvasLayers, so the order holds no draw meaning for them, while their
	# per-frame watch of player state (the tutorial drink lesson) must tick
	# after the player to see a channel close inside the player's physics step.
	move_child(player, -1)
	player.global_position = _map.cafe_spawn().global_position
	if _has_saved_position:
		# Section 18: the reload puts the player back at the save point, not
		# at the cafe spawn. The camera snaps to the same spot below.
		player.global_position = _saved_position
	camera.global_position = player.global_position
	var city_bounds := _map.city_size()
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(city_bounds.x + BRIDGE_DECK_WIDTH)
	camera.limit_bottom = int(city_bounds.y)
	_build_outro()
	if run_tutorial and city_index == 1:
		_build_tutorial()
	_resume_completed_city()


func _build_quest_markers() -> void:
	# The quest log holds the chain of this run, and the marker layer draws
	# its signals: the tower marker of section 19 step 7 comes first. The
	# quest state lands before the bind, so the markers draw the loaded chain
	# without replaying a beat. The chain rides the traveler when a road just
	# landed, so the finished beats of the whole route cross with the player.
	quest_log.setup(MAIN_ROUTE, definition.city_id)
	if not _arriving_traveler.is_empty():
		quest_log.load_state(SaveData.dict_or_empty(_arriving_traveler.get("quests", {})))
	elif not _world_state.is_empty():
		quest_log.load_state(SaveData.dict_or_empty(_world_state.get("quests", {})))
	_markers = QuestMarkers.new()
	_markers.name = "QuestMarkers"
	add_child(_markers)
	_markers.bind(quest_log, _map)


func _build_field_base_quests() -> void:
	# Section 10, van level 3: awakened survivors gather at the field base and
	# give small side quests. The giver stands above the tables and answers at
	# the van. It registers after the quest log setup, so the round joins the
	# log beside the signature quests of the route.
	field_base_quests = FieldBaseQuestGiver.new()
	field_base_quests.name = "FieldBaseQuestGiver"
	field_base_quests.balance = FIELD_BASE_QUEST_BALANCE
	field_base_quests.definition = FIELD_BASE_QUEST_DEFINITION
	add_child(field_base_quests)
	field_base_quests.setup(self)


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
	# outro director waits dormant on that city until it completes. A saved
	# outro lands on its step before the setup, so it never replays. A return
	# trip into the ended city reads the same stored step, section 23.
	if not _is_last_city():
		return
	_outro = OUTRO_SCENE.instantiate() as OutroDirector
	_outro.name = "Outro"
	add_child(_outro)
	if not _world_state.is_empty():
		_outro.flow.load_state(SaveData.dict_or_empty(_world_state.get("outro", {})))
	_outro.setup(self)
	_outro.flow.finished.connect(func() -> void: _record_save_point(SaveData.POINT_POST_GAME))


func _is_last_city() -> bool:
	# The route order of the main quest names the end of the version. When a
	# later version appends cities, the outro moves with the route.
	var city_ids := MAIN_ROUTE.city_ids()
	return not city_ids.is_empty() and city_ids.back() == definition.city_id


func _build_tutorial() -> void:
	# Section 19: the first ten minutes play inside this run. The director
	# rides the run as the "Tutorial" child; it hides the quest markers until
	# the survivor names the tower. A saved tutorial continues at its step,
	# so a closed app mid-lesson loses no lesson.
	_tutorial = (load(TUTORIAL_SCENE_PATH) as PackedScene).instantiate() as TutorialDirector
	_tutorial.name = "Tutorial"
	add_child(_tutorial)
	if not _world_state.is_empty():
		var tower := _map.broadcast_tower()
		_tutorial.load_saved_state(
			SaveData.dict_or_empty(_world_state.get("tutorial", {})),
			tower != null and tower.is_switched_off()
		)
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
	_update_cafe_entry_save_point()
	_update_touch_context()


func _update_cafe_entry_save_point() -> void:
	# The first save point of section 18: entry to the cafe. The poll runs
	# before the player's own physics step, so a beat that lands inside the
	# cafe this frame never writes the slot after itself: the sleep path must
	# not reload, and the death path reloads the slot as it stood.
	var inside := _player_inside_cafe() and not player.is_asleep()
	if inside and not _player_was_in_cafe:
		_record_save_point(SaveData.POINT_CAFE_ENTRY)
	_player_was_in_cafe = inside


func _update_touch_context() -> void:
	# The run opens the touch context buttons where their action works, so the
	# on-screen set matches the game rules, and it stands down while a screen-
	# owning overlay is up, like the SleepyDex phone or the end screen.
	touch_controls.set_button_available(TouchControls.ButtonKind.TOOL, player.toolbelt.has_any())
	touch_controls.set_button_available(TouchControls.ButtonKind.SWAP, player.toolbelt.has_any())
	# The cure weapon buttons open once the player finds the first weapon
	# along the route, section 11.
	touch_controls.set_button_available(TouchControls.ButtonKind.WEAPON, player.armory.has_any())
	touch_controls.set_button_available(TouchControls.ButtonKind.WSWAP, player.armory.has_any())
	touch_controls.set_button_available(TouchControls.ButtonKind.REFILL, _refill_available())
	touch_controls.set_button_available(
		TouchControls.ButtonKind.VAN, van_state != null and van_state.is_field_cafe()
	)
	touch_controls.set_button_available(TouchControls.ButtonKind.BREW, brew_pot.available_here())
	# The seedling button shows only while the bag holds one, section 6.
	touch_controls.set_button_available(
		TouchControls.ButtonKind.PLANT, player.inventory.has_item(Player.COFFEE_SEEDLING_ID)
	)
	var screen_locked := (
		_end_screen_shown
		or hud.dex_app.is_open()
		or brew_pot.stand() != null
		or (signature_quest != null and signature_quest.owns_screen())
		or (moonwalker_mystery != null and moonwalker_mystery.owns_screen())
	)
	touch_controls.set_overlay_open(screen_locked)


func _refill_available() -> bool:
	# The free refill works inside the cafe safe zone, section 11, and the
	# button hides once the pot has nothing left to fill.
	if _map == null:
		return false
	return (
		_player_inside_cafe() and (player.coffee_supply.cups < player.coffee_supply.carry_limit())
	)


func _player_inside_cafe() -> bool:
	if _map == null:
		return false
	var cafe_block := _map.find_block_of_kind(CityBlock.Kind.CAFE)
	if cafe_block == null:
		return false
	var safe_zone := cafe_block.safe_zone()
	return safe_zone != null and safe_zone.has_player_inside()


func city_map() -> CityMap:
	return _map


func van() -> MobileCafeVan:
	return _van


func boss() -> Node2D:
	# The boss fight of the city on its arena block. Null until the city has
	# one, like a later city before its boss fight ships.
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


func _interact_with_television() -> bool:
	# Section 22: the Dr. Morgen video replays on the cafe television. One
	# press at the set plays it again; any press inside skips it. A locked
	# player stands in a cinematic, so the set stays quiet for him.
	var television := _cafe_television()
	if television == null or not television.is_player_at_television():
		return false
	if player.is_input_locked():
		return false
	_morgen_replay().begin(player)
	return true


func _cafe_television() -> CafeTelevision:
	if _map == null:
		return null
	var cafe_block := _map.find_block_of_kind(CityBlock.Kind.CAFE)
	if cafe_block == null:
		return null
	return cafe_block.television()


func _morgen_replay() -> MorgenReplayPlayer:
	if _television_replay == null:
		_television_replay = MORGEN_REPLAY_SCENE.instantiate() as MorgenReplayPlayer
		_television_replay.name = "MorgenReplay"
		add_child(_television_replay)
	return _television_replay


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


func notify_boss_cured() -> void:
	# The boss fight beat calls this when the city boss drinks the cure.
	# Every boss fight of the route wires itself here, the band, the market,
	# and the keynote alike.
	progress.mark_boss_cured()
	quest_log.mark_boss_cured()
	_record_save_point(SaveData.POINT_BOSS_CURED)


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


func _build_bridge_gate() -> void:
	# The road east ends at the bridge paywall, section 4. The gate reads the
	# unlock state; the purchase itself stays external. The paywall stands at
	# the bridge out of San Coffesco only: every later city sits behind the
	# paid bridge, so its deck stays open.
	if city_index > 1:
		return

	var city_bounds := _map.city_size()
	_bridge_gate = BRIDGE_GATE_SCENE.instantiate() as BridgeGate
	_bridge_gate.position = Vector2(city_bounds.x + BRIDGE_DECK_WIDTH * 0.5, city_bounds.y * 0.5)
	_bridge_gate.paywall_reached.connect(func() -> void: hud.show_toast(PAYWALL_TEXT))
	_bridge_gate.opened.connect(func() -> void: hud.show_toast(ROAD_OPEN_TEXT))
	add_child(_bridge_gate)
	_bridge_gate.bind_unlock_state(unlock_state)


func _build_boss() -> void:
	# The boss of the city plays its fight on the arena landmark. The Sleep Jam
	# of Pourtland, the Fish Throwers of Steamtle, and the Sam Oatman keynote
	# of San Coffesco ride the same hook; the boss fights of the later cities
	# reuse it when they ship.
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
		band.band_woke.connect(_on_boss_woke.bind(SleepJamBand.WAKE_TOAST))
		WakeLinePresenter.attach(band, band.spoke, STAGE_WAKE_LINE_OFFSET)
	var throwers := _boss as FishThrowers
	if throwers != null:
		throwers.crew_woke.connect(_on_boss_woke.bind(FishThrowers.WAKE_TOAST))
		WakeLinePresenter.attach(throwers, throwers.spoke, STAGE_WAKE_LINE_OFFSET)
	var keynote := _boss as SamOatman
	if keynote != null:
		keynote.boss_woke.connect(_on_boss_woke.bind(SamOatman.WAKE_TOAST))
		WakeLinePresenter.attach(keynote, keynote.spoke, STAGE_WAKE_LINE_OFFSET)


func _on_boss_woke(toast: String) -> void:
	# The cure landed: the show of the city ends, the beat moves the chain,
	# and the city completes once the tower is off too, section 7. The wake
	# toast carries each boss's own beat.
	hud.show_toast(toast)
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
	if not _arriving_traveler.is_empty():
		van_state.load_state(VanHandoff.take_arriving_level(MobileCafe.Level.VAN))
	elif not _saved_state.is_empty():
		van_state.load_state(int(_saved_state.get("van_level", MobileCafe.Level.NONE)))
	elif city_index > 1:
		van_state.load_state(VanHandoff.take_arriving_level(MobileCafe.Level.VAN))
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


func _build_master_school() -> void:
	# Section 8: the master of the city teaches at the cafe, where the awake
	# coffee experts gather. The school component stands the residents on the
	# master spot and answers the interact key there.
	master_school = MasterSchool.new()
	master_school.name = "MasterSchool"
	add_child(master_school)
	master_school.setup(self)


func _spawn_crowd() -> void:
	# Every block holds its budgeted sleepwalkers, section 17. The builder
	# wires the dex feed and the wake lines, and the saved awake flags of a
	# reload or a return trip ride the spawn, T134.
	_crowd = CrowdBuilder.spawn(self, _map, definition, dex, CrowdBuilder.saved_flags(_world_state))


func _on_tower_switched_off() -> void:
	# Section 14: the switch restores 1 wake-up, up to the maximum; hardcore
	# holds none, so the restore lands as a no-op there. The map silences its
	# own speaker poles, the quest chain moves on, and the save lands after
	# the restore, so the slot holds the new wake-up count.
	progress.mark_tower_off()
	quest_log.mark_tower_off()
	player.wake_ups.restore_one()
	_record_save_point(SaveData.POINT_TOWER_SWITCH)


func _apply_saved_state() -> void:
	# Restore city world beats silently, then unpack either the arriving
	# traveler or this scene's own saved run state.
	var has_arriving_steep := ColdBrewHandoff.has_arriving()
	var arriving_steep := ColdBrewHandoff.take_arriving_state()
	if _world_state.is_empty() and _arriving_traveler.is_empty():
		if not arriving_steep.is_empty():
			cold_fridge.load_state(arriving_steep, player.brewing_library)
		return
	progress.load_state(SaveData.dict_or_empty(_world_state.get("progress", {})))
	moving_day.load_state(bool(_world_state.get("moving_day", false)))
	BossSaveState.apply_saved(_boss, SaveData.dict_or_empty(_world_state.get("boss", {})))
	var saved_phase := int(_world_state.get("tower_phase", -1))
	if saved_phase >= 0:
		_map.load_tower_state(saved_phase)
		var tower := _map.broadcast_tower()
		if tower != null and tower.is_switched_off():
			address_audio.cut_address()
	var saved_vault := bool(_world_state.get("vault_open", false))
	var vault := _map.locked_side_room()
	var vault_was_open := (
		saved_vault or (save_system != null and save_system.is_vault_open(definition.city_id))
	)
	if vault != null and vault_was_open:
		vault.load_state(true)
	if cold_fridge != null:
		var steep := arriving_steep
		if not has_arriving_steep:
			steep = SaveData.dict_or_empty(_world_state.get("cold_brew", {}))
		cold_fridge.load_state(steep, player.brewing_library)
	if not _arriving_traveler.is_empty():
		MoveHandoff.apply_arrival(
			_arriving_traveler, player, dex, unlock_state, ITEM_CATALOG, master_lessons
		)
		return
	if _saved_state.is_empty():
		return
	MoveHandoff.apply_carry(player, dex, _saved_state, ITEM_CATALOG, master_lessons)
	_has_saved_position = true
	_saved_position = _saved_state.get("position", Vector2.ZERO) as Vector2


func _record_save_point(point: String) -> void:
	# Section 18: one of the save points writes the whole slot at once.
	# The capture reads the live run, so the player can close the app the
	# moment the beat lands.
	if save_system == null or _map == null or definition == null:
		return
	save_system.record_save_point(point, _capture_run_state())


func _capture_run_state() -> Dictionary:
	# Every section 18 field of this run as one plain dict, the shape the
	# save system records. Position, meter, wake-ups, beans and gear (the
	# bag), cups, skill levels, SleepyDex, van level, quest state, and tower
	# state, plus the run identity that reloads this very scene.
	var supply := player.coffee_supply.save_state()
	var tutorial := {}
	if _tutorial != null:
		tutorial = _tutorial.flow.save_state()
	var outro := {}
	if _outro != null:
		outro = _outro.flow.save_state()
	var tower_phase := -1
	var tower := _map.broadcast_tower()
	if tower != null:
		tower_phase = tower.save_state()
	return {
		"city_id": definition.city_id,
		"scene_path": scene_file_path,
		"position": player.global_position,
		"meter_value": player.sleep_meter.save_state(),
		"wake_ups": player.wake_ups.save_state(),
		"bag": player.inventory.save_state(),
		"cups": int(supply.get("cups", 0)),
		"thermos_belt": bool(supply.get("thermos_belt", false)),
		"brew_hand": player.brew_hand.save_state(),
		"skills": player.brewing_skills.save_state(),
		"dex": dex.save_state(),
		"cold_brew": cold_fridge.save_state() if cold_fridge != null else {},
		"van_level": van_state.save_state() if van_state != null else MobileCafe.Level.NONE,
		"quests": quest_log.save_state(),
		"progress": progress.save_state(),
		"boss": BossSaveState.capture(_boss),
		"crowd_awake": CrowdBuilder.awake_flags(_crowd),
		"moving_day": moving_day.save_state(),
		"tutorial": tutorial,
		"outro": outro,
		"unlock": unlock_state.save_state(),
		"moonwalk_dodge": player.dodge_style == Player.DodgeStyle.MOONWALK,
		"master_lessons": master_lessons.save_state() if master_lessons != null else {},
		"game_mode": SaveData.MODE_HARDCORE if player.wake_ups.hardcore else SaveData.MODE_NORMAL,
		"tower_phase": tower_phase,
		"vault_open": _city_vault_open(),
	}


func _city_vault_open() -> bool:
	# The locked side room of this city, section 15: the slot stores the door.
	var room := _map.locked_side_room() if _map != null else null
	return room != null and not room.is_locked()


func _resume_completed_city() -> void:
	# A reload or a return trip into an already complete city, like a
	# boss-cured save, hands the roads back without replaying a beat: the last
	# city picks its outro up at the saved step, every earlier city arms the
	# road-east trigger. The road west arms in every complete city, section 23.
	if not progress.is_complete():
		return
	roads.arm_west()
	if _outro != null:
		# The flow refuses a second run on its own, so a saved outro past its
		# first step stays where the save left it.
		_outro.begin()
	else:
		roads.arm_east()


func _on_tower_birdsong() -> void:
	# The beat ends on birdsong; the toast confirms the restored wake-up.
	# Hardcore holds none, so the switch stays quiet there.
	if not player.wake_ups.hardcore:
		hud.show_toast(WAKE_UP_RESTORED_TEXT)


func _on_dex_complete() -> void:
	# Section 9: the completed dex says one line, and the line is the whole
	# reward. The keychain itself hangs on the van mirror, nothing more.
	hud.show_toast(SleepyDex.KEYCHAIN_LINE.to_upper())


func _on_player_woke_in_cafe() -> void:
	# The world stays as it is: only the player moves back to the cafe spawn.
	player.global_position = _map.cafe_spawn().global_position


func _on_player_died() -> void:
	# Section 18: full death at zero wake-ups reloads the last save, with the
	# wake-ups from that save; a run with no slot keeps the end screen.
	# Hardcore holds no wake-ups: the first sleep deletes the slot and ends
	# the run. The reload waits for idle time: a scene change inside the
	# physics step frees collision nodes mid-flush.
	if player.wake_ups.hardcore:
		if save_system != null:
			save_system.delete_save()
		_show_end_screen(HARDCORE_DEATH_TEXT, true, true)
		return
	if save_system != null and save_system.has_run_state():
		_reload_last_save.call_deferred()
		return
	_show_end_screen(DEATH_TEXT, true)


func _reload_last_save() -> void:
	# The slot rides the scene change, so the arriving run reads the same
	# document in a headless test and in a player build alike.
	MoveHandoff.reset_all()
	SaveSystem.park_for_scene_change(save_system)
	get_tree().change_scene_to_file(save_system.continue_scene_path())


func _on_city_completed() -> void:
	city_completed.emit()
	# Section 23: the finished city opens its road west, in the last city too,
	# where the outro holds the player until the credits end.
	roads.arm_west()
	if _outro != null:
		# Section 16: the version ends here. The Karen blocks the road east and
		# the credits catch her mid-sentence, so no completion screen shows and
		# the travel trigger never arms.
		_outro.begin()
		return
	roads.arm_east()
	_show_end_screen(CITY_COMPLETE_TEXT % [definition.display_name, definition.boss_name], false)


func _on_road_east_entered(body: Node2D) -> void:
	# The completed city hands the player to the next city east. The gate
	# before the trigger keeps the paywall, so this fires only past it.
	if not progress.is_complete() or not (body is Player):
		return
	east_road_taken.emit()


func _on_east_road_taken() -> void:
	# The road-east beat always hands the quest chain east; only the scene
	# travel needs a destination. The last city of the version keeps the road
	# closed by itself: the chain there has no next city.
	quest_log.travel_east()
	roads.travel(east_city_scene)


func _on_road_west_entered(body: Node2D) -> void:
	# Section 23: the completed city hands the player back to the city west of
	# it, so the post-game activities of the earlier cities stay reachable.
	if not progress.is_complete() or not (body is Player):
		return
	west_road_taken.emit()


func _on_west_road_taken() -> void:
	# The road west hands the chain back one city, then the road carries the
	# traveler. The destination loads at use time, like the tutorial scene,
	# because a west ext_resource would close a scene load cycle (T096).
	quest_log.travel_west()
	if west_city_path.is_empty():
		return
	roads.travel(load(west_city_path) as PackedScene)


func _show_end_screen(message: String, show_restart: bool, goes_to_menu := false) -> void:
	_end_screen_shown = true
	_end_screen_goes_to_menu = goes_to_menu
	player.set_input_locked(true)
	overlay.visible = true
	status_label.visible = true
	status_label.text = message
	restart_button.visible = show_restart
	continue_button.visible = not show_restart


func _on_continue_pressed() -> void:
	# The completion beat ends: the player takes the screen back, the touch
	# controls return, and the walk east can start.
	_end_screen_shown = false
	player.set_input_locked(false)
	overlay.visible = false
	status_label.visible = false
	continue_button.visible = false


func _on_restart_pressed() -> void:
	# A hardcore death ends the whole run: the menu owns the way back.
	MoveHandoff.reset_all()
	if _end_screen_goes_to_menu:
		get_tree().change_scene_to_file(MENU_SCENE_PATH)
		return
	get_tree().reload_current_scene()


func _unhandled_input(event: InputEvent) -> void:
	if _end_screen_shown or hud.dex_app.is_open() or player.is_asleep() or player.is_input_locked():
		return
	if event.is_action_pressed(&"refill_coffee"):
		refill_player_supply()
	elif event.is_action_pressed(&"interact"):
		if brew_pot.holds_interact():
			return
		if signature_quest != null and signature_quest.holds_interact():
			return
		if not master_school.interact() and not _interact_with_television():
			if (
				_bridge_gate == null
				or not _bridge_gate.try_purchase(purchase_gateway, unlock_state)
			):
				if signature_quest == null or not signature_quest.try_interact():
					if field_base_quests == null or not field_base_quests.try_interact(player):
						interact_with_van()
	elif event.is_action_pressed(&"call_van"):
		call_van()
	elif event.is_action_pressed(&"start_brew"):
		if _tutorial == null or _tutorial.flow.is_done():
			brew_pot.try_open()
