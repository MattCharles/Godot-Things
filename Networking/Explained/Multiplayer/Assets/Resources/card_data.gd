extends Resource
class_name CardData

enum Function {
	ADD,
	MULTIPLY,
	SET,
	AT_LEAST,
	AT_MOST
}

class ModifierMap extends Resource:
	var function: Function
	var variable_name: String
	var value: Variant
	
	func _init(new_func := Function.ADD,
		new_variable_name := "ERROR_MISSING_VARIABLE_NAME",
		new_value = null):
			function = new_func
			variable_name = new_variable_name
			new_value 

var modifiers:Array
var title:String
var description:String
var image:AnimatedSprite2D

# Autogenerate a unique ID.
var card_id:int

func _init(new_modifiers = null, 
	new_title = "MISSING TITLE", 
	new_description = "MISSING DESCRIPTION", 
	new_image = null):
	
	for entry in new_modifiers:
		assert(entry is ModifierMap, "ERROR: Modifiers must conform to ModifierMap type.")
	
	modifiers = new_modifiers
	title = new_title
	description = new_description
	image = new_image

	card_id = hash(title + description)


