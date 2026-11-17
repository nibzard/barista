# ABOUTME: MobileCafeVan is the van in the world: the survivors' gift, the rolling
# ABOUTME: kitchen, and the field base where awakened survivors gather.
class_name MobileCafeVan
extends Node2D

signal field_base_opened
signal field_base_packed

enum Interaction { NOT_AT_VAN, NEED_SCRAP, UPGRADED, OPENED_FIELD_BASE, PACKED_FIELD_BASE }

# The sleep zone scene stays a path, never a preload: several scripts share
# this scene, and a compile-time const binds an empty scene whenever another
# load of it is already running (T102).
const SLEEP_ZONE_SCENE_PATH := "res://scenes/components/sleep_zone.tscn"

# Placeholder van colors until the art pass brings the real vehicle.
const BODY_COLOR := Color(0.85, 0.72, 0.45, 1)
const ROOF_COLOR := Color(0.45, 0.32, 0.2, 1)
const WHEEL_COLOR := Color(0.15, 0.12, 0.1, 1)
const WINDOW_COLOR := Color(0.35, 0.6, 0.75, 1)
const AWNING_COLOR := Color(0.78, 0.25, 0.2, 1)
const LAMP_COLOR := Color(0.98, 0.9, 0.55, 1)
const TABLE_COLOR := Color(0.5, 0.38, 0.25, 1)
const ROOF_STRIPE_HEIGHT := 12.0
const WHEEL_RADIUS := 8.0
const WINDOW_HALF_HEIGHT := 11.0
const AWNING_SIZE := Vector2(56.0, 10.0)
const LAMP_RADIUS := 7.0
const TABLE_RADIUS := 12.0
const BODY_HALF_SIZE := Vector2(30.0, 46.0)
# The tables stand in rings around the parked van.
const FIRST_GATHER_RING_RADIUS := 78.0
const GATHER_RING_STEP := 26.0
const RING_SLOT_COUNT := 6
# The van mirror hangs on the cab. The troll doll keychain of the completed
# SleepyDex hangs there, section 9: placeholder shapes until the art pass.
const MIRROR_COLOR := Color(0.62, 0.78, 0.85, 1)
const MIRROR_RECT := Rect2(10.0, -30.0, 12.0, 18.0)
const KEYCHAIN_STRAP_COLOR := Color(0.35, 0.25, 0.15, 1)
const KEYCHAIN_HAIR_COLOR := Color(0.95, 0.45, 0.7, 1)
const KEYCHAIN_BODY_COLOR := Color(0.9, 0.74, 0.55, 1)
const KEYCHAIN_STRAP_LENGTH := 5.0
const KEYCHAIN_HEAD_RADIUS := 3.0
const KEYCHAIN_BODY_SIZE := Vector2(6.0, 8.0)

@export var balance: MobileCafeBalance
@export var notice_radius := 96.0

var state: MobileCafe = null

var _dex: SleepyDex = null
var _field_base: SleepZone = null
var _field_base_open := false
var _gathered: Array[Sleepwalker] = []
# The slot offsets are local: the field base releases its guests before a move.
var _gather_slots: Array[Vector2] = []


func _ready() -> void:
	_compose_notice_area()
	queue_redraw()


func _physics_process(_delta: float) -> void:
	if state == null:
		return
	# The survivors hand the van over when the player walks up, section 10.
	if not state.is_owned() and _player_at_van() != null:
		state.acquire()
	if _field_base_open:
		_invite_nearby_awakened()


func bind_state(van_state: MobileCafe) -> void:
	state = van_state
	state.upgraded.connect(func(_level: int) -> void: queue_redraw())
	queue_redraw()


func bind_dex(sleepy_dex: SleepyDex) -> void:
	# The completed SleepyDex hangs its keychain on the mirror, section 9.
	_dex = sleepy_dex
	sleepy_dex.keychain_awarded.connect(func() -> void: queue_redraw())
	queue_redraw()


func has_keychain_on_mirror() -> bool:
	return _dex != null and _dex.has_keychain()


func is_player_at_van() -> bool:
	return _player_at_van() != null


func is_player_brewing_here() -> bool:
	# Section 10, level 2: with a kitchen inside, the player brews anywhere the
	# van stands, outside the city cafe.
	return state != null and state.can_brew_outside_cafe() and is_player_at_van()


func interact(player: Player) -> Interaction:
	# One button at the van, context-sensitive: upgrade while scrap allows it,
	# then toggle the field base at level 3.
	if state == null or player == null or not is_player_at_van():
		return Interaction.NOT_AT_VAN
	if not state.is_fully_upgraded():
		if state.upgrade(player.inventory):
			return Interaction.UPGRADED
		return Interaction.NEED_SCRAP
	if _field_base_open:
		pack_field_base()
		return Interaction.PACKED_FIELD_BASE
	open_field_base(global_position)
	return Interaction.OPENED_FIELD_BASE


func call_to(park_position: Vector2) -> bool:
	# Park anywhere, section 10: the player calls, the van drives up and parks,
	# and the field base opens around it. Below level 3 the van stays put.
	if state == null or not state.is_field_cafe():
		return false
	return open_field_base(park_position)


func open_field_base(park_position: Vector2) -> bool:
	# Park anywhere, section 10: the van parks, and the field base opens around
	# it: a safe zone, tables, an awning, and a lamp.
	if state == null or not state.is_field_cafe():
		return false
	_release_gathered()
	global_position = park_position
	if _field_base == null:
		_field_base = (load(SLEEP_ZONE_SCENE_PATH) as PackedScene).instantiate() as SleepZone
		_field_base.name = "FieldBaseZone"
		_field_base.kind = SleepZone.Kind.SAFE
		var shape_node := _field_base.get_node(^"CollisionShape2D") as CollisionShape2D
		var circle := CircleShape2D.new()
		circle.radius = balance.field_base_radius
		shape_node.shape = circle
		add_child(_field_base)
	_field_base_open = true
	queue_redraw()
	field_base_opened.emit()
	return true


func pack_field_base() -> void:
	if not _field_base_open:
		return
	_field_base_open = false
	_release_gathered()
	if _field_base != null:
		_field_base.queue_free()
		_field_base = null
	queue_redraw()
	field_base_packed.emit()


func is_field_base_open() -> bool:
	return _field_base_open


func field_base_zone() -> SleepZone:
	return _field_base


func gathered_survivors() -> Array[Sleepwalker]:
	# The survivors that stand with the van: sent to a slot and arrived.
	var arrived: Array[Sleepwalker] = []
	for i: int in range(_gathered.size()):
		var survivor := _gathered[i]
		if survivor.is_awake() and _has_arrived(survivor, _gather_slots[i]):
			arrived.append(survivor)
	return arrived


func _invite_nearby_awakened() -> void:
	# Every awakened survivor inside the field base reach drifts to a table. A
	# survivor that follows a leader, like a Sleepvana fan on the walk to the
	# garage, keeps walking and never takes a table again.
	for node: Node in get_tree().get_nodes_in_group(&"sleepwalkers"):
		var survivor := node as Sleepwalker
		if survivor == null or not survivor.is_awake():
			continue
		if survivor.is_gathering() or survivor.is_following():
			continue
		if survivor.global_position.distance_to(global_position) > balance.field_base_radius:
			continue
		var slot := _gather_slot(_gathered.size())
		_gather_slots.append(slot)
		_gathered.append(survivor)
		survivor.gather_at(global_position + slot)


func release_survivors(survivors: Array[Sleepwalker]) -> void:
	# The gathered guests leave the tables for a leader, like the fan crowd of
	# the Sleepvana show, section 13. They stop gathering and leave the list.
	for survivor: Sleepwalker in survivors:
		var index := _gathered.find(survivor)
		if index < 0:
			continue
		survivor.stop_gathering()
		_gathered.remove_at(index)
		_gather_slots.remove_at(index)
	queue_redraw()


func _release_gathered() -> void:
	for survivor: Sleepwalker in _gathered:
		survivor.stop_gathering()
	_gathered.clear()
	_gather_slots.clear()


func _gather_slot(index: int) -> Vector2:
	var ring := index / RING_SLOT_COUNT
	var slot_in_ring := index % RING_SLOT_COUNT
	var radius := FIRST_GATHER_RING_RADIUS + GATHER_RING_STEP * float(ring)
	var angle := TAU * float(slot_in_ring) / float(RING_SLOT_COUNT) + TAU * 0.13 * float(ring)
	return Vector2.from_angle(angle) * radius


func _has_arrived(survivor: Sleepwalker, slot: Vector2) -> bool:
	return (
		survivor.global_position.distance_to(slot + global_position)
		<= (survivor.balance.gather_stop_distance)
	)


func _player_at_van() -> Player:
	var notice := get_node_or_null(^"NoticeArea") as Area2D
	if notice == null:
		return null
	for body: Node2D in notice.get_overlapping_bodies():
		if body is Player:
			return body
	return null


func _compose_notice_area() -> void:
	var notice := Area2D.new()
	notice.name = "NoticeArea"
	notice.collision_layer = 0
	notice.collision_mask = 2
	notice.monitorable = false
	var shape_node := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = notice_radius
	shape_node.shape = circle
	notice.add_child(shape_node)
	add_child(notice)


func _draw() -> void:
	# Placeholder van: the body grows a serving window at level 2, then an
	# awning and a lamp at level 3. The open field base draws the tables.
	var body := Rect2(
		-BODY_HALF_SIZE.x, -BODY_HALF_SIZE.y, BODY_HALF_SIZE.x * 2.0, BODY_HALF_SIZE.y * 2.0
	)
	draw_rect(body, BODY_COLOR)
	draw_rect(Rect2(body.position.x, body.position.y, body.size.x, ROOF_STRIPE_HEIGHT), ROOF_COLOR)
	for wheel: Vector2 in [
		Vector2(-BODY_HALF_SIZE.x, 18.0),
		Vector2(BODY_HALF_SIZE.x, 18.0),
		Vector2(-BODY_HALF_SIZE.x, -18.0),
		Vector2(BODY_HALF_SIZE.x, -18.0),
	]:
		draw_circle(wheel, WHEEL_RADIUS, WHEEL_COLOR)
	if state != null and state.has_kitchen():
		draw_rect(Rect2(-9.0, -WINDOW_HALF_HEIGHT, 18.0, WINDOW_HALF_HEIGHT * 2.0), WINDOW_COLOR)
	if state != null and state.is_field_cafe():
		draw_rect(
			Rect2(-AWNING_SIZE.x * 0.5, -BODY_HALF_SIZE.y - 16.0, AWNING_SIZE.x, AWNING_SIZE.y),
			AWNING_COLOR
		)
		draw_circle(Vector2(0.0, -BODY_HALF_SIZE.y - 27.0), LAMP_RADIUS, LAMP_COLOR)
	if _field_base_open:
		for slot: Vector2 in _gather_slots:
			draw_circle(slot, TABLE_RADIUS, TABLE_COLOR)
	_draw_mirror_and_keychain()


func _draw_mirror_and_keychain() -> void:
	# The mirror always hangs by the cab. The troll doll swings under it only
	# after the SleepyDex completes, and it stays a picture: no stats, no
	# skill, no secret, section 9.
	draw_rect(MIRROR_RECT, MIRROR_COLOR)
	if not has_keychain_on_mirror():
		return
	var strap_top := Vector2(MIRROR_RECT.get_center().x, MIRROR_RECT.end.y)
	draw_line(strap_top, strap_top + Vector2(0.0, KEYCHAIN_STRAP_LENGTH), KEYCHAIN_STRAP_COLOR, 1.5)
	var head_center := strap_top + Vector2(0.0, KEYCHAIN_STRAP_LENGTH + KEYCHAIN_HEAD_RADIUS)
	draw_circle(head_center, KEYCHAIN_HEAD_RADIUS, KEYCHAIN_HAIR_COLOR)
	var body_rect := Rect2(
		head_center.x - KEYCHAIN_BODY_SIZE.x * 0.5,
		head_center.y + KEYCHAIN_HEAD_RADIUS * 0.5,
		KEYCHAIN_BODY_SIZE.x,
		KEYCHAIN_BODY_SIZE.y
	)
	draw_rect(body_rect, KEYCHAIN_BODY_COLOR)
