# ABOUTME: CityLook is the art identity of one city: accent color, light, and weather.
# ABOUTME: All cities share one block kit; the look is what makes each city different.
class_name CityLook
extends Resource

enum Weather { CLEAR_FOG, DRIZZLE, FALLING_LEAVES }

@export var city_id: String
@export var display_name: String
@export var accent := Color.WHITE
# The color of the morning light after the tower goes off.
@export var morning_light := Color.WHITE
# The color of the city while it sleeps: dusk inside the morning.
@export var dusk_light := Color.WHITE
@export var weather: Weather = Weather.CLEAR_FOG
@export var weather_color := Color.WHITE
