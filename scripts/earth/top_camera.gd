class_name TopCamera
extends Camera3D
## 俯视镜头：WASD 移动，滚轮缩放，按住右键旋转（demo 文案 1-1）。

const MOVE_SPEED := 30.0
const ZOOM_STEP := 4.0
const MIN_DISTANCE := 15.0
const MAX_DISTANCE := 80.0
const ROTATE_SPEED := 0.3
const PITCH_DEGREES := -55.0
const START_DISTANCE := 58.0

var active := true
var focus := Vector3.ZERO
var yaw := 0.0
var distance := START_DISTANCE
var limit := 60.0
var _dragging := false
var dragged := false  # 这次按右键有没有转动镜头；没转动算"右键单击"（取消放置）


func _process(delta: float) -> void:
	if not active:
		return
	var input := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W):
		input.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		input.y += 1.0
	if Input.is_physical_key_pressed(KEY_A):
		input.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		input.x += 1.0
	if input != Vector2.ZERO:
		var move := Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, deg_to_rad(yaw)).normalized()
		focus += move * MOVE_SPEED * delta
		focus = focus.clamp(Vector3.ZERO, Vector3(limit, 0.0, limit))
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event
		if button.button_index == MOUSE_BUTTON_WHEEL_UP and button.pressed:
			distance = maxf(MIN_DISTANCE, distance - ZOOM_STEP)
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN and button.pressed:
			distance = minf(MAX_DISTANCE, distance + ZOOM_STEP)
		elif button.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = button.pressed
			if button.pressed:
				dragged = false
	elif event is InputEventMouseMotion and _dragging:
		var motion: InputEventMouseMotion = event
		yaw -= motion.relative.x * ROTATE_SPEED
		dragged = true


## 屏幕上一点对应地面的哪里；看不到地面时返回 Vector3.INF
func ground_point(screen_position: Vector2) -> Vector3:
	var origin := project_ray_origin(screen_position)
	var direction := project_ray_normal(screen_position)
	if absf(direction.y) < 0.001:
		return Vector3.INF
	var t := -origin.y / direction.y
	return Vector3.INF if t < 0.0 else origin + direction * t


func _apply() -> void:
	rotation_degrees = Vector3(PITCH_DEGREES, yaw, 0.0)
	position = focus - global_transform.basis.z * -distance
