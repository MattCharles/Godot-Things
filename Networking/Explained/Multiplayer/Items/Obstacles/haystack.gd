extends Node2D
class_name Haystack

var max_health := 90
var health := max_health
var default_sprite := "res://Items/Obstacles/hay.png"
var damaged_sprite := "res://Items/Obstacles/sad_hay.png"
var healed_sprite := "res://Items/Obstacles/glad_hay.png"

var DEFAULT_SPRITE_INDEX := 0
var DAMAGED_SPRITE_INDEX := 1
var HEALED_SPRITE_INDEX := 2

func damage(amount:int) -> void:
	print("damaging haystack")
	if multiplayer.is_server():
		rpc("set_health", health - amount)
		if health <= 0:
			rpc("set_active", false)
			return
		rpc("set_sprite", DAMAGED_SPRITE_INDEX)

@rpc("call_local", "reliable")
func set_active(value:bool) -> void:
	$"../Sprite2D".visible = value
	$CollisionPolygon2D.set_deferred("disabled", !value)
	
@rpc("call_local", "reliable")
func set_sprite(value:int) -> void:
	$"../Sprite2D".texture = load(damaged_sprite if value == DAMAGED_SPRITE_INDEX else healed_sprite)
	var modified_alpha := 1.0 if value == DEFAULT_SPRITE_INDEX else (float(health) / float(max_health) + 1) / 2
	$"../Sprite2D".modulate = Color(1, 1, 1, modified_alpha)

@rpc("call_local", "reliable")
func set_health(value:int) -> void:
	health = value

func heal(amount:int) -> void:
	if multiplayer.is_server():
		rpc("set_health", health - amount)
		if health <= 0:
			rpc("set_active", false)
			return
		rpc("set_sprite", HEALED_SPRITE_INDEX)
