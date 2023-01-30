extends Node

var sync_position : Vector2:
	set(value):
		sync_position = value
		processed_position = false
var processed_position : bool

var sync_velocity: Vector2

var sync_target: Vector2 #important note - does not sync after spawn on default bullet
