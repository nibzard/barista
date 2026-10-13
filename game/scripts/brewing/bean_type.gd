# ABOUTME: BeanType defines one coffee bean and its quality tier as data.
# ABOUTME: The V1 beans live in game/resources/brewing/beans/, one .tres per bean.
class_name BeanType
extends Resource

enum Quality {
	BASIC,
	GOOD,
	EXCELLENT,
}

@export var bean_id: String
@export var display_name: String
@export var quality: Quality
