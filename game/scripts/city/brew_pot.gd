# ABOUTME: BrewPot is the brewing station of the run: it owns the brew stand
# ABOUTME: overlay, the cold brew fridge, the pot rules, and the chalkboard
# ABOUTME: toast of each brew. It stands in the city cafe and in the van kitchen.
class_name BrewPot
extends Node

# The stand scene stays a path, never a preload: the city run pulls this
# script into its compile as a class, and a scene load inside that compile
# can bind corrupted constants (T102).
const BREW_STAND_SCENE_PATH := "res://scenes/minigames/brew_stand.tscn"

const BREW_TOAST_TEXT := "%s BREWED. SCORE %d."
const BREW_PLAIN_TOAST_TEXT := "CUP BREWED. SCORE %d."
const BREW_NOT_HERE_TEXT := "BREW AT THE CAFE POT."
const BREW_HAND_FULL_TEXT := "THE HAND IS FULL. NO ROOM FOR A BREWED CUP."
const STEEP_START_TOAST_TEXT := "%s STEEPING. COME BACK LATER."
const STEEP_READY_TOAST_TEXT := "THE COLD BREW IS READY. COLLECT IT AT THE POT."

# The run arrives as a plain Node: naming the run class here would tie this
# station's compile back into the city script (T112).
var _run: Node = null
var _stand: BrewStandView = null
# The cold brew fridge of the run, section 8: the pot ticks the steep while
# the player plays and announces its beats on the chalkboard.
var _fridge: ColdBrewFridge = null
# The frame the last stand closed on: the press that ends a brew shares its
# key with the live actions, so the pot eats it before the world answers.
var _stand_closed_frame := -1


func setup(run: Node, fridge: ColdBrewFridge = null) -> void:
	_run = run
	_fridge = fridge
	if _fridge != null:
		_fridge.steep_started.connect(_on_steep_started)
		_fridge.steep_ready.connect(_on_steep_ready)


func fridge() -> ColdBrewFridge:
	return _fridge


func _physics_process(delta: float) -> void:
	# The steep runs on the play clock: the fridge asks no player input, so
	# the timer advances every physics frame of the run, section 8.
	if _fridge != null:
		_fridge.tick(delta)


func _unhandled_input(_event: InputEvent) -> void:
	# The overlay owns the screen while it plays, and the closing press dies
	# with it: no refill, no van call, no second stand inside the brew.
	if _stand != null or Engine.get_process_frames() == _stand_closed_frame:
		get_viewport().set_input_as_handled()


func try_open() -> void:
	# The BREW key and button open the stand at the pot. Any overlay that
	# already holds the player keeps the key.
	if _stand != null or _run == null:
		return
	var player: Player = _run.player
	if player.is_input_locked() or player.is_asleep():
		return
	if not _run.brewing_allowed_here():
		_run.hud.show_toast(BREW_NOT_HERE_TEXT)
		return
	if player.coffee_supply.cups >= player.coffee_supply.carry_limit():
		_run.hud.show_toast(BREW_HAND_FULL_TEXT)
		return
	_stand = (load(BREW_STAND_SCENE_PATH) as PackedScene).instantiate() as BrewStandView
	_stand.name = "BrewStand"
	add_child(_stand)
	_stand.brewed.connect(_on_stand_cup)
	_stand.closed.connect(_on_stand_closed)
	_stand.begin(player, _run.master_lessons, _fridge)


func stand() -> BrewStandView:
	# The open brew stand, or null while the pot is closed.
	return _stand


func holds_interact() -> bool:
	# The stop and lift actions of the minigames share the E key with
	# interact, so the stand consumes the press while it plays and the press
	# that ends the brew.
	return _stand != null or Engine.get_process_frames() == _stand_closed_frame


func available_here() -> bool:
	# The BREW button shows where brewing works and the hand has room for
	# the brewed cup.
	if _run == null:
		return false
	var player: Player = _run.player
	return (
		_run.brewing_allowed_here()
		and player.coffee_supply.cups < player.coffee_supply.carry_limit()
	)


func _on_stand_cup(cup: BrewedCup) -> void:
	# The chalkboard toast names the brew and its earned score.
	var recipe := cup.matched_recipe(_run.player.brewing_library)
	if recipe == null:
		_run.hud.show_toast(BREW_PLAIN_TOAST_TEXT % roundi(cup.score))
	else:
		_run.hud.show_toast(BREW_TOAST_TEXT % [recipe.display_name.to_upper(), roundi(cup.score)])


func _on_steep_started(recipe_id: String) -> void:
	# The steep beat of section 8: the player starts it and comes back later.
	# The run arrives as a plain Node, so the duck-typed reads name their
	# types (T112).
	var recipe: Recipe = _run.player.brewing_library.find_recipe(recipe_id)
	var recipe_name: String = recipe.display_name.to_upper() if recipe != null else recipe_id
	_run.hud.show_toast(STEEP_START_TOAST_TEXT % recipe_name)


func _on_steep_ready(_recipe_id: String) -> void:
	# The steep ended while the player played: the chalkboard calls him back.
	_run.hud.show_toast(STEEP_READY_TOAST_TEXT)


func _on_stand_closed() -> void:
	if _stand == null:
		return
	_stand_closed_frame = Engine.get_process_frames()
	_stand.queue_free()
	_stand = null
