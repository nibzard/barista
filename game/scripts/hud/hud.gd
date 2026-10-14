# ABOUTME: Hud shows every player status from GAME_DESIGN section 9 on one chalkboard.
# ABOUTME: Presentation only: it re-reads the logic components; only the toast keeps state.
class_name Hud
extends CanvasLayer

const EMPTY_BAG_TEXT := "empty bag"
const TOAST_HOLD_SECONDS := 3.0

@export var player_path: NodePath

var player: Player = null

var _toast_time_left := 0.0

@onready var awake_bar: ProgressBar = $Board/Margin/Rows/AwakeRow/AwakeBar
@onready var awake_value: Label = $Board/Margin/Rows/AwakeRow/AwakeValue
@onready var coffee_value: Label = $Board/Margin/Rows/CoffeeRow/CoffeeValue
@onready var wake_ups_value: Label = $Board/Margin/Rows/WakeUpsRow/WakeUpsValue
@onready var bag_label: Label = $Board/Margin/Rows/BagLabel
@onready var toast_label: Label = $Toast


func _ready() -> void:
	if not player_path.is_empty():
		set_player(get_node_or_null(player_path) as Player)


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


func refresh() -> void:
	# Every shown number comes straight from a component, read at draw time.
	if player == null or player.sleep_meter == null:
		return
	var meter := player.sleep_meter
	awake_bar.max_value = meter.balance.max_value
	awake_bar.value = meter.value
	awake_value.text = "%d/%d" % [roundi(meter.value), roundi(meter.balance.max_value)]
	var supply := player.coffee_supply
	coffee_value.text = "%d/%d cups in hand" % [supply.cups, supply.carry_limit()]
	wake_ups_value.text = (
		"%d/%d" % [player.wake_ups.remaining, player.wake_ups.balance.max_wake_ups]
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
