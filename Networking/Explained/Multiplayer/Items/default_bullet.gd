extends RigidBody2D

var target = Vector2(0, 0)
var speed = 100000
var damage = 35
var num_bounces = 10

var velocity = Vector2()

func _on_VisibilityNotifier2D_screen_exited():
	rpc("free")

func _on_default_bullet_body_entered(body):
	if body is Player:
		body.damage(damage)
		rpc("free")
		
	elif num_bounces > 0:
		pass

@rpc("call_local", "any_peer")
func free():
	call_deferred("free")

func _on_body_entered(body):
	num_bounces = num_bounces - 1
	
	if body is Player:
		body.damage(damage)
		rpc("free")
		
	elif num_bounces <= 0:
		rpc("free")

func fire():
	print("firing at " + str(target))
	self.apply_impulse(Vector2.ZERO, Vector2(speed, speed))
