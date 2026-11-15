# ABOUTME: CityBlockView is the shared kit scene script for one city block.
# ABOUTME: It composes the sleep zone and scavenge scenes from the block data.
class_name CityBlockView
extends Node2D

const SLEEP_ZONE_SCENE := preload("res://scenes/components/sleep_zone.tscn")
const SCAVENGE_POINT_SCENE := preload("res://scenes/components/scavenge_point.tscn")
const BROADCAST_TOWER_SCENE := preload("res://scenes/tower/broadcast_tower.tscn")
const HOUSE_BEANS := preload("res://resources/items/beans/house.tres")
const FUSE_ITEM := preload("res://resources/items/materials/fuse.tres")
const SCRAP_PART_ITEM := preload("res://resources/items/materials/scrap_part.tres")

const FLOOR_COLOR := Color(0.18, 0.14, 0.1, 1)
const ACCENT_BORDER_WIDTH := 6.0
const KIND_MARKER_RADIUS := 70.0
# Section 10: the cafe marker grows with the cafe tier of the city. The tier
# steps stay presentation-only; the safe zone radius lives in the balance.
const CAFE_MARKER_TIER_STEP := 0.4
const QUEST_SITE_MARKER_RADIUS := 45.0
const KIND_TEXT_SIZE := 26
const KIND_TEXT_COLOR := Color(0.12, 0.09, 0.06)
const LABEL_TEXT_SIZE := 17
const LABEL_GAP := 8.0
const CROWD_MARKER_SPACING := 90.0
const CROWD_MARKER_LANE_Y := 0.5
# The player start stands off the crowd lane, inside the cafe safe zone.
const CAFE_SPAWN_FRACTION := Vector2(0.35, 0.35)
# The van stands by the cafe, outside the safe zone: the survivors hand it over
# there, section 10. When a bigger cafe tier grows the zone past the spot, the
# spot steps past the radius and keeps its kit direction.
const VAN_SPOT_FRACTION := Vector2(0.78, 0.3)
const VAN_SPOT_CLEARANCE := 60.0
# The brewing master of the city teaches at the cafe, inside the safe zone,
# section 8: the awake coffee experts gather where the coffee is real.
const MASTER_SPOT_FRACTION := Vector2(0.4, 0.66)
# A named site stands north of the crowd lane, off the pole zone center.
const QUEST_SITE_FRACTION := Vector2(0.5, 0.32)
const LOOT_POINT_OFFSET := Vector2(0, -170)
const KIT_LOOT_AMOUNT := 3
# Section 15: scrap parts pay for the van upgrades.
const KIT_SCRAP_AMOUNT := 2
# Section 19 step 9: one fuse waits at the foot of the tower.
const TOWER_FUSE_OFFSET := Vector2(140, 0)

# Placeholder landmark marker colors until the art pass replaces the kit shapes.
const KIND_COLORS := {
	CityBlock.Kind.CAFE: Color(0.93, 0.87, 0.72),
	CityBlock.Kind.TOWER: Color(0.78, 0.16, 0.14),
	CityBlock.Kind.BOSS_ARENA: Color(0.35, 0.3, 0.42),
	CityBlock.Kind.QUEST: Color(0.85, 0.7, 0.25),
	CityBlock.Kind.SCAVENGE: Color(0.55, 0.4, 0.25),
	CityBlock.Kind.QUEST_SITE: Color(0.55, 0.62, 0.45),
}

@export var block: CityBlock
@export var accent_color := Color.WHITE
@export var balance: CityBalance
# Section 10: the cafe tier of the city sizes the cafe marker and safe zone.
@export var cafe_tier: int = 1
# The city fills this in: the boss name on the arena, the quest name on the
# signature quest location. Empty on every other block.
@export var landmark_label := ""
# The city fills this in: the named place on the block, like the greenhouse of
# the Sleepvana quest. Empty on plain kit blocks.
@export var site_label := ""

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


func tower_fuse_point() -> ScavengePoint:
	if not _built:
		return null
	return get_node_or_null(^"Scavenge/TowerFuse") as ScavengePoint


func cafe_spawn() -> Marker2D:
	if not _built:
		return null
	return get_node_or_null(^"CafeSpawn") as Marker2D


func van_spot() -> Marker2D:
	if not _built:
		return null
	return get_node_or_null(^"VanSpot") as Marker2D


func master_spot() -> Marker2D:
	# The brewing master of the city stands here, inside the cafe safe zone.
	if not _built:
		return null
	return get_node_or_null(^"MasterSpot") as Marker2D


func quest_site_marker() -> Marker2D:
	# The anchor of a named place, like the garage of the Sleepvana quest. The
	# quest scripts find their band members here.
	if not _built:
		return null
	return get_node_or_null(^"QuestSite") as Marker2D


func cafe_zone_radius() -> float:
	# The safe zone radius that the tier of the city cafe sets, section 10.
	if not _built or block.kind != CityBlock.Kind.CAFE:
		return 0.0
	return CityRules.cafe_zone_radius(balance, cafe_tier)


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
		var zone_shape := cafe_safe_zone.get_node(^"CollisionShape2D") as CollisionShape2D
		var zone_circle := CircleShape2D.new()
		zone_circle.radius = CityRules.cafe_zone_radius(balance, cafe_tier)
		zone_shape.shape = zone_circle
		zones.add_child(cafe_safe_zone)
		var spawn := Marker2D.new()
		spawn.name = "CafeSpawn"
		spawn.position = size * CAFE_SPAWN_FRACTION
		add_child(spawn)
		var van_spot := Marker2D.new()
		van_spot.name = "VanSpot"
		van_spot.position = _van_spot_position()
		add_child(van_spot)
		var master_spot := Marker2D.new()
		master_spot.name = "MasterSpot"
		master_spot.position = size * MASTER_SPOT_FRACTION
		add_child(master_spot)
	if not block.site_name.is_empty():
		var site := Marker2D.new()
		site.name = "QuestSite"
		site.position = size * QUEST_SITE_FRACTION
		add_child(site)
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
		var scavenge := Node2D.new()
		scavenge.name = "Scavenge"
		add_child(scavenge)
		var fuse_point := SCAVENGE_POINT_SCENE.instantiate() as ScavengePoint
		fuse_point.name = "TowerFuse"
		fuse_point.position = size * 0.5 + TOWER_FUSE_OFFSET
		var fuse_drop := ScavengeDrop.new()
		fuse_drop.item = FUSE_ITEM
		fuse_drop.amount = 1
		fuse_point.drops = [fuse_drop]
		scavenge.add_child(fuse_point)
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
		var scrap_drop := ScavengeDrop.new()
		scrap_drop.item = SCRAP_PART_ITEM
		scrap_drop.amount = KIT_SCRAP_AMOUNT
		loot.drops = [drop, scrap_drop]
		scavenge.add_child(loot)


func _crowd_spawn_position(i: int) -> Vector2:
	var spread := CROWD_MARKER_SPACING * float(block.sleepwalker_count - 1)
	var x := size.x * 0.5 - spread * 0.5 + CROWD_MARKER_SPACING * float(i)
	return Vector2(x, size.y * CROWD_MARKER_LANE_Y)


func _van_spot_position() -> Vector2:
	# Section 10: the van stands by the cafe but outside its safe zone, so the
	# cafe brew and the van brew stay two different places. A bigger cafe tier
	# grows the zone past the plain kit fraction, so the spot slides out along
	# its direction until it clears the radius.
	var center := size * 0.5
	var offset := size * VAN_SPOT_FRACTION - center
	var zone_radius := CityRules.cafe_zone_radius(balance, cafe_tier)
	if offset.length() > zone_radius:
		return center + offset
	return center + offset.normalized() * (zone_radius + VAN_SPOT_CLEARANCE)


func _draw() -> void:
	if not _built:
		return
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, FLOOR_COLOR)
	draw_rect(rect, accent_color, false, ACCENT_BORDER_WIDTH)
	draw_circle(size * 0.5, _marker_radius(), KIND_COLORS[block.kind])
	draw_string(
		ThemeDB.fallback_font,
		Vector2(0, size.y * 0.5 + KIND_TEXT_SIZE * 0.5),
		CityRules.kind_name(block.kind).to_upper(),
		HORIZONTAL_ALIGNMENT_CENTER,
		size.x,
		KIND_TEXT_SIZE,
		KIND_TEXT_COLOR
	)
	var label_y := size.y * 0.5 + KIND_TEXT_SIZE * 0.5
	for label: String in [landmark_label, site_label]:
		if label.is_empty():
			continue
		label_y += LABEL_TEXT_SIZE + LABEL_GAP
		draw_string(
			ThemeDB.fallback_font,
			Vector2(0, label_y),
			label,
			HORIZONTAL_ALIGNMENT_CENTER,
			size.x,
			LABEL_TEXT_SIZE,
			accent_color
		)


func _marker_radius() -> float:
	# The cafe marker grows with the tier of the city, section 10; the minor
	# quest sites draw smaller than the big landmarks.
	if block.kind == CityBlock.Kind.CAFE:
		return KIND_MARKER_RADIUS * (1.0 + CAFE_MARKER_TIER_STEP * float(cafe_tier - 1))
	if block.kind == CityBlock.Kind.QUEST_SITE:
		return QUEST_SITE_MARKER_RADIUS
	return KIND_MARKER_RADIUS
