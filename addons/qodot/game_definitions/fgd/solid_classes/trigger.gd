extends Area3D

signal trigger()

func _ready():
	connect("body_entered", handle_body_entered)

func handle_body_entered(body: Node):
	if body is StaticBody3D:
		return

	emit_signal("trigger")
