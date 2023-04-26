extends RigidBody2D
class_name Bullet

var target = Vector2(0, 0)
var speed := 1000
var damage := 35
var num_bounces = 0
var poison_damage := 0
var poison_duration := 0.0
var shooter = -1
var vampire_ratio := .3
var heal_on_poison := false

# TODO: maybe pass this from player if its causing lag
@onready var level = get_node("/root/").find_child("Level")

func set_shooter(value):
	rpc("remote_set_shooter", value)
	
@rpc("reliable", "call_local", "any_peer")
func remote_set_shooter(value):
	shooter = value

func set_vampire_ratio(ratio:float):
	rpc("remote_set_vampire_ratio", ratio)

@rpc("reliable", "call_local", "any_peer")
func remote_set_vampire_ratio(value):
	vampire_ratio = value

func set_damage(value):
	if !multiplayer.is_server():
		return
	print("setting damage to " + str(value))
	rpc("sync_set_damage", value)
	
func set_poison(damage: float, duration: float) -> void:
	if !multiplayer.is_server():
		return
	rpc("sync_set_poison", damage, duration)

@rpc("reliable", "call_local")
func sync_set_poison(damage:float, duration:float):
	print("synching poison to " + str(damage) + " for " + str(duration) + " seconds")
	poison_damage = damage
	poison_duration = duration
	
func set_scale_for_all_clients(value):
	if !multiplayer.is_server():
		return
	print("setting scale to " + str(value))
	rpc("sync_set_scale", value)

@rpc("reliable", "call_local")
func sync_set_damage(value):
	print("synching damage to " + str(value))
	damage = value
	$Networking.sync_damage = damage
	
@rpc("reliable", "call_local")
func sync_set_scale(value):
	print("synching scale to " + str(value))
	scale = value
	$Networking.sync_scale = scale

@rpc("call_local", "any_peer")
func free():
	queue_free()

func _on_body_entered(body):
	if !multiplayer.is_server():
		return
	print("collided")
	
	if body is Player or body is Shield or body is Haystack:
		body.damage(damage)
		if vampire_ratio > .01:
			assert(shooter != -1, "Shooter wasn't assigned")
			var amount_to_heal = max(1, int(damage * vampire_ratio))
			level.heal_player(shooter, amount_to_heal)
		if not body is Shield:
			body.poison(poison_damage, poison_duration)
		rpc("free")
		
	if body is Bullet:
		return
		
	elif num_bounces <= 0:
		rpc("free")
	
	num_bounces = num_bounces - 1
	$Networking.sync_num_bounces = num_bounces

func _physics_process(_delta):
	scale = $Networking.sync_scale
	damage = $Networking.sync_damage

func fire():
	print("firing at " + str(target))
	self.apply_impulse(target.normalized() * speed, Vector2.ZERO)
