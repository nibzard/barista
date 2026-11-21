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
# The center of the raised stage platform where thrown cups and aim-assist lock.
const STAGE_AIM_OFFSET := Vector2(0.0, -140.0)
# Subtle chalk arc drawn on the street in front of the stage while performing.
const STAGE_CUE_COLOR := Color(0.95, 0.78, 0.4, 0.65)
# The stage outfit once awake, and one instrument per member, left to right.
const OUTFIT_COLOR := Color("#7A3B5E")
const MEMBER_GEAR: Array[ChibiPainter.Gear] = [
	ChibiPainter.Gear.GUITAR, ChibiPainter.Gear.MIC, ChibiPainter.Gear.BASS
]

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
	add_to_group(CureDelivery.WAKEABLE_GROUP)
	_collect_members()
	_tint_members(SLEEPING_COLOR)
	for i: int in _members.size():
		PersonFigure.dress(
			_members[i], "sleep_jam_%d" % i, OUTFIT_COLOR, MEMBER_GEAR[i % MEMBER_GEAR.size()]
		)
	_build_lullaby()
	queue_redraw()


func aim_point() -> Vector2:
	# Aim-assist, serve reach, and cure splash target the raised stage itself,
	# so throws from the street arc cleanly into the band.
	return global_position + STAGE_AIM_OFFSET


func _draw() -> void:
	if not _performing:
		return
	draw_arc(Vector2(0.0, -70.0), 56.0, 0.15 * PI, 0.85 * PI, 20, STAGE_CUE_COLOR, 3.0)


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
	for member: Polygon2D in _members:
		PersonFigure.celebrate(member)
	queue_redraw()
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


func save_state() -> Dictionary:
	# Section 18: the cure of the song rides the run slot as one plain flag,
	# so a reloaded arena never replays a fight the save already ended.
	return {"cured": not _performing}


func load_state(saved: Dictionary) -> void:
	# A saved cure lands silent: the song ends and the band wakes, but no wake
	# line speaks and no signal fires, because the save point already recorded
	# the beat.
	if not bool(saved.get("cured", false)):
		return
	_performing = false
	_lullaby.set_active(false)
	_tint_members(AWAKE_COLOR)
	queue_redraw()


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
	var circle := CircleShape2D.new()
	circle.radius = balance.lullaby_radius
	shape_node.shape = circle
	add_child(_lullaby)
