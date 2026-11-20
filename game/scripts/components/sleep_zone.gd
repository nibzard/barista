# ABOUTME: SleepZone is a reusable area that changes the meter drain of the player inside it.
# ABOUTME: Loudspeaker poles and street sleep zones use SLEEP; the cafe interior
# ABOUTME: uses SAFE; boss auras like the Sleep Jam lullaby use BORING.
class_name SleepZone
extends Area2D

enum Kind { SLEEP, SAFE, BORING }

# The shader stays a path, never a preload: the city kit and the tests share
# this scene, and a compile-time const can bind an empty shader while another
# load of it still runs (T102).
const SLEEP_HAZE_SHADER_PATH := "res://shaders/sleep_haze.gdshader"
# The haze square draws over the street and the walkers, like air.
const HAZE_Z_INDEX := 50
const HAZE_FADE_SECONDS := 0.9
# The drooping street lamp of a sleep zone: a post that bends like a tired
# flower, with its head still on, ART_DIRECTION section 5.
const LAMP_CURVE := [Vector2(0, 0), Vector2(3, -30), Vector2(10, -52), Vector2(22, -60)]
const LAMP_POLE_WIDTH := 5.0
const LAMP_HEAD_RADIUS := 7.0
const LAMP_GLOW_RADIUS := 18.0
# Soft ring steps: three lavender rings fade the zone edge, never a hard cut.
const RING_STEPS := 3
const RING_OUTER_ALPHA := 0.16

@export var kind: Kind = Kind.SLEEP

var _broadcast_silenced := false
var _active := true
var _palette: ArtPalette
var _haze: Polygon2D


func _ready() -> void:
	_palette = ArtPalette.world()
	if kind == Kind.SLEEP and not _broadcast_silenced:
		_build_haze()


func set_active(active: bool) -> void:
	# The owner of the zone can end its pull, like the endless song of the band
	# on the wake: the zone stops draining and stops drawing.
	if _active == active:
		return
	_active = active
	if _haze != null:
		_haze.visible = active and not _broadcast_silenced
	queue_redraw()


func is_active() -> bool:
	return _active


func silence_broadcast() -> void:
	# The tower of the city is off: the address no longer plays through this
	# pole, so the zone stops pulling the player down. The haze burns off and
	# the drooping lamp goes dark.
	if _broadcast_silenced:
		return
	_broadcast_silenced = true
	_fade_haze()
	queue_redraw()


func is_broadcast_silenced() -> bool:
	return _broadcast_silenced


func haze_strength() -> float:
	# Test read of the live haze shader strength.
	if _haze == null:
		return 0.0
	var material := _haze.material as ShaderMaterial
	if material == null:
		return 0.0
	return material.get_shader_parameter("strength") as float


func _physics_process(_delta: float) -> void:
	# Poll the overlap every physics frame, like the sleepwalker sensors do:
	# signal delivery order between siblings is not guaranteed, and the drain
	# tier must stay set for every frame of the stay inside the area.
	if not _active:
		return
	var player := _player_inside()
	if player == null:
		return
	if kind == Kind.SAFE:
		player.sleep_meter.suppress_environmental_drain()
	elif kind == Kind.BORING:
		# A boring attack, section 14: the lullaby of the band or the slides of
		# a keynote boss drain at the boring rate. The song is the boss's own,
		# so a silent broadcast tower does not stop it.
		player.sleep_meter.escalate_drain(SleepMeter.DrainTier.BORING_ATTACK)
	elif not _broadcast_silenced:
		player.sleep_meter.escalate_drain(SleepMeter.DrainTier.SLEEP_ZONE)


func has_player_inside() -> bool:
	# A live overlap check for callers outside the drain tick, like the free
	# cafe refill that flows only inside the cafe safe zone.
	return _player_inside() != null


func _player_inside() -> Player:
	for body: Node2D in get_overlapping_bodies():
		if body is Player:
			return body
	return null


func _build_haze() -> void:
	# The sleep haze shader of the style lab, now live on the pole zones: the
	# street inside loses color and drifts in lavender, never dark.
	var radius := _circle_radius()
	if radius <= 0.0:
		return
	_haze = Polygon2D.new()
	_haze.name = "SleepHaze"
	_haze.z_index = HAZE_Z_INDEX
	var diameter := radius * 2.0
	_haze.position = Vector2(-radius, -radius)
	_haze.polygon = PackedVector2Array(
		[Vector2.ZERO, Vector2(diameter, 0.0), Vector2(diameter, diameter), Vector2(0.0, diameter)]
	)
	var material := ShaderMaterial.new()
	material.shader = load(SLEEP_HAZE_SHADER_PATH) as Shader
	material.set_shader_parameter(
		"haze", _palette.lavender if _palette != null else Color("#A99BC4")
	)
	material.set_shader_parameter("strength", 1.0)
	material.set_shader_parameter("rect_size", Vector2(diameter, diameter))
	_haze.material = material
	_haze.visible = _active and not _broadcast_silenced
	add_child(_haze)


func _fade_haze() -> void:
	if _haze == null:
		return
	var material := _haze.material as ShaderMaterial
	var fade := create_tween()
	fade.tween_method(
		func(strength: float) -> void: material.set_shader_parameter("strength", strength),
		1.0,
		0.0,
		HAZE_FADE_SECONDS
	)
	fade.tween_callback(_haze.hide)


func _draw() -> void:
	# The zone edge stays visible, section 13 of ART_DIRECTION: soft rings in
	# the zone color, and the drooping lamp at the pole.
	if not _active or _palette == null:
		return
	var radius := _circle_radius()
	if radius <= 0.0:
		return
	_draw_rings(radius)
	if kind == Kind.SLEEP:
		_draw_lamp()


func _draw_rings(radius: float) -> void:
	var color := _ring_color()
	for step: int in RING_STEPS:
		var ring_radius := radius * (1.0 - float(step) * 0.12)
		var alpha := RING_OUTER_ALPHA * (1.0 - float(step) * 0.28)
		draw_circle(Vector2.ZERO, ring_radius, Color(color, alpha))


func _ring_color() -> Color:
	# The cafe safe zone reads warm: the sanctuary is the one finished
	# drawing. Sleep and boring zones read lavender: dusk and dream.
	if kind == Kind.SAFE:
		return _palette.butter
	return _palette.lavender


func _draw_lamp() -> void:
	# A street lamp that droops like a tired flower, section 5. While the
	# address plays, the head still burns warm inside the blue dusk.
	var curve := PackedVector2Array(LAMP_CURVE)
	draw_polyline(curve, _palette.espresso.lerp(_palette.cream, 0.45), LAMP_POLE_WIDTH)
	var head: Vector2 = LAMP_CURVE[LAMP_CURVE.size() - 1] + Vector2(LAMP_HEAD_RADIUS + 2.0, 4.0)
	var lit := _active and not _broadcast_silenced
	if lit:
		draw_circle(head, LAMP_GLOW_RADIUS, Color(_palette.butter, 0.28))
		draw_circle(head, LAMP_HEAD_RADIUS, _palette.butter)
	else:
		draw_circle(head, LAMP_HEAD_RADIUS, _palette.rain.lerp(_palette.cream, 0.4))


func _circle_radius() -> float:
	var shape_node := get_node_or_null(^"CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		return 0.0
	var circle := shape_node.shape as CircleShape2D
	if circle == null:
		return 0.0
	return circle.radius
