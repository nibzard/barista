# ABOUTME: Unit tests for the SleepyDex unlock rules from section 9.
# ABOUTME: Pure logic: no scene nodes, so the tests run without a tree.
extends GdUnitTestSuite

const DEX_CATALOG := preload("res://resources/dex/sleepy_dex.tres")
const LIBRARY := preload("res://resources/brewing/brewing_library.tres")

# The V1 catalog: six common types in meeting order, then the one rare type.
const COMMON_IDS: Array[String] = [
	"neighbor",
	"tourist",
	"tech_bro",
	"gamer",
	"tinfoil_man",
	"karen",
]
const RARE_ID := "moonwalker"


func _make_dex() -> SleepyDex:
	return SleepyDex.new(DEX_CATALOG)


func _meet_all_commons(dex: SleepyDex) -> void:
	for type_id: String in COMMON_IDS:
		dex.meet(type_id)


func test_a_new_dex_lists_every_common_type_as_not_found() -> void:
	var dex := _make_dex()
	assert_int(dex.entry_count()).is_equal(COMMON_IDS.size())
	assert_int(dex.found_count()).is_equal(0)
	assert_bool(dex.is_complete()).is_false()
	assert_bool(dex.has_keychain()).is_false()
	for type_id: String in COMMON_IDS:
		assert_bool(dex.is_found(type_id)).is_false()


func test_the_first_meeting_opens_the_entry() -> void:
	var dex := _make_dex()
	var opened: Array[String] = []
	dex.entry_opened.connect(func(type_id: String) -> void: opened.append(type_id))

	assert_bool(dex.meet("karen")).is_true()
	assert_bool(dex.is_found("karen")).is_true()
	assert_int(dex.found_count()).is_equal(1)
	assert_int(opened.size()).is_equal(1)
	assert_str(opened[0]).is_equal("karen")


func test_the_second_meeting_changes_nothing() -> void:
	var dex := _make_dex()
	var opened: Array[String] = []
	dex.entry_opened.connect(func(type_id: String) -> void: opened.append(type_id))

	assert_bool(dex.meet("neighbor")).is_true()
	assert_bool(dex.meet("neighbor")).is_false()
	assert_bool(dex.is_found("neighbor")).is_true()
	assert_int(dex.found_count()).is_equal(1)
	assert_int(opened.size()).is_equal(1)


func test_a_type_outside_the_catalog_never_opens_an_entry() -> void:
	# The trucker is the V2 tease, and an empty id is not a type at all.
	var dex := _make_dex()
	assert_bool(dex.meet("trucker")).is_false()
	assert_bool(dex.meet("")).is_false()
	assert_int(dex.found_count()).is_equal(0)
	assert_int(dex.entry_count()).is_equal(COMMON_IDS.size())


func test_the_catalog_ships_the_rare_type_and_the_dex_hides_it() -> void:
	# The rare type exists in the shipped data; only the dex state hides it.
	assert_int(DEX_CATALOG.size()).is_equal(COMMON_IDS.size() + 1)
	var rare := DEX_CATALOG.find_entry(RARE_ID)
	assert_object(rare).is_not_null()
	assert_bool(rare.is_rare()).is_true()


func test_a_rare_type_is_completely_absent_before_the_find() -> void:
	# Section 9: no placeholder, no count, no hint that a rare type exists.
	var dex := _make_dex()
	for entry: SleepyDexEntry in dex.listed_entries():
		assert_str(entry.type_id()).is_not_equal(RARE_ID)
	assert_int(dex.entry_count()).is_equal(COMMON_IDS.size())
	assert_int(dex.found_count()).is_equal(0)
	assert_bool(dex.is_found(RARE_ID)).is_false()


func test_finding_the_rare_type_reveals_it_as_a_found_entry() -> void:
	var dex := _make_dex()
	var opened: Array[String] = []
	dex.entry_opened.connect(func(type_id: String) -> void: opened.append(type_id))

	assert_bool(dex.meet(RARE_ID)).is_true()
	assert_bool(dex.is_found(RARE_ID)).is_true()
	assert_int(opened.size()).is_equal(1)
	assert_str(opened[0]).is_equal(RARE_ID)
	# The entry appears only now: the count grows past the common total.
	assert_int(dex.entry_count()).is_equal(COMMON_IDS.size() + 1)
	assert_int(dex.found_count()).is_equal(1)
	var listed := dex.listed_entries()
	assert_str(listed[listed.size() - 1].type_id()).is_equal(RARE_ID)


func test_every_common_type_found_stays_short_of_complete() -> void:
	# All commons found shows a full counter, but the dex stays open: the
	# hidden rare keeps it incomplete, and it says nothing about why.
	var dex := _make_dex()
	_meet_all_commons(dex)
	assert_int(dex.found_count()).is_equal(COMMON_IDS.size())
	assert_int(dex.entry_count()).is_equal(COMMON_IDS.size())
	assert_bool(dex.is_complete()).is_false()
	assert_bool(dex.has_keychain()).is_false()


func test_the_completed_dex_awards_the_keychain_once() -> void:
	var dex := _make_dex()
	_meet_all_commons(dex)
	var awards: Array[int] = []
	dex.keychain_awarded.connect(func() -> void: awards.append(1))
	assert_int(awards.size()).is_equal(0)

	assert_bool(dex.meet(RARE_ID)).is_true()
	assert_bool(dex.is_complete()).is_true()
	assert_bool(dex.has_keychain()).is_true()
	assert_int(awards.size()).is_equal(1)


func test_the_keychain_line_is_the_one_line() -> void:
	assert_str(SleepyDex.KEYCHAIN_LINE).is_equal("It is just a keychain.")


func test_save_round_trip_carries_the_dex_without_replays() -> void:
	var dex := _make_dex()
	_meet_all_commons(dex)
	dex.meet(RARE_ID)
	var saved := dex.save_state()

	var loaded := _make_dex()
	var opened: Array[String] = []
	var awards: Array[int] = []
	loaded.entry_opened.connect(func(type_id: String) -> void: opened.append(type_id))
	loaded.keychain_awarded.connect(func() -> void: awards.append(1))
	loaded.load_state(saved)

	assert_bool(loaded.is_complete()).is_true()
	assert_bool(loaded.has_keychain()).is_true()
	assert_int(loaded.found_count()).is_equal(COMMON_IDS.size() + 1)
	assert_int(opened.size()).is_equal(0)
	assert_int(awards.size()).is_equal(0)


func test_load_state_skips_ids_the_catalog_does_not_know() -> void:
	var loaded := _make_dex()
	loaded.load_state({"found_ids": ["trucker", "karen", 7], "keychain": false})
	assert_bool(loaded.is_found("karen")).is_true()
	assert_bool(loaded.is_found("trucker")).is_false()
	assert_int(loaded.found_count()).is_equal(1)
	assert_bool(loaded.is_complete()).is_false()


func test_load_state_grants_a_complete_set_its_silent_keychain() -> void:
	var loaded := _make_dex()
	loaded.load_state({"found_ids": COMMON_IDS + [RARE_ID], "keychain": false})
	assert_bool(loaded.is_complete()).is_true()
	assert_bool(loaded.has_keychain()).is_true()


func test_the_catalog_covers_the_v1_types_in_meeting_order() -> void:
	var expected: Array[String] = COMMON_IDS.duplicate()
	expected.append(RARE_ID)
	var listed: Array[String] = []
	for entry: SleepyDexEntry in DEX_CATALOG.entries:
		listed.append(entry.type_id())
	assert_array(listed).is_equal(expected)


func test_every_entry_names_a_wake_cup_from_the_brewing_data() -> void:
	# Section 9: each entry carries the coffee that wakes the type. The dex
	# data must link to the same cures the wake rules check.
	for entry: SleepyDexEntry in DEX_CATALOG.entries:
		var cure := LIBRARY.find_cure(entry.type_id())
		assert_object(cure).is_not_null()
		if cure.is_basic:
			continue
		assert_object(LIBRARY.find_recipe(cure.cure_recipe_id)).is_not_null()


func test_the_rare_entry_pins_the_moonwalker_identity() -> void:
	# Section 6: one white glove, a red jacket. The placeholder picture reads
	# the type's pajama color, so the rare entry keeps its own shade of red.
	var rare := DEX_CATALOG.find_entry(RARE_ID)
	assert_str(rare.display_name()).is_equal("The Moonwalker")
	assert_float(rare.portrait_color().r).is_greater(0.5)
	assert_float(rare.portrait_color().b).is_less(0.5)
