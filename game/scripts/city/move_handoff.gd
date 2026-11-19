# ABOUTME: MoveHandoff carries the whole traveler across the roads, section 10
# ABOUTME: east and section 23 west. One city packs; the next unpacks once.
class_name MoveHandoff
extends RefCounted

# The parked traveler of the city that just closed. It waits here through the
# scene change, because the two city runs never share a tree. The keys match
# the save fields of the player, so one loader serves the save and the move.
static var _parked: Dictionary = {}


static func park_traveler(
	player: Player, dex: SleepyDex, unlock: UnlockState, log: QuestLog
) -> void:
	# Section 10, moving day: the van carries every belonging east, and the
	# road west carries the same traveler back, section 23. The pack reads the
	# live player: bag, cups, belt, brewed batch, skills, dex, meter, wake-ups,
	# the quest chain, and the paid-bridge flag.
	var supply := player.coffee_supply.save_state()
	_parked = {
		"meter_value": player.sleep_meter.save_state(),
		"wake_ups": player.wake_ups.save_state(),
		"bag": player.inventory.save_state(),
		"cups": int(supply.get("cups", 0)),
		"thermos_belt": bool(supply.get("thermos_belt", false)),
		"brew_hand": player.brew_hand.save_state(),
		"skills": player.brewing_skills.save_state(),
		"dex": dex.save_state(),
		"quests": log.save_state(),
		"unlock": unlock.save_state(),
		"moonwalk_dodge": player.dodge_style == Player.DodgeStyle.MOONWALK,
	}


static func take_arriving() -> Dictionary:
	# The arriving city takes the parked traveler once. A move without a park,
	# like a fresh run that never traveled, reads empty and keeps its plain
	# start, so the first-city gift rules stay whole.
	var arriving := _parked
	_parked = {}
	return arriving


static func apply_arrival(
	traveler: Dictionary, player: Player, dex: SleepyDex, unlock: UnlockState, catalog: ItemCatalog
) -> void:
	# The arrival unpacks the van by the new cafe. An empty park changes
	# nothing. The caller runs this after the van level lands, so the supply
	# clamp reads the kitchen carry limit.
	if traveler.is_empty():
		return
	unlock.load_state(bool(traveler.get("unlock", false)))
	apply_carry(player, dex, traveler, catalog)


static func apply_carry(
	player: Player, dex: SleepyDex, carry: Dictionary, catalog: ItemCatalog
) -> void:
	# The player fields that ride a save point and a move east alike: dex,
	# meter, wake-ups, skills, the bag, the supply, and the brewed batch.
	dex.load_state(SaveData.dict_or_empty(carry.get("dex", {})))
	player.sleep_meter.load_state(float(carry.get("meter_value", 0.0)))
	player.wake_ups.load_state(int(carry.get("wake_ups", 0)))
	player.brewing_skills.load_state(SaveData.int_dict(carry.get("skills", {})))
	player.inventory.load_state(SaveData.int_dict(carry.get("bag", {})), catalog)
	# Section 11: the cure weapons and the support tools ride the bag as gear,
	# so a loaded traveler finds its armory and its belt restocked from the
	# saved finds.
	player.armory.sync_found_from_inventory(player.inventory)
	player.toolbelt.sync_unlocked_from_inventory(player.inventory)
	var supply := {
		"cups": int(carry.get("cups", 0)),
		"thermos_belt": bool(carry.get("thermos_belt", false)),
	}
	player.coffee_supply.load_state(supply)
	player.brew_hand.load_state(
		SaveData.dict_or_empty(carry.get("brew_hand", {})), player.brewing_library
	)
	# Section 24: the taught Moonwalk dodge crosses the road east too, and a
	# saved win lands without replaying the dance.
	if bool(carry.get("moonwalk_dodge", false)):
		player.dodge_style = Player.DodgeStyle.MOONWALK


static func park(traveler: Dictionary) -> void:
	# The plain store of the handoff, for callers that build the dict itself.
	_parked = traveler.duplicate(true)


static func reset() -> void:
	# A fresh session starts with an empty handoff. The test suites call this
	# so a parked move never leaks into an unrelated run.
	_parked = {}
