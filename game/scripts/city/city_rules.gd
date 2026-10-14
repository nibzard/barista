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
