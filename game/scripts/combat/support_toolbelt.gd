# ABOUTME: SupportToolbelt owns the support tools of section 11: the unlock
# ABOUTME: state, the equipped slot, the cooldowns, and the parry window.
# ABOUTME: Pure logic with no nodes; the player ticks the clocks and serves the world.
class_name SupportToolbelt
extends RefCounted

enum Tool { TAMPER, STEAM_WAND, PORTAFILTER, ICED_SPRAYER, BEAN_SLICK }

# The slot value when no tool is equipped. Tools are ints, so -1 works.
const NO_TOOL := -1

# The canonical cycle order, section 11: the order of the enum itself.
const CYCLE_ORDER: Array[Tool] = [
	Tool.TAMPER,
	Tool.STEAM_WAND,
	Tool.PORTAFILTER,
	Tool.ICED_SPRAYER,
	Tool.BEAN_SLICK,
]

# The gear item id that unlocks each tool, section 11: the player finds the
# tools along the route, so every tool rides a gear item in the bag and the
# save holds it with the rest of the gear, section 18.
const ITEM_IDS: Dictionary = {
	Tool.TAMPER: "tamper",
	Tool.STEAM_WAND: "steam_wand",
	Tool.PORTAFILTER: "portafilter",
	Tool.ICED_SPRAYER: "iced_sprayer",
	Tool.BEAN_SLICK: "bean_slick",
}

# The chalk name each tool wears on the interface: the display name of the
# gear item that carries it, so the readout and the bag row always agree.
const TOOL_NAMES: Dictionary = {
	Tool.TAMPER: "Tamper",
	Tool.STEAM_WAND: "Steam Wand",
	Tool.PORTAFILTER: "Portafilter",
	Tool.ICED_SPRAYER: "Iced Sprayer",
	Tool.BEAN_SLICK: "Bean Slick",
}

var balance: SupportToolsBalance

var _unlocked: Array[Tool] = []
var _equipped := NO_TOOL
var _cooldowns: Dictionary = {}
var _parry_time_left := 0.0


func _init(support_balance: SupportToolsBalance) -> void:
	balance = support_balance


func unlock(tool: Tool) -> void:
	# A found tool joins the belt. The first find equips itself, so the belt
	# is ready the moment it stops being empty.
	if _unlocked.has(tool):
		return
	_unlocked.append(tool)
	if _equipped == NO_TOOL:
		_equipped = tool


func unlock_all() -> void:
	# The development room hands the whole belt over for play and tests.
	for tool: Tool in CYCLE_ORDER:
		unlock(tool)


func grant_item(item_id: String) -> bool:
	# A picked-up gear item unlocks its tool. Gear that carries no tool
	# changes nothing.
	var tool := _tool_for_item(item_id)
	if tool == NO_TOOL:
		return false
	unlock(tool)
	return true


func sync_unlocked_from_inventory(inventory: Inventory) -> void:
	# A loaded bag restocks the belt, section 18: the save and the move east
	# carry the tools as bag gear, so every tool item in the bag unlocks its
	# tool again.
	for tool: Tool in CYCLE_ORDER:
		var item_id := ITEM_IDS[tool] as String
		if inventory.has_item(item_id):
			unlock(tool)


func is_unlocked(tool: Tool) -> bool:
	return _unlocked.has(tool)


func unlocked_tools() -> Array[Tool]:
	return _unlocked.duplicate()


func has_any() -> bool:
	return not _unlocked.is_empty()


func equipped_tool() -> int:
	return _equipped


func equip(tool: Tool) -> bool:
	# Only a found tool can ride in the slot.
	if not _unlocked.has(tool):
		return false
	_equipped = tool
	return true


func cycle() -> bool:
	# The swap: the next found tool in the canonical order, wrapping around.
	# An empty belt swaps nothing.
	if _unlocked.is_empty():
		return false
	var current := _unlocked.find(_equipped as Tool)
	var next_index := (current + 1) % _unlocked.size()
	if next_index < 0:
		next_index += _unlocked.size()
	_equipped = _unlocked[next_index]
	return true


func start_cooldown(tool: Tool) -> void:
	_cooldowns[tool] = _cooldown_seconds_for(tool)


func is_on_cooldown(tool: Tool) -> bool:
	return cooldown_time_left(tool) > 0.0


func cooldown_time_left(tool: Tool) -> float:
	return _cooldowns.get(tool, 0.0) as float


func tick(delta: float) -> void:
	# The player ticks the clocks once per physics frame.
	for tool: Tool in CYCLE_ORDER:
		if _cooldowns.has(tool):
			var time_left: float = _cooldowns[tool]
			_cooldowns[tool] = maxf(0.0, time_left - delta)
	if _parry_time_left > 0.0:
		_parry_time_left = maxf(0.0, _parry_time_left - delta)


func open_parry_window() -> void:
	# The Steam Wand swing opens the parry window of section 14.
	_parry_time_left = balance.parry_window_seconds


func is_parrying() -> bool:
	return _parry_time_left > 0.0


func parry_time_left() -> float:
	return _parry_time_left


func consume_parry() -> bool:
	# One swing stops one hug: a parry spends the window, and the next hug
	# inside the same window lands like any other.
	if not is_parrying():
		return false
	_parry_time_left = 0.0
	return true


func try_parry_hug(attacker: Sleepwalker) -> bool:
	# A hug that lands inside the Steam Wand parry window bounces off,
	# section 14: the attacker staggers for the parry time and the spent
	# window closes, so the next hug in the same swing lands like any other.
	if not is_parrying():
		return false
	consume_parry()
	attacker.stagger(balance.parry_stagger_seconds)
	return true


func try_block_hug(attacker: Sleepwalker, player: Player) -> bool:
	# A hug that meets the raised Portafilter stops cold, section 11: no
	# grab, a shove, and a beat of stagger while the sleeper finds its
	# footing again. The shield rides on the equipped tool; a sleeping
	# player drops it.
	if player.is_asleep() or _equipped != Tool.PORTAFILTER:
		return false
	var away := attacker.global_position - player.global_position
	if away.length() <= 1.0:
		away = Vector2.RIGHT
	attacker.stagger(balance.portafilter_block_stagger_seconds)
	attacker.push_away(
		away.normalized(),
		balance.portafilter_block_push_speed,
		balance.portafilter_block_push_seconds
	)
	return true


func _tool_for_item(item_id: String) -> int:
	# The gear item of a tool names it. Unknown gear carries no tool.
	for tool: Tool in CYCLE_ORDER:
		if ITEM_IDS[tool] == item_id:
			return tool
	return NO_TOOL


func _cooldown_seconds_for(tool: Tool) -> float:
	match tool:
		Tool.TAMPER:
			return balance.tamper_cooldown_seconds
		Tool.STEAM_WAND:
			return balance.steam_wand_cooldown_seconds
		Tool.PORTAFILTER:
			return balance.portafilter_bash_cooldown_seconds
		Tool.ICED_SPRAYER:
			return balance.sprayer_cooldown_seconds
		Tool.BEAN_SLICK:
			return balance.bean_slick_cooldown_seconds
	return 0.0
