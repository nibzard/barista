# ABOUTME: CityRules checks one CityDefinition against the section 17 level rules.
# ABOUTME: Pure logic only: no scene nodes, so tests need no rendered output.
class_name CityRules
extends RefCounted

const LANDMARK_KINDS := [
	CityBlock.Kind.CAFE,
	CityBlock.Kind.TOWER,
	CityBlock.Kind.BOSS_ARENA,
	CityBlock.Kind.QUEST,
]
# The cafe building keeps the shape of the kit shell (460 by 270), and its
# interior stops this share of the tier circle short of the rim, so the safe
# zone always covers the whole cafe floor, section 17.
const CAFE_BUILDING_ASPECT := 460.0 / 270.0
const CAFE_INTERIOR_FILL := 0.97


static func validate(city: CityDefinition, balance: CityBalance) -> Array[String]:
	var violations: Array[String] = []
	if city == null or balance == null:
		violations.append("The city needs a definition and a rule resource.")
		return violations
	var blocks := city.blocks
	if blocks.size() < balance.min_blocks:
		violations.append(
			(
				"The city must hold a minimum of %d blocks, found %d."
				% [balance.min_blocks, blocks.size()]
			)
		)
	if blocks.size() > balance.max_blocks:
		violations.append(
			(
				"The city must hold a maximum of %d blocks, found %d."
				% [balance.max_blocks, blocks.size()]
			)
		)
	if blocks.is_empty():
		return violations
	violations.append_array(_landmark_violations(city))
	violations.append_array(_site_violations(city))
	violations.append_array(_find_violations(city))
	violations.append_array(_side_room_violations(city))
	violations.append_array(_crate_extra_violations(city))
	violations.append_array(_tier_violations(city, balance))
	violations.append_array(_density_violations(city, balance))
	violations.append_array(_pole_violations(city, balance))
	return violations


static func count_kind(city: CityDefinition, kind: CityBlock.Kind) -> int:
	var count := 0
	for block: CityBlock in city.blocks:
		if block.kind == kind:
			count += 1
	return count


static func pole_block_indices(block_count: int, balance: CityBalance) -> Array[int]:
	# The poles guard the last blocks before the tower: the pole_count blocks
	# that stand before the tower block itself. The tower and the cafe hold none.
	var indices: Array[int] = []
	var first := maxi(block_count - 1 - balance.speaker_pole_count, 0)
	for i: int in range(first, maxi(block_count - 1, 0)):
		indices.append(i)
	return indices


static func block_size(balance: CityBalance) -> Vector2:
	# Section 17: one phone screen shows about blocks_per_screen blocks across,
	# so one block is as wide as the viewport divided by that count.
	var viewport_width := float(
		ProjectSettings.get_setting("display/window/size/viewport_width", 1280)
	)
	var viewport_height := float(
		ProjectSettings.get_setting("display/window/size/viewport_height", 720)
	)
	return Vector2(viewport_width / balance.blocks_per_screen, viewport_height)


static func cafe_zone_radius(balance: CityBalance, cafe_tier: int) -> float:
	# Section 10: the cafe safe zone grows with the city on the route. Tier 1
	# reads the first entry; every tier above the table reads the last one.
	if balance == null or balance.cafe_zone_radius_per_tier.is_empty():
		return 0.0
	var index := clampi(cafe_tier, 1, balance.cafe_zone_radius_per_tier.size()) - 1
	return balance.cafe_zone_radius_per_tier[index]


static func cafe_interior_size(balance: CityBalance, cafe_tier: int) -> Vector2:
	# Section 10 with section 17, T063: the real cafe building grows with the
	# city tier, and the safe zone circle of the tier carries its whole
	# interior. The interior rect keeps the kit building shape and sits
	# inscribed in the circle, short of the rim.
	var radius := cafe_zone_radius(balance, cafe_tier)
	if radius <= 0.0:
		return Vector2.ZERO
	var filled := radius * CAFE_INTERIOR_FILL
	var half_height := filled / sqrt(CAFE_BUILDING_ASPECT * CAFE_BUILDING_ASPECT + 1.0)
	var half_width := CAFE_BUILDING_ASPECT * half_height
	return Vector2(half_width, half_height) * 2.0


static func kind_name(kind: CityBlock.Kind) -> String:
	return CityBlock.Kind.keys()[kind].to_lower().replace("_", " ")


static func _landmark_violations(city: CityDefinition) -> Array[String]:
	var violations: Array[String] = []
	var blocks := city.blocks
	for kind: int in LANDMARK_KINDS:
		var landmark_kind := kind as CityBlock.Kind
		var found := count_kind(city, landmark_kind)
		if found != 1:
			violations.append(
				"The city needs exactly one %s block, found %d." % [kind_name(landmark_kind), found]
			)
	if blocks[0].kind != CityBlock.Kind.CAFE:
		violations.append("The cafe block must stand at the first edge of the city.")
	if blocks[blocks.size() - 1].kind != CityBlock.Kind.TOWER:
		violations.append("The tower block must stand at the last edge of the city.")
	return violations


static func _site_violations(city: CityDefinition) -> Array[String]:
	# Named sites, like the Sleepvana places, need a name on every site block,
	# and one name may not mark two places in one city.
	var violations: Array[String] = []
	var seen: Dictionary = {}
	for block: CityBlock in city.blocks:
		if block.kind != CityBlock.Kind.QUEST_SITE and block.site_name.is_empty():
			continue
		if block.site_name.is_empty():
			violations.append("A quest site block needs a site name.")
			continue
		if seen.has(block.site_name):
			violations.append("The site name %s marks two blocks." % block.site_name)
		seen[block.site_name] = true
	return violations


static func _find_violations(city: CityDefinition) -> Array[String]:
	# Authored finds, section 15: every find row needs its item and a positive
	# amount, because the scavenge point silently drops a broken row.
	var violations: Array[String] = []
	for i: int in range(city.blocks.size()):
		for find: ScavengeDrop in city.blocks[i].finds:
			if find.item == null:
				violations.append("Block %d authors a find with no item." % i)
			elif find.amount <= 0:
				violations.append(
					"Block %d authors a find of %s with no amount." % [i, find.item.item_id]
				)
	return violations


static func _side_room_violations(city: CityDefinition) -> Array[String]:
	# Section 15 beans table: one locked side room per city holds the Geisha
	# Vault beans. The validator pins the authored shape: at most one room, on
	# a scavenge block, behind a key the city crates stock.
	var violations: Array[String] = []
	var rooms := 0
	for i: int in range(city.blocks.size()):
		var loot: SideRoomLoot = city.blocks[i].locked_side_room
		if loot == null:
			continue
		rooms += 1
		if city.blocks[i].kind != CityBlock.Kind.SCAVENGE:
			violations.append("Block %d hosts a locked side room outside a scavenge building." % i)
		if loot.key == null:
			violations.append("Block %d authors a locked side room with no key." % i)
		elif not _crate_stocks(city, loot.key):
			violations.append(
				"The locked side room key %s has no stock in the city crates." % loot.key.item_id
			)
		if loot.drops.is_empty():
			violations.append("Block %d authors a locked side room with no finds." % i)
		for find: ScavengeDrop in loot.drops:
			if find.item == null:
				violations.append("Block %d authors a side room find with no item." % i)
			elif find.amount <= 0:
				violations.append(
					(
						"Block %d authors a side room find of %s with no amount."
						% [i, find.item.item_id]
					)
				)
	if rooms > 1:
		violations.append("The city may hold at most one locked side room, found %d." % rooms)
	return violations


static func _crate_stocks(city: CityDefinition, item: ItemType) -> bool:
	# The lock stays honest: the key that opens the room must also spawn
	# somewhere in the city, or the finds lock away for good.
	for extra: ScavengeDrop in city.crate_extras:
		if extra.item == item and extra.amount > 0:
			return true
	return false


static func _crate_extra_violations(city: CityDefinition) -> Array[String]:
	# The city-wide crate stock follows the authored-find rule: a broken row
	# would silently drop out of the crate.
	var violations: Array[String] = []
	for extra: ScavengeDrop in city.crate_extras:
		if extra.item == null:
			violations.append("The city authors a crate extra with no item.")
		elif extra.amount <= 0:
			violations.append(
				"The city authors a crate extra of %s with no amount." % extra.item.item_id
			)
	return violations


static func _tier_violations(city: CityDefinition, balance: CityBalance) -> Array[String]:
	var violations: Array[String] = []
	if city.cafe_tier < 1:
		violations.append("The cafe tier must start at 1, found %d." % city.cafe_tier)
	if cafe_zone_radius(balance, city.cafe_tier) <= 0.0:
		violations.append("The cafe tier %d has no safe zone radius." % city.cafe_tier)
	return violations


static func _density_violations(city: CityDefinition, balance: CityBalance) -> Array[String]:
	var violations: Array[String] = []
	var blocks := city.blocks
	for i: int in range(blocks.size()):
		var block := blocks[i]
		if block.sleepwalker_count < balance.density_min:
			violations.append(
				(
					"Block %d must hold a minimum of %d sleepwalkers, found %d."
					% [i, balance.density_min, block.sleepwalker_count]
				)
			)
		if block.sleepwalker_count > balance.density_max:
			violations.append(
				(
					"Block %d must hold a maximum of %d sleepwalkers, found %d."
					% [i, balance.density_max, block.sleepwalker_count]
				)
			)
		if i > 0 and block.sleepwalker_count < blocks[i - 1].sleepwalker_count:
			violations.append("Block %d density must not fall toward the tower." % i)
	var cafe_count := blocks[0].sleepwalker_count
	var tower_count := blocks[blocks.size() - 1].sleepwalker_count
	if tower_count <= cafe_count:
		violations.append("The tower block must hold more sleepwalkers than the cafe block.")
	return violations


static func _pole_violations(city: CityDefinition, balance: CityBalance) -> Array[String]:
	var violations: Array[String] = []
	var blocks := city.blocks
	var found_poles := 0
	for block: CityBlock in blocks:
		if block.has_speaker_pole:
			found_poles += 1
	if found_poles != balance.speaker_pole_count:
		violations.append(
			(
				"The city needs exactly %d speaker poles, found %d."
				% [balance.speaker_pole_count, found_poles]
			)
		)
		return violations
	var expected := pole_block_indices(blocks.size(), balance)
	for i: int in range(blocks.size()):
		if blocks[i].has_speaker_pole and not expected.has(i):
			violations.append(
				(
					"The speaker poles must guard the %d blocks before the tower block."
					% balance.speaker_pole_count
				)
			)
			break
	return violations
