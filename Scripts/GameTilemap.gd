extends TileMap

# Shadow variables
onready var shadow  := $Shadow as TileMap

# Internal init
func _ready() -> void:
    _init_shadow()

# Shadow functions
func _init_shadow() -> void:
    # Grab cell positions
    var cell_positions  := get_used_cells()

    # Grab hole ids, ignore shadow
    var hole_ids   := [
        tile_set.find_tile_by_name("HoleTop"),
        tile_set.find_tile_by_name("HoleBottom")
    ]
    
    # Pass foreach cell
    for cell_pos in cell_positions:
        # Get cell id
        var cell_id := get_cell(cell_pos.x, cell_pos.y)

        # Ignore shadow
        if cell_id in hole_ids: continue

        # Cell flipped x
        var cell_flip_x := is_cell_x_flipped(cell_pos.x, cell_pos.y)

        # Cell flipped y
        var cell_flip_y := is_cell_y_flipped(cell_pos.x, cell_pos.y)

        # Cell transposed
        var cell_transpose  := is_cell_transposed(cell_pos.x, cell_pos.y)

        # Set cell in shadow
        shadow.set_cell(cell_pos.x, cell_pos.y, cell_id, cell_flip_x, cell_flip_y, cell_transpose)
        
