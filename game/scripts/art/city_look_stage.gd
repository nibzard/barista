# ABOUTME: CityLookStage wires one CityLook into the live city: dusk light, weather, paper grain.
# ABOUTME: The tower switch-off brings the morning: the dusk lifts over the whole city.
class_name CityLookStage
extends Node2D

# The style lab sunrise beat, section 19 step 9: the switch is the reward.
const SUNRISE_SECONDS := 2.4
# The paper grain overlay sits above the interface, so the whole screen reads
# as one sheet of paper, ART_DIRECTION sections 3 and 14.
const PAPER_LAYER := 8
const FOG_BAND_Y := 60.0

var _look: CityLook
var _modulate: CanvasModulate
var _weather: CPUParticles2D
var _paper: ColorRect
var _morning := false


func setup(look: CityLook, world_size: Vector2) -> void:
	# One stage per city build. A city without a look stays plain.
	if look == null:
		return
	_look = look
	_modulate = CanvasModulate.new()
	_modulate.name = "DuskLight"
	_modulate.color = look.dusk_light
	add_child(_modulate)
	_build_weather(world_size)
	_build_paper()


func bring_morning(instant := false) -> void:
	# The city wakes: the dusk lifts and the morning light floods in.
	if _look == null or _morning:
		return
	_morning = true
	if instant or SUNRISE_SECONDS <= 0.0:
		_modulate.color = _look.morning_light
		return
	var sunrise := create_tween()
	sunrise.tween_property(_modulate, "color", _look.morning_light, SUNRISE_SECONDS)


func is_morning() -> bool:
	return _morning


func weather_kind() -> int:
	return _look.weather if _look != null else -1


func dusk_color() -> Color:
	return _modulate.color if _modulate != null else Color.WHITE


func _build_weather(world_size: Vector2) -> void:
	# One light weather layer over the whole city, cheap for Android.
	match _look.weather:
		CityLook.Weather.DRIZZLE:
			_weather = _particles(world_size, 120, Vector2(0, 520), 1.4)
			_weather.texture = _rain_streak()
			_weather.scale_amount_min = 0.9
			_weather.scale_amount_max = 1.2
		CityLook.Weather.FALLING_LEAVES:
			_weather = _particles(world_size, 22, Vector2(-30, 60), 12.5)
			_weather.texture = _soft_dot(14)
			_weather.scale_amount_min = 0.8
			_weather.scale_amount_max = 1.3
			_weather.angular_velocity_min = -90.0
			_weather.angular_velocity_max = 90.0
		CityLook.Weather.CLEAR_FOG:
			for side: int in 2:
				var fog := Sprite2D.new()
				fog.name = "FogBank%d" % side
				fog.texture = _soft_dot(256)
				fog.position = Vector2(world_size.x * (0.25 + 0.5 * float(side)), FOG_BAND_Y)
				fog.scale = Vector2(3.2, 1.1)
				fog.modulate = _look.weather_color
				add_child(fog)
	if _weather != null:
		add_child(_weather)


func _particles(
	world_size: Vector2, amount: int, velocity: Vector2, lifetime: float
) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.name = "Weather"
	particles.amount = amount
	particles.lifetime = lifetime
	particles.preprocess = lifetime
	particles.position = Vector2(world_size.x * 0.5, -20.0)
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(world_size.x * 0.6, 10.0)
	particles.direction = velocity.normalized()
	particles.spread = 4.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = velocity.length() * 0.85
	particles.initial_velocity_max = velocity.length() * 1.15
	particles.color = _look.weather_color
	return particles


func _build_paper() -> void:
	# The engine part of the style lab, now on the live screen: cream paper
	# grain over everything, so every scene shares one ground.
	var layer := CanvasLayer.new()
	layer.name = "PaperLayer"
	layer.layer = PAPER_LAYER
	add_child(layer)
	_paper = ColorRect.new()
	_paper.name = "PaperGrain"
	_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paper.set_anchors_preset(Control.PRESET_FULL_RECT)
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/paper_grain.gdshader")
	_paper.material = material
	layer.add_child(_paper)


func _soft_dot(dot_size: int) -> GradientTexture2D:
	var fade := Gradient.new()
	fade.set_color(0, Color.WHITE)
	fade.set_color(1, Color(1, 1, 1, 0))
	var dot := GradientTexture2D.new()
	dot.gradient = fade
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(1.0, 0.5)
	dot.width = dot_size
	dot.height = dot_size
	return dot


func _rain_streak() -> GradientTexture2D:
	# Steamtle drizzle reads as chalk strokes, ART_DIRECTION section 6.
	var streak := _soft_dot(4)
	streak.fill = GradientTexture2D.FILL_LINEAR
	streak.fill_from = Vector2(0.5, 1.0)
	streak.fill_to = Vector2(0.5, 0.0)
	streak.width = 3
	streak.height = 24
	return streak
