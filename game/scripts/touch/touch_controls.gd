# ABOUTME: TouchControls routes raw screen touches into the game: the virtual
# ABOUTME: stick drives the move actions, the buttons fire the same input actions
# ABOUTME: the keys fire, so the whole game plays without a keyboard, section 4.
# ABOUTME: The board also names the equipped support tool and cure weapon in
# ABOUTME: chalk, each beside the coasters that fire and swap it.
class_name TouchControls
extends CanvasLayer

enum ButtonKind {
	THROW,
	DODGE,
	DRINK,
	SERVE,
	USE,
	TOOL,
	SWAP,
	REFILL,
	VAN,
	BREW,
	PLANT,
	WEAPON,
	WSWAP,
}

# The mouse event a touch emulates carries device -1. The raw touch already
# reached this layer, so the copy is skipped.
const EMULATED_MOUSE_DEVICE := -1
# The desktop mouse rides the same routing as one more pointer.
const MOUSE_POINTER := -10
# One chalk glyph per button, ART_DIRECTION section 11: icons replace words
# where possible. Cup for throw, mug for drink, roll arrow for dodge; the
# rest follow the interface kit of the artboard.
const BUTTON_ICONS := {
	ButtonKind.THROW: TouchButton.Icon.CUP,
	ButtonKind.DODGE: TouchButton.Icon.ROLL_ARROW,
	ButtonKind.DRINK: TouchButton.Icon.MUG,
	ButtonKind.SERVE: TouchButton.Icon.SERVE_CUP,
	ButtonKind.USE: TouchButton.Icon.UP_ARROW,
	ButtonKind.TOOL: TouchButton.Icon.WRENCH,
	ButtonKind.SWAP: TouchButton.Icon.SWAP_ARROWS,
	ButtonKind.REFILL: TouchButton.Icon.FILL_CUP,
	ButtonKind.VAN: TouchButton.Icon.VAN,
	ButtonKind.BREW: TouchButton.Icon.POT,
	ButtonKind.PLANT: TouchButton.Icon.SPROUT,
	ButtonKind.WEAPON: TouchButton.Icon.RETICLE,
	ButtonKind.WSWAP: TouchButton.Icon.CYCLE_ARROWS,
}
# The context buttons wait for the run to open them; the rest are always on.
# TOOL and SWAP wait with them: the belt starts empty until the player finds
# the first support tool, section 11. WEAPON and WSWAP wait the same way for
# the first cure weapon. PLANT waits until the bag holds a coffee seedling,
# section 6.
const CONTEXT_KINDS: Array[ButtonKind] = [
	ButtonKind.TOOL,
	ButtonKind.SWAP,
	ButtonKind.REFILL,
	ButtonKind.VAN,
	ButtonKind.BREW,
	ButtonKind.PLANT,
	ButtonKind.WEAPON,
	ButtonKind.WSWAP,
]

@export var balance: TouchControlsBalance

# The run binds its player: the THROW, DODGE, and DRINK buttons act on it.
var player: Player = null

var _overlay_open := false
var _held_by_pointer: Dictionary = {}

@onready var stick_view: TouchStickView = $Board/Stick
@onready var tool_readout: Label = $Board/ToolReadout
@onready var weapon_readout: Label = $Board/WeaponReadout
@onready var _buttons: Dictionary = {
	ButtonKind.THROW: $Board/Buttons/Throw,
	ButtonKind.DODGE: $Board/Buttons/Dodge,
	ButtonKind.DRINK: $Board/Buttons/Drink,
	ButtonKind.SERVE: $Board/Buttons/Serve,
	ButtonKind.USE: $Board/Buttons/Use,
	ButtonKind.TOOL: $Board/Buttons/Tool,
	ButtonKind.SWAP: $Board/Buttons/Swap,
	ButtonKind.REFILL: $Board/Buttons/Refill,
	ButtonKind.VAN: $Board/Buttons/Van,
	ButtonKind.BREW: $Board/Buttons/Brew,
	ButtonKind.PLANT: $Board/Buttons/Plant,
	ButtonKind.WEAPON: $Board/Buttons/Weapon,
	ButtonKind.WSWAP: $Board/Buttons/WeaponSwap,
}


func _ready() -> void:
	# The stick and the buttons cover only their own corner of the screen, so
	# the layer never blocks the HUD, the menus, or a minigame overlay.
	var throw_button := _buttons[ButtonKind.THROW] as TouchButton
	throw_button.tapped.connect(
		func() -> void: player.try_action(&"throw_coffee", stick_view.direction())
	)
	var dodge_button := _buttons[ButtonKind.DODGE] as TouchButton
	dodge_button.tapped.connect(func() -> void: player.try_action(&"dodge", stick_view.direction()))
	var drink_button := _buttons[ButtonKind.DRINK] as TouchButton
	drink_button.tapped.connect(func() -> void: player.try_action(&"drink_coffee", Vector2.ZERO))
	# The serve hands the brewed cup straight over, no aim: the Turkish cure
	# of the Tinfoil Man rides it past the hat, section 6.
	var serve_button := _buttons[ButtonKind.SERVE] as TouchButton
	serve_button.tapped.connect(func() -> void: player.try_action(&"serve_coffee", Vector2.ZERO))
	# The shared buttons fire the same input actions the keys fire, so every
	# handler in the game answers them unchanged: USE covers the interact key
	# (tower fuse and switch, masters, quests, the van), REFILL the cafe pot,
	# VAN the field-base call, BREW the pot.
	var use_button := _buttons[ButtonKind.USE] as TouchButton
	use_button.tapped.connect(func() -> void: _fire_action(&"interact"))
	# The support tools fire with the stick aim, and the swap rides the same
	# action the key fires, so the whole belt plays without a keyboard.
	var tool_button := _buttons[ButtonKind.TOOL] as TouchButton
	tool_button.tapped.connect(
		func() -> void: player.try_action(&"use_tool", stick_view.direction())
	)
	var swap_button := _buttons[ButtonKind.SWAP] as TouchButton
	swap_button.tapped.connect(func() -> void: player.try_action(&"cycle_tool"))
	var refill_button := _buttons[ButtonKind.REFILL] as TouchButton
	refill_button.tapped.connect(func() -> void: _fire_action(&"refill_coffee"))
	var van_button := _buttons[ButtonKind.VAN] as TouchButton
	van_button.tapped.connect(func() -> void: _fire_action(&"call_van"))
	var brew_button := _buttons[ButtonKind.BREW] as TouchButton
	brew_button.tapped.connect(func() -> void: _fire_action(&"start_brew"))
	# The seedling drops under the player, so the tap needs no aim, section 6.
	var plant_button := _buttons[ButtonKind.PLANT] as TouchButton
	plant_button.tapped.connect(func() -> void: player.try_action(&"plant_coffee", Vector2.ZERO))
	# The cure weapons fire with the stick aim, and the weapon swap rides the
	# same action the key fires, so the whole armory plays without a keyboard.
	var weapon_button := _buttons[ButtonKind.WEAPON] as TouchButton
	weapon_button.tapped.connect(_on_weapon_tapped)
	weapon_button.released.connect(func() -> void: _release_action(&"fire_weapon"))
	var weapon_swap_button := _buttons[ButtonKind.WSWAP] as TouchButton
	weapon_swap_button.tapped.connect(func() -> void: player.try_action(&"cycle_weapon"))
	# The context buttons wait closed for the run to open them. The state and
	# the visibility start in step, so the first open call really opens.
	for kind: ButtonKind in CONTEXT_KINDS:
		(_buttons[kind] as TouchButton).set_available(false)
	# Every coaster takes its chalk glyph, section 11.
	for kind: ButtonKind in _buttons:
		(_buttons[kind] as TouchButton).icon = icon_for(kind)


static func icon_for(kind: ButtonKind) -> TouchButton.Icon:
	# The glyph one button wears. Every kind carries one: the words left the
	# coasters, so a missing row is a bug, not a fallback.
	return BUTTON_ICONS[kind]


static func tool_name_for(tool: int) -> String:
	# The chalk name of a support tool, or an empty string for the empty slot.
	# The readout draws this; an empty belt shows no readout at all.
	if tool == SupportToolbelt.NO_TOOL:
		return ""
	return SupportToolbelt.TOOL_NAMES[tool]


static func weapon_name_for(weapon: int) -> String:
	# The chalk name of a cure weapon, or an empty string for the empty slot.
	# The readout draws this; an empty armory shows no readout at all.
	if weapon == CureArmory.NO_WEAPON:
		return ""
	return CureArmory.WEAPON_NAMES[weapon]


func _process(_delta: float) -> void:
	_update_tool_readout()
	_update_weapon_readout()
	# The controls show only while the player acts: a locked player stands in a
	# cinematic or a minigame overlay that owns the whole screen, and a sleeping
	# player needs no buttons.
	var playable := (
		player != null
		and not player.is_input_locked()
		and not player.is_asleep()
		and not _overlay_open
	)
	if playable == visible:
		return
	visible = playable
	if not playable:
		stick_view.force_release()
		for button: TouchButton in _buttons.values():
			button.lift()


func stick() -> TouchStickView:
	return stick_view


func button(kind: ButtonKind) -> TouchButton:
	return _buttons[kind] as TouchButton


func set_button_available(kind: ButtonKind, available: bool) -> void:
	# The run owns the rules: it opens the context buttons where their action
	# works, like the refill inside the cafe safe zone.
	(_buttons[kind] as TouchButton).set_available(available)


func set_overlay_open(open: bool) -> void:
	# A full-screen overlay that is not a cinematic, like the SleepyDex phone or
	# the end screen, owns the screen for its own buttons.
	_overlay_open = open


func _input(event: InputEvent) -> void:
	if not visible or player == null:
		return
	var touch := event as InputEventScreenTouch
	if touch != null:
		if touch.pressed:
			_pointer_down(touch.index, touch.position)
		else:
			_pointer_up(touch.index)
		return
	var drag := event as InputEventScreenDrag
	if drag != null:
		stick_view.move_pointer(drag.index, drag.position)
		return
	_handle_mouse(event)


func _pointer_down(pointer_id: int, position: Vector2) -> void:
	if stick_view.try_press(pointer_id, position):
		return
	for kind: ButtonKind in _buttons:
		var action_button := _buttons[kind] as TouchButton
		if action_button.is_hit(position):
			action_button.press()
			_held_by_pointer[pointer_id] = action_button
			return


func _pointer_up(pointer_id: int) -> void:
	stick_view.release_pointer(pointer_id)
	var held := _held_by_pointer.get(pointer_id) as TouchButton
	if held != null:
		held.lift()
		_held_by_pointer.erase(pointer_id)


func _handle_mouse(event: InputEvent) -> void:
	# The desktop mouse drives the same controls, a development convenience.
	# The emulated copy of a touch is skipped: the raw touch already arrived.
	var mouse := event as InputEventMouseButton
	if mouse != null:
		if mouse.device == EMULATED_MOUSE_DEVICE or mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse.pressed:
			_pointer_down(MOUSE_POINTER, mouse.position)
		else:
			_pointer_up(MOUSE_POINTER)
		return
	var motion := event as InputEventMouseMotion
	if motion != null and motion.device != EMULATED_MOUSE_DEVICE:
		if (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			stick_view.move_pointer(MOUSE_POINTER, motion.position)


func _update_tool_readout() -> void:
	# The swap readout of T098: the chalk name of the tool that rides the
	# slot, beside the TOOL and SWAP coasters. The SWAP tap changes the slot
	# with no other feedback, so the name is the only way a touch player
	# sees the swap land. An empty belt shows no readout, like the hidden
	# tool buttons themselves.
	var tool_name := ""
	if player != null:
		tool_name = tool_name_for(player.toolbelt.equipped_tool())
	tool_readout.text = tool_name
	tool_readout.visible = tool_name != ""


func _update_weapon_readout() -> void:
	# The weapon twin of the T098 swap readout: the chalk name of the weapon
	# that rides the slot, beside the WEAPON and WSWAP coasters. The WSWAP tap
	# changes the slot with no other feedback, so the name is the only way a
	# touch player sees the swap land. An empty armory shows no readout, like
	# the hidden weapon buttons themselves.
	var weapon_name := ""
	if player != null:
		weapon_name = weapon_name_for(player.armory.equipped_weapon())
	weapon_readout.text = weapon_name
	weapon_readout.visible = weapon_name != ""


func _fire_action(action: StringName) -> void:
	# One synthesized press through the normal input pipeline: every unhandled
	# input handler in the game answers it, exactly like the key.
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	Input.parse_input_event(press)
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)


func _on_weapon_tapped() -> void:
	# The Minigun owns no single shot, section 11: its touch press holds the
	# fire action like a key, and the lift releases it, so the stream runs
	# only while the finger stays down. Every other weapon fires one shot on
	# the tap, with the stick aim.
	if player.armory.equipped_weapon() == CureArmory.Weapon.MINIGUN:
		_press_action(&"fire_weapon")
		return
	player.try_action(&"fire_weapon", stick_view.direction())


func _press_action(action: StringName) -> void:
	# The press half of a held action: the release comes with the lift.
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	Input.parse_input_event(press)


func _release_action(action: StringName) -> void:
	# The release half of a held action: the stream of the Minigun stops the
	# moment the finger or the overlay takes the button away.
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)
