# ABOUTME: ColdBrewFridge is the cold brew station of the run: it holds the
# ABOUTME: one steep the player started and hands the finished cup out.
# ABOUTME: Pure logic with signals, no nodes: the pot ticks it, the stand reads it.
class_name ColdBrewFridge
extends RefCounted

signal steep_started(recipe_id: String)
signal steep_ready(recipe_id: String)

var balance: ColdBrewBalance

var _recipe: Recipe = null
var _bean: BeanType = null
var _roast_kind: int = BrewFlow.NO_ROAST_CHOICE
var _brew: ColdBrew = null


func _init(p_balance: ColdBrewBalance) -> void:
	balance = p_balance


func start(
	p_recipe: Recipe,
	p_bean: BeanType,
	p_method: BrewingMethod,
	p_roast_kind: int = BrewFlow.NO_ROAST_CHOICE
) -> bool:
	# The player starts the steep at the stand, section 8, with the roast the
	# picker chose: the steep holds it until the cup leaves. One fridge holds
	# one steep: a second start lands only after the cup leaves.
	if p_recipe == null or p_bean == null or p_method == null:
		return false
	if _brew != null:
		return false
	_recipe = p_recipe
	_bean = p_bean
	_roast_kind = p_roast_kind
	_brew = ColdBrew.new(p_method, balance)
	steep_started.emit(p_recipe.recipe_id)
	return true


func tick(delta: float) -> void:
	# The pot calls this every physics frame, so the steep runs on the play
	# clock while the player walks the city. The ready signal fires once, from
	# the tick path alone: a loaded brew never replays the beat.
	if _brew == null or _brew.is_ready():
		return
	_brew.tick(delta)
	if _brew.is_ready():
		steep_ready.emit(_recipe.recipe_id)


func steeped_recipe() -> Recipe:
	return _recipe


func steeped_bean() -> BeanType:
	return _bean


func is_empty() -> bool:
	return _brew == null


func is_steeping() -> bool:
	return _brew != null and not _brew.is_ready()


func is_ready() -> bool:
	return _brew != null and _brew.is_ready()


func remaining_seconds() -> float:
	return _brew.remaining_seconds() if _brew != null else 0.0


func steep_seconds() -> float:
	return balance.steep_seconds if balance != null else 0.0


func collect(library: BrewingLibrary) -> BrewedCup:
	# Take the finished cup out of the fridge. The frozen steep result grades
	# the cup at the method ceiling, the roast of the steep rides the cup, and
	# the fridge empties for the next start. Before the steep ends there is no
	# cup to take.
	if not is_ready():
		return null
	var flow := BrewFlow.resolve(_recipe, _bean, library, _roast_kind)
	flow.apply_cold_brew(_brew.collect())
	var cup := flow.cup()
	_recipe = null
	_bean = null
	_roast_kind = BrewFlow.NO_ROAST_CHOICE
	_brew = null
	return cup


func save_state(now_unix: float = -1.0) -> Dictionary:
	# The save system stores the steep, so the player can close the app and
	# come back later, section 18. An empty fridge stores nothing.
	if _brew == null:
		return {}
	var saved_at := now_unix if now_unix >= 0.0 else Time.get_unix_time_from_system()
	return {
		"recipe_id": _recipe.recipe_id if _recipe != null else "",
		"bean_id": _bean.bean_id if _bean != null else "",
		"roast_kind": _roast_kind,
		"elapsed": _brew.elapsed,
		"saved_at": saved_at,
	}


func load_state(saved: Dictionary, library: BrewingLibrary, now_unix: float = -1.0) -> void:
	# A loaded fridge stands where it stood, silent: no signal fires. A steep
	# that ran out while the game was closed is ready at once. Unknown recipe
	# or bean ids drop away, so a data change never breaks a slot.
	_recipe = null
	_bean = null
	_roast_kind = BrewFlow.NO_ROAST_CHOICE
	_brew = null
	if library == null or saved.is_empty():
		return
	var recipe := library.find_recipe(str(saved.get("recipe_id", "")))
	var bean := library.find_bean(str(saved.get("bean_id", "")))
	if recipe == null or bean == null:
		return
	var roast_kind := _saved_roast_kind(saved, library)
	var flow := BrewFlow.resolve(recipe, bean, library, roast_kind)
	if flow.method == null:
		return
	_recipe = recipe
	_bean = bean
	_roast_kind = roast_kind
	_brew = ColdBrew.new(flow.method, balance)
	var elapsed := float(saved.get("elapsed", 0.0))
	var saved_at := float(saved.get("saved_at", 0.0))
	if saved_at > 0.0:
		var now := now_unix if now_unix >= 0.0 else Time.get_unix_time_from_system()
		elapsed += maxf(0.0, now - saved_at)
	_brew.load_state({"elapsed": elapsed})


func _saved_roast_kind(saved: Dictionary, library: BrewingLibrary) -> int:
	# The roast of the stored steep: the choice the player made, when the save
	# holds one the library still knows. A save without the choice, like one
	# from before the picker, brews the cafe default.
	var kind := int(saved.get("roast_kind", BrewFlow.NO_ROAST_CHOICE))
	if kind != BrewFlow.NO_ROAST_CHOICE and library.find_roast_by_kind(kind) != null:
		return kind
	return BrewFlow.NO_ROAST_CHOICE
