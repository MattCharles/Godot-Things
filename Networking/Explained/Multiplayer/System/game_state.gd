extends Node

signal room_code_changed(new_code: String)

var room_code: String = "XXXXX":
	set(new_code):
		room_code = new_code
		print('room code is ' + str(room_code))
		emit_signal(StringName("room_code_changed"), room_code)

var names: Array = []
var ids: Array = []

var name_dict := {}

