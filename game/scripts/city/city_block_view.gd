# ABOUTME: CityBlockView is the shared kit scene script for one city block.
# ABOUTME: It composes the cafe and scavenge buildings and the zones from data.
class_name CityBlockView
extends Node2D

# The sleep zone scene stays a path, never a preload: several scripts share
# this scene, and a compile-time const binds an empty scene whenever another
# load of it is already running (T102). The scavenge point scene, the tower
# scene, and the kit items follow the same rule: the cafe scene and the
# balance resources also load each of them (T112).
const SLEEP_ZONE_SCENE_PATH := "res://scenes/components/sleep_zone.tscn"
const SCAVENGE_POINT_SCENE_PATH := "res://scenes/components/scavenge_point.tscn"
const BROADCAST_TOWER_SCENE_PATH := "res://scenes/tower/broadcast_tower.tscn"
const HOUSE_BEANS_PATH := "res://resources/items/beans/house.tres"
const FUSE_ITEM_PATH := "res://resources/items/materials/fuse.tres"
const SCRAP_PART_ITEM_PATH := "res://resources/items/materials/scrap_part.tres"
const SEEDLING_ITEM_PATH := "res://resources/items/materials/coffee_seedling.tres"
const BUILDING_SHELL_SCENE := preload("res://scenes/components/building_shell.tscn")
const LOCKED_SIDE_ROOM_SCENE := preload("res://scenes/components/locked_side_room.tscn")
const CAFE_TELEVISION_SCENE := preload("res://scenes/cafe/cafe_television.tscn")

const KIND_MARKER_RADIUS := 70.0
# Section 10: the cafe marker grows with the cafe tier of the city. The tier
# steps stay presentation-only; the safe zone radius lives in the balance.
const CAFE_MARKER_TIER_STEP := 0.4
const QUEST_SITE_MARKER_RADIUS := 45.0
const LABEL_GAP := 8.0
const CROWD_MARKER_SPACING := 90.0
const CROWD_MARKER_LANE_Y := 0.5
# The cafe crowd wanders the south street, past the window, section 19 step 4.
# The lane stands far off the player start: a Neighbor senses 110 px around
# itself, and a chase into the cafe on the wake-up frames would break the
# script. The mid-block lane keeps the plain kit look on every other block.
const CAFE_CROWD_MARKER_LANE_Y := 0.9
# The interior anchors of the cafe, T063: fractions of the interior half
# extents of the tier-sized cafe building, minus one to one per axis. Every
# anchor rides the building, so it stays inside the safe zone by construction
# and keeps its kit direction in every city.
# The player start stands in the northwest of the floor, off the crowd lane
# and the walls, with open floor for the first walk of section 19.
const CAFE_SPAWN_ANCHOR := Vector2(-0.72, -0.45)
# The van stands by the cafe, outside the safe zone: the survivors hand it over
# there, section 10. When a bigger cafe tier grows the zone past the spot, the
# spot steps past the radius and keeps its kit direction.
const VAN_SPOT_FRACTION := Vector2(0.78, 0.3)
const VAN_SPOT_CLEARANCE := 60.0
# The brewing master of the city teaches in the northeast of the floor, off
# the south door, section 8: the awake coffee experts gather where the coffee
# is real. The school spaces a master pair along the spot, clear of the wall.
const CAFE_MASTER_ANCHOR := Vector2(0.65, -0.5)
# The cafe television hangs in the southwest of the floor, off the door, the
# master spot, and the player start, so the section 22 replay never snags
# another cafe lesson.
const CAFE_TELEVISION_ANCHOR := Vector2(-0.75, 0.68)
# A named site stands north of the crowd lane, off the pole zone center.
const QUEST_SITE_FRACTION := Vector2(0.5, 0.32)
# Section 17: the scavenge building stands on the crate row, north of the
# crowd lane. The crate waits inside its walls.
const LOOT_POINT_OFFSET := Vector2(0, -170)
# Section 15: the locked side room stands west of the scavenge building, its
# own small vault on the same crate row.
const SIDE_ROOM_SIZE := Vector2(170.0, 200.0)
const SIDE_ROOM_GAP := 14.0
# Section 15: the unique find of a block waits at its own loot spot. Inside a
# scavenge building, the spot stands south of the crate, still behind the
# walls.
const INTERIOR_FIND_OFFSET := Vector2(0, 80)
# The open-street spot for a find on a block without a building.
const FIND_POINT_OFFSET := Vector2(0, 170)
# Section 19 step 9: one fuse waits at the foot of the tower.
const TOWER_FUSE_OFFSET := Vector2(140, 0)

# The art direction pass, section 20: warm creams, wood browns, and brick
# reds on the kit, one accent per city, and no horror darkness anywhere.
# Landmark markers take the world palette; the tower block carries the
# corporate red of Mug Roasters Co.
const ACCENT_WASH_ALPHA := 0.14
const STREET_LANE_HEIGHT := 0.24
const STREET_TILE_PATH := "res://assets/art/tiles/street_tile.jpg"

@export var block: CityBlock
@export var accent_color := Color.WHITE
# The art identity of the city: the kit washes its street lane with the city
# accent, ART_DIRECTION section 6. Null keeps the plain kit.
@export var city_look: CityLook
@export var balance: CityBalance
# Section 15 beans table: the region bean of the city. The scavenge crates of
# a region city yield it on top of the house beans. Null when the city holds
# none, like San Coffesco.
@export var region_bean: ItemType
# Section 15: the stock every scavenge crate of the city holds on top of the
# kit beans and scrap, like the vault key that opens the locked side room.
# The city hands this down from its own data.
@export var crate_extras: Array[ScavengeDrop] = []
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
var _palette: ArtPalette
var _street_tex: Texture2D = null


func _ready() -> void:
	if block != null and balance != null:
		build()


func build() -> void:
	if _built:
		return
	_built = true
	_palette = ArtPalette.world()
	size = CityRules.block_size(balance)
	_compose()
	queue_redraw()


func kind() -> CityBlock.Kind:
	return block.kind


func _sleep_zone_scene() -> PackedScene:
	# Loaded at use time: every script is compiled by then, so no compile
	# order can hand the kit an empty scene.
	return load(SLEEP_ZONE_SCENE_PATH) as PackedScene


func _scavenge_point_scene() -> PackedScene:
	# Loaded at use time: the cafe scene also stands scavenge points, so no
	# compile order can hand the kit an empty scene (T112).
	return load(SCAVENGE_POINT_SCENE_PATH) as PackedScene


func _broadcast_tower_scene() -> PackedScene:
	# Loaded at use time: the cafe scene also stands a tower, so no compile
	# order can hand the kit an empty scene (T112).
	return load(BROADCAST_TOWER_SCENE_PATH) as PackedScene


func _kit_item(path: String) -> ItemType:
	# Loaded at use time: the cafe scene and the balance resources also load
	# these items, so no compile order can hand the kit an empty item (T112).
	return load(path) as ItemType


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


func building() -> BuildingShell:
	# The enterable scavenge building of the block, section 17. Null on every
	# landmark block: the cafe keeps its own building through cafe_building().
	if not _built:
		return null
	return get_node_or_null(^"Building") as BuildingShell


func cafe_building() -> BuildingShell:
	# The enterable cafe building of the city, T063: the tier-sized shell at
	# the safe zone center, whose whole interior the safe zone covers. Null on
	# every other block.
	if not _built:
		return null
	return get_node_or_null(^"CafeBuilding") as BuildingShell


func locked_side_room() -> LockedSideRoom:
	# The locked side room of the city, section 15: the Geisha Vault beans
	# wait behind its door. Null on every block the city authors no room for.
	if not _built:
		return null
	return get_node_or_null(^"SideRoom") as LockedSideRoom


func find_point() -> ScavengePoint:
	# The unique find of the block, section 15, when the city authors one.
	if not _built:
		return null
	return get_node_or_null(^"Scavenge/FindPoint") as ScavengePoint


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


func television() -> CafeTelevision:
	# The cafe television of section 22: the Dr. Morgen video replays here
	# after the opening.
	if not _built:
		return null
	return get_node_or_null(^"CafeTelevision") as CafeTelevision


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
		# The real cafe building, T063: one kit shell at the safe zone center,
		# sized so the zone circle covers its whole interior. The tier of the
		# city cafe sizes the floor, and the shell adds its walls around it.
		var cafe_building := BUILDING_SHELL_SCENE.instantiate() as BuildingShell
		cafe_building.name = "CafeBuilding"
		cafe_building.position = size * 0.5
		var wall := cafe_building.wall_thickness
		cafe_building.building_size = (
			CityRules.cafe_interior_size(balance, cafe_tier) + Vector2(wall, wall) * 2.0
		)
		add_child(cafe_building)
		# The furniture of the cafe: it rides the shell and never collides.
		var dressing := CafeDressing.new()
		dressing.name = "CafeDressing"
		dressing.interior_size = cafe_building.interior_rect().size
		cafe_building.add_child(dressing)
		var cafe_safe_zone := _sleep_zone_scene().instantiate() as SleepZone
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
		spawn.position = _cafe_anchor(CAFE_SPAWN_ANCHOR)
		add_child(spawn)
		var van_spot := Marker2D.new()
		van_spot.name = "VanSpot"
		van_spot.position = _van_spot_position()
		add_child(van_spot)
		var master_spot := Marker2D.new()
		master_spot.name = "MasterSpot"
		master_spot.position = _cafe_anchor(CAFE_MASTER_ANCHOR)
		add_child(master_spot)
		var television := CAFE_TELEVISION_SCENE.instantiate() as CafeTelevision
		television.name = "CafeTelevision"
		television.position = _cafe_anchor(CAFE_TELEVISION_ANCHOR)
		add_child(television)
	if not block.site_name.is_empty():
		var site := Marker2D.new()
		site.name = "QuestSite"
		site.position = size * QUEST_SITE_FRACTION
		add_child(site)
	if block.has_speaker_pole:
		var pole := _sleep_zone_scene().instantiate() as SleepZone
		pole.name = "SpeakerPoleZone"
		pole.position = size * 0.5
		zones.add_child(pole)
	if block.kind == CityBlock.Kind.TOWER:
		var tower := _broadcast_tower_scene().instantiate() as BroadcastTower
		tower.name = "BroadcastTower"
		tower.position = size * 0.5
		add_child(tower)
		var scavenge := Node2D.new()
		scavenge.name = "Scavenge"
		add_child(scavenge)
		var fuse_point := _scavenge_point_scene().instantiate() as ScavengePoint
		fuse_point.name = "TowerFuse"
		fuse_point.position = size * 0.5 + TOWER_FUSE_OFFSET
		var fuse_drop := ScavengeDrop.new()
		fuse_drop.item = _kit_item(FUSE_ITEM_PATH)
		# The stock reads the same balance the switch consumes, so a tuning
		# change to fuses_needed in broadcast_tower.tres moves the stock with
		# it and the tower stays openable.
		fuse_drop.amount = tower.balance.fuses_needed
		fuse_point.drops = [fuse_drop]
		scavenge.add_child(fuse_point)
	if block.kind == CityBlock.Kind.SCAVENGE:
		# Section 17: the rest of the city is scavenge buildings, and section
		# 4: the player enters houses. The shell wraps the crate row: the loot
		# waits behind its walls, and the south door is the way in.
		var building := BUILDING_SHELL_SCENE.instantiate() as BuildingShell
		building.name = "Building"
		building.position = size * 0.5 + LOOT_POINT_OFFSET
		add_child(building)
		var scavenge := Node2D.new()
		scavenge.name = "Scavenge"
		add_child(scavenge)
		var loot := _scavenge_point_scene().instantiate() as ScavengePoint
		loot.name = "LootPoint"
		loot.position = size * 0.5 + LOOT_POINT_OFFSET
		var drop := ScavengeDrop.new()
		drop.item = _kit_item(HOUSE_BEANS_PATH)
		drop.amount = balance.scavenge_house_beans
		# Section 15: scrap parts pay for the van upgrades. One city's scavenge
		# loot funds both upgrade steps on its own, section 10, so the field
		# cafe never depends on scrap the bag left in the city west.
		var scrap_drop := ScavengeDrop.new()
		scrap_drop.item = _kit_item(SCRAP_PART_ITEM_PATH)
		scrap_drop.amount = balance.scavenge_scrap_parts
		var drops: Array[ScavengeDrop] = [drop, scrap_drop]
		if balance.scavenge_seedlings > 0:
			# Section 6, T109: the crates restock the plantable bait along the
			# route. The stock reads the balance, never a kit literal (T086),
			# so a city that stands the bait down keeps plain crates.
			var seedling_drop := ScavengeDrop.new()
			seedling_drop.item = _kit_item(SEEDLING_ITEM_PATH)
			seedling_drop.amount = balance.scavenge_seedlings
			drops.append(seedling_drop)
		if region_bean != null:
			# Section 15 beans table: the good bean of the region, Golden
			# Coast arabica in Steamtle and Moss Hollow organic in Pourtland,
			# yields in the same crates as the common house beans.
			var region_drop := ScavengeDrop.new()
			region_drop.item = region_bean
			region_drop.amount = balance.scavenge_region_beans
			drops.append(region_drop)
		for extra: ScavengeDrop in crate_extras:
			# Section 15: the city-wide crate stock, like the vault key that
			# opens the locked side room, rides every scavenge crate.
			drops.append(extra)
		loot.drops = drops
		scavenge.add_child(loot)
		if block.locked_side_room != null:
			_compose_side_room(building, block.locked_side_room)
	if not block.finds.is_empty():
		# Section 15: the unique finds of the block, like the thermos belt and
		# the cafe appliances, wait at their own loot spot.
		var find_parent := get_node_or_null(^"Scavenge") as Node2D
		if find_parent == null:
			find_parent = Node2D.new()
			find_parent.name = "Scavenge"
			add_child(find_parent)
		var find_point := _scavenge_point_scene().instantiate() as ScavengePoint
		find_point.name = "FindPoint"
		find_point.position = _find_point_position()
		find_point.drops = block.finds
		find_parent.add_child(find_point)


func _compose_side_room(building: BuildingShell, loot: SideRoomLoot) -> void:
	# Section 15 beans table: the excellent Geisha Vault beans wait in one
	# locked side room per city, west of the scavenge building. The door
	# opens on the authored key, and the finds stand on the vault floor.
	var room := LOCKED_SIDE_ROOM_SCENE.instantiate() as LockedSideRoom
	room.name = "SideRoom"
	room.room_size = SIDE_ROOM_SIZE
	room.key = loot.key
	room.position = _side_room_position(building)
	add_child(room)
	var room_loot := _scavenge_point_scene().instantiate() as ScavengePoint
	room_loot.name = "Loot"
	room_loot.drops = loot.drops
	room.add_child(room_loot)


func _side_room_position(building: BuildingShell) -> Vector2:
	# The vault stands west of the scavenge building, clear of its walls and
	# of the crowd lane on the street south of both.
	var west: float = building.building_size.x * 0.5 + SIDE_ROOM_GAP + SIDE_ROOM_SIZE.x * 0.5
	return building.position + Vector2(-west, 0.0)


func _find_point_position() -> Vector2:
	# Section 15: the unique find waits at its own loot spot. On a scavenge
	# block the spot stands inside the building, south of the crate; on an
	# open block it keeps the street spot.
	if building() != null:
		return size * 0.5 + LOOT_POINT_OFFSET + INTERIOR_FIND_OFFSET
	return size * 0.5 + FIND_POINT_OFFSET


func _crowd_spawn_position(i: int) -> Vector2:
	var spread := CROWD_MARKER_SPACING * float(block.sleepwalker_count - 1)
	var x := size.x * 0.5 - spread * 0.5 + CROWD_MARKER_SPACING * float(i)
	var lane_y := CROWD_MARKER_LANE_Y
	if block.kind == CityBlock.Kind.CAFE:
		lane_y = CAFE_CROWD_MARKER_LANE_Y
	return Vector2(x, size.y * lane_y)


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


func _cafe_anchor(anchor: Vector2) -> Vector2:
	# A spot on the cafe interior floor, T063: the anchor fraction of the
	# interior half extents around the building center. The tier sizes the
	# floor, so every cafe anchor moves with the building and the safe zone
	# covers each one by construction.
	var interior_half := CityRules.cafe_interior_size(balance, cafe_tier) * 0.5
	return size * 0.5 + interior_half * anchor


func _draw() -> void:
	if not _built or _palette == null:
		return
	# The paper ground of the world: warm cream, never a dark void. The
	# street lane that the crowd walks reads through the city accent wash.
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, _palette.cream)
	if _street_tex == null and ResourceLoader.exists(STREET_TILE_PATH):
		_street_tex = load(STREET_TILE_PATH) as Texture2D
	if _street_tex != null:
		var tile_step := Vector2(360.0, 360.0)
		var y := 0.0
		while y < size.y:
			var x := 0.0
			var h := minf(tile_step.y, size.y - y)
			while x < size.x:
				var w := minf(tile_step.x, size.x - x)
				draw_texture_rect(
					_street_tex,
					Rect2(Vector2(x, y), Vector2(w, h)),
					false,
					Color(1.0, 0.98, 0.94, 0.72)
				)
				x += tile_step.x
			y += tile_step.y
	# The road, the curb, and the sidewalk of the kit, with its crosswalk at
	# the west corner. The curb lip carries the city accent, section 6.
	var accent := city_look.accent if city_look != null else accent_color
	StreetPainter.paint_road(self, size, STREET_LANE_HEIGHT, _palette, accent)
	if city_look != null:
		draw_rect(
			StreetPainter.lane_rect(size, STREET_LANE_HEIGHT),
			Color(city_look.accent, ACCENT_WASH_ALPHA)
		)
	StreetPainter.paint_trees(self, size, get_index() * 7919 + 13, _palette)
	StreetPainter.paint_lamps(self, size, STREET_LANE_HEIGHT, _palette)
	StreetPainter.paint_marker(self, size * 0.5, _marker_radius(), _marker_color(), _palette)
	# The tower stands on its own marker and carries its own label, so the
	# kind name would only cover the prop.
	var kind_text := "" if block.kind == CityBlock.Kind.TOWER else CityRules.kind_name(block.kind)
	StreetPainter.paint_sign_text(
		self,
		Vector2(0, size.y * 0.5 + StreetPainter.KIND_TEXT_SIZE * 0.35),
		size.x,
		kind_text.to_upper(),
		StreetPainter.KIND_TEXT_SIZE,
		_palette.cream
	)
	var label_y := size.y * 0.5 + StreetPainter.KIND_TEXT_SIZE * 0.35
	for label: String in [landmark_label, site_label]:
		if label.is_empty():
			continue
		label_y += StreetPainter.LABEL_TEXT_SIZE + LABEL_GAP
		StreetPainter.paint_sign_text(
			self, Vector2(0, label_y), size.x, label, StreetPainter.LABEL_TEXT_SIZE, _palette.butter
		)


func _marker_color() -> Color:
	# Landmark markers keep one palette color per kind, so every city reads
	# the same kit. The tower block carries the corporate red.
	match block.kind:
		CityBlock.Kind.CAFE:
			return _palette.butter
		CityBlock.Kind.TOWER:
			return _palette.mug_red
		CityBlock.Kind.BOSS_ARENA:
			return _palette.lavender
		CityBlock.Kind.QUEST:
			return _palette.brick
		CityBlock.Kind.QUEST_SITE:
			return _palette.moss
		_:
			return _palette.espresso.lerp(_palette.cream, 0.62)


func _marker_radius() -> float:
	# The cafe marker grows with the tier of the city, section 10; the minor
	# quest sites draw smaller than the big landmarks.
	if block.kind == CityBlock.Kind.CAFE:
		return KIND_MARKER_RADIUS * (1.0 + CAFE_MARKER_TIER_STEP * float(cafe_tier - 1))
	if block.kind == CityBlock.Kind.QUEST_SITE:
		return QUEST_SITE_MARKER_RADIUS
	return KIND_MARKER_RADIUS
