extends Node2D

var nickname = "": 
	set(value):
		nickname = value
		$Details/Name.set_text(value)
