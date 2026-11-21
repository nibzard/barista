# ABOUTME: CityMap composes one city from the shared block kit scene.
# ABOUTME: The blocks stand in one row: cafe edge first, tower edge last.
class_name CityMap
extends Node2D

const CITY_BLOCK_SCENE := preload("res://scenes/city/city_block.tscn")
# The tower bloom: the wake burst at city scale, ART_DIRECTION section 1.
const TOWER_BLOOM_SCALE := 7.0
const TOWER_BLOOM_SECONDS := 1.4

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
	var old_stage := look_stage()
	if old_stage != null:
		remove_child(old_stage)
		old_stage.queue_free()
	var block_size := CityRules.block_size(balance)
	for i: int in range(definition.blocks.size()):
		var view := CITY_BLOCK_SCENE.instantiate() as CityBlockView
		view.name = "Block%02d" % i
		view.block = definition.blocks[i]
		view.accent_color = definition.accent_color
		view.city_look = definition.city_look
		view.balance = balance
		view.region_bean = definition.region_bean
		view.crate_extras = definition.crate_extras
		view.cafe_tier = definition.cafe_tier
		view.landmark_label = _landmark_label_for(definition.blocks[i].kind)
		view.site_label = definition.blocks[i].site_name
		view.position = Vector2(block_size.x * float(i), 0.0)
		add_child(view)
		_block_views.append(view)
	var tower := broadcast_tower()
	if tower != null:
		tower.switched_off.connect(_on_tower_switched_off)
	if definition.city_look != null:
		# The live wiring of the art direction: dusk light, weather, and paper
		# grain over the whole city, ART_DIRECTION section 14.
		var stage := CityLookStage.new()
		stage.name = "LookStage"
		stage.setup(definition.city_look, city_size())
		add_child(stage)


func look_stage() -> CityLookStage:
	return get_node_or_null(^"LookStage") as CityLookStage


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


func load_tower_state(saved_phase: int) -> void:
	# The save system hands the stored tower phase back on a reload. A loaded
	# tower never replays the beat, so the map silences the poles itself when
	# the saved phase is off, like the live switch does.
	var tower := broadcast_tower()
	if tower == null:
		return
	tower.load_state(saved_phase)
	if tower.is_switched_off():
		var stage := look_stage()
		if stage != null:
			# A loaded city never replays the sunrise: the morning stands.
			stage.bring_morning(true)
		_silence_city()


func _on_tower_switched_off() -> void:
	# The live switch: the city goes quiet and the reward bloom plays. A
	# loaded save calls _silence_city alone, so it never replays the beat.
	_silence_city()
	_bloom_at_tower()


func _silence_city() -> void:
	# The address of the city is dead: every speaker pole zone goes quiet.
	for view: CityBlockView in _block_views:
		var pole := view.pole_zone()
		if pole != null:
			pole.silence_broadcast()
	var stage := look_stage()
	if stage != null:
		stage.bring_morning()


func _bloom_at_tower() -> void:
	# The reward beat of section 19 step 9: a big ring of morning light runs
	# out from the dead tower, and the camera takes one strong bump.
	var tower_block := find_block_of_kind(CityBlock.Kind.TOWER)
	if tower_block == null:
		return
	var bloom := WakeBurst.new()
	bloom.name = "TowerBloom"
	bloom.duration = TOWER_BLOOM_SECONDS
	bloom.kick_strength = 0.9
	bloom.scale = Vector2.ONE * TOWER_BLOOM_SCALE
	bloom.position = tower_block.position + tower_block.size * 0.5
	add_child(bloom)


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


func locked_side_room() -> LockedSideRoom:
	# The one locked side room of the city, section 15, when a block hosts
	# it. The save system reads the door through this single handle.
	for view: CityBlockView in _block_views:
		var room := view.locked_side_room()
		if room != null:
			return room
	return null
