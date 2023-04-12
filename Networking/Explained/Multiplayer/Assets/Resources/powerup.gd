extends Resource

class ModifierMap extends Resource:
	var multiply: float
	var add: float
	var set: float
	var at_least: float
	var at_most: float

@export var modifiers:ModifierMap
@export var title:String
@export var description:String
@export var image:AnimatedSprite2D

func _init(new_modifiers = null, 
	new_title = "MISSING TITLE", 
	new_description = "MISSING DESCRIPTION", 
	new_image = null):
	
	modifiers = new_modifiers
	title = new_title
	description = new_description
	image = new_image
