# ABOUTME: Hud shows every player status from GAME_DESIGN section 9 on one chalkboard.
# ABOUTME: Presentation only: it re-reads the logic components; only the toast keeps state.
class_name Hud
extends CanvasLayer

const EMPTY_BAG_TEXT := "empty bag"
const TOAST_HOLD_SECONDS := 3.0

@export var player_path: NodePath

var player: Player = null

var _toast_time_left := 0.0

@onready var awake_meter: MugMeter = $Board/Margin/Rows/AwakeRow/AwakeMeter
@onready var awake_value: Label = $Board/Margin/Rows/AwakeRow/AwakeValue
@onready var cup_row: PaperCupRow = $Board/Margin/Rows/CoffeeRow/CupRow
@onready var wake_clocks: AlarmClocks = $Board/Margin/Rows/WakeUpsRow/WakeClocks
@onready var bag_label: Label = $Board/Margin/Rows/BagLabel
@onready var toast_label: Label = $Toast
@onready var dex_button: Button = $DexButton
@onready var dex_app: SleepyDexApp = $DexApp


func _ready() -> void:
	ChalkTheme.apply_display_font(toast_label)
	if not player_path.is_empty():
		set_player(get_node_or_null(player_path) as Player)
	dex_button.visible = false
	dex_button.pressed.connect(open_dex)


func _process(_delta: float) -> void:
	refresh()


func _physics_process(delta: float) -> void:
	_tick_toast(delta)


func show_toast(message: String) -> void:
	# A toast is a short-lived announcement, like the tower-switch reward text.
	toast_label.text = message
	toast_label.visible = true
	_toast_time_left = TOAST_HOLD_SECONDS


func toast_message() -> String:
	return toast_label.text


func is_toast_visible() -> bool:
	return toast_label.visible


func _tick_toast(delta: float) -> void:
	if _toast_time_left <= 0.0:
		return
	_toast_time_left = maxf(0.0, _toast_time_left - delta)
	if _toast_time_left == 0.0:
		toast_label.visible = false


func set_player(target: Player) -> void:
	player = target
	refresh()


func bind_dex(sleepy_dex: SleepyDex, library: BrewingLibrary) -> void:
	# The smartphone lives on the HUD: one button opens the one app, section 9.
	# Scenes without a dex, like the cafe development room, keep the button hid.
	dex_app.library = library
	dex_app.bind(sleepy_dex)
	dex_button.visible = true


func open_dex() -> void:
	if player != null and player.is_input_locked():
		return
	dex_app.open()


func toggle_dex() -> void:
	if dex_app.is_open():
		dex_app.close()
	else:
		open_dex()


func _unhandled_input(event: InputEvent) -> void:
	# The Tab key is the desktop convenience for the phone button, section 4.
	if event.is_action_pressed(&"toggle_dex"):
		if player != null and player.is_input_locked() and not dex_app.is_open():
			return
		toggle_dex()
		get_viewport().set_input_as_handled()


func refresh() -> void:
	# Every shown number comes straight from a component, read at draw time.
	if player == null or player.sleep_meter == null:
		return
	var meter := player.sleep_meter
	awake_meter.max_value = meter.balance.max_value
	awake_meter.value = meter.value
	awake_value.text = "%d/%d" % [roundi(meter.value), roundi(meter.balance.max_value)]
	var supply := player.coffee_supply
	# Section 11: the cups in hand and the wake-ups read as icon rows, so the
	# board carries numbers only where no icon speaks, like the awake value.
	cup_row.read(supply.cups, supply.carry_limit())
	wake_clocks.read(
		player.wake_ups.remaining, player.wake_ups.balance.max_wake_ups, player.wake_ups.hardcore
	)
	bag_label.text = _bag_text()


func _bag_text() -> String:
	# The bag rows, grouped by category. Brewed coffee lives in the supply,
	# so the cups-in-hand line above is its inventory row.
	var lines: Array[String] = []
	var last_category := -1
	for item: ItemType in player.inventory.held_items():
		if item.category != last_category:
			lines.append(_category_name(item.category))
			last_category = item.category
		lines.append("  %s x%d" % [item.display_name, player.inventory.count(item.item_id)])
	if lines.is_empty():
		return EMPTY_BAG_TEXT
	return "\n".join(lines)


func _category_name(category: ItemType.Category) -> String:
	match category:
		ItemType.Category.BEAN:
			return "Beans"
		ItemType.Category.GEAR:
			return "Gear"
		ItemType.Category.MATERIAL:
			return "Materials"
		_:
			return "Appliances"
