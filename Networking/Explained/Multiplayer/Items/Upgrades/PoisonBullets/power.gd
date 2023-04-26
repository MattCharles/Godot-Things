extends Node

const card_id := 25

const modifiers := {
	"poison_damage": {
		"add": 10
	},
	"poison_duration": {
		# After about a second, the first of the three ticks of poison will go off.
		"add": 3.99
	}
}
