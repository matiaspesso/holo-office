extends Node2D
class_name GameWorld

signal cell_clicked(cell: Vector2i)
signal drag_completed(mode_name: String, start_cell: Vector2i, end_cell: Vector2i)
signal character_clicked(character_node: SimCharacter)
signal right_clicked(cell: Vector2i, screen_position: Vector2)

const GRID_WIDTH := 40
const GRID_HEIGHT := 30
const CELL_SIZE := 128
const WORLD_ORIGIN := Vector2.ZERO
const WORLD_BACKGROUND := Color("1b2230")
const GRID_COLOR := Color(1, 1, 1, 0.06)
const FLOOR_COLOR := Color("5d748e")
const WALL_COLOR := Color("2a3548")
const DOOR_COLOR := Color("9f6a3d")
const OFFICE_TINT := Color("4da3ff")
const BATHROOM_TINT := Color("5dd39e")
const STORAGE_TINT := Color("ffbe5c")
const RECORDING_TINT := Color("ff7aa8")
const SHOP_TINT := Color("ffd86b")
const CHAIR_COLOR := Color("d6c2a1")
const TABLE_COLOR := Color("8a6239")
const WALL_PAD_COLOR := Color("5b4f67")
const SHELF_COLOR := Color("b77f36")
const DROPPOINT_COLOR := Color("6ed0ff")
const CHECKOUT_COLOR := Color("e96f6f")
const BLUEPRINT_TINT := Color(0.6, 0.85, 1.0, 0.45)
const DIRT_TINT := Color(0.38, 0.28, 0.16, 0.5)

@onready var furniture: Node2D = $Furniture
@onready var characters: Node2D = $Characters

var grid: Dictionary = {}
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var navigation: AStarGrid2D = AStarGrid2D.new()
var current_tool_mode: String = "none"
var drag_start_cell: Vector2i = Vector2i(-1, -1)
var drag_current_cell: Vector2i = Vector2i(-1, -1)
var is_dragging: bool = false
var blueprint_cells: Array[Vector2i] = []
var blueprint_lookup: Dictionary = {}
var redraw_pending: bool = false


func _ready() -> void:
	rng.randomize()
	_configure_navigation()
	request_world_redraw()


func reset_world() -> void:
	grid.clear()
	blueprint_cells.clear()
	blueprint_lookup.clear()
	redraw_pending = false
	for child in characters.get_children():
		child.queue_free()
	for child in furniture.get_children():
		child.queue_free()
	_configure_navigation()
	request_world_redraw()


func seed_rooms() -> void:
	make_room(Rect2i(4, 4, 8, 6), "office")
	make_room(Rect2i(15, 4, 5, 5), "bathroom")
	make_room(Rect2i(22, 4, 6, 5), "storage")
	_rebuild_navigation()
	request_world_redraw()


func make_room(rect: Rect2i, designation: String) -> void:
	for y in range(rect.size.y):
		for x in range(rect.size.x):
			var cell: Vector2i = Vector2i(rect.position.x + x, rect.position.y + y)
			var is_border: bool = x == 0 or y == 0 or x == rect.size.x - 1 or y == rect.size.y - 1
			if is_border:
				grid[cell] = _make_tile(false, true, false, "")
			else:
				grid[cell] = _make_tile(true, false, false, designation)
	var door_cell: Vector2i = Vector2i(rect.position.x + int(rect.size.x / 2), rect.position.y + rect.size.y - 1)
	grid[door_cell] = _make_tile(true, false, true, designation)


func _draw() -> void:
	var world_rect: Rect2 = Rect2(WORLD_ORIGIN, Vector2(GRID_WIDTH * CELL_SIZE, GRID_HEIGHT * CELL_SIZE))
	draw_rect(world_rect, WORLD_BACKGROUND, true)
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			var cell: Vector2i = Vector2i(x, y)
			var cell_rect: Rect2 = Rect2(WORLD_ORIGIN + Vector2(x * CELL_SIZE, y * CELL_SIZE), Vector2(CELL_SIZE, CELL_SIZE))
			var tile: Dictionary = grid.get(cell, _make_tile())
			if bool(tile.get("floor", false)):
				draw_rect(cell_rect.grow(-2), FLOOR_COLOR, true)
				var designation: String = String(tile.get("designation", ""))
				if designation == "office":
					draw_rect(cell_rect.grow(-6), OFFICE_TINT, true)
				elif designation == "bathroom":
					draw_rect(cell_rect.grow(-6), BATHROOM_TINT, true)
				elif designation == "storage":
					draw_rect(cell_rect.grow(-6), STORAGE_TINT, true)
				elif designation == "recording_booth":
					draw_rect(cell_rect.grow(-6), RECORDING_TINT, true)
				elif designation == "shop":
					draw_rect(cell_rect.grow(-6), SHOP_TINT, true)
			if bool(tile.get("wall", false)):
				draw_rect(cell_rect.grow(-1), WALL_COLOR, true)
				if bool(tile.get("wall_pad", false)):
					draw_rect(cell_rect.grow(-12), WALL_PAD_COLOR, true)
			elif bool(tile.get("door", false)):
				draw_rect(cell_rect.grow(-4), DOOR_COLOR, true)
			if bool(tile.get("chair", false)):
				draw_rect(cell_rect.grow(-8), CHAIR_COLOR, true)
				draw_rect(cell_rect.grow(-8), Color(0.22, 0.16, 0.08), false, 1.5)
			if bool(tile.get("table", false)):
				draw_rect(cell_rect.grow(-18), TABLE_COLOR, true)
				draw_rect(cell_rect.grow(-18), Color(0.19, 0.11, 0.05), false, 1.5)
			if bool(tile.get("shelf", false)):
				draw_rect(cell_rect.grow(-16), SHELF_COLOR, true)
				var shelf_ratio: float = float(tile.get("merch_stock", 0)) / maxf(1.0, float(tile.get("merch_capacity", 1)))
				draw_rect(Rect2(cell_rect.position + Vector2(14, cell_rect.size.y - 24), Vector2((cell_rect.size.x - 28) * shelf_ratio, 10)), Color("fff2ad"), true)
			if bool(tile.get("droppoint", false)):
				draw_rect(cell_rect.grow(-20), DROPPOINT_COLOR, true)
			if bool(tile.get("checkout", false)):
				draw_rect(cell_rect.grow(-20), CHECKOUT_COLOR, true)
			var blueprint_type: String = String(tile.get("blueprint", ""))
			if blueprint_type != "":
				draw_rect(cell_rect.grow(-5), BLUEPRINT_TINT, true)
				draw_rect(cell_rect.grow(-5), Color(0.8, 0.94, 1.0, 0.85), false, 1.5)
			var dirt_value: float = float(tile.get("dirt", 0.0))
			if dirt_value > 0.0:
				draw_rect(cell_rect.grow(-10), DIRT_TINT * Color(1.0, 1.0, 1.0, minf(1.0, dirt_value / 100.0)), true)
			draw_rect(cell_rect, GRID_COLOR, false, 1.0)
	if is_dragging and is_valid_cell(drag_start_cell) and is_valid_cell(drag_current_cell):
		var drag_rect: Rect2i = get_drag_rect(drag_start_cell, drag_current_cell)
		var preview_origin: Vector2 = WORLD_ORIGIN + Vector2(drag_rect.position.x * CELL_SIZE, drag_rect.position.y * CELL_SIZE)
		var preview_size: Vector2 = Vector2(drag_rect.size.x * CELL_SIZE, drag_rect.size.y * CELL_SIZE)
		var preview_rect: Rect2 = Rect2(preview_origin, preview_size)
		draw_rect(preview_rect, Color(1.0, 1.0, 1.0, 0.08), true)
		draw_rect(preview_rect, Color(1.0, 1.0, 1.0, 0.60), false, 2.0)


func _input(event: InputEvent) -> void:
	var hovered_control: Control = get_viewport().gui_get_hovered_control()
	if hovered_control != null and not is_dragging:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			is_dragging = false
			drag_start_cell = Vector2i(-1, -1)
			drag_current_cell = Vector2i(-1, -1)
			request_world_redraw()
			var right_click_cell: Vector2i = screen_to_cell(get_global_mouse_position())
			right_clicked.emit(right_click_cell, event.position)
			return
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		var world_mouse: Vector2 = get_global_mouse_position()
		var cell: Vector2i = screen_to_cell(world_mouse)
		if event.pressed:
			if hovered_control != null:
				return
			if _try_select_character(world_mouse):
				return
			if not is_valid_cell(cell):
				return
			if current_tool_mode == "door" or current_tool_mode == "chair" or current_tool_mode == "erase" or current_tool_mode == "table" or current_tool_mode == "wall_pad" or current_tool_mode == "shelf" or current_tool_mode == "droppoint" or current_tool_mode == "checkout":
				cell_clicked.emit(cell)
				return
			if current_tool_mode == "none":
				cell_clicked.emit(cell)
				return
			is_dragging = true
			drag_start_cell = cell
			drag_current_cell = cell
			request_world_redraw()
		else:
			if not is_dragging:
				return
			is_dragging = false
			if is_valid_cell(cell):
				drag_current_cell = cell
			request_world_redraw()
			if current_tool_mode != "none" and is_valid_cell(drag_start_cell) and is_valid_cell(drag_current_cell):
				drag_completed.emit(current_tool_mode, drag_start_cell, drag_current_cell)
			drag_start_cell = Vector2i(-1, -1)
			drag_current_cell = Vector2i(-1, -1)
	elif event is InputEventMouseMotion and is_dragging:
		var hover_cell: Vector2i = screen_to_cell(get_global_mouse_position())
		if is_valid_cell(hover_cell):
			drag_current_cell = hover_cell
			request_world_redraw()


func _try_select_character(mouse_position: Vector2) -> bool:
	for child in characters.get_children():
		var character: SimCharacter = child as SimCharacter
		if character != null and character.global_position.distance_to(mouse_position) <= 18.0:
			character_clicked.emit(character)
			return true
	return false


func screen_to_cell(point: Vector2) -> Vector2i:
	var local_point: Vector2 = point - global_position - WORLD_ORIGIN
	return Vector2i(floor(local_point.x / CELL_SIZE), floor(local_point.y / CELL_SIZE))


func is_valid_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < GRID_WIDTH and cell.y < GRID_HEIGHT


func cell_center(cell: Vector2i) -> Vector2:
	return global_position + WORLD_ORIGIN + Vector2(cell.x * CELL_SIZE + CELL_SIZE / 2.0, cell.y * CELL_SIZE + CELL_SIZE / 2.0)


func set_tool_mode(mode_name: String) -> void:
	current_tool_mode = mode_name
	if mode_name == "none":
		is_dragging = false
		drag_start_cell = Vector2i(-1, -1)
		drag_current_cell = Vector2i(-1, -1)
		request_world_redraw()


func get_random_walkable_cell() -> Vector2i:
	var walkable: Array[Vector2i] = []
	for cell_variant in grid.keys():
		var cell: Vector2i = cell_variant
		if is_cell_walkable(cell):
			walkable.append(cell)
	if walkable.is_empty():
		return Vector2i(5, 5)
	return walkable[rng.randi_range(0, walkable.size() - 1)]


func add_character(character_scene: PackedScene, display_name: String, kind: String, texture_path: String, label_color: Color) -> SimCharacter:
	var node: SimCharacter = character_scene.instantiate() as SimCharacter
	characters.add_child(node)
	var texture: Texture2D = load(texture_path) as Texture2D
	node.position = cell_center(get_random_walkable_cell())
	node.configure(display_name, kind, texture, label_color)
	return node


func set_character_selected(target: SimCharacter) -> void:
	for child in characters.get_children():
		var character: SimCharacter = child as SimCharacter
		if character != null:
			character.set_selected(character == target)


func assign_character_destination(character: SimCharacter, target_cell: Vector2i) -> void:
	var start_cell: Vector2i = get_character_cell(character)
	var resolved_target: Vector2i = get_nearest_walkable_cell(target_cell)
	if not is_valid_cell(start_cell) or not is_valid_cell(resolved_target):
		return
	var path_cells: Array[Vector2i] = get_path_cells(start_cell, resolved_target)
	if path_cells.is_empty():
		return
	var path_points: Array[Vector2] = []
	for index in range(1, path_cells.size()):
		path_points.append(cell_center(path_cells[index]))
	character.set_path(path_points)


func get_character_cell(character: SimCharacter) -> Vector2i:
	var approx_cell: Vector2i = screen_to_cell(character.global_position)
	if is_cell_walkable(approx_cell):
		return approx_cell
	return get_nearest_walkable_cell(approx_cell)


func get_nearest_walkable_cell(origin_cell: Vector2i) -> Vector2i:
	if is_cell_walkable(origin_cell):
		return origin_cell
	var best_cell: Vector2i = Vector2i(-1, -1)
	var best_distance: int = 999999
	for cell_variant in grid.keys():
		var cell: Vector2i = cell_variant
		if not is_cell_walkable(cell):
			continue
		var distance: int = absi(cell.x - origin_cell.x) + absi(cell.y - origin_cell.y)
		if distance < best_distance:
			best_distance = distance
			best_cell = cell
	return best_cell


func is_cell_walkable(cell: Vector2i) -> bool:
	if not is_valid_cell(cell):
		return false
	var tile: Dictionary = grid.get(cell, _make_tile())
	return bool(tile.get("floor", false)) and not bool(tile.get("wall", false))


func is_room_interior_cell(cell: Vector2i) -> bool:
	if not is_valid_cell(cell):
		return false
	var tile: Dictionary = grid.get(cell, _make_tile())
	return bool(tile.get("floor", false)) and not bool(tile.get("wall", false)) and not bool(tile.get("door", false))


func get_path_cells(start_cell: Vector2i, end_cell: Vector2i) -> Array[Vector2i]:
	if not is_cell_walkable(start_cell) or not is_cell_walkable(end_cell):
		return []
	var point_path: Array[Vector2i] = navigation.get_id_path(start_cell, end_cell)
	return point_path


func get_drag_rect(start_cell: Vector2i, end_cell: Vector2i) -> Rect2i:
	var min_x: int = mini(start_cell.x, end_cell.x)
	var min_y: int = mini(start_cell.y, end_cell.y)
	var max_x: int = maxi(start_cell.x, end_cell.x)
	var max_y: int = maxi(start_cell.y, end_cell.y)
	return Rect2i(Vector2i(min_x, min_y), Vector2i(max_x - min_x + 1, max_y - min_y + 1))


func designate_rect(designation: String, start_cell: Vector2i, end_cell: Vector2i) -> bool:
	var drag_rect: Rect2i = get_drag_rect(start_cell, end_cell)
	if not _can_designate_rect(drag_rect):
		return false
	for y in range(drag_rect.position.y, drag_rect.end.y):
		for x in range(drag_rect.position.x, drag_rect.end.x):
			var cell: Vector2i = Vector2i(x, y)
			var tile: Dictionary = grid.get(cell, _make_tile())
			tile["designation"] = designation
			grid[cell] = tile
	request_world_redraw()
	return true


func clear_designation_rect(start_cell: Vector2i, end_cell: Vector2i) -> void:
	var drag_rect: Rect2i = get_drag_rect(start_cell, end_cell)
	for y in range(drag_rect.position.y, drag_rect.end.y):
		for x in range(drag_rect.position.x, drag_rect.end.x):
			var cell: Vector2i = Vector2i(x, y)
			var tile: Dictionary = grid.get(cell, _make_tile())
			if bool(tile.get("floor", false)):
				tile["designation"] = ""
				grid[cell] = tile
	request_world_redraw()


func create_room_blueprints(start_cell: Vector2i, end_cell: Vector2i) -> Array[Vector2i]:
	var created: Array[Vector2i] = []
	var drag_rect: Rect2i = get_drag_rect(start_cell, end_cell)
	for y in range(drag_rect.position.y, drag_rect.end.y):
		for x in range(drag_rect.position.x, drag_rect.end.x):
			var cell: Vector2i = Vector2i(x, y)
			var is_border: bool = x == drag_rect.position.x or y == drag_rect.position.y or x == drag_rect.end.x - 1 or y == drag_rect.end.y - 1
			var blueprint_type: String = "wall" if is_border else "floor"
			var preferred_stand: Vector2i = Vector2i(-1, -1)
			if blueprint_type == "wall":
				preferred_stand = _get_room_wall_outside_cell(cell, drag_rect)
			if place_blueprint(blueprint_type, cell, true, preferred_stand):
				created.append(cell)
	if not created.is_empty():
		request_world_redraw()
	return created


func create_floor_blueprints(start_cell: Vector2i, end_cell: Vector2i) -> Array[Vector2i]:
	var created: Array[Vector2i] = []
	var drag_rect: Rect2i = get_drag_rect(start_cell, end_cell)
	for y in range(drag_rect.position.y, drag_rect.end.y):
		for x in range(drag_rect.position.x, drag_rect.end.x):
			var cell: Vector2i = Vector2i(x, y)
			if place_blueprint("floor", cell, true):
				created.append(cell)
	if not created.is_empty():
		request_world_redraw()
	return created


func place_blueprint(blueprint_type: String, cell: Vector2i, defer_redraw: bool = false, preferred_stand: Vector2i = Vector2i(-1, -1)) -> bool:
	if not is_valid_cell(cell):
		return false
	var tile: Dictionary = grid.get(cell, _make_tile())
	if blueprint_type == "chair":
		var designation: String = String(tile.get("designation", ""))
		if designation != "office" and designation != "recording_booth":
			return false
		if not bool(tile.get("floor", false)) or bool(tile.get("wall", false)) or bool(tile.get("door", false)) or bool(tile.get("chair", false)):
			return false
	if blueprint_type == "table":
		if String(tile.get("designation", "")) != "recording_booth":
			return false
		if not bool(tile.get("floor", false)) or bool(tile.get("wall", false)) or bool(tile.get("door", false)) or bool(tile.get("chair", false)) or bool(tile.get("table", false)):
			return false
	if blueprint_type == "wall_pad":
		if not bool(tile.get("wall", false)) or bool(tile.get("wall_pad", false)):
			return false
		if not _wall_adjacent_to_designation(cell, "recording_booth"):
			return false
	if blueprint_type == "shelf":
		if String(tile.get("designation", "")) != "shop":
			return false
		if not bool(tile.get("floor", false)) or bool(tile.get("wall", false)) or bool(tile.get("door", false)):
			return false
		if bool(tile.get("chair", false)) or bool(tile.get("table", false)) or bool(tile.get("shelf", false)) or bool(tile.get("checkout", false)) or bool(tile.get("droppoint", false)):
			return false
	if blueprint_type == "droppoint":
		if not bool(tile.get("floor", false)) or bool(tile.get("wall", false)) or bool(tile.get("door", false)):
			return false
		if bool(tile.get("chair", false)) or bool(tile.get("table", false)) or bool(tile.get("shelf", false)) or bool(tile.get("checkout", false)) or bool(tile.get("droppoint", false)):
			return false
	if blueprint_type == "checkout":
		if String(tile.get("designation", "")) != "shop":
			return false
		if not bool(tile.get("floor", false)) or bool(tile.get("wall", false)) or bool(tile.get("door", false)):
			return false
		if bool(tile.get("chair", false)) or bool(tile.get("table", false)) or bool(tile.get("shelf", false)) or bool(tile.get("checkout", false)) or bool(tile.get("droppoint", false)):
			return false
	tile["blueprint"] = blueprint_type
	tile["build_progress"] = 0.0
	tile["blueprint_stand"] = preferred_stand
	grid[cell] = tile
	_register_blueprint_cell(cell)
	if not defer_redraw:
		request_world_redraw()
	return true


func clear_cell(cell: Vector2i) -> bool:
	if not grid.has(cell):
		return false
	_unregister_blueprint_cell(cell)
	grid.erase(cell)
	request_world_redraw()
	_update_navigation_cell(cell)
	return true


func remove_chair(cell: Vector2i) -> bool:
	if not grid.has(cell):
		return false
	var tile: Dictionary = grid.get(cell, _make_tile())
	if not bool(tile.get("chair", false)):
		return false
	tile["chair"] = false
	grid[cell] = tile
	request_world_redraw()
	return true


func remove_table(cell: Vector2i) -> bool:
	if not grid.has(cell):
		return false
	var tile: Dictionary = grid.get(cell, _make_tile())
	if not bool(tile.get("table", false)):
		return false
	tile["table"] = false
	grid[cell] = tile
	request_world_redraw()
	return true


func remove_wall_pad(cell: Vector2i) -> bool:
	if not grid.has(cell):
		return false
	var tile: Dictionary = grid.get(cell, _make_tile())
	if not bool(tile.get("wall_pad", false)):
		return false
	tile["wall_pad"] = false
	grid[cell] = tile
	request_world_redraw()
	return true


func remove_shelf(cell: Vector2i) -> bool:
	if not grid.has(cell):
		return false
	var tile: Dictionary = grid.get(cell, _make_tile())
	if not bool(tile.get("shelf", false)):
		return false
	tile["shelf"] = false
	tile["merch_stock"] = 0
	grid[cell] = tile
	request_world_redraw()
	return true


func remove_droppoint(cell: Vector2i) -> bool:
	if not grid.has(cell):
		return false
	var tile: Dictionary = grid.get(cell, _make_tile())
	if not bool(tile.get("droppoint", false)):
		return false
	tile["droppoint"] = false
	tile["merch_stock"] = 0
	grid[cell] = tile
	request_world_redraw()
	return true


func remove_checkout(cell: Vector2i) -> bool:
	if not grid.has(cell):
		return false
	var tile: Dictionary = grid.get(cell, _make_tile())
	if not bool(tile.get("checkout", false)):
		return false
	tile["checkout"] = false
	grid[cell] = tile
	request_world_redraw()
	return true


func count_designation(designation: String) -> int:
	var total: int = 0
	for cell_variant in grid.keys():
		var cell: Vector2i = cell_variant
		if String(grid[cell].get("designation", "")) == designation:
			total += 1
	return total


func count_chairs_in_designation(designation: String) -> int:
	var total: int = 0
	for cell_variant in grid.keys():
		var cell: Vector2i = cell_variant
		var tile: Dictionary = grid[cell]
		if bool(tile.get("chair", false)) and String(tile.get("designation", "")) == designation:
			total += 1
	return total


func get_cells_in_designation(designation: String) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell_variant in grid.keys():
		var cell: Vector2i = cell_variant
		var tile: Dictionary = grid[cell]
		if String(tile.get("designation", "")) != designation:
			continue
		if bool(tile.get("floor", false)) and not bool(tile.get("wall", false)):
			result.append(cell)
	return result


func get_cells_with_chairs(designation: String = "") -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell_variant in grid.keys():
		var cell: Vector2i = cell_variant
		var tile: Dictionary = grid[cell]
		if not bool(tile.get("chair", false)):
			continue
		if designation != "" and String(tile.get("designation", "")) != designation:
			continue
		result.append(cell)
	return result


func get_cells_with_tables(designation: String = "") -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell_variant in grid.keys():
		var cell: Vector2i = cell_variant
		var tile: Dictionary = grid[cell]
		if not bool(tile.get("table", false)):
			continue
		if designation != "" and String(tile.get("designation", "")) != designation:
			continue
		result.append(cell)
	return result


func get_cells_with_feature(feature_name: String, designation: String = "") -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell_variant in grid.keys():
		var cell: Vector2i = cell_variant
		var tile: Dictionary = grid[cell]
		if not bool(tile.get(feature_name, false)):
			continue
		if designation != "" and String(tile.get("designation", "")) != designation:
			continue
		result.append(cell)
	return result


func get_room_anchor(start_cell: Vector2i, designation: String) -> Vector2i:
	var room_cells: Array[Vector2i] = get_designated_room_cells(start_cell, designation)
	if room_cells.is_empty():
		return Vector2i(-1, -1)
	var best_cell: Vector2i = room_cells[0]
	for cell in room_cells:
		if cell.y < best_cell.y or (cell.y == best_cell.y and cell.x < best_cell.x):
			best_cell = cell
	return best_cell


func room_key(cell: Vector2i, designation: String) -> String:
	var anchor: Vector2i = get_room_anchor(cell, designation)
	if anchor.x < 0:
		return ""
	return "%s:%s,%s" % [designation, anchor.x, anchor.y]


func get_blueprint_cells() -> Array[Vector2i]:
	return blueprint_cells.duplicate()


func get_dirty_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell_variant in grid.keys():
		var cell: Vector2i = cell_variant
		if float(grid[cell].get("dirt", 0.0)) > 0.0:
			result.append(cell)
	return result


func add_random_dirt(amount: float) -> void:
	var candidates: Array[Vector2i] = []
	for cell_variant in grid.keys():
		var cell: Vector2i = cell_variant
		if is_cell_walkable(cell):
			candidates.append(cell)
	if candidates.is_empty():
		return
	var target: Vector2i = candidates[rng.randi_range(0, candidates.size() - 1)]
	add_dirt(target, amount)


func add_dirt(cell: Vector2i, amount: float) -> void:
	if not grid.has(cell):
		return
	var tile: Dictionary = grid.get(cell, _make_tile())
	tile["dirt"] = clampf(float(tile.get("dirt", 0.0)) + amount, 0.0, 100.0)
	grid[cell] = tile
	request_world_redraw()


func reduce_dirt(cell: Vector2i, amount: float) -> void:
	if not grid.has(cell):
		return
	var tile: Dictionary = grid.get(cell, _make_tile())
	tile["dirt"] = maxf(0.0, float(tile.get("dirt", 0.0)) - amount)
	grid[cell] = tile
	request_world_redraw()


func get_dirt(cell: Vector2i) -> float:
	var tile: Dictionary = grid.get(cell, _make_tile())
	return float(tile.get("dirt", 0.0))


func get_blueprint_type(cell: Vector2i) -> String:
	var tile: Dictionary = grid.get(cell, _make_tile())
	return String(tile.get("blueprint", ""))


func get_blueprint_progress(cell: Vector2i) -> float:
	var tile: Dictionary = grid.get(cell, _make_tile())
	return float(tile.get("build_progress", 0.0))


func add_blueprint_progress(cell: Vector2i, amount: float) -> void:
	var tile: Dictionary = grid.get(cell, _make_tile())
	tile["build_progress"] = float(tile.get("build_progress", 0.0)) + amount
	grid[cell] = tile


func complete_blueprint(cell: Vector2i) -> void:
	if not grid.has(cell):
		return
	var tile: Dictionary = grid.get(cell, _make_tile())
	var blueprint_type: String = String(tile.get("blueprint", ""))
	match blueprint_type:
		"wall":
			tile = _make_tile(false, true, false, "")
		"floor":
			tile["floor"] = true
			tile["wall"] = false
			tile["door"] = false
		"door":
			tile["floor"] = true
			tile["wall"] = false
			tile["door"] = true
		"chair":
			tile["chair"] = true
		"table":
			tile["table"] = true
		"wall_pad":
			tile["wall_pad"] = true
		"shelf":
			tile["shelf"] = true
			tile["merch_capacity"] = 8
			tile["merch_stock"] = 0
		"droppoint":
			tile["droppoint"] = true
			tile["merch_capacity"] = 999
			tile["merch_stock"] = 4
		"checkout":
			tile["checkout"] = true
	tile["blueprint"] = ""
	tile["build_progress"] = 0.0
	tile["blueprint_stand"] = Vector2i(-1, -1)
	grid[cell] = tile
	_unregister_blueprint_cell(cell)
	request_world_redraw()
	_update_navigation_cell(cell)


func get_build_stand_cell(target_cell: Vector2i) -> Vector2i:
	var tile: Dictionary = grid.get(target_cell, _make_tile())
	var preferred_stand: Vector2i = tile.get("blueprint_stand", Vector2i(-1, -1))
	if is_valid_cell(preferred_stand) and is_cell_walkable(preferred_stand):
		return preferred_stand
	var candidates: Array[Vector2i] = []
	var blueprint_type: String = String(tile.get("blueprint", ""))
	if blueprint_type != "wall" and bool(tile.get("floor", false)) and not bool(tile.get("wall", false)):
		candidates.append(target_cell)
	for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var neighbor: Vector2i = target_cell + direction
		if is_cell_walkable(neighbor):
			candidates.append(neighbor)
	if candidates.is_empty():
		return Vector2i(-1, -1)
	var best_cell: Vector2i = candidates[0]
	var best_score: int = -1
	for candidate in candidates:
		var score: int = _count_open_neighbors(candidate)
		if score > best_score:
			best_score = score
			best_cell = candidate
	return best_cell


func get_nearest_blueprint_job(start_cell: Vector2i, excluded_cells: Array[Vector2i] = []) -> Dictionary:
	var excluded_lookup: Dictionary = {}
	for cell in excluded_cells:
		excluded_lookup["%s,%s" % [cell.x, cell.y]] = true
	var best_job: Dictionary = {}
	var best_priority: int = 999999
	var best_path_length: int = 999999
	var candidate_jobs: Array[Dictionary] = []
	for target_cell in blueprint_cells:
		if excluded_lookup.has("%s,%s" % [target_cell.x, target_cell.y]):
			continue
		var blueprint_type: String = get_blueprint_type(target_cell)
		candidate_jobs.append({
			"target_cell": target_cell,
			"priority": _get_blueprint_priority(blueprint_type),
			"heuristic_distance": absi(target_cell.x - start_cell.x) + absi(target_cell.y - start_cell.y),
		})
	candidate_jobs.sort_custom(_sort_blueprint_candidates)
	var max_candidates: int = mini(candidate_jobs.size(), 12)
	for index in range(max_candidates):
		var candidate: Dictionary = candidate_jobs[index]
		var target_cell: Vector2i = candidate["target_cell"]
		var stand_cell: Vector2i = get_build_stand_cell(target_cell)
		if not is_valid_cell(stand_cell):
			continue
		var path_cells: Array[Vector2i] = get_path_cells(start_cell, stand_cell)
		if path_cells.is_empty():
			continue
		var priority: int = int(candidate["priority"])
		if priority < best_priority or (priority == best_priority and path_cells.size() < best_path_length):
			best_priority = priority
			best_path_length = path_cells.size()
			best_job = {
				"target_cell": target_cell,
				"stand_cell": stand_cell,
				"path_cells": path_cells,
			}
	return best_job


func get_nearest_walkable_outside_region(region_cells: Array[Vector2i], origin_cell: Vector2i) -> Vector2i:
	var region_lookup: Dictionary = {}
	for region_cell in region_cells:
		region_lookup["%s,%s" % [region_cell.x, region_cell.y]] = true
	var best_cell: Vector2i = Vector2i(-1, -1)
	var best_distance: int = 999999
	for cell_variant in grid.keys():
		var cell: Vector2i = cell_variant
		if not is_cell_walkable(cell):
			continue
		if region_lookup.has("%s,%s" % [cell.x, cell.y]):
			continue
		var distance: int = absi(cell.x - origin_cell.x) + absi(cell.y - origin_cell.y)
		if distance < best_distance:
			best_distance = distance
			best_cell = cell
	return best_cell


func get_nearest_dirty_job(start_cell: Vector2i) -> Dictionary:
	var best_job: Dictionary = {}
	var best_path_length: int = 999999
	for dirty_cell in get_dirty_cells():
		var path_cells: Array[Vector2i] = get_path_cells(start_cell, dirty_cell)
		if path_cells.is_empty():
			continue
		if path_cells.size() < best_path_length:
			best_path_length = path_cells.size()
			best_job = {
				"target_cell": dirty_cell,
				"path_cells": path_cells,
			}
	return best_job


func _can_designate_rect(drag_rect: Rect2i) -> bool:
	var visited_rooms: Dictionary = {}
	for y in range(drag_rect.position.y, drag_rect.end.y):
		for x in range(drag_rect.position.x, drag_rect.end.x):
			var cell: Vector2i = Vector2i(x, y)
			if not is_room_interior_cell(cell):
				return false
			var room_key: String = "%s,%s" % [cell.x, cell.y]
			if visited_rooms.has(room_key):
				continue
			var room_cells: Array[Vector2i] = []
			if not _is_enclosed_room(cell, room_cells):
				return false
			for room_cell in room_cells:
				visited_rooms["%s,%s" % [room_cell.x, room_cell.y]] = true
	return true


func _is_enclosed_room(start_cell: Vector2i, room_cells: Array[Vector2i]) -> bool:
	var open_list: Array[Vector2i] = [start_cell]
	var visited: Dictionary = {}
	while not open_list.is_empty():
		var cell: Vector2i = open_list.pop_back()
		var key: String = "%s,%s" % [cell.x, cell.y]
		if visited.has(key):
			continue
		visited[key] = true
		room_cells.append(cell)
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var neighbor: Vector2i = cell + direction
			if not is_valid_cell(neighbor):
				return false
			var tile: Dictionary = grid.get(neighbor, _make_tile())
			var is_wall: bool = bool(tile.get("wall", false))
			var is_door: bool = bool(tile.get("door", false))
			var is_floor: bool = bool(tile.get("floor", false))
			if is_wall or is_door:
				continue
			if not is_floor:
				return false
			var neighbor_key: String = "%s,%s" % [neighbor.x, neighbor.y]
			if not visited.has(neighbor_key):
				open_list.append(neighbor)
	return true


func get_enclosed_region(cell: Vector2i) -> Array[Vector2i]:
	var region_cells: Array[Vector2i] = []
	if not is_cell_walkable(cell):
		return region_cells
	var open_list: Array[Vector2i] = [cell]
	var visited: Dictionary = {}
	while not open_list.is_empty():
		var current: Vector2i = open_list.pop_back()
		var key: String = "%s,%s" % [current.x, current.y]
		if visited.has(key):
			continue
		visited[key] = true
		region_cells.append(current)
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var neighbor: Vector2i = current + direction
			if is_cell_walkable(neighbor) and not visited.has("%s,%s" % [neighbor.x, neighbor.y]):
				open_list.append(neighbor)
	return region_cells


func _configure_navigation() -> void:
	navigation.region = Rect2i(Vector2i.ZERO, Vector2i(GRID_WIDTH, GRID_HEIGHT))
	navigation.cell_size = Vector2i.ONE
	navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	navigation.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	navigation.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	navigation.update()


func _rebuild_navigation() -> void:
	_configure_navigation()
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			var cell: Vector2i = Vector2i(x, y)
			_update_navigation_cell(cell)


func _count_open_neighbors(cell: Vector2i) -> int:
	var total: int = 0
	for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if is_cell_walkable(cell + direction):
			total += 1
	return total


func _get_walkable_region_size(start_cell: Vector2i) -> int:
	if not is_cell_walkable(start_cell):
		return 0
	var open_list: Array[Vector2i] = [start_cell]
	var visited: Dictionary = {}
	var total: int = 0
	while not open_list.is_empty():
		var cell: Vector2i = open_list.pop_back()
		var key: String = "%s,%s" % [cell.x, cell.y]
		if visited.has(key):
			continue
		visited[key] = true
		total += 1
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var neighbor: Vector2i = cell + direction
			if is_cell_walkable(neighbor) and not visited.has("%s,%s" % [neighbor.x, neighbor.y]):
				open_list.append(neighbor)
	return total


func _get_blueprint_priority(blueprint_type: String) -> int:
	match blueprint_type:
		"floor":
			return 0
		"door":
			return 1
		"chair":
			return 2
		"table":
			return 2
		"wall_pad":
			return 2
		"shelf":
			return 2
		"droppoint":
			return 2
		"checkout":
			return 2
		"wall":
			return 3
	return 4


func get_merch_stock(cell: Vector2i) -> int:
	var tile: Dictionary = grid.get(cell, _make_tile())
	return int(tile.get("merch_stock", 0))


func add_merch_stock(cell: Vector2i, amount: int) -> void:
	if not grid.has(cell):
		return
	var tile: Dictionary = grid.get(cell, _make_tile())
	var current: int = int(tile.get("merch_stock", 0))
	var capacity: int = int(tile.get("merch_capacity", 999))
	tile["merch_stock"] = mini(capacity, current + amount)
	grid[cell] = tile
	request_world_redraw()


func remove_merch_stock(cell: Vector2i, amount: int) -> int:
	if not grid.has(cell):
		return 0
	var tile: Dictionary = grid.get(cell, _make_tile())
	var current: int = int(tile.get("merch_stock", 0))
	var removed: int = mini(current, amount)
	tile["merch_stock"] = current - removed
	grid[cell] = tile
	request_world_redraw()
	return removed


func get_designated_room_cells(start_cell: Vector2i, designation: String) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not is_valid_cell(start_cell):
		return result
	var start_tile: Dictionary = grid.get(start_cell, _make_tile())
	if String(start_tile.get("designation", "")) != designation:
		return result
	var open_list: Array[Vector2i] = [start_cell]
	var visited: Dictionary = {}
	while not open_list.is_empty():
		var cell: Vector2i = open_list.pop_back()
		var key: String = "%s,%s" % [cell.x, cell.y]
		if visited.has(key):
			continue
		visited[key] = true
		var tile: Dictionary = grid.get(cell, _make_tile())
		if String(tile.get("designation", "")) != designation or not bool(tile.get("floor", false)) or bool(tile.get("wall", false)):
			continue
		result.append(cell)
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var neighbor: Vector2i = cell + direction
			if is_valid_cell(neighbor) and not visited.has("%s,%s" % [neighbor.x, neighbor.y]):
				open_list.append(neighbor)
	return result


func recording_booth_has_requirements(start_cell: Vector2i) -> bool:
	var room_cells: Array[Vector2i] = get_designated_room_cells(start_cell, "recording_booth")
	if room_cells.is_empty():
		return false
	var has_chair: bool = false
	var has_table: bool = false
	for cell in room_cells:
		var tile: Dictionary = grid.get(cell, _make_tile())
		has_chair = has_chair or bool(tile.get("chair", false))
		has_table = has_table or bool(tile.get("table", false))
	return has_chair and has_table


func is_recording_booth_fully_padded(start_cell: Vector2i) -> bool:
	var room_cells: Array[Vector2i] = get_designated_room_cells(start_cell, "recording_booth")
	if room_cells.is_empty():
		return false
	for cell in room_cells:
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var neighbor: Vector2i = cell + direction
			if not is_valid_cell(neighbor):
				return false
			var neighbor_tile: Dictionary = grid.get(neighbor, _make_tile())
			if bool(neighbor_tile.get("wall", false)) and not bool(neighbor_tile.get("wall_pad", false)):
				return false
	# Doors are allowed unpadded, but every wall around the room must be padded.
	return true


func get_recording_booth_work_cell(start_cell: Vector2i) -> Vector2i:
	var room_cells: Array[Vector2i] = get_designated_room_cells(start_cell, "recording_booth")
	if room_cells.is_empty():
		return Vector2i(-1, -1)
	var fallback_table: Vector2i = Vector2i(-1, -1)
	for cell in room_cells:
		var tile: Dictionary = grid.get(cell, _make_tile())
		if bool(tile.get("chair", false)):
			return cell
		if bool(tile.get("table", false)) and fallback_table.x < 0:
			fallback_table = cell
	return fallback_table


func get_recording_booth_summary(start_cell: Vector2i) -> Dictionary:
	return {
		"has_requirements": recording_booth_has_requirements(start_cell),
		"fully_padded": is_recording_booth_fully_padded(start_cell),
		"work_cell": get_recording_booth_work_cell(start_cell),
	}


func _sort_blueprint_candidates(a: Dictionary, b: Dictionary) -> bool:
	var a_priority: int = int(a["priority"])
	var b_priority: int = int(b["priority"])
	if a_priority != b_priority:
		return a_priority < b_priority
	return int(a["heuristic_distance"]) < int(b["heuristic_distance"])


func _wall_adjacent_to_designation(cell: Vector2i, designation: String) -> bool:
	for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var neighbor: Vector2i = cell + direction
		if not is_valid_cell(neighbor):
			continue
		var tile: Dictionary = grid.get(neighbor, _make_tile())
		if String(tile.get("designation", "")) == designation and bool(tile.get("floor", false)) and not bool(tile.get("wall", false)):
			return true
	return false


func _get_room_wall_outside_cell(cell: Vector2i, room_rect: Rect2i) -> Vector2i:
	if cell.x == room_rect.position.x:
		return cell + Vector2i.LEFT
	if cell.x == room_rect.end.x - 1:
		return cell + Vector2i.RIGHT
	if cell.y == room_rect.position.y:
		return cell + Vector2i.UP
	return cell + Vector2i.DOWN


func _register_blueprint_cell(cell: Vector2i) -> void:
	var key: String = "%s,%s" % [cell.x, cell.y]
	if blueprint_lookup.has(key):
		return
	blueprint_lookup[key] = true
	blueprint_cells.append(cell)


func _unregister_blueprint_cell(cell: Vector2i) -> void:
	var key: String = "%s,%s" % [cell.x, cell.y]
	if not blueprint_lookup.has(key):
		return
	blueprint_lookup.erase(key)
	var index: int = blueprint_cells.find(cell)
	if index >= 0:
		blueprint_cells.remove_at(index)


func _update_navigation_cell(cell: Vector2i) -> void:
	if not is_valid_cell(cell):
		return
	navigation.set_point_solid(cell, not is_cell_walkable(cell))


func request_world_redraw() -> void:
	if redraw_pending:
		return
	redraw_pending = true
	queue_redraw()


func _process(_delta: float) -> void:
	redraw_pending = false


func _make_tile(floor: bool = true, wall: bool = false, door: bool = false, designation: String = "") -> Dictionary:
	return {
		"floor": floor,
		"wall": wall,
		"door": door,
		"designation": designation,
		"chair": false,
		"table": false,
		"wall_pad": false,
		"shelf": false,
		"droppoint": false,
		"checkout": false,
		"blueprint": "",
		"blueprint_stand": Vector2i(-1, -1),
		"build_progress": 0.0,
		"merch_stock": 0,
		"merch_capacity": 0,
		"dirt": 0.0,
	}
