extends RigidBody2D
class_name Bullet

var target = Vector2(0, 0)
var speed = 1000
var damage = 35
var num_bounces = 1

var velocity = Vector2()

func _ready():
	$Networking.sync_num_bounces = num_bounces

@rpc("call_local", "any_peer")
func free():
	call_deferred("free")

func _on_body_entered(body):
	print("collided")
	
	if body is Player:
		body.damage(damage)
		rpc("free")
		
	if body is Bullet:
		return
		
	elif num_bounces <= 0:
		rpc("free")
	
	
	num_bounces = num_bounces - 1
	$Networking.sync_num_bounces = num_bounces

func fire():
	print("firing at " + str(target))
	self.apply_impulse(target.normalized() * speed, Vector2.ZERO)
