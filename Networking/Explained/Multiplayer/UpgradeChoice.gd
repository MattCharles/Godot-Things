extends Control

# Synchronized fields
var picker := 0
var remote_animation := "default"
var updated_animation := true
var card_id := 0

signal picked(id, picker)

# Local fields
var animation := "default"

func set_picker(value):
	rpc("sync_picker", value)
	
func set_title(value):
	rpc("sync_title", value)
	
func set_description(value):
	rpc("sync_description", value)

func set_id(id):
	rpc("sync_id", id)
	
@rpc("call_local", "reliable", "any_peer")
func sync_id(id):
	card_id = id
	
@rpc("call_local", "reliable", "any_peer")
func sync_title(value):
	$Title.text = value
	
@rpc("call_local", "reliable", "any_peer")
func sync_description(value):
	$Description.text = value
	
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
	emit_signal("picked", card_id, picker)

func _on_button_mouse_entered():
	if multiplayer.get_unique_id() != picker:
		return
	rpc("update_animation", "hover")

func _on_button_mouse_exited():
	if multiplayer.get_unique_id() != picker:
		return
	rpc("update_animation", "default")

