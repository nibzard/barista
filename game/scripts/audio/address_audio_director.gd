# ABOUTME: AddressAudioDirector plays the section 21 address loop in a city run.
# ABOUTME: The rules live in AddressAudio; this node reads the world and mixes.
class_name AddressAudioDirector
extends Node

# The address rides one bus per distance layer, so every pole plays through
# the filter of its own layer: muffled far away, clearer near the pole.
const FAR_BUS_NAME := "AddressFar"
const MID_BUS_NAME := "AddressMid"
const NEAR_BUS_NAME := "AddressNear"
# The tolerance sound id of the address itself. The diegetic tracks register
# under their own track names.
const ADDRESS_ID := "address_loop"

@export var balance: AddressAudioBalance

# The band boss of the city hands the director its own song, and the
# Sleepvana stage hands in the concert beat. Both stay null when the city
# has neither.
var band: SleepJamBand = null
var sleepvana: SleepvanaStage = null

var _rules: AddressAudio = null
var _tolerance: SoundTolerance = null
var _player: Player = null
var _cafe_center := Vector2.ZERO
var _cafe_radius := 0.0
var _poles: Array[Vector2] = []
var _offsets: Array[float] = []
var _address_players: Array[AudioStreamPlayer] = []
var _layer_filters: Array[AudioEffectLowPassFilter] = []
var _antagonist_player: AudioStreamPlayer = null
var _birdsong_player: AudioStreamPlayer = null
var _diegetic_player: AudioStreamPlayer = null
var _layer: int = AddressAudio.Layer.FAR
var _address_volume_db := 0.0
var _antagonist_volume_db := 0.0
var _venue: DiegeticMusic.Venue = DiegeticMusic.Venue.SILENT
var _diegetic_track := ""
var _address_cut := false
# A headless test run transports no audio and its input pipeline is fragile:
# there the director keeps every rule and every mix state but builds no
# streams and plays nothing, so the run stays as quiet as the baseline.
var _playback_live := false


func setup(map: CityMap, run_player: Player, tower: BroadcastTower, city_id: String) -> void:
	# The run hands over its poles, its player, and its tower. The city id
	# seeds the pole offsets, so every city keeps its own stable spread.
	var poles: Array[Vector2] = []
	var cafe_center := Vector2.ZERO
	var cafe_radius := 0.0
	if map != null:
		poles = map.speaker_pole_positions()
		var cafe_block := map.find_block_of_kind(CityBlock.Kind.CAFE)
		if cafe_block != null:
			var cafe_zone := cafe_block.safe_zone()
			if cafe_zone != null:
				cafe_center = cafe_zone.global_position
				cafe_radius = _circle_radius(cafe_zone)
	_setup_core(poles, cafe_center, cafe_radius, run_player, tower, city_id)


func setup_room(
	pole_zones: Array[SleepZone],
	cafe_zone: SleepZone,
	run_player: Player,
	tower: BroadcastTower,
	room_id: String
) -> void:
	# The cafe development room holds no CityMap, T099: it hands its own pole
	# zones and its cafe circle over. The room id seeds the pole offsets like a
	# city id does, so the room keeps its own stable spread too.
	var poles: Array[Vector2] = []
	for zone: SleepZone in pole_zones:
		poles.append(zone.global_position)
	var cafe_center := Vector2.ZERO
	var cafe_radius := 0.0
	if cafe_zone != null:
		cafe_center = cafe_zone.global_position
		cafe_radius = _circle_radius(cafe_zone)
	_setup_core(poles, cafe_center, cafe_radius, run_player, tower, room_id)


func _setup_core(
	poles: Array[Vector2],
	cafe_center: Vector2,
	cafe_radius: float,
	run_player: Player,
	tower: BroadcastTower,
	city_id: String
) -> void:
	_rules = AddressAudio.new(balance)
	_tolerance = SoundTolerance.new(balance)
	_tolerance.register(ADDRESS_ID, true)
	_player = run_player
	_poles = poles
	_cafe_center = cafe_center
	_cafe_radius = cafe_radius
	_playback_live = DisplayServer.get_name() != "headless"
	_offsets = _rules.loop_offsets(_poles.size(), AddressAudio.city_seed(city_id))
	_address_volume_db = balance.far_volume_db
	_antagonist_volume_db = balance.antagonist_far_volume_db
	_ensure_layer_buses()
	_build_players()
	_apply_filters(false)
	if tower != null:
		# The tower owns the cut clock: the switch stops the address mid-word,
		# its one second of silence passes, then the birdsong signal plays.
		tower.switched_off.connect(_on_tower_switched_off)
		tower.birdsong.connect(_on_tower_birdsong)


func pole_count() -> int:
	return _poles.size()


func pole_offsets() -> Array[float]:
	return _offsets


func current_layer() -> AddressAudio.Layer:
	return _layer


func address_volume_db() -> float:
	return _address_volume_db


func address_filter_hz() -> float:
	if _layer_filters.is_empty():
		return 0.0
	return _layer_filters[_layer].cutoff_hz


func antagonist_volume_db() -> float:
	return _antagonist_volume_db


func current_venue() -> DiegeticMusic.Venue:
	return _venue


func diegetic_track() -> String:
	return _diegetic_track


func is_address_cut() -> bool:
	return _address_cut


func tolerance() -> SoundTolerance:
	return _tolerance


func pole_player(index: int) -> AudioStreamPlayer:
	if index < 0 or index >= _address_players.size():
		return null
	return _address_players[index]


func birdsong_player() -> AudioStreamPlayer:
	return _birdsong_player


func _physics_process(delta: float) -> void:
	if _rules == null or _player == null:
		return
	_update_address(delta)
	_update_antagonist()
	_update_diegetic(delta)


func _build_players() -> void:
	# One player per pole, every one started at its own offset on the same
	# 5-second loop: the poles play the same address and never sync. A
	# headless run keeps the players as state holders without streams.
	var loop: AudioStreamWAV = null
	if _playback_live:
		loop = PlaceholderTones.address_loop(balance.loop_seconds)
	for i: int in range(_poles.size()):
		var pole_player := AudioStreamPlayer.new()
		pole_player.name = "Pole%d" % i
		pole_player.stream = loop
		pole_player.bus = FAR_BUS_NAME
		pole_player.volume_db = balance.far_volume_db
		add_child(pole_player)
		if _playback_live:
			pole_player.play(_offsets[i])
		_address_players.append(pole_player)
	_antagonist_player = AudioStreamPlayer.new()
	_antagonist_player.name = "Antagonist"
	if _playback_live:
		_antagonist_player.stream = PlaceholderTones.antagonist_loop()
	_antagonist_player.volume_db = balance.antagonist_far_volume_db
	add_child(_antagonist_player)
	if _playback_live:
		_antagonist_player.play()
	_birdsong_player = AudioStreamPlayer.new()
	_birdsong_player.name = "Birdsong"
	if _playback_live:
		_birdsong_player.stream = PlaceholderTones.birdsong()
	_birdsong_player.volume_db = balance.birdsong_volume_db
	add_child(_birdsong_player)
	_diegetic_player = AudioStreamPlayer.new()
	_diegetic_player.name = "Diegetic"
	add_child(_diegetic_player)


func _ensure_layer_buses() -> void:
	# Three buses in Layer order, each behind its own low-pass: the address
	# always arrives filtered, however close the player stands. The set is
	# idempotent, so a second director reuses the buses already in the server.
	_layer_filters.clear()
	var bus_names: Array[String] = [FAR_BUS_NAME, MID_BUS_NAME, NEAR_BUS_NAME]
	for bus_name: String in bus_names:
		var index := _bus_index(bus_name)
		if index < 0:
			AudioServer.add_bus()
			index = AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus_name)
			AudioServer.set_bus_send(index, "Master")
			AudioServer.add_bus_effect(index, AudioEffectLowPassFilter.new())
		_layer_filters.append(AudioServer.get_bus_effect(index, 0) as AudioEffectLowPassFilter)


func _circle_radius(zone: SleepZone) -> float:
	# The drawn radius of a zone circle, the same read SleepZone draws with.
	var shape_node := zone.get_node_or_null(^"CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		return 0.0
	var circle := shape_node.shape as CircleShape2D
	return circle.radius if circle != null else 0.0


func _bus_index(bus_name: String) -> int:
	for i: int in AudioServer.bus_count:
		if AudioServer.get_bus_name(i) == bus_name:
			return i
	return -1


func _bus_name(layer: int) -> String:
	match layer:
		AddressAudio.Layer.MID:
			return MID_BUS_NAME
		AddressAudio.Layer.NEAR:
			return NEAR_BUS_NAME
		_:
			return FAR_BUS_NAME


func _update_address(delta: float) -> void:
	if _address_cut or _address_players.is_empty():
		return
	# Every pole plays through the filter and at the volume of its own
	# distance layer, so the nearest pole dominates the mix where it stands.
	_tolerance.expose(ADDRESS_ID, delta / 60.0)
	var nearest_index := 0
	var nearest_distance := INF
	for i: int in range(_poles.size()):
		var distance := _player.global_position.distance_to(_poles[i])
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_index = i
	_layer = _rules.layer_for_distance(nearest_distance)
	var grabbed := _player.is_grabbed()
	for i: int in range(_poles.size()):
		var layer := _rules.layer_for_distance(_player.global_position.distance_to(_poles[i]))
		var pole_player := _address_players[i]
		pole_player.bus = _bus_name(layer)
		pole_player.volume_db = _rules.volume_db(layer, grabbed)
	_address_volume_db = _address_players[nearest_index].volume_db
	_apply_filters(_tolerance.remedy(ADDRESS_ID) == SoundTolerance.Remedy.FILTER)


func _apply_filters(deep: bool) -> void:
	# The tolerance remedy filters the address deeper on every layer at once,
	# never raising a layer whose cutoff already sits below the remedy floor.
	var cutoffs := _rules.cutoffs_hz()
	for i: int in range(_layer_filters.size()):
		_layer_filters[i].cutoff_hz = (
			minf(cutoffs[i], balance.tolerance_filter_hz) if deep else cutoffs[i]
		)


func _update_antagonist() -> void:
	# The antagonist track follows the nearest enemy that still sleeps: it
	# rides the volume ramp and gets loud only at arm's length.
	var nearest := _nearest_enemy_distance()
	_antagonist_volume_db = _rules.antagonist_volume_db(nearest)
	_antagonist_player.volume_db = _antagonist_volume_db


func _nearest_enemy_distance() -> float:
	var nearest := INF
	for node: Node in get_tree().get_nodes_in_group(Sleepwalker.SLEEPWALKER_GROUP):
		var enemy := node as Sleepwalker
		if enemy == null or enemy.is_awake():
			continue
		nearest = minf(nearest, _player.global_position.distance_to(enemy.global_position))
	return nearest


func _update_diegetic(delta: float) -> void:
	var venue := _resolve_venue()
	if venue != _venue:
		_venue = venue
		_switch_track()
	if _diegetic_track.is_empty():
		return
	_tolerance.expose(_diegetic_track, delta / 60.0)
	if _tolerance.remedy(_diegetic_track) == SoundTolerance.Remedy.STOP:
		# The tolerance rule ends a grating record: it goes.
		_diegetic_player.stop()
		_diegetic_track = ""


func _resolve_venue() -> DiegeticMusic.Venue:
	# Music is diegetic first: the cafe record spins inside the cafe, the band
	# plays while its song still reaches the player, and the Sleepvana concert
	# plays its hit for the whole celebrating city. The venues read plain
	# distances to the zone circles, never fresh overlap polls: an overlap
	# report lags a physics step and lands mid-callback, which no music cue
	# needs.
	if (
		sleepvana != null
		and sleepvana.quest != null
		and sleepvana.quest.phase() == SleepvanaQuest.Phase.CONCERT
	):
		return DiegeticMusic.Venue.SLEEPVANA_CONCERT
	if band != null and band.is_performing():
		if _player_within(band.global_position, band.balance.lullaby_radius):
			return DiegeticMusic.Venue.BAND_STAGE
	if _player_within(_cafe_center, _cafe_radius):
		return DiegeticMusic.Venue.CAFE
	return DiegeticMusic.Venue.SILENT


func _player_within(center: Vector2, radius: float) -> bool:
	return _player.global_position.distance_to(center) <= radius


func _switch_track() -> void:
	var track := DiegeticMusic.track_name(_venue)
	if track.is_empty():
		_diegetic_player.stop()
		_diegetic_track = ""
		return
	# A diegetic record is not the address: past the tolerance limit it goes
	# silent instead of filtering deeper, and stays silent on re-entry.
	_tolerance.register(track, false)
	if _tolerance.remedy(track) == SoundTolerance.Remedy.STOP:
		_diegetic_player.stop()
		_diegetic_track = ""
		return
	_diegetic_track = track
	if _playback_live:
		_diegetic_player.stream = PlaceholderTones.diegetic_loop(_venue)
		_diegetic_player.play()


func cut_address() -> void:
	# The address stops mid-word: a plain stop the same frame, no fade and no
	# tail. The live switch leaves the one second of silence to the tower
	# clock; the save-load path calls this directly, because a loaded tower
	# never replays the beat.
	_address_cut = true
	for pole_player: AudioStreamPlayer in _address_players:
		pole_player.stop()


func _on_tower_switched_off() -> void:
	cut_address()


func _on_tower_birdsong() -> void:
	# The reward of the beat: morning birdsong over the quiet city.
	if _playback_live:
		_birdsong_player.play()
