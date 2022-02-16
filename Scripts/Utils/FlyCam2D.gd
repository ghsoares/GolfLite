extends Camera2D

class_name FlyCam2D

# Input variables
var dragging	:= false

# Zoom variables
var curr_zoom	:= 1.0

# Position variables
var curr_position := Vector2.ZERO

# Input settings
export var zoom_sensitivity		:= 1.0
export var move_sensitivity		:= 1.0

# Zoom settings
export var zoom_range	:= Vector2(0.1, 10.0)
export var zoom_lerp	:= 8.0

# Position settings
export var move_lerp	:= 8.0

# Internal init
func _ready() -> void:
	# Set zoom and position
	curr_zoom = zoom.x
	curr_position = global_position

# Input handling
func _input(event: InputEvent) -> void:
	# Start/end dragging and zoom
	if event is InputEventMouseButton:
		# Drag
		if event.button_index == BUTTON_LEFT:
			dragging = event.pressed
		# Zoom
		if event.button_index == BUTTON_WHEEL_UP:
			if event.pressed: curr_zoom -= zoom_sensitivity
		elif event.button_index == BUTTON_WHEEL_DOWN:
			if event.pressed: curr_zoom += zoom_sensitivity

	# Dragging
	if event is InputEventMouseMotion:
		if dragging:
			var rel	:= (event.relative * move_sensitivity) as Vector2
			curr_position -= rel * curr_zoom
	
	# Clamp current zoom
	curr_zoom = clamp(curr_zoom, zoom_range.x, zoom_range.y)

# Internal processing
func _physics_process(delta: float) -> void:
	# Interpolation weights
	var zoom_t	:= clamp(delta * zoom_lerp, 0.0, 1.0)
	var pos_t	:= clamp(delta * move_lerp, 0.0, 1.0)

	# Interpolate zoom
	zoom = zoom.linear_interpolate(
		Vector2.ONE * curr_zoom, zoom_t
	)

	# Interpolate position
	global_position = global_position.linear_interpolate(
		curr_position, pos_t
	)