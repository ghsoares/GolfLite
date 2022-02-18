extends Node2D

# Room variables
var added_rooms	        := {}
var possible_rooms      := {}
var level_bounds_min    := Vector2.ONE
var level_bounds_max    := Vector2.ONE
var generation_coroutine 
var generation_delay    := 0.0
var generated           := false

# Tilemap variables
onready var tilemap	:= $Tilemap as TileMap

# Grass variables
onready var grass   := $Grass as Control

# Level settings
export var level_size  := 8

# Internal init
func _ready() -> void:
    randomize()

# Internal processing
func _process(_delta: float) -> void:
    if Input.is_action_just_pressed("ui_accept"):
        generation_coroutine = _generate_level()
    
    if generation_coroutine:
        generation_delay += _delta
        while generation_delay >= .1:
            generation_coroutine = generation_coroutine.resume()
            generation_delay -= .025
            if generated:
                generation_coroutine = null
                print("Finished")
                break

# Room utility functions
func _rotate_cell(flip_x: bool, flip_y: bool, transpose: bool, steps: int) -> Dictionary:
    # Based on https://github.com/godotengine/godot/blob/0ea54d07f29e9813a368ca6858aa38a6139385dc/editor/plugins/tile_map_editor_plugin.cpp#L1853

    var normal_rotation_matrix = [
        [0, 0, 0],
        [1, 1, 0],
        [0, 1, 1],
        [1, 0, 1]
    ]
    var mirrored_rotation_matrix = [
        [0, 1, 0],
        [1, 1, 1],
        [0, 0, 1],
        [1, 0, 0]
    ]

    # Convert bool to int, as bitwise^ only works with int
    var fx  := int(flip_x)
    var fy  := int(flip_y)
    var tr  := int(transpose)

    if tr ^ fx ^ fy:
        # Odd number of flags activated = mirrored rotation
        for i in range(4):
            if tr == mirrored_rotation_matrix[i][0] and fx == mirrored_rotation_matrix[i][1] and fy == mirrored_rotation_matrix[i][2]:
                var new_id  := ((i + steps) % 4 + 4) % 4
                tr = mirrored_rotation_matrix[new_id][0]
                fx = mirrored_rotation_matrix[new_id][1]
                fy = mirrored_rotation_matrix[new_id][2]
                break
    else:
        # Even number of flags activated = normal rotation
        for i in range(4):
            if tr == normal_rotation_matrix[i][0] and fx == normal_rotation_matrix[i][1] and fy == normal_rotation_matrix[i][2]:
                var new_id  := ((i + steps) % 4 + 4) % 4
                tr = normal_rotation_matrix[new_id][0]
                fx = normal_rotation_matrix[new_id][1]
                fy = normal_rotation_matrix[new_id][2]
                break

    return {
        "flip_x": bool(fx),
        "flip_y": bool(fy),
        "transpose": bool(tr)
    }

func _pos_key(pos_x: int, pos_y: int) -> int:
    var hashc    := 17
    hashc = hashc * 31 + pos_x
    hashc = hashc * 31 + pos_y

    return hashc

# Level generation functions
func _generate_level() -> void:
    level_bounds_min = Vector2.ONE *  9999999999
    level_bounds_max = Vector2.ONE * -9999999999

    generated = false

    added_rooms.clear()
    possible_rooms.clear()
    tilemap.clear()

    # Create start room
    _create_start_room()

    # While there's possible rooms
    while possible_rooms.size() > 0:
        yield()
        _collapse_best_room()

    # Update dirty quadrants
    tilemap.update_dirty_quadrants()

    generated = true

func _create_start_room() -> void:
    _add_room(0, 0b000,  0,  0) 
    _add_room(4, 0b000,  0, -1) 
    _add_room(4, 0b010,  1,  0) 
    _add_room(4, 0b100,  0,  1) 
    _add_room(4, 0b110, -1,  0) 
    _add_room(3, 0b000, -1, -1) 
    _add_room(3, 0b010,  1, -1) 
    _add_room(3, 0b100,  1,  1) 
    _add_room(3, 0b110, -1,  1) 

func _add_room(id: int, state: int, pos_x: int, pos_y: int) -> void:
    print(pos_x, ", ", pos_y, ": ", id, " - ", state)

    # Grab room info
    var info    := RoomsCollection.get_room_info(id)

    # Apply tilemap, but only if the room isn't a closed box
    #if id != 1:
    _room_apply_tilemap(info, state, pos_x, pos_y)

    # Get room pos key
    var r_pos   := _pos_key(pos_x, pos_y)

    # Add room to added rooms
    added_rooms[r_pos] = {
        "id": id,
        "state": state,
        "pos_x": pos_x,
        "pos_y": pos_y
    }

    # Remove the room from possible rooms
    # warning-ignore:RETURN_VALUE_DISCARDED
    possible_rooms.erase(r_pos)

    # Evaluate neighbour rooms
    _evalulate_neighbour_room(info, state, pos_x, pos_y, 0)
    _evalulate_neighbour_room(info, state, pos_x, pos_y, 1)
    _evalulate_neighbour_room(info, state, pos_x, pos_y, 2)
    _evalulate_neighbour_room(info, state, pos_x, pos_y, 3)

    update()

    # Update bounds
    level_bounds_min.x = min(level_bounds_min.x, (pos_x * 512 - 256))
    level_bounds_max.x = max(level_bounds_max.x, (pos_x * 512 + 256))
    level_bounds_min.y = min(level_bounds_min.y, (pos_y * 512 - 256))
    level_bounds_max.y = max(level_bounds_max.y, (pos_y * 512 + 256))

    # Set grass rect
    grass.rect_position = level_bounds_min
    grass.rect_size     = level_bounds_max - level_bounds_min

func _room_apply_tilemap(info: Dictionary, state: int, pos_x: int, pos_y: int) -> void:
    # Grab room tilemap
    var room_tilemap	:= info.tilemap as TileMap

    # Flip x from state
    var flip_x  := (state & 0b001) > 0

    # Rotation from state
    var rot     := (state & 0b110) >> 1

    # Pass for each room tile
    for x in range(16):
        for y in range(16):
            # Tile pos
            var tile_x     := x - 7.5
            var tile_y     := y - 7.5

            # Rotate
            for _r in range(rot):
                var temp    := tile_x
                tile_x      = tile_y
                tile_y      = -temp
            
            # Flip x
            if flip_x: tile_x *= -1
            
            # Normalize tile pos
            tile_x += 7.5
            tile_y += 7.5

            # Tile pos in room
            var r_x := int(tile_x)
            var r_y := int(tile_y)

            # Tile pos in world
            var w_x     := x - 8 + pos_x * 16
            var w_y     := y - 8 + pos_y * 16

            # Grab cell id
            var cell_id         := room_tilemap.get_cell(r_x, r_y)

            # It's air, skip it
            if cell_id == -1: continue

            # Grab cell flipped x
            var cell_flipped_x  := room_tilemap.is_cell_x_flipped(r_x, r_y)

            # Grab cell flipped y
            var cell_flipped_y  := room_tilemap.is_cell_y_flipped(r_x, r_y)

            # Grab cell transposed
            var cell_transposed := room_tilemap.is_cell_transposed(r_x, r_y) 

            # First flip x
            if flip_x: cell_flipped_x = !cell_flipped_x

            # If room has rotation, apply transformation
            if rot != 0:
                var transformed := _rotate_cell(cell_flipped_x, cell_flipped_y, cell_transposed, rot)
                cell_flipped_x = transformed.flip_x
                cell_flipped_y = transformed.flip_y
                cell_transposed = transformed.transpose

            # Set world tile
            tilemap.set_cell(
                w_x, w_y,
                cell_id, cell_flipped_x, cell_flipped_y,
                cell_transposed
            )

func _evalulate_neighbour_room(info: Dictionary, state: int, pos_x: int, pos_y: int, side: int) -> void:
    # Neighbour pos
    var npos_x  := pos_x
    var npos_y  := pos_y

    # Match side
    match side:
        # Left
        0: npos_x -= 1
        # Top
        1: npos_y -= 1
        # Right
        2: npos_x += 1
        # Bottom
        3: npos_y += 1
    
    # If is out of bounds, just return
    if npos_x < -level_size || npos_x > level_size: return
    if npos_y < -level_size || npos_y > level_size: return

    # Get neighbour pos key
    var npos_k  := _pos_key(npos_x, npos_y)

    # Check if neighbour don't exist in the added rooms
    if not added_rooms.has(npos_k):
        # Grab the neighbour
        var nroom   := possible_rooms.get(npos_k, {}) as Dictionary
        
        # Didn't find the neighbour room, so create one
        if nroom.empty():
            nroom = _create_possible_room(npos_x, npos_y)
        
        # Evaluate possible room and eliminate the possibilities
        _evaluate_possible_room(nroom, info, state, side)

        # If number of possibilities in the neighbour is zero, remove it
        if nroom.possibilities.size() == 0:
            # warning-ignore:RETURN_VALUE_DISCARDED
            possible_rooms.erase(npos_k)

func _evaluate_possible_room(p_room: Dictionary, f_room: Dictionary, state: int, side: int) -> void:
    # Pass foreach possibility
    var possibilities   := p_room.possibilities as Array
    var i   := possibilities.size() - 1
    while i >= 0:
        # Grab room id
        var p_id    := possibilities[i] as int

        # Grab possibility info
        var p_info  := RoomsCollection.get_possibility_room_info(p_id) as Dictionary
    
        # Grab room info
        var r_info  := RoomsCollection.get_room_info(p_info.room_id)
    
        # Grab room state
        var r_state := p_info.state as int

        # Check if rooms match
        var matches := RoomsCollection.rooms_match(f_room, r_info, state, r_state, side) as bool

        # If don't, eliminate the possibility
        if !matches:
            possibilities.remove(i)

        # Go backwards
        i -= 1

func _create_possible_room(pos_x: int, pos_y: int) -> Dictionary:
    # Create a list of possibility indexes
    var p_room := {
        "possibilities": range(RoomsCollection.get_num_possibilities()),
        "pos_x": pos_x,
        "pos_y": pos_y
    }

    # Add it to possible rooms
    possible_rooms[_pos_key(pos_x, pos_y)] = p_room

    # Return it
    return p_room

func _collapse_best_room() -> void:
    if possible_rooms.size() == 0: return

    # Get the best room, the room with less possibilities
    var best_r  := {}
    var best_l  := 999999999999999

    # Pass for each possible room
    for p_room in possible_rooms.values():
        # Get the number of possibilities
        var l   := p_room.possibilities.size() as int

        # Is better
        if l < best_l:
            best_r = p_room
            best_l = l
        
    # Collapse the best room
    _collapse_possible_room(best_r.possibilities, best_r.pos_x, best_r.pos_y)

func _collapse_possible_room(p_room: Array, pos_x: int, pos_y: int) -> void:
    # Grab a random id
    var p_id    := randi() % p_room.size()

    # If the id is a closed box, reduce the chance to use it
    if p_id == 1 and p_room.size() > 2:
        var r   := randf()
        if r <= 0.75:
            while p_id == 1:
                p_id = randi() % p_room.size()
    
    # Grab possibility info
    var p_info  := RoomsCollection.get_possibility_room_info(p_room[p_id]) as Dictionary

    # Grab room state
    var r_state := p_info.state as int

    # Add room
    _add_room(p_info.room_id, r_state, pos_x, pos_y)

