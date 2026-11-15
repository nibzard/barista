# ABOUTME: TouchControls routes raw screen touches into the game: the virtual
# ABOUTME: stick drives the move actions, the buttons fire the same input actions
# ABOUTME: the keys fire, so the whole game plays without a keyboard, section 4.
class_name TouchControls
extends CanvasLayer

enum ButtonKind { THROW, DODGE, DRINK, USE, TOOL, SWAP, REFILL, VAN, BREW }

# The mouse event a touch emulates carries device -1. The raw touch already
# reached this layer, so the copy is skipped.
const EMULATED_MOUSE_DEVICE := -1
# The desktop mouse rides the same routing as one more pointer.
const MOUSE_POINTER := -10
# The context buttons wait for the run to open them; the rest are always on.
# TOOL and SWAP wait with them: the belt starts empty until the player finds
# the first support tool, section 11.
const CONTEXT_KINDS: Array[ButtonKind] = [
	ButtonKind.TOOL,
	ButtonKind.SWAP,
	ButtonKind.REFILL,
	ButtonKind.VAN,
	ButtonKind.BREW,
]

@export var balance: TouchControlsBalance

# The run binds its player: the THROW, DODGE, and DRINK buttons act on it.
var player: Player = null

var _overlay_open := false
var _held_by_pointer: Dictionary = {}

@onready var stick_view: TouchStickView = $Board/Stick
@onready var _buttons: Dictionary = {
	ButtonKind.THROW: $Board/Buttons/Throw,
	ButtonKind.DODGE: $Board/Buttons/Dodge,
	ButtonKind.DRINK: $Board/Buttons/Drink,
	ButtonKind.USE: $Board/Buttons/Use,
	ButtonKind.TOOL: $Board/Buttons/Tool,
	ButtonKind.SWAP: $Board/Buttons/Swap,
	ButtonKind.REFILL: $Board/Buttons/Refill,
	ButtonKind.VAN: $Board/Buttons/Van,
	ButtonKind.BREW: $Board/Buttons/Brew,
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
	# The context buttons wait closed for the run to open them. The state and
	# the visibility start in step, so the first open call really opens.
	for kind: ButtonKind in CONTEXT_KINDS:
		(_buttons[kind] as TouchButton).set_available(false)


func _process(_delta: float) -> void:
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
