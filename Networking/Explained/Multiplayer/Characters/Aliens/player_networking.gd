extends Node


var player_name: String
var sync_position : Vector2:
	set(value):
		sync_position = value
		processed_position = false
var processed_position : bool

var sync_hand_position : Vector2:
	set(value):
		sync_hand_position = value
		processed_hand_position = false
var processed_hand_position: bool

var sync_velocity : Vector2

var sync_move_state: Movement.states:
	set(value):
		sync_move_state = value
		processed_move_state = false
var processed_move_state: bool

var sync_flip_sprite: bool = false
