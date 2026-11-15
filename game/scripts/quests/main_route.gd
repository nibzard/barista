# ABOUTME: MainRoute is the ordered city row of the main quest, west to east.
# ABOUTME: The route order drives the unlock rule and carries the side quests.
class_name MainRoute
extends Resource

@export var cities: Array[CityDefinition] = []


func city_ids() -> Array[String]:
	var ids: Array[String] = []
	for city: CityDefinition in cities:
		ids.append(city.city_id)
	return ids


func find_city(city_id: String) -> CityDefinition:
	for city: CityDefinition in cities:
		if city.city_id == city_id:
			return city
	return null
