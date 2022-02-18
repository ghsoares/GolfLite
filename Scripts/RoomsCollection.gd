extends Node2D

# Rooms variables
var rooms   := []

# Room possibilities
var possibilities   := []

# Internal init
func _enter_tree() -> void:
    # Hide self
    hide()

    _init_all_rooms()

# Room functions
func _init_all_rooms() -> void:
    # Get collection root node
    var collection_root := get_node("Collection")

    # Iterate collection children
    for room in collection_root.get_children():
        _init_room(room)
    
    # Remove collection root to avoid interaction with other objects
    remove_child(collection_root)
    
func _init_room(room: Node2D) -> void:
    # Skip room if not visible
    if !room.visible: return

    # Grab room tilemap
    var tilemap := room.get_node("Tilemap") as TileMap

    # Grab room bitmask
    var bitmask := room.get_node("Bitmask") as TileMap
    
    # Connection bitmaps
    var btm_l    := []
    var btm_t    := []
    var btm_r    := []
    var btm_b    := []

    # Pass foreach connection tile
    for i in range(16):
        # Get each side tile
        var tile_l  := bitmask.get_cell(0, 15 - i)
        var tile_t  := bitmask.get_cell(i, 0)
        var tile_r  := bitmask.get_cell(15, i)
        var tile_b  := bitmask.get_cell(15 - i, 15)

        # Set each bitmap
        btm_l.append(tile_l)
        btm_t.append(tile_t)
        btm_r.append(tile_r)
        btm_b.append(tile_b)

    # Create room info
    var info    := {
        "name": room.name,
        "node": room,
        "tilemap": tilemap,
        "bitmasks": [btm_l, btm_t, btm_r, btm_b],
        "id": rooms.size()
    }

    # Add room info
    rooms.append(info)

    # Add possibilities, but only if isn't the first room (air)
    # FlipX(2) * Rotation(4) = 8
    #if info.id != 0:
    for i in range(8):
        possibilities.append({
            "room_id": info.id,
            "state":   i
        })

func get_room_bitmask(room_info: Dictionary, state: int, side: int) -> Array:
    # Flip x from state
    var flip_x  := (state & 0b001) > 0

    # Rotation from state
    var rot     := (state & 0b110) >> 1

    # Rotate side index
    side = ((side - rot) % 4 + 4) % 4

    # Swap side if flip x
    if flip_x:
        if side == 0: side = 2
        elif side == 2: side = 0

    # Return bitmask
    return [room_info.bitmasks[side], flip_x]

func bitmasks_match(btm1: Array, btm2: Array, invert1: bool, invert2: bool) -> bool:
    # Bitmask has length of 16
    for i in range(16):
        # Grab indexes
        var i1  := i
        var i2  := 15 - i

        i1 = 15 - i1 if invert1 else i1
        i2 = 15 - i2 if invert2 else i2

        # Grab values
        var v1  := btm1[i1] as int
        var v2  := btm2[i2] as int

        # If different, return false
        if v1 != v2: return false
    return true

func rooms_match(room1: Dictionary, room2: Dictionary, state1: int, state2: int, side: int) -> bool:
    # Get other side
    var side2   := (side + 2) % 4

    # Grab bitmasks
    var btm1    := get_room_bitmask(room1, state1, side)
    var btm2    := get_room_bitmask(room2, state2, side2)

    # Match bitmasks
    return bitmasks_match(btm1[0], btm2[0], btm1[1], btm2[1])

func get_num_rooms() -> int: return rooms.size()

func get_num_possibilities() -> int: return possibilities.size()

func get_room_info(id: int) -> Dictionary: return rooms[id]

func get_possibility_room_info(id: int) -> Dictionary:
    return possibilities[id]











    
