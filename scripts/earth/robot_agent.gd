class_name RobotAgent
extends Node3D
## 施工机器人：自己找活、绕开障碍走过去、到了就播施工动作。
## 施工结果在周结算时算，这里只负责让小镇看起来是活的（demo 文案 1-3）。

const BODY_SIZE := Vector3(1.2, 1.2, 1.6)
const BODY_COLOR := Color(0.9, 0.55, 0.15)
const WORK_BOB_HEIGHT := 0.25
const WORK_BOB_SPEED := 8.0
const ARRIVE_DISTANCE := 0.1
const TURN_SPEED := 10.0

enum State { IDLE, WALKING, WORKING }

var state := State.IDLE
var view: EarthView
var target_job: Dictionary = {}

var _path: Array[Vector2i] = []
var _speed: float
var _time := 0.0
var _body: MeshInstance3D


func setup(earth_view: EarthView, start_cell: Vector2i) -> void:
	view = earth_view
	_speed = float(DataDB.balance("earth_robot_speed"))
	var mesh := BoxMesh.new()
	mesh.size = BODY_SIZE
	var material := StandardMaterial3D.new()
	material.albedo_color = BODY_COLOR
	mesh.material = material
	_body = MeshInstance3D.new()
	_body.mesh = mesh
	_body.position = Vector3.UP * BODY_SIZE.y / 2.0
	add_child(_body)
	position = view.cell_center(start_cell)


## 派活：走到任务旁边最近的空格
func assign(job: Dictionary, rect: Rect2i) -> void:
	target_job = job
	_walk_to(_nearest_free_beside(rect))


## 没活了回家
func send_home(cell: Vector2i) -> void:
	target_job = {}
	_walk_to(cell)


func _process(delta: float) -> void:
	_time += delta
	match state:
		State.WALKING:
			_follow_path(delta)
		State.WORKING:
			_body.position.y = BODY_SIZE.y / 2.0 + absf(sin(_time * WORK_BOB_SPEED)) * WORK_BOB_HEIGHT
		_:
			_body.position.y = BODY_SIZE.y / 2.0


func _walk_to(goal: Vector2i) -> void:
	var from := view.cell_at(position)
	# 脚下刚被放了建筑时，先从最近的空格出发，否则找不到路
	if view.astar.is_point_solid(from):
		from = _nearest_free(from)
		position = view.cell_center(from)
	_path = []
	if goal != from and not view.astar.is_point_solid(goal):
		_path.assign(view.astar.get_id_path(from, goal))
	if _path.is_empty():
		state = State.WORKING if not target_job.is_empty() else State.IDLE
	else:
		state = State.WALKING


func _follow_path(delta: float) -> void:
	if _path.is_empty():
		state = State.WORKING if not target_job.is_empty() else State.IDLE
		return
	var goal := view.cell_center(_path[0])
	var to_goal := goal - position
	if to_goal.length() <= ARRIVE_DISTANCE:
		_path.remove_at(0)
		return
	position += to_goal.normalized() * minf(_speed * delta, to_goal.length())
	var facing := atan2(to_goal.x, to_goal.z)
	rotation.y = lerp_angle(rotation.y, facing, minf(1.0, TURN_SPEED * delta))


func _nearest_free_beside(rect: Rect2i) -> Vector2i:
	var from := view.cell_at(position)
	var best := from
	var best_distance := INF
	for x in range(rect.position.x - 1, rect.end.x + 1):
		for z in range(rect.position.y - 1, rect.end.y + 1):
			var cell := Vector2i(x, z)
			if rect.has_point(cell) or not view.astar.is_in_boundsv(cell) or view.astar.is_point_solid(cell):
				continue
			var distance := Vector2(from).distance_squared_to(Vector2(cell))
			if distance < best_distance:
				best_distance = distance
				best = cell
	return best


func _nearest_free(from: Vector2i) -> Vector2i:
	for radius in range(1, view.world.grid_size):
		for x in range(from.x - radius, from.x + radius + 1):
			for z in range(from.y - radius, from.y + radius + 1):
				var cell := Vector2i(x, z)
				if view.astar.is_in_boundsv(cell) and not view.astar.is_point_solid(cell):
					return cell
	return from
