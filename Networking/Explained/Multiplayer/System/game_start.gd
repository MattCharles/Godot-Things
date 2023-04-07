extends Node

signal start_game

var num_playing: int:
	set(value):
		num_playing = value
		print(str(value) + " players playing")

var num_connected: int = 1: # one because host starts connected
	set(value):
		if num_connected == value:
			print("setting num_connected")
			return
		num_connected = value
		print(str(value) + " players connected")
		if num_connected == num_playing:
			emit_signal("start_game")
