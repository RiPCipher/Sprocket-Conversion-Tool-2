extends Camera3D

# Tuning
var orbit_sensitivity : float = 0.3
var zoom_sensitivity  : float = 0.5
var zoom_min          : float = 0.5
var zoom_max          : float = 20.0

# State
var _pivot       : Vector3  = Vector3.ZERO
var _distance    : float    = 3.0
var _yaw         : float    = 0.0
var _pitch       : float    = 25.0
var _dragging    : bool     = false

# Node ref
@onready var _viewport_container : SubViewportContainer = $"../../.."


func _ready() -> void:
	_apply_transform()


func _input(event: InputEvent) -> void:
	if not _mouse_in_viewport():
		_dragging = false
		return
		
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
			
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_distance = clampf(_distance - zoom_sensitivity, zoom_min, zoom_max)
			_apply_transform()

		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_distance = clampf(_distance + zoom_sensitivity, zoom_min, zoom_max)
			_apply_transform()
			
	elif event is InputEventMouseMotion and _dragging:
		_yaw   -= event.relative.x * orbit_sensitivity
		_pitch += event.relative.y * orbit_sensitivity
		_pitch  = clampf(_pitch, -89.0, 89.0)  # prevent gimbal flip
		_apply_transform()


# Recalculate camera position and orientation from spherical coords
func _apply_transform() -> void:
	var yaw_rad   := deg_to_rad(_yaw)
	var pitch_rad := deg_to_rad(_pitch)

	# Spherical -> offset from pivot
	var offset := Vector3(
		_distance * cos(pitch_rad) * sin(yaw_rad),
		_distance * sin(pitch_rad),
		_distance * cos(pitch_rad) * cos(yaw_rad)
	)

	global_position = _pivot + offset
	look_at(_pivot, Vector3.UP)

func _mouse_in_viewport() -> bool:
	if _viewport_container == null:
		return false
	var mouse_pos  : Vector2 = _viewport_container.get_viewport().get_mouse_position()
	var rect       : Rect2   = _viewport_container.get_global_rect()
	return rect.has_point(mouse_pos)

## Re-center the orbit pivot on a given world position
func set_pivot(new_pivot: Vector3) -> void:
	_pivot = new_pivot
	_apply_transform()

## Reset to default view distance
func reset_view(distance: float = 3.0) -> void:
	_distance = distance
	_yaw      = 0.0
	_pitch    = 25.0
	_apply_transform()
