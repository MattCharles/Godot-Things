extends Node2D

@onready var radius := $Area2D
@onready var timer := $Timer
@onready var progress := $TextureProgressBar
const HEAL_AMOUNT := 30

func _process(delta):
	progress.value = timer.wait_time

func _on_timer_timeout():
	for entity in radius.get_overlapping_bodies():
		if entity is Player or entity is Haystack:
			entity.heal(HEAL_AMOUNT)
	queue_free()
