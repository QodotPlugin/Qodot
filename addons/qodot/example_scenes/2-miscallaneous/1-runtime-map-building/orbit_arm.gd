class_name OrbitArm
extends Node3D

@export var should_translate := true
@export var should_rotate := true
@export var zoom := true

var yaw = 0.0
var pitch = 0.0

func _ready() -> void:
	yaw = transform.basis.get_euler().y
	pitch = transform.basis.get_euler().x

func _process(delta):
	rotation = Vector3.ZERO
	rotate(Vector3.RIGHT, pitch)
	rotate(Vector3.UP, yaw)

func _input(event) -> void:
	if event is InputEventMouseButton:
		if not zoom: return
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			$Camera.translation.z -= 2.0
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			$Camera.translation.z += 2.0
	elif event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			if not should_translate: return
			translate($Camera.global_transform.basis.x * event.relative.x * -0.05)
			translate($Camera.global_transform.basis.y * event.relative.y * 0.05)
		elif Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			if not should_rotate: return
			yaw += event.relative.x * -0.002
			pitch += event.relative.y * -0.002
