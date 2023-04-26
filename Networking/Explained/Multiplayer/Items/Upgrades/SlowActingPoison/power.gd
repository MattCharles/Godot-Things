extends Node

const card_id := 27

const modifiers := {
	"poison_damage": {
		"at_least": 2
	},
	"poison_duration": {
		# After about a second, the poison will go off.
		"add": 10.99
	}
}
