extends Node

var sync_player_name: String
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
var sync_hand_rotation: float
var sync_velocity : Vector2
var sync_hand_flip: bool

var sync_move_state: Movement.states

var sync_flip_sprite: bool

var sync_health: int
var sync_max_health: int

var sync_collidable := false
var sync_dead: bool

var sync_bullets_per_shot := 1
