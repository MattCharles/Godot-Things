extends Control

# Synchronized fields
var picker := 0
var remote_animation := "default"
var updated_animation := true

# Local fields
var animation := "default"

func set_picker(value):
	rpc("sync_picker", value)
	
@rpc("call_local", "reliable", "any_peer")
func sync_picker(value):
	picker = value
	
@rpc("call_local", "reliable", "any_peer")
func update_animation(animation):
	remote_animation = animation
	updated_animation = false
	$Button/AnimatedSprite2D.play(animation)

func _on_button_pressed():
	if multiplayer.get_unique_id() != picker:
		return
	print("click")

func _on_button_mouse_entered():
	if multiplayer.get_unique_id() != picker:
		return
	rpc("update_animation", "hover")

func _on_button_mouse_exited():
	if multiplayer.get_unique_id() != picker:
		return
	rpc("update_animation", "default")

