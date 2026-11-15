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
		view.cafe_tier = definition.cafe_tier
		view.landmark_label = _landmark_label_for(definition.blocks[i].kind)
		view.site_label = definition.blocks[i].site_name
		view.position = Vector2(block_size.x * float(i), 0.0)
		add_child(view)
		_block_views.append(view)
	var tower := broadcast_tower()
	if tower != null:
		tower.switched_off.connect(_on_tower_switched_off)


func city_size() -> Vector2:
	# The full row: cafe edge to tower edge, one block high.
	var block_size := CityRules.block_size(balance)
	return Vector2(block_size.x * float(_block_views.size()), block_size.y)


func cafe_spawn() -> Marker2D:
	# The player start on the cafe block, inside the safe zone.
	var cafe_block := find_block_of_kind(CityBlock.Kind.CAFE)
	if cafe_block == null:
		return null
	return cafe_block.cafe_spawn()


func _landmark_label_for(kind: CityBlock.Kind) -> String:
	# The named landmarks: the boss arena and the signature quest location.
	match kind:
		CityBlock.Kind.BOSS_ARENA:
			return definition.boss_name
		CityBlock.Kind.QUEST:
			return definition.quest_name
		_:
			return ""


func speaker_pole_positions() -> Array[Vector2]:
	# The world spots of every loudspeaker pole: the anchors the address loop
	# measures its distance layers against, section 21.
	var positions: Array[Vector2] = []
	for view: CityBlockView in _block_views:
		var pole := view.pole_zone()
		if pole != null:
			positions.append(pole.global_position)
	return positions


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


func find_quest_site(site_name: String) -> CityBlockView:
	# The named place of the signature quest, like the garage of Sleepvana.
	# The block carries its site marker, the anchor for the quest scripts.
	for view: CityBlockView in _block_views:
		if view.block.site_name == site_name:
			return view
	return null
