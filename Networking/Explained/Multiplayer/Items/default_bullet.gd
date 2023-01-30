extends Node2D

var target = Vector2(0, 0)
var speed = 300

var velocity = Vector2()

func _physics_process(delta):
	velocity = position.direction_to(target) * speed
	position = position + velocity * delta
