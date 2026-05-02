extends Node2D

const CharacterScene := preload("res://scenes/actors/sim_character.tscn")

@onready var world: GameWorld = $GameWorld
@onready var hud: GameHud = $GameHud

var loc := HoloLocalization.new()
var build_mode := "none"
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
var roam_timer := 0.0

var selected_entity: Dictionary = {}
var workers: Array[Dictionary] = []
var talents: Array[Dictionary] = []
var worker_offer_index := 0
var talent_offer_index := 0

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


func _ready() -> void:
	world.cell_clicked.connect(_on_world_cell_clicked)
	world.character_clicked.connect(_on_world_character_clicked)
	world.right_clicked.connect(_on_world_right_clicked)
	hud.build_mode_selected.connect(_on_build_mode_selected)
	hud.pause_toggled.connect(_on_pause_toggled)
	hud.speed_pressed.connect(_on_speed_pressed)
	hud.hire_worker_requested.connect(_hire_current_worker)
	hud.hire_talent_requested.connect(_hire_current_talent)
	hud.task_requested.connect(_assign_task)
	hud.locale_requested.connect(_change_locale)
	_reset_game()


func _reset_game() -> void:
	world.reset_world()
	world.seed_rooms()
	workers.clear()
	talents.clear()
	logs.clear()
	selected_entity.clear()
	build_mode = "none"
	sim_time = 0.0
	current_day = 1
	current_month_day = 1
	speed_index = 1
	money = 12000
	reputation = 0
	company_level = 1
	worker_offer_index = 2
	talent_offer_index = 1
	_spawn_worker(worker_pool[0])
	_spawn_worker(worker_pool[1])
	_spawn_talent(talent_pool[0])
	_add_log("log.start")
	_refresh_ui()


func _process(delta: float) -> void:
	var active_scale: float = time_scales[speed_index]
	if active_scale > 0.0:
		sim_time += delta * active_scale
		roam_timer += delta * active_scale
		if roam_timer >= 2.0:
			roam_timer = 0.0
			world.update_roaming_targets()
		if sim_time >= seconds_per_day:
			sim_time -= seconds_per_day
			_finish_day()


func _on_world_cell_clicked(cell: Vector2i) -> void:
	_apply_build_mode(cell)


func _on_world_character_clicked(character_node: SimCharacter) -> void:
	for worker in workers:
		if worker["node"] == character_node:
			_select_entity(worker, true)
			return
	for talent in talents:
		if talent["node"] == character_node:
			_select_entity(talent, false)
			return


func _on_world_right_clicked() -> void:
	build_mode = "none"
	_add_log("log.cancel_mode")
	_refresh_ui()


func _on_build_mode_selected(mode_name: String) -> void:
	build_mode = mode_name
	_refresh_ui()


func _on_pause_toggled() -> void:
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


func _change_locale(locale_code: String) -> void:
	loc.set_locale(locale_code)
	_refresh_ui()


func _spawn_worker(worker_data: Dictionary) -> void:
	var entry := worker_data.duplicate(true)
	entry["node"] = world.add_character(CharacterScene, entry["name"], "worker", entry["sprite"], Color("d7f0ff"))
	entry["task_key"] = "task.idle"
	workers.append(entry)


func _spawn_talent(talent_data: Dictionary) -> void:
	var entry := talent_data.duplicate(true)
	entry["node"] = world.add_character(CharacterScene, entry["name"], "talent", entry["sprite"], Color("ffe8f3"))
	entry["task_key"] = "task.idle"
	talents.append(entry)


func _select_entity(entry: Dictionary, is_worker: bool) -> void:
	selected_entity = {"entry": entry, "is_worker": is_worker}
	world.set_character_selected(entry["node"])
	_refresh_ui()


func _apply_build_mode(cell: Vector2i) -> void:
	match build_mode:
		"wall":
			world.apply_tile_mode("wall", cell)
			_add_log("log.build", {"name": loc.translate_key("button.mode.wall"), "x": cell.x, "y": cell.y})
		"door":
			world.apply_tile_mode("door", cell)
			_add_log("log.build", {"name": loc.translate_key("button.mode.door"), "x": cell.x, "y": cell.y})
		"floor":
			world.apply_tile_mode("floor", cell)
			_add_log("log.build", {"name": loc.translate_key("button.mode.floor"), "x": cell.x, "y": cell.y})
		"erase":
			world.apply_tile_mode("erase", cell)
			_add_log("log.erase", {"x": cell.x, "y": cell.y})
		"office":
			world.apply_tile_mode("office", cell)
			_add_log("log.designate", {"designation": loc.translate_key("designation.office"), "x": cell.x, "y": cell.y})
		"bathroom":
			world.apply_tile_mode("bathroom", cell)
			_add_log("log.designate", {"designation": loc.translate_key("designation.bathroom"), "x": cell.x, "y": cell.y})
		"storage":
			world.apply_tile_mode("storage", cell)
			_add_log("log.designate", {"designation": loc.translate_key("designation.storage"), "x": cell.x, "y": cell.y})
	_refresh_ui()


func _finish_day() -> void:
	var office_tiles := world.count_designation("office")
	var bathroom_tiles := world.count_designation("bathroom")
	var storage_tiles := world.count_designation("storage")
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


func _count_task(task_key: String) -> int:
	var total := 0
	for talent in talents:
		if talent.get("task_key", "task.idle") == task_key:
			total += 1
	return total


func _hire_current_worker() -> void:
	var candidate: Dictionary = worker_pool[worker_offer_index % worker_pool.size()]
	if money < candidate["salary"]:
		_add_log("log.not_enough_money")
		return
	_spawn_worker(candidate)
	worker_offer_index = (worker_offer_index + 1) % worker_pool.size()
	_add_log("log.worker_hired", {"name": candidate["name"]})
	_refresh_ui()


func _hire_current_talent() -> void:
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
	_add_log("log.task_assigned", {"name": talent["name"], "task": loc.translate_key(task_key)})
	_refresh_ui()


func _format_time_of_day() -> String:
	var normalized := sim_time / seconds_per_day
	var minutes_total := int(round(normalized * 24.0 * 60.0))
	var hours := int(minutes_total / 60) % 24
	var minutes := minutes_total % 60
	return "%02d:%02d" % [hours, minutes]


func _add_log(key: String, replacements: Dictionary = {}) -> void:
	logs.push_front(loc.translate_key(key, replacements))
	if logs.size() > 9:
		logs.resize(9)
	hud.update_logs(logs)


func _refresh_ui() -> void:
	var stats_text := "%s  |  %s   |   %s   |   %s   |   %s   |   %s   |   %s" % [
		loc.translate_key("game.title"),
		loc.translate_key("hud.money", {"amount": money}),
		loc.translate_key("hud.day", {"day": current_day}),
		loc.translate_key("hud.level", {"level": company_level}),
		loc.translate_key("hud.reputation", {"value": reputation}),
		loc.translate_key("hud.staff", {"count": workers.size()}),
		loc.translate_key("hud.talents", {"count": talents.size()}),
	]
	var time_text := "%s   |   %s" % [
		loc.translate_key("hud.time", {"time": _format_time_of_day(), "speed": "x%s" % int(time_scales[speed_index]) if speed_index > 0 else loc.translate_key("button.pause")}),
		loc.translate_key("hud.payroll", {"amount": _calculate_monthly_payroll()}),
	]
	var room_text := loc.translate_key("hud.room_summary", {
		"office": world.count_designation("office"),
		"bathroom": world.count_designation("bathroom"),
		"storage": world.count_designation("storage"),
	})
	var selected_text := loc.translate_key("hud.selected.none")
	if not selected_entity.is_empty():
		var entry: Dictionary = selected_entity["entry"]
		if selected_entity["is_worker"]:
			selected_text = loc.translate_key("hud.selected.worker", {"name": entry["name"], "role": loc.translate_key(entry["role_key"])})
		else:
			selected_text = loc.translate_key("hud.selected.talent", {"name": entry["name"], "task": loc.translate_key(entry.get("task_key", "task.idle"))})
	var mode_text := loc.translate_key("mode.none")
	match build_mode:
		"wall":
			mode_text = loc.translate_key("mode.wall")
		"door":
			mode_text = loc.translate_key("mode.door")
		"floor":
			mode_text = loc.translate_key("mode.floor")
		"erase":
			mode_text = loc.translate_key("mode.erase")
		"office":
			mode_text = loc.translate_key("mode.designate_office")
		"bathroom":
			mode_text = loc.translate_key("mode.designate_bathroom")
		"storage":
			mode_text = loc.translate_key("mode.designate_storage")
	var worker_offer := worker_pool[worker_offer_index % worker_pool.size()]
	var talent_offer := talent_pool[talent_offer_index % talent_pool.size()]
	hud.update_texts({
		"stats_text": stats_text,
		"time_text": time_text,
		"room_text": room_text,
		"mode_text": mode_text,
		"selected_text": selected_text,
		"worker_offer_text": loc.translate_key("hud.worker_offer", {
			"name": worker_offer["name"],
			"ops": worker_offer["ops"],
			"mood": worker_offer["mood"],
			"salary": worker_offer["salary"],
		}),
		"talent_offer_text": loc.translate_key("hud.talent_offer", {
			"name": talent_offer["name"],
			"focus": loc.translate_key(talent_offer["focus_key"]),
			"salary": talent_offer["salary"],
			"level": talent_offer["unlock_level"],
		}),
		"pause_text": loc.translate_key("button.resume") if speed_index == 0 else loc.translate_key("button.pause"),
		"speed_text": loc.translate_key("button.speed", {"value": int(time_scales[speed_index]) if speed_index > 0 else 1}),
	}, loc)
	hud.update_logs(logs)
