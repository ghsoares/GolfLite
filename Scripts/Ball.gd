extends KinematicBody2D

class_name Ball

# Velocity variables
var velocity := Vector2.ZERO
var motion := Vector2.ZERO

# Physics settings
export var mass := 1.0

# Velocity settings
export var velocity_stop_threshold  := 0.1
export var velocity_max_bounces     := 4

# Internal init
func _ready() -> void:
    var club    := Club.new()
    club.max_force = 320.0 * 2.0

    tuck(club, 180.0, 1.0)
    tuck(club, 45.0, 1.0)

# Internal processing
func _physics_process(delta: float) -> void:
    _apply_forces(delta)
    _move(delta)

# Movement function
func _apply_forces(delta: float) -> void:
    # Calculate drag
    var drag := 100.0

    # Get velocity magnitude
    var mag := velocity.length()

    # Get velocity direction
    var dir := velocity.normalized()

    # Calculate drag force
    var drag_force := min(mag, drag * delta)

    # Apply drag force
    velocity -= dir * drag_force

func _move(delta: float) -> void:
    # Don't move if velocity is less than threshold
    if velocity.length_squared() <= velocity_stop_threshold * velocity_stop_threshold: return
    
    # Calculate motion
    motion = velocity * delta
    
    # Move and bounce kinematic body
    for _i in range(velocity_max_bounces):
        # Move and collide using motion
        var col := move_and_collide(motion, false)

        # Bounce motion and velocity
        if col:
            # Collider is static
            if col.collider is StaticBody2D or col.collider is TileMap:
                _resolve_static_collision(col)
            # Collider is rigidbody
            elif col.collider is RigidBody2D:
                _resolve_rigidbody_collision(col)
            # Collider is ball
            elif col.collider.get_class() == "Ball":
                _resolve_ball_collision(col)
            
        # Finish movement
        else:
            break

func _resolve_static_collision(col: KinematicCollision2D) -> void:
    # Subtract the remainder from the motion
    motion -= col.remainder

    # Motion bounce
    motion = motion.bounce(col.normal)

    # Velocity bounce
    velocity = velocity.bounce(col.normal)

func _resolve_rigidbody_collision(col: KinematicCollision2D) -> void:
    # Subtract the remainder from the motion
    motion -= col.remainder

    # Calculate relative velocity
    var rv := (velocity - col.collider.linear_velocity) as Vector2
 
    # Calculate relative velocity in terms of the normal direction
    var vel_along_normal := rv.dot(col.normal)
 
    # Do not resolve if velocities are separating
    if vel_along_normal > 0: return
 
    # Calculate impulse
    var impulse := vel_along_normal * col.normal
    impulse /= (1.0 / mass) + (1.0 / col.collider.mass)

    # Apply impulse
    velocity -= (1.0 / mass) * impulse
    col.collider.apply_impulse(col.position - col.collider.global_position, (1.0 / col.collider.mass) * impulse)

func _resolve_ball_collision(col: KinematicCollision2D) -> void:
    # Subtract the remainder from the motion
    motion -= col.remainder

    # Calculate relative velocity
    var rv := (velocity - col.collider.velocity) as Vector2
 
    # Calculate relative velocity in terms of the normal direction
    var vel_along_normal := rv.dot(col.normal)
 
    # Do not resolve if velocities are separating
    if vel_along_normal > 0: return
 
    # Calculate impulse
    var impulse := vel_along_normal * col.normal
    impulse /= (1.0 / mass) + (1.0 / col.collider.mass)

    # Apply impulse
    velocity -= (1.0 / mass) * impulse
    col.collider.velocity += (1.0 / col.collider.mass) * impulse

# Tuck functions
func tuck(club: Club, direction: float, force_mult: float) -> void:
    # Calculate angle
    var ang := deg2rad(direction)

    # Calculate dir
    var dir := Vector2(cos(ang), sin(ang))

    # Calculate velocity along dir
    var dir_vel := dir.dot(velocity)

    # Calculate force
    var force   := max(dir_vel, club.max_force * force_mult)

    # Set velocity
    velocity    = dir * force

# Overrides
func get_class() -> String: return "Ball"




