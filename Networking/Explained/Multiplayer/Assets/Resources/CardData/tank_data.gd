extends CardData

const _title := "Tank"
const _description := "Get bigger and healthier - but slower!"
const image_path := "res://Assets/Resources/Animations/tank.tres"

var _modifiers:Array = [
	CardData.ModifierMap.new(
		CardData.Function.MULTIPLY,
		"max_health",
		1.2
	),
	CardData.ModifierMap.new(
		CardData.Function.MULTIPLY,
		"scale",
		1.2
	),
	CardData.ModifierMap.new(
		CardData.Function.MULTIPLY,
		"speed",
		.9
	)
]

func _init():
	super._init(_modifiers, _title, _description, load(image_path))
