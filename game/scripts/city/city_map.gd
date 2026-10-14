# ABOUTME: CityMap composes one city from the shared block kit scene.
# ABOUTME: The blocks stand in one row: cafe edge first, tower edge last.
class_name CityMap
extends Node2D

const CITY_BLOCK_SCENE := preload("res://scenes/city/city_block.tscn")

@export var definition: CityDefinition
@export var balance: CityBalance

var _block_views: Array[CityBlockView] = []


func _ready() -> void:
	if definition != null and balance != null:
		build()


func build() -> void:
	for view: CityBlockView in _block_views:
		view.queue_free()
	_block_views.clear()
	var block_size := CityRules.block_size(balance)
	for i: int in range(definition.blocks.size()):
		var view := CITY_BLOCK_SCENE.instantiate() as CityBlockView
		view.name = "Block%02d" % i
		view.block = definition.blocks[i]
		view.accent_color = definition.accent_color
		view.balance = balance
		view.position = Vector2(block_size.x * float(i), 0.0)
		add_child(view)
		_block_views.append(view)
	var tower := broadcast_tower()
	if tower != null:
		tower.switched_off.connect(_on_tower_switched_off)


func broadcast_tower() -> BroadcastTower:
	# Every city has one broadcast tower; the save system reads its state.
	var tower_block := find_block_of_kind(CityBlock.Kind.TOWER)
	if tower_block == null:
		return null
	return tower_block.broadcast_tower()


func _on_tower_switched_off() -> void:
	# The address of the city is dead: every speaker pole zone goes quiet.
	for view: CityBlockView in _block_views:
		var pole := view.pole_zone()
		if pole != null:
			pole.silence_broadcast()


func block_count() -> int:
	return _block_views.size()


func block_view(index: int) -> CityBlockView:
	if index < 0 or index >= _block_views.size():
		return null
	return _block_views[index]


func find_block_of_kind(kind: CityBlock.Kind) -> CityBlockView:
	for view: CityBlockView in _block_views:
		if view.kind() == kind:
			return view
	return null
