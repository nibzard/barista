# ABOUTME: SleepJamBand is the Pourtland boss: an indie band on one endless song.
# ABOUTME: The lullaby drains the player meter until the Geisha Vault cure lands.
class_name SleepJamBand
extends StaticBody2D

signal band_woke
signal spoke(line: String)

# The toast of the wake beat: the endless song is the fight, so its end is the
# reward, section 21.
const WAKE_TOAST := "THE SLEEP JAM IS AWAKE. THE SONG IS OVER."
# Sleeping band members wear their pajama indigo; the wake turns it green like
# every awakened sleeper.
const SLEEPING_COLOR := Color(0.42, 0.38, 0.72)
const AWAKE_COLOR := Color(0.45, 0.85, 0.5)
const LULLABY_ZONE_NAME := "LullabyZone"

# The sleep zone scene stays a path, never a preload: several scripts share
# this scene, and a compile-time const binds an empty scene whenever another
# load of it is already running (T102).
const SLEEP_ZONE_SCENE_PATH := "res://scenes/components/sleep_zone.tscn"

@export var balance: SleepJamBalance
@export var brewing_balance: BrewingBalance
# The cure of the band, section 6: a cup from the most obscure single-origin
# beans in the world, the Geisha Vault tier recipe.
@export var cure: Recipe

var _performing := true
var _lullaby: SleepZone = null
var _members: Array[Polygon2D] = []


func _ready() -> void:
	_collect_members()
	_tint_members(SLEEPING_COLOR)
	_build_lullaby()


static func cure_accepted(cup: BrewedCup, cure: Recipe, brew_balance: BrewingBalance) -> bool:
	# The cure condition of the fight, the shared tier-led rule of the bosses:
	# only the obscure beans work between the tiers.
	return BossCure.accepted(cup, cure, brew_balance)


func try_wake(cup: BrewedCup) -> bool:
	# The cure delivery of the fight: a thrown or served cup lands on the
	# stage. The right cup wakes the whole band and ends the song.
	if not _performing:
		return false
	if not cure_accepted(cup, cure, brewing_balance):
		return false
	_performing = false
	_lullaby.set_active(false)
	_tint_members(AWAKE_COLOR)
	if not balance.wake_line.is_empty():
		spoke.emit(balance.wake_line)
	band_woke.emit()
	return true


func lullaby_zone() -> SleepZone:
	# The reach of the endless song, section 6: the boring-attack aura of the
	# fight. Tests and the audio system read it from outside.
	return _lullaby


func is_performing() -> bool:
	return _performing


func is_awake() -> bool:
	return not _performing


func band_members() -> Array[Polygon2D]:
	return _members.duplicate()


func _collect_members() -> void:
	for child: Node in get_node(^"Members").get_children():
		var member := child as Polygon2D
		if member != null:
			_members.append(member)


func _tint_members(tint: Color) -> void:
	for member: Polygon2D in _members:
		member.color = tint


func _build_lullaby() -> void:
	# The song is the arena-wide aura of the fight: it drains every player
	# inside its reach at the boring-attack rate, section 14.
	_lullaby = (load(SLEEP_ZONE_SCENE_PATH) as PackedScene).instantiate() as SleepZone
	_lullaby.name = LULLABY_ZONE_NAME
	_lullaby.kind = SleepZone.Kind.BORING
	var shape_node := _lullaby.get_node(^"CollisionShape2D") as CollisionShape2D
	var circle := shape_node.shape as CircleShape2D
	circle.radius = balance.lullaby_radius
	add_child(_lullaby)
