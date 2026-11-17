# ABOUTME: Aisle7Stage is the Aisle 7 side quest in the world: the wife with
# ABOUTME: the photo, the husband asleep in aisle 7, the Foam Watch brew, the
# ABOUTME: sweet hug, and the Turkish master, section 13 of GAME_DESIGN.md.
class_name Aisle7Stage
extends SignatureQuest

signal spoke(line: String)

const QUEST_ID := "aisle_7"
const TURKISH_METHOD_ID := "turkish"
# The quest brews the common bean at the roast the recipe pins, because the
# bean match of the Turkish recipe is any bean, section 15.
const QUEST_BEAN_ID := "house"
const QUEST_ROAST_ID := "medium"
const SITE_STORE := "The Hardware Store"

const FOAM_WATCH_SCENE := preload("res://scenes/minigames/foam_watch.tscn")
const HUSBAND_SCENE := preload("res://scenes/quests/aisle_7_husband.tscn")
const WIFE_SCENE := preload("res://scenes/quests/aisle_7_wife.tscn")
# The master scene stays a path, never a preload: the city run preloads the
# same scene, and a compile-time const binds an empty scene whenever another
# load of it is already running (T102).
const MASTER_NPC_SCENE_PATH := "res://scenes/masters/master_npc.tscn"

const GREET_LINE := "Please. My husband sleeps in aisle 7, between the screws and the sandpaper."
const PHOTO_LINE := "He drank only Turkish coffee, all his life. Brew him one cup, in front of him."
const CRY_LINE := "The foam... it tastes like our first morning."
const HUG_LINE := "Found you."
const LINE_HOLD_SECONDS := 4.0

const PHOTO_TOAST := "PHOTO RECEIVED. HE SLEEPS IN AISLE 7, BETWEEN THE SCREWS AND THE SANDPAPER."
const WAKE_TOAST := "HE WAKES. HE CRIES. SHE RUNS TO HIM."
const HUG_TOAST := "HE HOLDS HIS WIFE. THE ONLY SWEET HUG IN THE GAME."
const MASTER_TOAST := "THE SLEEPER BECOMES THE TEACHER. THE TURKISH MASTER IS OPEN."
const WEAK_CUP_TOAST := "A WEAK TURKISH CUP. THE HUSBAND SLEEPS ON. BREW AGAIN."
const BOILED_OVER_TOAST := "THE POT BOILED OVER. GREED COSTS THE CUP. BREW AGAIN."
const COLD_CUP_TOAST := "A COLD POT. NO FOAM. THE HUSBAND SLEEPS ON. BREW AGAIN."

const HUSBAND_LABEL := "THE HUSBAND"
const HUSBAND_HINT := "HE DRANK ONLY TURKISH COFFEE, ALL HIS LIFE."
# The wife waits in the aisle mouth, south of her sleeping husband.
const WIFE_OFFSET := Vector2(-60.0, 150.0)
# The screw shelf and the sandpaper rack flank the aisle, section 13.
const SCREW_SHELF_OFFSET := Vector2(-150.0, -40.0)
const SANDPAPER_SHELF_OFFSET := Vector2(150.0, -40.0)
const SHELF_SIZE := Vector2(110.0, 34.0)
const SHELF_EDGE_COLOR := Color(0.2, 0.15, 0.1, 1.0)
const SCREW_SHELF_COLOR := Color(0.62, 0.64, 0.7, 1.0)
const SANDPAPER_SHELF_COLOR := Color(0.82, 0.7, 0.48, 1.0)
const SHELF_TEXT_SIZE := 13
const SHELF_TEXT_COLOR := Color(0.9, 0.87, 0.78, 1.0)
# The master teaches a step south of the hugging pair.
const MASTER_OFFSET := Vector2(0.0, 84.0)
# The brew overlay rides above the HUD, like the tutorial views.
const OVERLAY_LAYER := 10

@export var balance: Aisle7Balance
@export var brewing_balance: BrewingBalance
# The Turkish recipe that wakes the husband, section 15.
@export var turkish_cure: Recipe
# The master the sleeper becomes when the hug ends.
@export var master: BrewingMaster
# The photo of the husband, the quest item the wife hands over.
@export var photo_item: ItemType

var quest: Aisle7Quest = null

var _run: CityRun = null
var _husband: Aisle7Husband = null
var _wife: Aisle7Wife = null
var _overlay_layer: CanvasLayer = null
var _foam_view: FoamWatchView = null
var _store_position := Vector2.ZERO
var _greeted := false
var _master_time_left := 0.0


func _ready() -> void:
	quest = Aisle7Quest.new(turkish_cure, brewing_balance)
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.name = "Aisle7Overlay"
	_overlay_layer.layer = OVERLAY_LAYER
	add_child(_overlay_layer)


func setup(run: CityRun) -> void:
	# The stage builds the store scene and wires every quest beat to the world:
	# the toasts, the walk, the hug, and the master unlock.
	_run = run
	_build_store()
	_wire_beats()


func _physics_process(delta: float) -> void:
	if quest == null or _run == null:
		return
	match quest.phase():
		Aisle7Quest.Phase.PHOTO_WAIT:
			_tick_photo_wait()
		Aisle7Quest.Phase.SWEET_HUG:
			_tick_hug(delta)
		Aisle7Quest.Phase.MASTER_OPEN:
			_tick_master(delta)
		_:
			pass


func try_interact() -> bool:
	# One button in the store: the photo at the wife, then the brew at the
	# husband. Anywhere else keeps the key for the van.
	if _run == null or quest == null:
		return false
	match quest.phase():
		Aisle7Quest.Phase.PHOTO_WAIT:
			return _try_take_photo()
		Aisle7Quest.Phase.HUSBAND_ASLEEP:
			return _try_brew()
		_:
			return false


func holds_interact() -> bool:
	# The Foam Watch overlay owns the interact key while it plays, because the
	# lift action shares the E key with interact.
	return _foam_view != null


func husband() -> Aisle7Husband:
	return _husband


func wife() -> Aisle7Wife:
	return _wife


func foam_watch_view() -> FoamWatchView:
	return _foam_view


func store_position() -> Vector2:
	return _store_position


func _build_store() -> void:
	# Aisle 7 of the hardware store, section 13: the husband sleeps at the site
	# anchor between the screw shelf and the sandpaper rack, and his wife waits
	# in the aisle mouth.
	var store := _run.city_map().find_quest_site(SITE_STORE)
	if store == null or store.quest_site_marker() == null:
		return
	_store_position = store.quest_site_marker().global_position
	_husband = HUSBAND_SCENE.instantiate() as Aisle7Husband
	_husband.name = "Husband"
	_husband.quest = quest
	_husband.idle_text = "%s\n%s" % [HUSBAND_LABEL, HUSBAND_HINT]
	_husband.cry_line = CRY_LINE
	add_child(_husband)
	_husband.global_position = _store_position
	_wife = WIFE_SCENE.instantiate() as Aisle7Wife
	_wife.name = "Wife"
	add_child(_wife)
	_wife.global_position = _store_position + WIFE_OFFSET
	queue_redraw()


func _wire_beats() -> void:
	quest.husband_woke.connect(_on_husband_woke)
	quest.sweet_hug.connect(_on_sweet_hug)


func _tick_photo_wait() -> void:
	# The wife greets the player once when he walks up, so the player learns
	# where the husband sleeps before the photo.
	if _greeted or _wife == null or not _wife.is_player_near():
		return
	_greeted = true
	_wife.speak(GREET_LINE, LINE_HOLD_SECONDS)


func _tick_hug(delta: float) -> void:
	# The wife crosses the aisle to her husband; her arrival ends in the hug.
	if _wife == null:
		return
	if _wife.step_walk(delta, balance.wife_walk_speed, balance.hug_arrive_radius):
		quest.hug_completed()


func _tick_master(delta: float) -> void:
	# The hug holds; then the sleeper becomes the teacher.
	if _master_time_left <= 0.0:
		return
	_master_time_left = maxf(0.0, _master_time_left - delta)
	if _master_time_left == 0.0:
		_spawn_master()


func _try_take_photo() -> bool:
	if _wife == null or not _wife.is_player_near():
		return false
	if not quest.take_photo():
		return false
	_run.quest_log.accept(QUEST_ID)
	_run.player.pickup_item(photo_item, 1)
	_wife.set_photo_held(false)
	_wife.speak(PHOTO_LINE, LINE_HOLD_SECONDS)
	_run.hud.show_toast(PHOTO_TOAST)
	return true


func _try_brew() -> bool:
	# The player stands at the husband and brews one Turkish cup in front of
	# him: the Foam Watch opens, and its result becomes the served cup.
	if _foam_view != null:
		return true
	if _husband == null:
		return false
	if (
		_run.player.global_position.distance_to(_husband.global_position)
		> balance.brew_stand_radius
	):
		return false
	_open_foam_watch()
	return true


func _open_foam_watch() -> void:
	_foam_view = FOAM_WATCH_SCENE.instantiate() as FoamWatchView
	_foam_view.name = "Aisle7FoamWatch"
	_foam_view.method = _run.player.brewing_library.find_method(TURKISH_METHOD_ID)
	_foam_view.finished.connect(_on_foam_finished)
	_overlay_layer.add_child(_foam_view)
	_run.player.set_input_locked(true)


func _close_foam_watch() -> void:
	if _foam_view == null:
		return
	_foam_view.queue_free()
	_foam_view = null
	_run.player.set_input_locked(false)


func _on_foam_finished(watch_result: FoamResult) -> void:
	# The watch ends: the brew trains the Turkish skill, the cup lands in front
	# of the husband, and a failed brew leaves him asleep with a hint.
	_close_foam_watch()
	_run.player.brewing_skills.record_brew(TURKISH_METHOD_ID, watch_result.score)
	var cup := _served_cup(watch_result.score)
	if _husband.try_wake(cup):
		return
	_run.hud.show_toast(_failed_brew_toast(watch_result.outcome))


func _served_cup(score: float) -> BrewedCup:
	# The Foam Watch result becomes the served cup: the Turkish method, the
	# medium roast the recipe pins, the common bean, and the foam score.
	var library := _run.player.brewing_library
	return BrewedCup.new(
		library.find_bean(QUEST_BEAN_ID),
		library.find_roast(QUEST_ROAST_ID),
		library.find_method(TURKISH_METHOD_ID),
		"",
		score
	)


func _failed_brew_toast(outcome: FoamResult.Outcome) -> String:
	match outcome:
		FoamResult.Outcome.BOILED_OVER:
			return BOILED_OVER_TOAST
		FoamResult.Outcome.COLD:
			return COLD_CUP_TOAST
		_:
			return WEAK_CUP_TOAST


func _on_husband_woke() -> void:
	# He wakes and cries; his wife runs to him across the aisle.
	_wife.begin_walk_to(_husband.global_position)
	_run.hud.show_toast(WAKE_TOAST)


func _on_sweet_hug() -> void:
	# The only sweet hug in the game: the pair stands together, the quest
	# completes, and the master opens his school a beat later.
	_wife.set_hugging(true)
	_wife.speak(HUG_LINE, LINE_HOLD_SECONDS)
	_run.quest_log.complete(QUEST_ID)
	_run.hud.show_toast(HUG_TOAST)
	spoke.emit(HUG_LINE)
	_master_time_left = balance.master_unlock_delay


func _spawn_master() -> void:
	# Section 13: the sleeper becomes the teacher. The husband joins the school
	# where he woke, south of the hugging pair, and the run finds him through
	# the same master path as its cafe masters.
	if not _run.master_lessons.register_master(master):
		return
	var npc := (load(MASTER_NPC_SCENE_PATH) as PackedScene).instantiate() as MasterNpc
	npc.name = "Master" + master.master_id.capitalize()
	add_child(npc)
	npc.global_position = _store_position + MASTER_OFFSET
	npc.bind_master(master, _run.master_lessons)
	_run.hud.show_toast(MASTER_TOAST)


func _draw() -> void:
	# The two shelves that flank aisle 7, so the scene reads like the spec:
	# the husband sleeps between the screws and the sandpaper.
	if _store_position == Vector2.ZERO:
		return
	_draw_shelf(_store_position + SCREW_SHELF_OFFSET, SCREW_SHELF_COLOR, "SCREWS")
	_draw_shelf(_store_position + SANDPAPER_SHELF_OFFSET, SANDPAPER_SHELF_COLOR, "SANDPAPER")


func _draw_shelf(center: Vector2, color: Color, label: String) -> void:
	var shelf := Rect2(center - SHELF_SIZE * 0.5, SHELF_SIZE)
	draw_rect(shelf, color)
	draw_rect(shelf, SHELF_EDGE_COLOR, false, 2.0)
	draw_string(
		ThemeDB.fallback_font,
		center + Vector2(-SHELF_SIZE.x * 0.5, SHELF_SIZE.y),
		label,
		HORIZONTAL_ALIGNMENT_CENTER,
		SHELF_SIZE.x,
		SHELF_TEXT_SIZE,
		SHELF_TEXT_COLOR
	)
