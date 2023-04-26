extends Node

const card_id := 26

const modifiers := {
	"poison_damage": {
		"add": 20
	},
	"poison_duration": {
		# After about a second, the poison will go off.
		"at_least": .99
	}
}
