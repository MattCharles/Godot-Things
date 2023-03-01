extends RigidBody2D
class_name Bullet

var target = Vector2(0, 0)
var speed = 1000
var damage := 35
var num_bounces = 0

func _ready():
	$Networking.sync_num_bounces = num_bounces

func set_damage(value):
	if !multiplayer.is_server():
		return
	print("setting damage to " + str(value))
	rpc("sync_set_damage", value)

@rpc("reliable", "call_local")
func sync_set_damage(value):
	print("synching damage to " + str(value))
	damage = value
	$Networking.sync_damage = damage

@rpc("call_local", "any_peer")
func free():
	call_deferred("free")

func _on_body_entered(body):
	if !multiplayer.is_server():
		return
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
