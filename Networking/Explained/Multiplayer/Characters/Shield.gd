extends StaticBody2D

class_name Shield

var max_health := 50
var health := max_health
var default_sprite := "res://Characters/Shield.png"
var damaged_sprite := "res://Characters/DamagedShield.png"

var DEFAULT_SPRITE := 0
var DAMAGED_SPRITE := 1

func damage(amount:int) -> void:
	if multiplayer.is_server():
		rpc("set_health", health - amount)
		if health <= 0:
			rpc("set_active", false)
			return
		rpc("set_sprite", DAMAGED_SPRITE)

func reset() -> void:
	if multiplayer.is_server():
		rpc("set_health", max_health)
		rpc("set_active", true)
		rpc("set_sprite", DEFAULT_SPRITE)

@rpc("call_local", "reliable")
func set_active(value:bool) -> void:
	$Sprite2D.visible = value
	$CollisionShape2D.set_deferred("disabled", !value)
	
@rpc("call_local", "reliable")
func set_sprite(value:int) -> void:
	$Sprite2D.texture = load(default_sprite if value == DEFAULT_SPRITE else damaged_sprite)
	var modified_alpha := 1.0 if value == DEFAULT_SPRITE else (1 + float(health) / float(max_health)) / 2
	$Sprite2D.modulate = Color(1, 1, 1, modified_alpha)

@rpc("call_local", "reliable")
func set_health(value:int) -> void:
	health = value
