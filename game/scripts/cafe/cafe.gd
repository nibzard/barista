# ABOUTME: Cafe is the development room for the core mechanics: throw, hug, refill.
# ABOUTME: The playable city flow lives in CityRun; this room keeps the tests fast.
class_name Cafe
extends Node2D

signal game_over

const DEATH_TEXT := "Your last wake-up is gone. The dream takes you."
const WAKE_UP_RESTORED_TEXT := "WAKE-UP RESTORED"
# The director scene stays a path, never a preload: CityRun already
# const-preloads it, and two const preloads of one resource can bind an empty
# scene in one compile order (T102).
const ADDRESS_AUDIO_DIRECTOR_PATH := "res://scenes/audio/address_audio_director.tscn"
# The room id seeds the pole offsets of the address loop, like a city id does.
const ROOM_ID := "cafe_dev_room"

# Section 21: the address loop rides the dev room too, so the room demos the
# sound rules without a city run. The room holds no CityMap, so the builder
# hands the director its own zones.
var address_audio: AddressAudioDirector = null

var _game_over := false

@onready var player: Player = $Player
@onready var sleepwalkers: Node2D = $Sleepwalkers
@onready var cafe_spawn: Marker2D = $CafeSpawn
@onready var broadcast_tower: BroadcastTower = $BroadcastTower
@onready var speaker_pole: SleepZone = $Zones/SpeakerPole
@onready var cafe_safe_zone: SleepZone = $Zones/CafeSafeZone
@onready var hud: Hud = $Hud
@onready var overlay: ColorRect = $UI/Overlay
@onready var status_label: Label = $UI/StatusLabel
@onready var restart_button: Button = $UI/RestartButton


func _ready() -> void:
	# The development room hands the whole support tool belt and the whole
	# cure armory over, section 11: this room is the playground for the core
	# mechanics. The cities hand the gear over where the route finds it.
	player.toolbelt.unlock_all()
	player.armory.unlock_all()
	player.died.connect(_on_player_died)
	player.woke_in_cafe.connect(_on_player_woke_in_cafe)
	broadcast_tower.switched_off.connect(_on_tower_switched_off)
	broadcast_tower.birdsong.connect(_on_tower_birdsong)
	_build_address_audio()
	overlay.visible = false
	status_label.visible = false
	restart_button.visible = false
	restart_button.pressed.connect(_on_restart_pressed)


func _build_address_audio() -> void:
	# Section 21, T099: the address loop rides the dev room. The room holds no
	# CityMap, so it hands its own pole zone and cafe circle straight to the
	# director. The tower wiring stays with the room: the switch restores the
	# wake-up and quiets the zone, while the director cuts the loop.
	address_audio = (
		(load(ADDRESS_AUDIO_DIRECTOR_PATH) as PackedScene).instantiate() as AddressAudioDirector
	)
	address_audio.name = "AddressAudio"
	add_child(address_audio)
	var pole_zones: Array[SleepZone] = [speaker_pole]
	address_audio.setup_room(pole_zones, cafe_safe_zone, player, broadcast_tower, ROOM_ID)


func get_sleepwalker(index: int) -> Sleepwalker:
	return sleepwalkers.get_child(index) as Sleepwalker


func is_game_over() -> bool:
	return _game_over


func _on_player_died() -> void:
	_game_over = true
	game_over.emit()
	_show_end_screen(DEATH_TEXT)


func _on_player_woke_in_cafe() -> void:
	# The world stays as it is: only the player moves back to the cafe spawn.
	player.global_position = cafe_spawn.global_position


func _on_tower_switched_off() -> void:
	# Section 14: switching off a city tower restores 1 wake-up, up to the
	# maximum. The address is dead, so the speaker pole of the city goes quiet.
	player.wake_ups.restore_one()
	speaker_pole.silence_broadcast()


func _on_tower_birdsong() -> void:
	# The beat ends on birdsong; the toast confirms the restored wake-up.
	hud.show_toast(WAKE_UP_RESTORED_TEXT)


func _show_end_screen(message: String) -> void:
	overlay.visible = true
	status_label.visible = true
	restart_button.visible = true
	status_label.text = message


func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()


func refill_player_supply() -> int:
	return player.refill_supply()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"refill_coffee"):
		refill_player_supply()
