extends Control

func _on_button_pressed():
	print("click")
	pass # Replace with function body.

func _on_button_mouse_entered():
	$Button/AnimatedSprite2D.play("hover")
	pass # Replace with function body.

func _on_button_mouse_exited():
	$Button/AnimatedSprite2D.play("default")
	pass # Replace with function body.
