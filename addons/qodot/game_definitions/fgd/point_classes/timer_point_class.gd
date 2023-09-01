@tool
class_name TimerPoint
extends QodotEntity

func _ready():
	var new_timer: Timer = Timer.new()
	add_child(new_timer)

func update_properties():
	super.update_properties()
	if not get_child(0) is Timer:
		push_error("could not find timer on %s" % [name])
	if "time" in properties:
		$Timer.wait_time = properties.time
	if "oneshot" in properties:
		$Timer.wait_time = properties.oneshot

func restart() -> void:
	$Timer.restart()
