# ABOUTME: TutorialFinaleView draws the section 19 step 10 reveal: the three-city
# ABOUTME: map of the version and the Apocalypse Barista title card.
class_name TutorialFinaleView
extends Control

const CITY_SAN_COFFESCO := preload("res://resources/city/san_coffesco.tres")
const CITY_STEAMTLE := preload("res://resources/city/steamtle.tres")
const CITY_POURLAND := preload("res://resources/city/pourtland.tres")

const BACKDROP_COLOR := Color(0.02, 0.02, 0.04, 0.88)
const ROAD_COLOR := Color(0.78, 0.7, 0.5, 0.9)
const ROAD_FADE_COLOR := Color(0.78, 0.7, 0.5, 0.35)
const CITY_RADIUS := 14.0
const CITY_RING_WIDTH := 4.0
const LABEL_TEXT_SIZE := 24
const LABEL_COLOR := Color(0.96, 0.93, 0.85, 1.0)
const HERE_TEXT_SIZE := 16
const HERE_COLOR := Color(0.98, 0.83, 0.25, 1.0)
const HERE_LABEL := "YOU ARE HERE"
const TITLE_TEXT := "APOCALYPSE BARISTA"
const TITLE_TEXT_SIZE := 84
const TITLE_COLOR := Color(0.96, 0.93, 0.85, 1.0)
const SUBTITLE_TEXT := "BREW IT STRONG."
const SUBTITLE_TEXT_SIZE := 26
const SUBTITLE_COLOR := Color(0.78, 0.62, 0.35, 1.0)
# The dots sit left to right on one road, west to east like the journey.
const MAP_ROW_FRACTION := 0.46
const DOT_FRACTIONS: Array[float] = [0.26, 0.5, 0.74]
# How fast the map and the title fade in, in alpha per second.
const FADE_SPEED := 2.5

var _map_alpha := 0.0
var _title_alpha := 0.0
var _map_target := 0.0
var _title_target := 0.0


func _process(delta: float) -> void:
	var map_next := move_toward(_map_alpha, _map_target, FADE_SPEED * delta)
	var title_next := move_toward(_title_alpha, _title_target, FADE_SPEED * delta)
	if map_next == _map_alpha and title_next == _title_alpha:
		return
	_map_alpha = map_next
	_title_alpha = title_next
	queue_redraw()


func reset() -> void:
	_map_alpha = 0.0
	_title_alpha = 0.0
	_map_target = 0.0
	_title_target = 0.0
	queue_redraw()


func show_map() -> void:
	_map_target = 1.0


func show_title() -> void:
	_title_target = 1.0


func is_map_faded_in() -> bool:
	return _map_alpha >= 0.99


func is_title_faded_in() -> bool:
	return _title_alpha >= 0.99


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKDROP_COLOR)
	if _map_alpha > 0.0:
		_draw_map()
	if _title_alpha > 0.0:
		_draw_title()


func _draw_map() -> void:
	# Three cities on the map, one road through them, and the road east that
	# runs on past the edge: the journey does not end at Pourtland.
	var row := Vector2(size.x * 0.1, size.y * MAP_ROW_FRACTION)
	var end := Vector2(size.x * 0.9, row.y)
	draw_line(row, Vector2(end.x - 260.0, end.y), ROAD_COLOR * Color(1, 1, 1, _map_alpha), 5.0)
	draw_line(Vector2(end.x - 260.0, end.y), end, ROAD_FADE_COLOR * Color(1, 1, 1, _map_alpha), 5.0)
	var cities := _cities()
	for i: int in range(cities.size()):
		var center := Vector2(size.x * DOT_FRACTIONS[i], row.y)
		var accent: Color = cities[i].accent_color
		accent.a = _map_alpha
		draw_circle(center, CITY_RADIUS, accent)
		draw_arc(
			center,
			CITY_RADIUS + CITY_RING_WIDTH,
			0.0,
			TAU,
			32,
			LABEL_COLOR * Color(1, 1, 1, _map_alpha),
			2.0
		)
		_draw_centered(
			center + Vector2(0.0, 48.0),
			cities[i].display_name.to_upper(),
			LABEL_TEXT_SIZE,
			LABEL_COLOR * Color(1, 1, 1, _map_alpha)
		)
		if i == 0:
			_draw_centered(
				center + Vector2(0.0, -40.0),
				HERE_LABEL,
				HERE_TEXT_SIZE,
				HERE_COLOR * Color(1, 1, 1, _map_alpha)
			)


func _draw_title() -> void:
	_draw_centered(
		Vector2(size.x * 0.5, size.y * 0.7),
		TITLE_TEXT,
		TITLE_TEXT_SIZE,
		TITLE_COLOR * Color(1, 1, 1, _title_alpha)
	)
	_draw_centered(
		Vector2(size.x * 0.5, size.y * 0.78),
		SUBTITLE_TEXT,
		SUBTITLE_TEXT_SIZE,
		SUBTITLE_COLOR * Color(1, 1, 1, _title_alpha)
	)


func _draw_centered(at: Vector2, text: String, text_size: int, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x
	draw_string(
		font, at + Vector2(-width * 0.5, 0.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, color
	)


func _cities() -> Array[CityDefinition]:
	var cities: Array[CityDefinition] = [CITY_SAN_COFFESCO, CITY_STEAMTLE, CITY_POURLAND]
	return cities
