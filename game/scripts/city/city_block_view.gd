# ABOUTME: CityBlockView is the shared kit scene script for one city block.
# ABOUTME: It composes the sleep zone and scavenge scenes from the block data.
class_name CityBlockView
extends Node2D

const SLEEP_ZONE_SCENE := preload("res://scenes/components/sleep_zone.tscn")
const SCAVENGE_POINT_SCENE := preload("res://scenes/components/scavenge_point.tscn")
const BROADCAST_TOWER_SCENE := preload("res://scenes/tower/broadcast_tower.tscn")
const HOUSE_BEANS := preload("res://resources/items/beans/house.tres")

const FLOOR_COLOR := Color(0.18, 0.14, 0.1, 1)
const ACCENT_BORDER_WIDTH := 6.0
const KIND_MARKER_RADIUS := 70.0
const KIND_TEXT_SIZE := 26
const KIND_TEXT_COLOR := Color(0.12, 0.09, 0.06)
const CROWD_MARKER_SPACING := 90.0
const CROWD_MARKER_LANE_Y := 0.5
const LOOT_POINT_OFFSET := Vector2(0, -170)
const KIT_LOOT_AMOUNT := 3

# Placeholder landmark marker colors until the art pass replaces the kit shapes.
const KIND_COLORS := {
	CityBlock.Kind.CAFE: Color(0.93, 0.87, 0.72),
	CityBlock.Kind.TOWER: Color(0.78, 0.16, 0.14),
	CityBlock.Kind.BOSS_ARENA: Color(0.35, 0.3, 0.42),
	CityBlock.Kind.QUEST: Color(0.85, 0.7, 0.25),
	CityBlock.Kind.SCAVENGE: Color(0.55, 0.4, 0.25),
}

@export var block: CityBlock
@export var accent_color := Color.WHITE
@export var balance: CityBalance

var size := Vector2.ZERO
var _built := false


func _ready() -> void:
	if block != null and balance != null:
		build()


func build() -> void:
	if _built:
		return
	_built = true
	size = CityRules.block_size(balance)
	_compose()
	queue_redraw()


func kind() -> CityBlock.Kind:
	return block.kind


func crowd_spawn_markers() -> Array[Marker2D]:
	var markers: Array[Marker2D] = []
	if not _built:
		return markers
	for child: Node in get_node(^"Crowd").get_children():
		var marker := child as Marker2D
		if marker != null:
			markers.append(marker)
	return markers


func pole_zone() -> SleepZone:
	if not _built:
		return null
	return get_node_or_null(^"Zones/SpeakerPoleZone") as SleepZone


func safe_zone() -> SleepZone:
	if not _built:
		return null
	return get_node_or_null(^"Zones/CafeSafeZone") as SleepZone


func scavenge_point() -> ScavengePoint:
	if not _built:
		return null
	return get_node_or_null(^"Scavenge/LootPoint") as ScavengePoint


func broadcast_tower() -> BroadcastTower:
	if not _built:
		return null
	return get_node_or_null(^"BroadcastTower") as BroadcastTower


func _compose() -> void:
	var zones := Node2D.new()
	zones.name = "Zones"
	add_child(zones)
	var crowd := Node2D.new()
	crowd.name = "Crowd"
	add_child(crowd)
	for i: int in range(block.sleepwalker_count):
		var marker := Marker2D.new()
		marker.name = "CrowdSpawn%d" % i
		marker.position = _crowd_spawn_position(i)
		crowd.add_child(marker)
	if block.kind == CityBlock.Kind.CAFE:
		var cafe_safe_zone := SLEEP_ZONE_SCENE.instantiate() as SleepZone
		cafe_safe_zone.name = "CafeSafeZone"
		cafe_safe_zone.kind = SleepZone.Kind.SAFE
		cafe_safe_zone.position = size * 0.5
		zones.add_child(cafe_safe_zone)
	if block.has_speaker_pole:
		var pole := SLEEP_ZONE_SCENE.instantiate() as SleepZone
		pole.name = "SpeakerPoleZone"
		pole.position = size * 0.5
		zones.add_child(pole)
	if block.kind == CityBlock.Kind.TOWER:
		var tower := BROADCAST_TOWER_SCENE.instantiate() as BroadcastTower
		tower.name = "BroadcastTower"
		tower.position = size * 0.5
		add_child(tower)
	if block.kind == CityBlock.Kind.SCAVENGE:
		var scavenge := Node2D.new()
		scavenge.name = "Scavenge"
		add_child(scavenge)
		var loot := SCAVENGE_POINT_SCENE.instantiate() as ScavengePoint
		loot.name = "LootPoint"
		loot.position = size * 0.5 + LOOT_POINT_OFFSET
		var drop := ScavengeDrop.new()
		drop.item = HOUSE_BEANS
		drop.amount = KIT_LOOT_AMOUNT
		loot.drops = [drop]
		scavenge.add_child(loot)


func _crowd_spawn_position(i: int) -> Vector2:
	var spread := CROWD_MARKER_SPACING * float(block.sleepwalker_count - 1)
	var x := size.x * 0.5 - spread * 0.5 + CROWD_MARKER_SPACING * float(i)
	return Vector2(x, size.y * CROWD_MARKER_LANE_Y)


func _draw() -> void:
	if not _built:
		return
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, FLOOR_COLOR)
	draw_rect(rect, accent_color, false, ACCENT_BORDER_WIDTH)
	draw_circle(size * 0.5, KIND_MARKER_RADIUS, KIND_COLORS[block.kind])
	draw_string(
		ThemeDB.fallback_font,
		Vector2(0, size.y * 0.5 + KIND_TEXT_SIZE * 0.5),
		CityRules.kind_name(block.kind).to_upper(),
		HORIZONTAL_ALIGNMENT_CENTER,
		size.x,
		KIND_TEXT_SIZE,
		KIND_TEXT_COLOR
	)
