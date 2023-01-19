extends Node

signal button_press_count_changed(newValue : int)

signal p1_ready_update(newValue: bool)
signal p2_ready_update(newValue: bool)
signal p3_ready_update(newValue: bool)
signal p4_ready_update(newValue: bool)

signal p1_rename(newName: String)
signal p2_rename(newName: String)
signal p3_rename(newName: String)
signal p4_rename(newName: String)

var button_press_count := 0:
	set(value):
		print('button press updated: ', value)
		button_press_count = value
		emit_signal(StringName("button_press_count_changed"), value)


var p1_ready: bool:
	set(value):
		p1_ready = value
		print('p1 ready!')
		emit_signal(StringName("p1_ready_update"), value)
		
var p2_ready: bool:
	set(value):
		p2_ready = value
		print('p2 ready!')
		emit_signal(StringName("p2_ready_update"), value)
		
var p3_ready: bool:
	set(value):
		p3_ready = value
		print('p3 ready!')
		emit_signal(StringName("p3_ready_update"), value)
		
var p4_ready: bool:
	set(value):
		p4_ready = value
		print('p4 ready!')
		emit_signal(StringName("p4_ready_update"), value)

var p1_name: String:
	set(newName):
		p1_name = newName
		print('p1 renamed to ' + str(p1_name))
		emit_signal(StringName("p1_rename"), newName)
		
var p2_name: String:
	set(newName):
		p2_name = newName
		print('p2 renamed to ' + str(p2_name))
		emit_signal(StringName("p2_rename"), newName)
		
var p3_name: String:
	set(newName):
		p3_name = newName
		print('p3 renamed to ' + str(p2_name))
		emit_signal(StringName("p3_rename"), newName)
		
var p4_name: String:
	set(newName):
		p4_name = newName
		print('p4 renamed to ' + str(p2_name))
		emit_signal(StringName("p4_rename"), newName)
