extends Node2D

const Localization := preload("res://scripts/localization.gd")
const SimCharacter := preload("res://scripts/sim_character.gd")

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

enum BuildMode {
	NONE,
	WALL,
	DOOR,
	FLOOR,
	ERASE,
	DESIGNATE_OFFICE,
	DESIGNATE_BATHROOM,
	DESIGNATE_STORAGE,
}

var loc := Localization.new()
var rng := RandomNumberGenerator.new()

var build_mode := BuildMode.NONE
var sim_time := 0.0
var current_day := 1
var current_month_day := 1
var seconds_per_day := 300.0
var speed_index := 1
var time_scales := [0.0, 1.0, 2.0, 4.0]
var money := 12000
var reputation := 0
var company_level := 1
var logs: Array[String] = []
var selected_entity: Dictionary = {}

var grid: Dictionary = {}
var workers: Array[Dictionary] = []
var talents: Array[Dictionary] = []
var worker_offer_index := 0
var talent_offer_index := 0
var roam_timer := 0.0

var worker_pool := [
	{"name": "A-chan", "role_key": "role.producer", "ops": 4, "mood": 6, "salary": 780, "sprite": "res://assets/sprites/fan_mascots/Chattini.png"},
	{"name": "Daichi", "role_key": "role.builder", "ops": 6, "mood": 5, "salary": 710, "sprite": "res://assets/sprites/fan_mascots/Kronie.png"},
	{"name": "Mina", "role_key": "role.hr", "ops": 5, "mood": 7, "salary": 760, "sprite": "res://assets/sprites/fan_mascots/MikoPi.png"},
	{"name": "Riku", "role_key": "role.logistics", "ops": 7, "mood": 4, "salary": 735, "sprite": "res://assets/sprites/fan_mascots/Otomo.png"},
	{"name": "Sota", "role_key": "role.builder", "ops": 5, "mood": 8, "salary": 720, "sprite": "res://assets/sprites/fan_mascots/pebble.png"},
]

var talent_pool := [
	{"name": "Tokino Sora", "focus_key": "focus.streaming", "unlock_level": 1, "salary": 1800, "sprite": "res://assets/sprites/talents/TokinoSora.png"},
	{"name": "AZKi", "focus_key": "focus.performance", "unlock_level": 2, "salary": 2200, "sprite": "res://assets/sprites/talents/Azki.png"},
	{"name": "Mori Calliope", "focus_key": "focus.merch", "unlock_level": 2, "salary": 2500, "sprite": "res://assets/sprites/talents/MoriCalliope.png"},
	{"name": "Sakura Miko", "focus_key": "focus.streaming", "unlock_level": 3, "salary": 2800, "sprite": "res://assets/sprites/talents/SakuraMiko.png"},
	{"name": "Suisei", "focus_key": "focus.performance", "unlock_level": 4, "salary": 3200, "sprite": "res://assets/sprites/talents/Suisei.png"},
]

var hud_layer: CanvasLayer
var stats_label: Label
var time_label: Label
var room_label: Label
var selected_label: Label
var mode_label: Label
var worker_offer_label: Label
var talent_offer_label: Label
var instructions_label: Label
var logs_label: RichTextLabel
var pause_button: Button
var speed_button: Button
var hire_worker_button: Button
var hire_talent_button: Button


func _ready() -> void:
	rng.randomize()
	_seed_map()
	_seed_staff()
	_build_ui()
	_add_log("log.start")
	_refresh_ui()
	set_process(true)
	queue_redraw()


func _build_ui() -> void:
	hud_layer = CanvasLayer.new()
	add_child(hud_layer)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_layer.add_child(root)

	var top_panel := PanelContainer.new()
	top_panel.position = Vector2(16, 12)
	top_panel.size = Vector2(1248, 86)
	root.add_child(top_panel)

	var top_margin := MarginContainer.new()
	top_margin.add_theme_constant_override("margin_left", 12)
	top_margin.add_theme_constant_override("margin_top", 10)
	top_margin.add_theme_constant_override("margin_right", 12)
	top_margin.add_theme_constant_override("margin_bottom", 10)
	top_panel.add_child(top_margin)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 18)
	top_margin.add_child(top_row)

	var stats_box := VBoxContainer.new()
	stats_box.custom_minimum_size = Vector2(500, 0)
	top_row.add_child(stats_box)

	stats_label = Label.new()
	stats_box.add_child(stats_label)

	time_label = Label.new()
	stats_box.add_child(time_label)

	room_label = Label.new()
	stats_box.add_child(room_label)

	var controls_box := VBoxContainer.new()
	controls_box.custom_minimum_size = Vector2(220, 0)
	top_row.add_child(controls_box)

	mode_label = Label.new()
	controls_box.add_child(mode_label)

	selected_label = Label.new()
	controls_box.add_child(selected_label)

	instructions_label = Label.new()
	instructions_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instructions_label.custom_minimum_size = Vector2(450, 0)
	top_row.add_child(instructions_label)

	var right_panel := PanelContainer.new()
	right_panel.position = Vector2(830, 112)
	right_panel.size = Vector2(434, 590)
	root.add_child(right_panel)

	var right_margin := MarginContainer.new()
	right_margin.add_theme_constant_override("margin_left", 10)
	right_margin.add_theme_constant_override("margin_top", 10)
	right_margin.add_theme_constant_override("margin_right", 10)
	right_margin.add_theme_constant_override("margin_bottom", 10)
	right_panel.add_child(right_margin)

	var right_column := VBoxContainer.new()
	right_column.add_theme_constant_override("separation", 10)
	right_margin.add_child(right_column)

	var build_panel := _make_section(right_column)
	_add_section_title(build_panel, "panel.build")
	var build_grid := GridContainer.new()
	build_grid.columns = 2
	build_grid.add_theme_constant_override("h_separation", 6)
	build_grid.add_theme_constant_override("v_separation", 6)
	build_panel.add_child(build_grid)

	_add_mode_button(build_grid, "button.mode.wall", BuildMode.WALL)
	_add_mode_button(build_grid, "button.mode.door", BuildMode.DOOR)
	_add_mode_button(build_grid, "button.mode.floor", BuildMode.FLOOR)
	_add_mode_button(build_grid, "button.mode.erase", BuildMode.ERASE)
	_add_mode_button(build_grid, "button.mode.office", BuildMode.DESIGNATE_OFFICE)
	_add_mode_button(build_grid, "button.mode.bathroom", BuildMode.DESIGNATE_BATHROOM)
	_add_mode_button(build_grid, "button.mode.storage", BuildMode.DESIGNATE_STORAGE)

	var time_row := HBoxContainer.new()
	time_row.add_theme_constant_override("separation", 6)
	build_panel.add_child(time_row)

	pause_button = Button.new()
	pause_button.name = "button.pause.dynamic"
	pause_button.pressed.connect(_on_pause_pressed)
	time_row.add_child(pause_button)

	speed_button = Button.new()
	speed_button.name = "button.speed.dynamic"
	speed_button.pressed.connect(_on_speed_pressed)
	time_row.add_child(speed_button)

	var staff_panel := _make_section(right_column)
	_add_section_title(staff_panel, "panel.staff")
	worker_offer_label = Label.new()
	worker_offer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	staff_panel.add_child(worker_offer_label)
	hire_worker_button = Button.new()
	hire_worker_button.name = "button.hire_worker"
	hire_worker_button.pressed.connect(_hire_current_worker)
	staff_panel.add_child(hire_worker_button)

	talent_offer_label = Label.new()
	talent_offer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	staff_panel.add_child(talent_offer_label)
	hire_talent_button = Button.new()
	hire_talent_button.name = "button.hire_talent"
	hire_talent_button.pressed.connect(_hire_current_talent)
	staff_panel.add_child(hire_talent_button)

	var assignment_panel := _make_section(right_column)
	_add_section_title(assignment_panel, "panel.assignment")
	_add_task_button(assignment_panel, "button.task.stream", "task.stream")
	_add_task_button(assignment_panel, "button.task.concert", "task.concert")
	_add_task_button(assignment_panel, "button.task.merch", "task.merch")
	_add_task_button(assignment_panel, "button.task.idle", "task.idle")

	var language_panel := _make_section(right_column)
	_add_section_title(language_panel, "panel.language")
	var language_row := HBoxContainer.new()
	language_row.add_theme_constant_override("separation", 6)
	language_panel.add_child(language_row)
	for locale_entry in loc.LOCALES:
		_add_language_button(language_row, locale_entry["code"], locale_entry["label"])

	var logs_panel := _make_section(right_column)
	_add_section_title(logs_panel, "panel.logs")
	logs_label = RichTextLabel.new()
	logs_label.custom_minimum_size = Vector2(0, 180)
	logs_label.fit_content = true
	logs_label.bbcode_enabled = true
	logs_panel.add_child(logs_label)


func _make_section(parent: Control) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 6)
	parent.add_child(section)
	return section


func _add_section_title(parent: Control, key: String) -> void:
	var label := Label.new()
	label.name = key
	label.text = loc.tr(key)
	label.add_theme_font_size_override("font_size", 17)
	parent.add_child(label)


func _add_mode_button(parent: Control, key: String, target_mode: int) -> void:
	var button := Button.new()
	button.name = key
	button.text = loc.tr(key)
	button.pressed.connect(func() -> void:
		build_mode = target_mode
		_refresh_ui()
	)
	parent.add_child(button)


func _add_task_button(parent: Control, key: String, task_key: String) -> void:
	var button := Button.new()
	button.name = key
	button.text = loc.tr(key)
	button.pressed.connect(func() -> void:
		_assign_task(task_key)
	)
	parent.add_child(button)


func _add_language_button(parent: Control, locale_code: String, label_text: String) -> void:
	var button := Button.new()
	button.text = label_text
	button.pressed.connect(func() -> void:
		loc.set_locale(locale_code)
		_refresh_ui()
	)
	parent.add_child(button)


func _process(delta: float) -> void:
	var active_scale: float = time_scales[speed_index]
	if active_scale > 0.0:
		sim_time += delta * active_scale
		roam_timer += delta * active_scale
		if roam_timer >= 2.0:
			roam_timer = 0.0
			_update_roaming_targets()
		if sim_time >= seconds_per_day:
			sim_time -= seconds_per_day
			_finish_day()
	if int(Time.get_ticks_msec() / 250) % 2 == 0:
		_refresh_ui()


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
		var mouse_position := event.position
		if event.button_index == MOUSE_BUTTON_RIGHT:
			build_mode = BuildMode.NONE
			_add_log("log.cancel_mode")
			_refresh_ui()
			return
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		if _try_select_character(mouse_position):
			return
		var cell := _screen_to_cell(mouse_position)
		if not _is_valid_cell(cell):
			return
		_apply_build_mode(cell)


func _screen_to_cell(point: Vector2) -> Vector2i:
	var local_point := point - WORLD_ORIGIN
	return Vector2i(floor(local_point.x / CELL_SIZE), floor(local_point.y / CELL_SIZE))


func _is_valid_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < GRID_WIDTH and cell.y < GRID_HEIGHT


func _cell_center(cell: Vector2i) -> Vector2:
	return WORLD_ORIGIN + Vector2(cell.x * CELL_SIZE + CELL_SIZE / 2.0, cell.y * CELL_SIZE + CELL_SIZE / 2.0)


func _seed_map() -> void:
	_make_room(Rect2i(1, 2, 7, 5), "office")
	_make_room(Rect2i(10, 2, 4, 4), "bathroom")
	_make_room(Rect2i(15, 2, 5, 4), "storage")


func _make_room(rect: Rect2i, designation: String) -> void:
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


func _seed_staff() -> void:
	_spawn_worker(worker_pool[0])
	_spawn_worker(worker_pool[1])
	_spawn_talent(talent_pool[0])
	worker_offer_index = 2
	talent_offer_index = 1


func _spawn_worker(worker_data: Dictionary) -> void:
	var entry := worker_data.duplicate(true)
	entry["node"] = _create_character_node(entry["name"], "worker", entry["sprite"], Color("d7f0ff"))
	entry["task_key"] = "task.idle"
	workers.append(entry)


func _spawn_talent(talent_data: Dictionary) -> void:
	var entry := talent_data.duplicate(true)
	entry["node"] = _create_character_node(entry["name"], "talent", entry["sprite"], Color("ffe8f3"))
	entry["task_key"] = "task.idle"
	talents.append(entry)


func _create_character_node(display_name: String, kind: String, texture_path: String, label_color: Color) -> SimCharacter:
	var node := SimCharacter.new()
	add_child(node)
	var texture := load(texture_path)
	node.configure(display_name, kind, texture, label_color)
	node.position = _cell_center(_get_random_walkable_cell())
	return node


func _get_random_walkable_cell() -> Vector2i:
	var walkable: Array[Vector2i] = []
	for cell in grid.keys():
		var tile: Dictionary = grid[cell]
		if tile.get("floor", false) and not tile.get("wall", false):
			walkable.append(cell)
	if walkable.is_empty():
		return Vector2i.ZERO
	return walkable[rng.randi_range(0, walkable.size() - 1)]


func _update_roaming_targets() -> void:
	for worker in workers:
		var node: SimCharacter = worker["node"]
		node.target_position = _cell_center(_get_random_walkable_cell())
	for talent in talents:
		var node: SimCharacter = talent["node"]
		node.target_position = _cell_center(_get_random_walkable_cell())


func _try_select_character(mouse_position: Vector2) -> bool:
	for worker in workers:
		var node: SimCharacter = worker["node"]
		if node.position.distance_to(mouse_position) <= 18.0:
			_select_entity(worker, true)
			return true
	for talent in talents:
		var node: SimCharacter = talent["node"]
		if node.position.distance_to(mouse_position) <= 18.0:
			_select_entity(talent, false)
			return true
	return false


func _select_entity(entry: Dictionary, is_worker: bool) -> void:
	selected_entity = {
		"entry": entry,
		"is_worker": is_worker,
	}
	for worker in workers:
		var node: SimCharacter = worker["node"]
		node.set_selected(node == entry["node"])
	for talent in talents:
		var node: SimCharacter = talent["node"]
		node.set_selected(node == entry["node"])
	_refresh_ui()


func _apply_build_mode(cell: Vector2i) -> void:
	var tile: Dictionary = grid.get(cell, {"wall": false, "door": false, "floor": false, "designation": ""})
	match build_mode:
		BuildMode.WALL:
			tile = {"wall": true, "door": false, "floor": false, "designation": ""}
			grid[cell] = tile
			_add_log("log.build", {"name": loc.tr("button.mode.wall"), "x": cell.x, "y": cell.y})
		BuildMode.DOOR:
			tile["wall"] = false
			tile["door"] = true
			tile["floor"] = true
			grid[cell] = tile
			_add_log("log.build", {"name": loc.tr("button.mode.door"), "x": cell.x, "y": cell.y})
		BuildMode.FLOOR:
			tile["wall"] = false
			tile["door"] = false
			tile["floor"] = true
			grid[cell] = tile
			_add_log("log.build", {"name": loc.tr("button.mode.floor"), "x": cell.x, "y": cell.y})
		BuildMode.ERASE:
			grid.erase(cell)
			_add_log("log.erase", {"x": cell.x, "y": cell.y})
		BuildMode.DESIGNATE_OFFICE:
			if tile.get("floor", false):
				tile["designation"] = "office"
				grid[cell] = tile
				_add_log("log.designate", {"designation": loc.tr("designation.office"), "x": cell.x, "y": cell.y})
		BuildMode.DESIGNATE_BATHROOM:
			if tile.get("floor", false):
				tile["designation"] = "bathroom"
				grid[cell] = tile
				_add_log("log.designate", {"designation": loc.tr("designation.bathroom"), "x": cell.x, "y": cell.y})
		BuildMode.DESIGNATE_STORAGE:
			if tile.get("floor", false):
				tile["designation"] = "storage"
				grid[cell] = tile
				_add_log("log.designate", {"designation": loc.tr("designation.storage"), "x": cell.x, "y": cell.y})
	_refresh_ui()
	queue_redraw()


func _finish_day() -> void:
	var office_tiles := _count_designation("office")
	var bathroom_tiles := _count_designation("bathroom")
	var storage_tiles := _count_designation("storage")
	var streaming_count := _count_task("task.stream")
	var concert_count := _count_task("task.concert")
	var merch_count := _count_task("task.merch")
	var worker_ops := 0
	for worker in workers:
		worker_ops += worker.get("ops", 0)

	var efficiency := 1.0 + min(float(office_tiles) / 18.0, 0.35) + min(float(storage_tiles) / 20.0, 0.20)
	if bathroom_tiles == 0 and workers.size() >= 3:
		efficiency -= 0.20
	var revenue := int(round((140 + worker_ops * 16 + streaming_count * 180 + concert_count * 240 + merch_count * 145) * max(efficiency, 0.45)))
	money += revenue
	reputation += 8 + streaming_count * 4 + concert_count * 6 + merch_count * 3
	_add_log("log.new_day", {"day": current_day, "amount": revenue})

	current_day += 1
	current_month_day += 1
	if current_month_day > 30:
		current_month_day = 1
		var payroll := _calculate_monthly_payroll()
		money -= payroll
		_add_log("log.payroll", {"amount": payroll})

	var expected_level := 1 + int(reputation / 120)
	if expected_level > company_level:
		company_level = expected_level
		_add_log("log.level_up", {"level": company_level})
	_refresh_ui()


func _calculate_monthly_payroll() -> int:
	var total := 0
	for worker in workers:
		total += worker.get("salary", 0)
	for talent in talents:
		total += talent.get("salary", 0)
	return total


func _count_designation(designation: String) -> int:
	var total := 0
	for cell in grid.keys():
		if grid[cell].get("designation", "") == designation:
			total += 1
	return total


func _count_task(task_key: String) -> int:
	var total := 0
	for talent in talents:
		if talent.get("task_key", "task.idle") == task_key:
			total += 1
	return total


func _hire_current_worker() -> void:
	if worker_pool.is_empty():
		return
	var candidate: Dictionary = worker_pool[worker_offer_index % worker_pool.size()]
	if money < candidate["salary"]:
		_add_log("log.not_enough_money")
		return
	_spawn_worker(candidate)
	worker_offer_index = (worker_offer_index + 1) % worker_pool.size()
	_add_log("log.worker_hired", {"name": candidate["name"]})
	_refresh_ui()


func _hire_current_talent() -> void:
	if talent_pool.is_empty():
		return
	var candidate: Dictionary = talent_pool[talent_offer_index % talent_pool.size()]
	if company_level < candidate["unlock_level"]:
		_add_log("log.locked_talent", {"name": candidate["name"], "level": candidate["unlock_level"]})
		return
	if money < candidate["salary"]:
		_add_log("log.not_enough_money")
		return
	_spawn_talent(candidate)
	talent_offer_index = (talent_offer_index + 1) % talent_pool.size()
	_add_log("log.talent_hired", {"name": candidate["name"]})
	_refresh_ui()


func _assign_task(task_key: String) -> void:
	if selected_entity.is_empty() or selected_entity.get("is_worker", true):
		_add_log("log.no_selection")
		return
	var talent: Dictionary = selected_entity["entry"]
	talent["task_key"] = task_key
	var node: SimCharacter = talent["node"]
	node.set_task(task_key)
	_add_log("log.task_assigned", {"name": talent["name"], "task": loc.tr(task_key)})
	_refresh_ui()


func _on_pause_pressed() -> void:
	if speed_index == 0:
		speed_index = 1
	else:
		speed_index = 0
	_refresh_ui()


func _on_speed_pressed() -> void:
	if speed_index == 0:
		speed_index = 1
	else:
		speed_index += 1
		if speed_index >= time_scales.size():
			speed_index = 1
	_refresh_ui()


func _format_time_of_day() -> String:
	var normalized := sim_time / seconds_per_day
	var minutes_total := int(round(normalized * 24.0 * 60.0))
	var hours := int(minutes_total / 60) % 24
	var minutes := minutes_total % 60
	return "%02d:%02d" % [hours, minutes]


func _add_log(key: String, replacements: Dictionary = {}) -> void:
	logs.push_front(loc.tr(key, replacements))
	if logs.size() > 9:
		logs.resize(9)
	_refresh_logs()


func _refresh_logs() -> void:
	if logs_label == null:
		return
	logs_label.clear()
	var combined := ""
	for entry in logs:
		combined += "- %s\n" % entry
	logs_label.append_text(combined)


func _refresh_ui() -> void:
	if stats_label == null:
		return
	var stats_text := "%s   |   %s   |   %s   |   %s   |   %s   |   %s" % [
		loc.tr("hud.money", {"amount": money}),
		loc.tr("hud.day", {"day": current_day}),
		loc.tr("hud.level", {"level": company_level}),
		loc.tr("hud.reputation", {"value": reputation}),
		loc.tr("hud.staff", {"count": workers.size()}),
		loc.tr("hud.talents", {"count": talents.size()}),
	]
	stats_label.text = "%s  |  %s" % [loc.tr("game.title"), stats_text]
	time_label.text = "%s   |   %s" % [
		loc.tr("hud.time", {"time": _format_time_of_day(), "speed": "x%s" % int(time_scales[speed_index]) if speed_index > 0 else loc.tr("button.pause")}),
		loc.tr("hud.payroll", {"amount": _calculate_monthly_payroll()}),
	]
	room_label.text = loc.tr("hud.room_summary", {
		"office": _count_designation("office"),
		"bathroom": _count_designation("bathroom"),
		"storage": _count_designation("storage"),
	})

	if selected_entity.is_empty():
		selected_label.text = loc.tr("hud.selected.none")
	else:
		var entry: Dictionary = selected_entity["entry"]
		if selected_entity["is_worker"]:
			selected_label.text = loc.tr("hud.selected.worker", {
				"name": entry["name"],
				"role": loc.tr(entry["role_key"]),
			})
		else:
			selected_label.text = loc.tr("hud.selected.talent", {
				"name": entry["name"],
				"task": loc.tr(entry.get("task_key", "task.idle")),
			})

	var mode_key := "mode.none"
	match build_mode:
		BuildMode.WALL:
			mode_key = "mode.wall"
		BuildMode.DOOR:
			mode_key = "mode.door"
		BuildMode.FLOOR:
			mode_key = "mode.floor"
		BuildMode.ERASE:
			mode_key = "mode.erase"
		BuildMode.DESIGNATE_OFFICE:
			mode_key = "mode.designate_office"
		BuildMode.DESIGNATE_BATHROOM:
			mode_key = "mode.designate_bathroom"
		BuildMode.DESIGNATE_STORAGE:
			mode_key = "mode.designate_storage"
	mode_label.text = loc.tr(mode_key)
	instructions_label.text = loc.tr("hud.instructions")

	var worker_offer := worker_pool[worker_offer_index % worker_pool.size()]
	worker_offer_label.text = loc.tr("hud.worker_offer", {
		"name": worker_offer["name"],
		"ops": worker_offer["ops"],
		"mood": worker_offer["mood"],
		"salary": worker_offer["salary"],
	})

	var talent_offer := talent_pool[talent_offer_index % talent_pool.size()]
	talent_offer_label.text = loc.tr("hud.talent_offer", {
		"name": talent_offer["name"],
		"focus": loc.tr(talent_offer["focus_key"]),
		"salary": talent_offer["salary"],
		"level": talent_offer["unlock_level"],
	})

	pause_button.text = loc.tr("button.resume") if speed_index == 0 else loc.tr("button.pause")
	speed_button.text = loc.tr("button.speed", {"value": int(time_scales[speed_index]) if speed_index > 0 else 1})
	hire_worker_button.text = loc.tr("button.hire_worker")
	hire_talent_button.text = loc.tr("button.hire_talent")

	_refresh_section_titles(hud_layer)
	_refresh_buttons(hud_layer)
	_refresh_logs()


func _refresh_section_titles(node: Node) -> void:
	for child in node.get_children():
		if child is Label and String(child.name).begins_with("panel."):
			child.text = loc.tr(String(child.name))
		_refresh_section_titles(child)


func _refresh_buttons(node: Node) -> void:
	for child in node.get_children():
		if child is Button:
			var button_name := String(child.name)
			if button_name.begins_with("button.mode.") or button_name.begins_with("button.task.") or button_name == "button.hire_worker" or button_name == "button.hire_talent":
				child.text = loc.tr(button_name)
		_refresh_buttons(child)
