extends Node2D
class_name GameWorld

signal cell_clicked(cell: Vector2i)
signal character_clicked(character_node: SimCharacter)
signal right_clicked

const GRID_WIDTH := 24
const GRID_HEIGHT := 18
const CELL_SIZE := 32
const WORLD_ORIGIN := Vector2(24, 112)
const WORLD_BACKGROUND := Color("1b2230")
const GRID_COLOR := Color(1, 1, 1, 0.08)
const FLOOR_COLOR := Color("5d748e")
const WALL_COLOR := Color("2a3548")
const DOOR_COLOR := Color("9f6a3d")
const OFFICE_TINT := Color("4da3ff")
const BATHROOM_TINT := Color("5dd39e")
const STORAGE_TINT := Color("ffbe5c")

@onready var characters: Node2D = $Characters

var grid: Dictionary = {}
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	queue_redraw()


func reset_world() -> void:
	grid.clear()
	for child in characters.get_children():
		child.queue_free()
	queue_redraw()


func seed_rooms() -> void:
	make_room(Rect2i(1, 2, 7, 5), "office")
	make_room(Rect2i(10, 2, 4, 4), "bathroom")
	make_room(Rect2i(15, 2, 5, 4), "storage")
	queue_redraw()


func make_room(rect: Rect2i, designation: String) -> void:
	for y in range(rect.size.y):
		for x in range(rect.size.x):
			var cell := Vector2i(rect.position.x + x, rect.position.y + y)
			var is_border := x == 0 or y == 0 or x == rect.size.x - 1 or y == rect.size.y - 1
			if is_border:
				grid[cell] = {"wall": true, "door": false, "floor": false, "designation": ""}
			else:
				grid[cell] = {"wall": false, "door": false, "floor": true, "designation": designation}
	var door_cell := Vector2i(rect.position.x + int(rect.size.x / 2), rect.position.y + rect.size.y - 1)
	grid[door_cell] = {"wall": false, "door": true, "floor": true, "designation": designation}


func _draw() -> void:
	var world_rect := Rect2(WORLD_ORIGIN, Vector2(GRID_WIDTH * CELL_SIZE, GRID_HEIGHT * CELL_SIZE))
	draw_rect(world_rect, WORLD_BACKGROUND, true)
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			var cell := Vector2i(x, y)
			var cell_rect := Rect2(WORLD_ORIGIN + Vector2(x * CELL_SIZE, y * CELL_SIZE), Vector2(CELL_SIZE, CELL_SIZE))
			var tile: Dictionary = grid.get(cell, {})
			if tile.get("floor", false):
				draw_rect(cell_rect.grow(-2), FLOOR_COLOR, true)
				var designation := tile.get("designation", "")
				if designation == "office":
					draw_rect(cell_rect.grow(-6), OFFICE_TINT, true)
				elif designation == "bathroom":
					draw_rect(cell_rect.grow(-6), BATHROOM_TINT, true)
				elif designation == "storage":
					draw_rect(cell_rect.grow(-6), STORAGE_TINT, true)
			if tile.get("wall", false):
				draw_rect(cell_rect.grow(-1), WALL_COLOR, true)
			elif tile.get("door", false):
				draw_rect(cell_rect.grow(-4), DOOR_COLOR, true)
			draw_rect(cell_rect, GRID_COLOR, false, 1.0)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			right_clicked.emit()
			return
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		if _try_select_character(event.position):
			return
		var cell := screen_to_cell(event.position)
		if is_valid_cell(cell):
			cell_clicked.emit(cell)


func _try_select_character(mouse_position: Vector2) -> bool:
	for child in characters.get_children():
		var character := child as SimCharacter
		if character != null and character.position.distance_to(mouse_position) <= 18.0:
			character_clicked.emit(character)
			return true
	return false


func screen_to_cell(point: Vector2) -> Vector2i:
	var local_point := point - WORLD_ORIGIN
	return Vector2i(floor(local_point.x / CELL_SIZE), floor(local_point.y / CELL_SIZE))


func is_valid_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < GRID_WIDTH and cell.y < GRID_HEIGHT


func cell_center(cell: Vector2i) -> Vector2:
	return WORLD_ORIGIN + Vector2(cell.x * CELL_SIZE + CELL_SIZE / 2.0, cell.y * CELL_SIZE + CELL_SIZE / 2.0)


func get_random_walkable_cell() -> Vector2i:
	var walkable: Array[Vector2i] = []
	for cell in grid.keys():
		var tile: Dictionary = grid[cell]
		if tile.get("floor", false) and not tile.get("wall", false):
			walkable.append(cell)
	if walkable.is_empty():
		return Vector2i.ZERO
	return walkable[rng.randi_range(0, walkable.size() - 1)]


func add_character(character_scene: PackedScene, display_name: String, kind: String, texture_path: String, label_color: Color) -> SimCharacter:
	var node := character_scene.instantiate() as SimCharacter
	characters.add_child(node)
	var texture := load(texture_path) as Texture2D
	node.position = cell_center(get_random_walkable_cell())
	node.configure(display_name, kind, texture, label_color)
	return node


func update_roaming_targets() -> void:
	for child in characters.get_children():
		var character := child as SimCharacter
		if character != null:
			character.target_position = cell_center(get_random_walkable_cell())


func set_character_selected(target: SimCharacter) -> void:
	for child in characters.get_children():
		var character := child as SimCharacter
		if character != null:
			character.set_selected(character == target)


func apply_tile_mode(mode_name: String, cell: Vector2i) -> Dictionary:
	var tile: Dictionary = grid.get(cell, {"wall": false, "door": false, "floor": false, "designation": ""})
	match mode_name:
		"wall":
			tile = {"wall": true, "door": false, "floor": false, "designation": ""}
			grid[cell] = tile
		"door":
			tile["wall"] = false
			tile["door"] = true
			tile["floor"] = true
			grid[cell] = tile
		"floor":
			tile["wall"] = false
			tile["door"] = false
			tile["floor"] = true
			grid[cell] = tile
		"erase":
			grid.erase(cell)
		"office":
			if tile.get("floor", false):
				tile["designation"] = "office"
				grid[cell] = tile
		"bathroom":
			if tile.get("floor", false):
				tile["designation"] = "bathroom"
				grid[cell] = tile
		"storage":
			if tile.get("floor", false):
				tile["designation"] = "storage"
				grid[cell] = tile
	queue_redraw()
	return grid.get(cell, {})


func count_designation(designation: String) -> int:
	var total := 0
	for cell in grid.keys():
		if grid[cell].get("designation", "") == designation:
			total += 1
	return total
