extends Node2D

var target = Vector2(0, 0)
var speed = 1000
var damage = 100

var velocity = Vector2()

func _physics_process(delta):
	velocity = position.direction_to(target) * speed
	position = position + velocity * delta

func _on_VisibilityNotifier2D_screen_exited():
	queue_free()

func _on_default_bullet_body_entered(body):
	if multiplayer.is_server():
		pass
	print("hit!")
	queue_free()
		
