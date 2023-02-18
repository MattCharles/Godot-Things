extends Node2D

var target = Vector2(0, 0)
var speed = 1000
var damage = 35

var velocity = Vector2()

func _physics_process(delta):
	velocity = position.direction_to(target) * speed
	position = position + velocity * delta

func _on_VisibilityNotifier2D_screen_exited():
	rpc("free")

func _on_default_bullet_body_entered(body):
	if body is Player:
		body.damage(damage)
	
	rpc("free")
		

@rpc("call_local", "any_peer")
func free():
	queue_free()
