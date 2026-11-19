# ABOUTME: BrewStandView is the live brew overlay: the recipe menu, the Grind
# ABOUTME: Dial pre-step, the method minigame of the chosen recipe, and the
# ABOUTME: cold brew fridge: start the steep, come back later, collect the cup.
# ABOUTME: BrewFlow grades the cup and owns the input economy; the overlay gates the player.
class_name BrewStandView
extends CanvasLayer

signal brewed(cup: BrewedCup)
signal closed

enum Phase { MENU, GRIND, METHOD }

# The minigame scenes stay paths, never preloads: the tutorial director already
# const-preloads the Grind Dial scene, and one resource with two const-preload
# owners can bind empty in one compile order (T102).
const GRIND_DIAL_SCENE_PATH := "res://scenes/minigames/grind_dial.tscn"
const POUR_SCENE_PATH := "res://scenes/minigames/pour_bloom.tscn"
const PRESS_SCENE_PATH := "res://scenes/minigames/press_shot.tscn"
const FOAM_WATCH_SCENE_PATH := "res://scenes/minigames/foam_watch.tscn"

const HINT_TEXT := "PICK A RECIPE. THE DIAL GRINDS. THE METHOD BREWS."
const NO_EXTRA_TEXT := "NO EXTRA"
const MASTER_MARK := " (MASTER)"
const NEEDS_BEAN_TEXT := "NEEDS: %s"
const NEEDS_APPLIANCE_TEXT := "NEEDS: %s"
const COLD_STEEP_PLAN_TEXT := "THE FRIDGE STEEPS IT: %s. START IT AND COME BACK LATER."
const COLD_BUSY_PLAN_TEXT := "THE FRIDGE IS BUSY. %s LEFT ON THE STEEP."
const COLD_READY_PLAN_TEXT := "THE FRIDGE HOLDS A READY CUP. COLLECT IT BELOW."
const STEEP_STATUS_TEXT := "COLD BREW: %s LEFT"
const STEEP_READY_TEXT := "COLD BREW: READY"
const COUNTDOWN_FORMAT := "%d:%02d"

var player: Player = null
# The school of the city masters marks the recipes the lessons taught.
var lessons: MasterLessons = null
# The cold brew station of the run, section 8: the stand starts the steep and
# collects the cup, the pot ticks the timer between the visits.
var fridge: ColdBrewFridge = null

var _phase: int = Phase.MENU
var _recipe: Recipe = null
var _bean: BeanType = null
var _roast: RoastProfile = null
var _flow: BrewFlow = null
var _bean_group := ButtonGroup.new()
var _roast_group := ButtonGroup.new()
var _dial: GrindDialView = null
var _pour: PourBloomView = null
var _press: PressShotView = null
var _foam: FoamWatchView = null
var _closed := false

@onready var board: Panel = $Board
@onready var hint_label: Label = $Board/HintLabel
@onready var left_column: VBoxContainer = $Board/Columns/LeftColumn
@onready var right_column: VBoxContainer = $Board/Columns/RightColumn
@onready var steep_panel: HBoxContainer = $Board/SteepPanel
@onready var steep_label: Label = $Board/SteepPanel/SteepLabel
@onready var collect_button: Button = $Board/SteepPanel/CollectButton
@onready var plan_panel: VBoxContainer = $Board/PlanPanel
@onready var plan_label: Label = $Board/PlanPanel/PlanLabel
@onready var bean_row: HBoxContainer = $Board/PlanPanel/BeanRow
@onready var roast_row: HBoxContainer = $Board/PlanPanel/RoastRow
@onready var start_button: Button = $Board/PlanPanel/ButtonsRow/StartButton
@onready var auto_button: Button = $Board/PlanPanel/ButtonsRow/AutoButton
@onready var back_button: Button = $Board/PlanPanel/ButtonsRow/BackButton
@onready var close_button: Button = $Board/CloseButton


func begin(
	p_player: Player, p_lessons: MasterLessons = null, p_fridge: ColdBrewFridge = null
) -> void:
	# The stand opens: the overlay owns the player for its whole run, so the
	# shared keys of the minigames cannot also throw a cup or take a lesson.
	player = p_player
	lessons = p_lessons
	fridge = p_fridge
	_bean_group = ButtonGroup.new()
	_roast_group = ButtonGroup.new()
	player.set_input_locked(true)
	_build_menu()
	_show_menu()


func close() -> void:
	# The stand ends, brewed or not: the player takes the input back. The
	# unlock waits for idle time: the press that ends a brew shares its key
	# with the live actions, and the locked player must not act on it after
	# the overlay is gone.
	if _closed:
		return
	_closed = true
	_free_minigame_views()
	if is_instance_valid(player):
		player.set_input_locked.call_deferred(false)
	closed.emit()


func phase() -> int:
	return _phase


func selected_recipe() -> Recipe:
	return _recipe


func selected_bean() -> BeanType:
	return _bean


func brewable_recipes() -> Array[Recipe]:
	# Every recipe the stand can brew: one of the seven minigame methods,
	# plus the cold brew steep that runs on its own clock, section 8.
	if player == null:
		return []
	var library := player.brewing_library
	var brewable: Array[Recipe] = []
	for recipe: Recipe in library.recipes:
		var brew_method := _recipe_method(recipe)
		if brew_method == null:
			continue
		brewable.append(recipe)
	return brewable


func bean_options(recipe: Recipe) -> Array[BeanType]:
	return BrewFlow.bean_options(recipe, player.inventory, player.brewing_library)


func roast_options(recipe: Recipe) -> Array[RoastProfile]:
	return BrewFlow.roast_options(recipe, player.brewing_library)


func selected_roast() -> RoastProfile:
	return _roast


func select_recipe(recipe: Recipe) -> void:
	# One recipe row: the plan shows its pins, the beans the bag offers, and
	# the roast choice of a recipe that pins no roast. A recipe whose cafe
	# appliance the bag lacks stays locked and names the find, section 15.
	_recipe = recipe
	_bean = null
	_roast = null
	for child: Node in bean_row.get_children():
		bean_row.remove_child(child)
		child.queue_free()
	for child: Node in roast_row.get_children():
		roast_row.remove_child(child)
		child.queue_free()
	var options := bean_options(recipe)
	for bean: BeanType in options:
		var bean_button := Button.new()
		bean_button.text = bean.display_name.to_upper()
		bean_button.toggle_mode = true
		bean_button.button_group = _bean_group
		bean_button.pressed.connect(_choose_bean.bind(bean))
		bean_row.add_child(bean_button)
		if bean == options[0]:
			bean_button.set_pressed_no_signal(true)
			_bean = bean
	for roast: RoastProfile in BrewFlow.roast_options(recipe, player.brewing_library):
		var roast_button := Button.new()
		roast_button.text = BrewFlow.roast_button_label(roast)
		roast_button.toggle_mode = true
		roast_button.button_group = _roast_group
		roast_button.pressed.connect(select_roast.bind(roast))
		roast_row.add_child(roast_button)
		if roast.kind == BrewFlow.ANY_ROAST_DEFAULT_KIND:
			roast_button.set_pressed_no_signal(true)
			_roast = roast
	var brew_method := _recipe_method(recipe)
	var is_cold_recipe := brew_method.minigame_group == BrewingMethod.MinigameGroup.NONE
	start_button.disabled = not _brew_inputs_ready() or _cold_start_blocked()
	auto_button.visible = (
		_brew_inputs_ready()
		and not is_cold_recipe
		and player.brewing_skills.is_auto_brew_available(brew_method.method_id)
	)
	plan_label.text = _plan_text(recipe, options.is_empty())
	_set_hint(BrewFlow.wake_hint_text(recipe, player.brewing_library))
	plan_panel.visible = true


func select_roast(roast: RoastProfile) -> void:
	# The roast choice of an open-roast recipe, section 8: different roast
	# levels give different coffees, and the plan names the one brewing.
	if roast == null:
		return
	_roast = roast
	if _recipe != null:
		plan_label.text = _plan_text(_recipe, bean_options(_recipe).is_empty())


func begin_selected_brew() -> void:
	# The START of the plan: the chosen bean pays into the grinder, section 7,
	# then the Grind Dial pre-step runs, and after it the method minigame of
	# the resolved method. A cold brew recipe skips both: the fridge steeps
	# it, and the player comes back later, section 8.
	if not _brew_inputs_ready():
		return
	_flow = BrewFlow.resolve(_recipe, _bean, player.brewing_library, _chosen_roast_kind())
	if not _flow.needs_method_minigame():
		_begin_cold_steep()
		return
	if not _spend_the_bean():
		return
	_hide_menu()
	_spawn_grind_dial()


func begin_auto_brew() -> void:
	# Auto-brew skips both steps: the machine always scores the auto-brew
	# score, never a perfect cup, section 14. The bean pays like any brew,
	# and the cold brew has no minigame to skip, so its steep never runs
	# this path.
	if not _brew_inputs_ready():
		return
	_flow = BrewFlow.resolve(_recipe, _bean, player.brewing_library, _chosen_roast_kind())
	if not _flow.needs_method_minigame():
		return
	if not _spend_the_bean():
		return
	_flow.apply_auto_brew(player.brewing_balance)
	_finish_brew()


func collect_steep() -> void:
	# Take the finished cup out of the fridge: the hand receives it, the
	# skill trains, and the stand ends like any brew. A full hand keeps the
	# cup waiting in the fridge.
	if fridge == null or player == null:
		return
	if not fridge.is_ready():
		return
	if player.coffee_supply.cups >= player.coffee_supply.carry_limit():
		return
	_deliver(fridge.collect(player.brewing_library))


func _begin_cold_steep() -> void:
	# The cold brew start: no grind, no minigame. The chosen bean and the
	# chosen roast pay into the fridge, the fridge takes the steep, and the
	# stand closes at once; the player comes back later.
	if fridge == null:
		return
	if not _spend_the_bean():
		return
	if not fridge.start(_recipe, _bean, _flow.method, _chosen_roast_kind()):
		return
	close()


func grind_dial() -> GrindDialView:
	return _dial


func pour_view() -> PourBloomView:
	return _pour


func press_view() -> PressShotView:
	return _press


func foam_view() -> FoamWatchView:
	return _foam


func _ready() -> void:
	hint_label.text = HINT_TEXT
	close_button.pressed.connect(close)
	back_button.pressed.connect(_show_menu)
	start_button.pressed.connect(begin_selected_brew)
	auto_button.pressed.connect(begin_auto_brew)
	collect_button.pressed.connect(collect_steep)
	plan_panel.visible = false
	steep_panel.visible = false


func _process(_delta: float) -> void:
	# The fridge countdown runs while the menu stands open, so the player
	# watches the steep from the stand.
	_refresh_steep_panel()


func _refresh_steep_panel() -> void:
	if fridge == null or fridge.is_empty():
		steep_panel.visible = false
		return
	steep_panel.visible = true
	if fridge.is_ready():
		steep_label.text = STEEP_READY_TEXT
		collect_button.visible = true
	else:
		steep_label.text = STEEP_STATUS_TEXT % _countdown(fridge.remaining_seconds())
		collect_button.visible = false


func _countdown(seconds: float) -> String:
	# A whole-minute-and-seconds countdown, like a kitchen timer.
	var whole := maxi(roundi(seconds), 0)
	return COUNTDOWN_FORMAT % [whole / 60, whole % 60]


func _exit_tree() -> void:
	# A teardown without close, like a scene change, still frees the player.
	if not _closed and is_instance_valid(player):
		player.set_input_locked(false)


func _build_menu() -> void:
	for column: VBoxContainer in [left_column, right_column]:
		for child: Node in column.get_children():
			column.remove_child(child)
			child.queue_free()
	var recipes := brewable_recipes()
	var half := (recipes.size() + 1) / 2
	for i: int in range(recipes.size()):
		var recipe: Recipe = recipes[i]
		var row := Button.new()
		row.text = _row_text(recipe)
		row.pressed.connect(select_recipe.bind(recipe))
		if i < half:
			left_column.add_child(row)
		else:
			right_column.add_child(row)


func _row_text(recipe: Recipe) -> String:
	var text := recipe.display_name.to_upper()
	if lessons != null and lessons.is_recipe_known(recipe.recipe_id):
		text += MASTER_MARK
	return text


func _plan_text(recipe: Recipe, needs_bean: bool) -> String:
	# The pins of the recipe in plain words. A recipe the bag cannot fill
	# names the bean it needs, a recipe whose cafe appliance the bag lacks
	# names the find, and a cold brew recipe says how the fridge runs.
	var library := player.brewing_library
	var brew_method := _recipe_method(recipe)
	var roast := _planned_roast(library, recipe)
	var extra: RecipeExtra = library.find_extra(recipe.extra_id)
	var lines := (
		"%s - %s - %s"
		% [
			brew_method.display_name.to_upper(),
			roast.display_name.to_upper(),
			extra.display_name.to_upper() if extra != null else NO_EXTRA_TEXT,
		]
	)
	if needs_bean:
		lines += "\n" + NEEDS_BEAN_TEXT % _bean_need_text(recipe)
	if not BrewFlow.appliance_owned(recipe, player.inventory):
		lines += "\n" + NEEDS_APPLIANCE_TEXT % recipe.required_appliance.to_upper()
	lines += _cold_steep_lines(brew_method)
	return lines


func _planned_roast(library: BrewingLibrary, recipe: Recipe) -> RoastProfile:
	# The roast the plan brews: the pin of the recipe, the choice of the
	# player, or the balanced medium default.
	if recipe.roast_match == Recipe.Match.EXACT:
		return library.find_roast_by_kind(recipe.roast)
	if _roast != null:
		return _roast
	return library.find_roast_by_kind(BrewFlow.ANY_ROAST_DEFAULT_KIND)


func _cold_steep_lines(brew_method: BrewingMethod) -> String:
	# The fridge status for a cold brew recipe: how long the steep runs, or
	# why it cannot start. Other methods add nothing.
	if brew_method.minigame_group != BrewingMethod.MinigameGroup.NONE:
		return ""
	if fridge != null and fridge.is_ready():
		return "\n" + COLD_READY_PLAN_TEXT
	if fridge != null and fridge.is_steeping():
		return "\n" + COLD_BUSY_PLAN_TEXT % _countdown(fridge.remaining_seconds())
	if fridge != null:
		return "\n" + COLD_STEEP_PLAN_TEXT % _countdown(fridge.steep_seconds())
	return ""


func _bean_need_text(recipe: Recipe) -> String:
	match recipe.bean_match:
		Recipe.Match.EXACT:
			return recipe.bean_id.to_upper()
		Recipe.Match.QUALITY_MIN:
			return "%s OR BETTER" % BeanType.Quality.keys()[recipe.min_bean_quality].to_upper()
		_:
			return BrewFlow.CAFE_STOCK_BEAN_ID.to_upper()


func _recipe_method(recipe: Recipe) -> BrewingMethod:
	if player == null:
		return null
	var method_id := (
		recipe.method_id
		if recipe.method_match == Recipe.Match.EXACT
		else BrewFlow.ANY_METHOD_DEFAULT_ID
	)
	return player.brewing_library.find_method(method_id)


func _choose_bean(bean: BeanType) -> void:
	_bean = bean
	start_button.disabled = not _brew_inputs_ready() or _cold_start_blocked()


func _brew_inputs_ready() -> bool:
	# The gate of every brew start, sections 7 and 15: a chosen bean, and
	# the recipe's cafe appliance in the bag.
	if _recipe == null or _bean == null:
		return false
	return BrewFlow.appliance_owned(_recipe, player.inventory)


func _spend_the_bean() -> bool:
	# The chosen bean leaves the bag and pays the brew, section 7. The
	# stand's own jar of the common bean brews free, so an empty bag still
	# brews the house stock.
	return BrewFlow.spend_bean(_bean, player.inventory)


func _chosen_roast_kind() -> int:
	# The roast choice for the resolve call. A pinned roast ignores the
	# choice inside resolve, so only an open roast ever reads it.
	if _roast != null:
		return _roast.kind
	return BrewFlow.NO_ROAST_CHOICE


func _cold_start_blocked() -> bool:
	# One fridge holds one steep: a busy or ready fridge blocks only the
	# start of another cold brew, never a minigame brew beside it.
	if fridge == null or fridge.is_empty() or _recipe == null:
		return false
	var brew_method := _recipe_method(_recipe)
	return brew_method != null and brew_method.minigame_group == BrewingMethod.MinigameGroup.NONE


func _show_menu() -> void:
	_phase = Phase.MENU
	_recipe = null
	_bean = null
	_roast = null
	_flow = null
	_free_minigame_views()
	plan_panel.visible = false
	_set_hint("")
	hint_label.visible = true
	close_button.visible = true
	board.visible = true


func _set_hint(wake_hint: String) -> void:
	# The hint line of the board: the generic stand instruction, or the roast
	# lesson of an open-roast recipe, section 15. An empty lesson falls back
	# to the instruction, so the board never shows a blank hint.
	hint_label.text = wake_hint if not wake_hint.is_empty() else HINT_TEXT


func _hide_menu() -> void:
	plan_panel.visible = false
	hint_label.visible = false
	close_button.visible = false
	board.visible = false


func _spawn_grind_dial() -> void:
	_phase = Phase.GRIND
	_dial = (load(GRIND_DIAL_SCENE_PATH) as PackedScene).instantiate() as GrindDialView
	_dial.name = "StandGrindDial"
	_dial.method = _flow.method
	_dial.finished.connect(_on_grind_finished)
	add_child(_dial)


func _spawn_method_view() -> void:
	_phase = Phase.METHOD
	match _flow.method.minigame_group:
		BrewingMethod.MinigameGroup.POUR:
			_pour = (load(POUR_SCENE_PATH) as PackedScene).instantiate() as PourBloomView
			_pour.name = "StandPour"
			_pour.method = _flow.method
			_pour.finished.connect(
				func(pour_result: PourResult) -> void: _on_method_finished(pour_result.score)
			)
			add_child(_pour)
		BrewingMethod.MinigameGroup.PRESS:
			_press = (load(PRESS_SCENE_PATH) as PackedScene).instantiate() as PressShotView
			_press.name = "StandPress"
			_press.method = _flow.method
			_press.finished.connect(
				func(press_result: PressResult) -> void: _on_method_finished(press_result.score)
			)
			add_child(_press)
		BrewingMethod.MinigameGroup.FOAM_WATCH:
			_foam = (load(FOAM_WATCH_SCENE_PATH) as PackedScene).instantiate() as FoamWatchView
			_foam.name = "StandFoamWatch"
			_foam.method = _flow.method
			_foam.finished.connect(
				func(foam_result: FoamResult) -> void: _on_method_finished(foam_result.score)
			)
			add_child(_foam)
		_:
			_finish_brew()


func _on_grind_finished(dial_result: GrindResult) -> void:
	_flow.apply_grind(dial_result)
	_free_minigame_views()
	if _flow.needs_method_minigame():
		_spawn_method_view()
	else:
		_finish_brew()


func _on_method_finished(score: float) -> void:
	_flow.apply_method_score(score)
	_free_minigame_views()
	_finish_brew()


func _finish_brew() -> void:
	_deliver(_flow.cup())


func _deliver(cup: BrewedCup) -> void:
	# The earned cup lands in the hand, the skill trains, and the stand ends.
	# A graded flow and a collected steep end the same way, section 8.
	if cup != null:
		player.brew_hand.receive(cup, player.coffee_supply.add_cups(1))
		player.brewing_skills.record_brew(cup.method.method_id, cup.score)
		brewed.emit(cup)
	close()


func _free_minigame_views() -> void:
	for view: Node in [_dial, _pour, _press, _foam]:
		if view != null:
			view.queue_free()
	_dial = null
	_pour = null
	_press = null
	_foam = null
