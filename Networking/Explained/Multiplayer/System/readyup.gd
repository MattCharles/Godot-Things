extends Control


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_start_game_button_pressed():
	get_node("/root/main_menu/HolePunch").finalize_peers()

func _on_cancel_button_pressed():
	get_tree().change_scene_to_file("res://System/main_menu.tscn")
