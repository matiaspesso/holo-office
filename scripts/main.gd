extends Node2D

const CharacterScene := preload("res://scenes/actors/sim_character.tscn")

@onready var camera_2d: Camera2D = $Camera2D
@onready var world: GameWorld = $GameWorld
@onready var hud: GameHud = $GameHud

var loc: HoloLocalization = HoloLocalization.new()
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var build_mode: String = "none"
var sim_time: float = 0.0
var current_day: int = 1
var current_month_day: int = 1
var seconds_per_day: float = 300.0
var speed_index: int = 0
var time_scales: Array[float] = [1.0, 2.0, 4.0, 8.0]
var is_paused: bool = false
var last_pause_toggle_time_ms: int = -1000
var money: int = 12000
var reputation: int = 0
var company_level: int = 1
var camera_dragging: bool = false
var camera_drag_origin: Vector2 = Vector2.ZERO
var camera_start_position: Vector2 = Vector2.ZERO
var camera_zoom_step: float = 0.1
var camera_zoom_min: float = 0.45
var camera_zoom_max: float = 1.8
var dirt_timer: float = 0.0
var ui_refresh_timer: float = 0.0

var selected_entity: Dictionary = {}
var workers: Array[Dictionary] = []
var talents: Array[Dictionary] = []
var recruit_candidates: Array[Dictionary] = []
var talent_candidates: Array[Dictionary] = []
var customers: Array[Dictionary] = []
var current_recruit_role: String = ""
var recording_value_progress: float = 0.0
var pending_talent_context_booth: Vector2i = Vector2i(-1, -1)
var pending_shop_context_shop: String = ""
var pending_shop_link_source: String = ""
var finance_stats: Dictionary = {}
var storage_inventories: Dictionary = {}
var shop_storage_links: Dictionary = {}
var customer_spawn_timer: float = 0.0
var merch_delivery_timer: float = 0.0

var unlocked_features: Dictionary = {"chairs": false}
var research_state: Dictionary = {"active_id": "", "progress": 0.0}
var research_definitions: Dictionary = {
	"chairs": {
		"name_key": "research.chairs.name",
		"description_key": "research.chairs.desc",
		"cost": 140.0,
	}
}

var worker_names: Array[String] = [
	"Aki", "Mina", "Sora", "Daichi", "Riku", "Saya", "Noa", "Kira", "Ren", "Yui",
]

var mascot_sprites: Array[String] = [
	"res://assets/sprites/fan_mascots/Chattini.png",
	"res://assets/sprites/fan_mascots/Kronie.png",
	"res://assets/sprites/fan_mascots/MikoPi.png",
	"res://assets/sprites/fan_mascots/MioFam.png",
	"res://assets/sprites/fan_mascots/NoveliteOutline.png",
	"res://assets/sprites/fan_mascots/Otomo.png",
	"res://assets/sprites/fan_mascots/SuCorn.png",
	"res://assets/sprites/fan_mascots/Zomrade.png",
	"res://assets/sprites/fan_mascots/pebble.png",
	"res://assets/sprites/fan_mascots/poyoyo.png",
]

var talent_roster: Array[Dictionary] = [
	{"name": "Tokino Sora", "sprite": "res://assets/sprites/talents/TokinoSora.png"},
	{"name": "AZKi", "sprite": "res://assets/sprites/talents/Azki.png"},
	{"name": "Suisei", "sprite": "res://assets/sprites/talents/Suisei.png"},
	{"name": "Fubuki", "sprite": "res://assets/sprites/talents/Fubuki.png"},
	{"name": "Miko", "sprite": "res://assets/sprites/talents/SakuraMiko.png"},
	{"name": "Mio", "sprite": "res://assets/sprites/talents/Mio.png"},
	{"name": "Calli", "sprite": "res://assets/sprites/talents/MoriCalliope.png"},
	{"name": "Shiori", "sprite": "res://assets/sprites/talents/Shiori.png"},
]


func _ready() -> void:
	rng.randomize()
	world.cell_clicked.connect(_on_world_cell_clicked)
	world.drag_completed.connect(_on_world_drag_completed)
	world.character_clicked.connect(_on_world_character_clicked)
	world.right_clicked.connect(_on_world_right_clicked)
	hud.build_mode_selected.connect(_on_build_mode_selected)
	hud.pause_toggled.connect(_toggle_pause)
	hud.speed_selected.connect(_set_speed_from_hud)
	hud.research_requested.connect(_select_research)
	hud.recruit_role_requested.connect(_generate_recruit_candidates)
	hud.hire_candidate_requested.connect(_hire_candidate)
	hud.hire_talent_candidate_requested.connect(_hire_talent_candidate)
	hud.talent_recruit_requested.connect(_generate_talent_candidates)
	hud.talent_context_action.connect(_on_talent_context_action)
	hud.area_context_action.connect(_on_area_context_action)
	_reset_game()


func _reset_game() -> void:
	world.reset_world()
	world.seed_rooms()
	workers.clear()
	talents.clear()
	customers.clear()
	recruit_candidates.clear()
	talent_candidates.clear()
	current_recruit_role = ""
	pending_talent_context_booth = Vector2i(-1, -1)
	pending_shop_context_shop = ""
	pending_shop_link_source = ""
	storage_inventories.clear()
	shop_storage_links.clear()
	customer_spawn_timer = 0.0
	merch_delivery_timer = 0.0
	selected_entity.clear()
	build_mode = "none"
	world.set_tool_mode(build_mode)
	sim_time = 0.0
	ui_refresh_timer = 0.0
	current_day = 1
	current_month_day = 1
	is_paused = false
	money = 12000
	reputation = 0
	company_level = 1
	unlocked_features["chairs"] = false
	research_state["active_id"] = ""
	research_state["progress"] = 0.0
	recording_value_progress = 0.0
	_reset_finance_stats()
	camera_2d.position = Vector2(2200, 1600)
	camera_2d.zoom = Vector2(1.2, 1.2)
	_sync_character_time_scale()
	_refresh_ui()


func _process(delta: float) -> void:
	_update_camera(delta)
	var active_scale: float = _get_active_time_scale()
	_sync_character_time_scale()
	if active_scale <= 0.0:
		return
	sim_time += delta * active_scale
	_update_research(delta * active_scale)
	_update_builders(delta * active_scale)
	_update_janitors(delta * active_scale)
	_update_staff(delta * active_scale)
	_update_cashiers(delta * active_scale)
	_update_talents(delta * active_scale)
	_update_customers(delta * active_scale)
	_update_merch_deliveries(delta * active_scale)
	dirt_timer += delta * active_scale
	if dirt_timer >= 18.0:
		dirt_timer = 0.0
		world.add_random_dirt(20.0)
	while sim_time >= seconds_per_day:
		sim_time -= seconds_per_day
		_finish_day()
	ui_refresh_timer += delta
	if ui_refresh_timer >= 0.25:
		ui_refresh_timer = 0.0
		_refresh_ui()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		camera_dragging = event.pressed
		if camera_dragging:
			camera_drag_origin = event.position
			camera_start_position = camera_2d.position
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_camera_zoom(minf(camera_zoom_max, camera_2d.zoom.x + camera_zoom_step))
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_camera_zoom(maxf(camera_zoom_min, camera_2d.zoom.x - camera_zoom_step))
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				_toggle_pause()
			KEY_1:
				_set_speed_from_hud(0)
			KEY_2:
				_set_speed_from_hud(1)
			KEY_3:
				_set_speed_from_hud(2)
			KEY_4:
				_set_speed_from_hud(3)
	if event is InputEventMouseMotion and camera_dragging:
		var delta: Vector2 = event.position - camera_drag_origin
		camera_2d.position = camera_start_position - delta


func _toggle_pause() -> void:
	var now_ms: int = Time.get_ticks_msec()
	if now_ms - last_pause_toggle_time_ms < 150:
		return
	last_pause_toggle_time_ms = now_ms
	is_paused = not is_paused
	_sync_character_time_scale()
	_refresh_ui()


func _set_speed_from_hud(index: int) -> void:
	speed_index = clampi(index, 0, time_scales.size() - 1)
	is_paused = false
	_sync_character_time_scale()
	_refresh_ui()


func _on_build_mode_selected(mode_name: String) -> void:
	build_mode = mode_name
	world.set_tool_mode(build_mode)
	_refresh_ui()


func _on_world_right_clicked(cell: Vector2i, screen_position: Vector2) -> void:
	if _try_open_talent_booth_context(cell, screen_position):
		return
	if _try_handle_shop_link_target(cell):
		return
	if _try_open_shop_context(cell, screen_position):
		return
	build_mode = "none"
	world.set_tool_mode(build_mode)
	_refresh_ui()


func _on_world_drag_completed(mode_name: String, start_cell: Vector2i, end_cell: Vector2i) -> void:
	var drag_rect: Rect2i = world.get_drag_rect(start_cell, end_cell)
	match mode_name:
		"office":
			if not world.designate_rect("office", start_cell, end_cell):
				return
		"bathroom":
			if not world.designate_rect("bathroom", start_cell, end_cell):
				return
		"storage":
			if not world.designate_rect("storage", start_cell, end_cell):
				return
		"shop":
			if not world.designate_rect("shop", start_cell, end_cell):
				return
		"recording_booth":
			if not world.designate_rect("recording_booth", start_cell, end_cell):
				return
		"clear_area":
			world.clear_designation_rect(start_cell, end_cell)
		"wall":
			for cell in world.create_room_blueprints(start_cell, end_cell):
				_log_blueprint(cell)
		"floor":
			for cell in world.create_floor_blueprints(start_cell, end_cell):
				_log_blueprint(cell)
	_reassign_office_chairs()
	_refresh_ui()


func _on_world_cell_clicked(cell: Vector2i) -> void:
	match build_mode:
		"door":
			if world.place_blueprint("door", cell):
				_log_blueprint(cell)
		"chair":
			if not bool(unlocked_features.get("chairs", false)):
				return
			if world.place_blueprint("chair", cell):
				_log_blueprint(cell)
		"table":
			if world.place_blueprint("table", cell):
				_log_blueprint(cell)
		"wall_pad":
			if world.place_blueprint("wall_pad", cell):
				_log_blueprint(cell)
		"shelf":
			if world.place_blueprint("shelf", cell):
				_log_blueprint(cell)
		"droppoint":
			if world.place_blueprint("droppoint", cell):
				_log_blueprint(cell)
		"checkout":
			if world.place_blueprint("checkout", cell):
				_log_blueprint(cell)
		"erase":
			if not world.remove_chair(cell) and not world.remove_table(cell) and not world.remove_wall_pad(cell) and not world.remove_shelf(cell) and not world.remove_droppoint(cell) and not world.remove_checkout(cell):
				world.clear_cell(cell)
	_reassign_office_chairs()
	_refresh_ui()


func _on_world_character_clicked(character_node: SimCharacter) -> void:
	for worker in workers:
		if worker["node"] == character_node:
			_select_entity(worker, true)
			return
	for talent in talents:
		if talent["node"] == character_node:
			_select_entity(talent, false)
			return


func _select_entity(entry: Dictionary, is_worker: bool) -> void:
	selected_entity = {"entry": entry, "is_worker": is_worker}
	world.set_character_selected(entry["node"])
	_refresh_ui()


func _generate_recruit_candidates(role_id: String) -> void:
	current_recruit_role = role_id
	recruit_candidates.clear()
	for _index in range(3):
		recruit_candidates.append(_make_worker_candidate(role_id))
	_refresh_ui()


func _generate_talent_candidates() -> void:
	talent_candidates.clear()
	var used_indices: Dictionary = {}
	var candidate_count: int = mini(3, talent_roster.size())
	for _index in range(candidate_count):
		var roster_index: int = rng.randi_range(0, talent_roster.size() - 1)
		while used_indices.has(roster_index):
			roster_index = rng.randi_range(0, talent_roster.size() - 1)
		used_indices[roster_index] = true
		talent_candidates.append(_make_talent_candidate(talent_roster[roster_index]))
	_refresh_ui()


func _make_worker_candidate(role_id: String) -> Dictionary:
	var level_band: int = maxi(1, company_level)
	var min_skill: int = mini(6, 1 + int(level_band / 2))
	var max_skill: int = mini(10, 3 + level_band)
	var research_skill: int = rng.randi_range(min_skill, max_skill)
	var build_skill: int = rng.randi_range(min_skill, max_skill)
	var clean_skill: int = rng.randi_range(min_skill, max_skill)
	match role_id:
		"researcher":
			research_skill += 2
		"builder":
			build_skill += 2
		"janitor":
			clean_skill += 2
		"staff":
			clean_skill += 2
		"cashier":
			research_skill += 1
			clean_skill += 1
	research_skill = mini(research_skill, 10)
	build_skill = mini(build_skill, 10)
	clean_skill = mini(clean_skill, 10)
	var sprite_path: String = mascot_sprites[rng.randi_range(0, mascot_sprites.size() - 1)]
	var name: String = worker_names[rng.randi_range(0, worker_names.size() - 1)]
	var salary: int = 320 + (research_skill + build_skill + clean_skill) * 36
	return {
		"name": name,
		"role_id": role_id,
		"role_key": "role.%s" % role_id,
		"research_skill": research_skill,
		"build_skill": build_skill,
		"clean_skill": clean_skill,
		"salary": salary,
		"sprite": sprite_path,
	}


func _make_talent_candidate(base_data: Dictionary) -> Dictionary:
	var level_band: int = maxi(1, company_level)
	var min_skill: int = mini(6, 2 + int(level_band / 2))
	var max_skill: int = mini(10, 4 + level_band)
	var recording_skill: int = rng.randi_range(min_skill, max_skill)
	var salary: int = 700 + recording_skill * 80
	return {
		"name": String(base_data.get("name", "")),
		"sprite": String(base_data.get("sprite", "")),
		"recording_skill": recording_skill,
		"salary": salary,
		"role_key": "role.talent",
	}


func _hire_candidate(candidate_index: int) -> void:
	if candidate_index < 0 or candidate_index >= recruit_candidates.size():
		return
	var candidate: Dictionary = recruit_candidates[candidate_index]
	_spawn_worker(candidate)
	recruit_candidates.clear()
	_refresh_ui()


func _hire_talent_candidate(candidate_index: int) -> void:
	if candidate_index < 0 or candidate_index >= talent_candidates.size():
		return
	var candidate: Dictionary = talent_candidates[candidate_index]
	_spawn_talent(candidate)
	talent_candidates.clear()
	_refresh_ui()


func _spawn_worker(worker_data: Dictionary) -> void:
	var entry: Dictionary = worker_data.duplicate(true)
	entry["node"] = world.add_character(CharacterScene, entry["name"], "worker", entry["sprite"], Color("d7f0ff"))
	entry["assigned_chair"] = Vector2i(-1, -1)
	entry["job_target"] = Vector2i(-1, -1)
	entry["job_stand"] = Vector2i(-1, -1)
	workers.append(entry)
	entry["node"].set_simulation_speed(_get_active_time_scale())
	_reassign_office_chairs()


func _spawn_talent(talent_data: Dictionary) -> void:
	var entry: Dictionary = talent_data.duplicate(true)
	entry["node"] = world.add_character(CharacterScene, entry["name"], "talent", entry["sprite"], Color("ffd9f3"))
	entry["assigned_booth"] = Vector2i(-1, -1)
	entry["task"] = "idle"
	talents.append(entry)
	entry["node"].set_simulation_speed(_get_active_time_scale())


func _select_research(research_id: String) -> void:
	if bool(unlocked_features.get(research_id, false)):
		return
	research_state["active_id"] = research_id
	research_state["progress"] = 0.0
	_refresh_ui()


func _update_research(delta_scaled: float) -> void:
	var active_id: String = String(research_state.get("active_id", ""))
	if active_id == "" or bool(unlocked_features.get(active_id, false)):
		return
	_reassign_office_chairs()
	var active_researchers: int = 0
	var research_rate: float = 0.0
	var office_cells: Array[Vector2i] = world.get_cells_in_designation("office")
	if office_cells.is_empty():
		return
	for worker in workers:
		if String(worker.get("role_id", "")) != "researcher":
			continue
		var node: SimCharacter = worker["node"]
		var work_cell: Vector2i = _get_research_work_cell(worker)
		if work_cell.x < 0:
			continue
		var current_cell: Vector2i = world.get_character_cell(node)
		if current_cell != work_cell:
			if node.path_points.is_empty():
				world.assign_character_destination(node, work_cell)
			continue
		active_researchers += 1
		var contribution: float = float(worker.get("research_skill", 0)) * 0.35
		var chair_cell: Vector2i = worker.get("assigned_chair", Vector2i(-1, -1))
		if chair_cell.x >= 0 and work_cell == chair_cell:
			contribution *= 1.10
		research_rate += contribution
	if active_researchers <= 0:
		return
	var progress: float = float(research_state.get("progress", 0.0))
	var cost: float = float(research_definitions[active_id]["cost"])
	progress += research_rate * delta_scaled
	research_state["progress"] = progress
	if progress >= cost:
		research_state["progress"] = cost
		unlocked_features[active_id] = true
		research_state["active_id"] = ""
	_refresh_ui()


func _update_builders(delta_scaled: float) -> void:
	for worker in workers:
		if String(worker.get("role_id", "")) != "builder":
			continue
		var node: SimCharacter = worker["node"]
		# Drain the job-search cooldown so we don't call pathfinding every frame
		# when no unclaimed blueprint is currently reachable.
		var job_cooldown: float = maxf(0.0, float(worker.get("job_cooldown", 0.0)) - delta_scaled)
		worker["job_cooldown"] = job_cooldown
		var job_target: Vector2i = worker.get("job_target", Vector2i(-1, -1))
		if job_target.x < 0 or world.get_blueprint_type(job_target) == "":
			if job_cooldown > 0.0:
				continue
			_assign_builder_job(worker)
			job_target = worker.get("job_target", Vector2i(-1, -1))
			if job_target.x < 0:
				continue
		var stand_cell: Vector2i = worker.get("job_stand", Vector2i(-1, -1))
		var current_cell: Vector2i = world.get_character_cell(node)
		if current_cell != stand_cell:
			var travel_timer: float = float(worker.get("travel_timer", 0.0)) + delta_scaled
			worker["travel_timer"] = travel_timer
			if node.path_points.is_empty():
				world.assign_character_destination(node, stand_cell)
			if travel_timer > 8.0:
				# Stuck in transit — path likely stale due to a wall being built.
				node.path_points.clear()
				worker["job_target"] = Vector2i(-1, -1)
				worker["job_stand"] = Vector2i(-1, -1)
				worker["travel_timer"] = 0.0
				worker["job_cooldown"] = 0.5
				_recover_builder_if_inside_wall(worker)
			continue
		worker["travel_timer"] = 0.0
		var build_speed: float = float(worker.get("build_skill", 1)) * 18.0
		world.add_blueprint_progress(job_target, delta_scaled * build_speed)
		if world.get_blueprint_progress(job_target) >= 100.0:
			var completed_type: String = world.get_blueprint_type(job_target)
			world.complete_blueprint(job_target)
			worker["job_target"] = Vector2i(-1, -1)
			worker["job_stand"] = Vector2i(-1, -1)
			worker["job_cooldown"] = 0.0
			worker["travel_timer"] = 0.0
			if completed_type == "chair":
				_reassign_office_chairs()


func _update_janitors(delta_scaled: float) -> void:
	for worker in workers:
		if String(worker.get("role_id", "")) != "janitor":
			continue
		var node: SimCharacter = worker["node"]
		var job_target: Vector2i = worker.get("job_target", Vector2i(-1, -1))
		if job_target.x < 0 or world.get_dirt(job_target) <= 0.0:
			_assign_janitor_job(worker)
			job_target = worker.get("job_target", Vector2i(-1, -1))
			if job_target.x < 0:
				continue
		var current_cell: Vector2i = world.get_character_cell(node)
		if current_cell != job_target:
			if node.path_points.is_empty():
				world.assign_character_destination(node, job_target)
			continue
		var clean_speed: float = float(worker.get("clean_skill", 1)) * 8.0
		world.reduce_dirt(job_target, delta_scaled * clean_speed)
		if world.get_dirt(job_target) <= 0.0:
			worker["job_target"] = Vector2i(-1, -1)
			worker["job_stand"] = Vector2i(-1, -1)


func _update_staff(delta_scaled: float) -> void:
	for worker in workers:
		if String(worker.get("role_id", "")) != "staff":
			continue
		var node: SimCharacter = worker["node"]
		var task_type: String = String(worker.get("retail_task", ""))
		var task_target: Vector2i = worker.get("job_target", Vector2i(-1, -1))
		if task_type == "" or task_target.x < 0:
			_assign_staff_job(worker)
			task_type = String(worker.get("retail_task", ""))
			task_target = worker.get("job_target", Vector2i(-1, -1))
			if task_type == "" or task_target.x < 0:
				continue
		var current_cell: Vector2i = world.get_character_cell(node)
		if current_cell != task_target:
			if node.path_points.is_empty():
				world.assign_character_destination(node, task_target)
			continue
		match task_type:
			"pickup_droppoint":
				if world.remove_merch_stock(task_target, 1) > 0:
					worker["carry_merch"] = 1
					worker["retail_task"] = "deliver_storage"
					worker["job_target"] = worker.get("storage_target", Vector2i(-1, -1))
			"deliver_storage":
				var storage_key: String = String(worker.get("storage_key", ""))
				if int(worker.get("carry_merch", 0)) > 0 and storage_key != "":
					storage_inventories[storage_key] = int(storage_inventories.get(storage_key, 0)) + int(worker.get("carry_merch", 0))
					worker["carry_merch"] = 0
				_clear_staff_job(worker)
			"pickup_storage":
				var storage_key2: String = String(worker.get("storage_key", ""))
				if storage_key2 != "" and int(storage_inventories.get(storage_key2, 0)) > 0:
					storage_inventories[storage_key2] = int(storage_inventories.get(storage_key2, 0)) - 1
					worker["carry_merch"] = 1
					worker["retail_task"] = "restock_shelf"
					worker["job_target"] = worker.get("shelf_target", Vector2i(-1, -1))
				else:
					_clear_staff_job(worker)
			"restock_shelf":
				if int(worker.get("carry_merch", 0)) > 0:
					world.add_merch_stock(task_target, 1)
					worker["carry_merch"] = 0
				_clear_staff_job(worker)


func _update_cashiers(_delta_scaled: float) -> void:
	var claimed_checkouts: Dictionary = {}
	for worker in workers:
		if String(worker.get("role_id", "")) != "cashier":
			continue
		var checkout_cell: Vector2i = worker.get("assigned_checkout", Vector2i(-1, -1))
		if checkout_cell.x < 0 or not world.get_cells_with_feature("checkout").has(checkout_cell):
			checkout_cell = _find_checkout_for_cashier(claimed_checkouts)
			worker["assigned_checkout"] = checkout_cell
		if checkout_cell.x < 0:
			continue
		claimed_checkouts["%s,%s" % [checkout_cell.x, checkout_cell.y]] = true
		var node: SimCharacter = worker["node"]
		var current_cell: Vector2i = world.get_character_cell(node)
		if current_cell != checkout_cell and node.path_points.is_empty():
			world.assign_character_destination(node, checkout_cell)


func _update_customers(delta_scaled: float) -> void:
	customer_spawn_timer += delta_scaled
	if customer_spawn_timer >= 22.0:
		customer_spawn_timer = 0.0
		_try_spawn_customer()
	var remaining_customers: Array[Dictionary] = []
	for customer in customers:
		var node: SimCharacter = customer["node"]
		var state: String = String(customer.get("state", ""))
		var target_cell: Vector2i = customer.get("target_cell", Vector2i(-1, -1))
		if state == "":
			continue
		if target_cell.x >= 0:
			var current_cell: Vector2i = world.get_character_cell(node)
			if current_cell != target_cell:
				if node.path_points.is_empty():
					world.assign_character_destination(node, target_cell)
				remaining_customers.append(customer)
				continue
		match state:
			"browse":
				customer["state"] = "checkout"
				customer["target_cell"] = customer.get("checkout_cell", Vector2i(-1, -1))
				remaining_customers.append(customer)
			"checkout":
				if _has_cashier_at_checkout(customer.get("checkout_cell", Vector2i(-1, -1))):
					var shelf_cell: Vector2i = customer.get("shelf_cell", Vector2i(-1, -1))
					var amount_bought: int = world.remove_merch_stock(shelf_cell, int(customer.get("units", 1)))
					if amount_bought > 0:
						_add_income("shop_sales", amount_bought * 18)
					customer["state"] = "leave"
					customer["target_cell"] = world.get_random_walkable_cell()
					remaining_customers.append(customer)
				else:
					remaining_customers.append(customer)
			"leave":
				node.queue_free()
			_:
				remaining_customers.append(customer)
	customers = remaining_customers


func _update_merch_deliveries(delta_scaled: float) -> void:
	merch_delivery_timer += delta_scaled
	if merch_delivery_timer < 16.0:
		return
	merch_delivery_timer = 0.0
	for droppoint_cell in world.get_cells_with_feature("droppoint"):
		if world.get_merch_stock(droppoint_cell) < 8:
			world.add_merch_stock(droppoint_cell, 1)


func _assign_staff_job(worker: Dictionary) -> void:
	var unique_storage_keys: Dictionary = {}
	for storage_key_variant in shop_storage_links.values():
		unique_storage_keys[String(storage_key_variant)] = true
	var storage_needs_supply: Array[String] = []
	for storage_key in unique_storage_keys.keys():
		if _storage_needs_supply(String(storage_key)):
			storage_needs_supply.append(String(storage_key))
	if not storage_needs_supply.is_empty():
		var droppoint_cell: Vector2i = _find_stocked_droppoint()
		if droppoint_cell.x >= 0:
			var target_storage_key: String = storage_needs_supply[0]
			var storage_target: Vector2i = _room_key_to_anchor(target_storage_key)
			worker["retail_task"] = "pickup_droppoint"
			worker["job_target"] = droppoint_cell
			worker["storage_key"] = target_storage_key
			worker["storage_target"] = storage_target
			return
	var restock_job: Dictionary = _find_shelf_restock_job()
	if not restock_job.is_empty():
		worker["retail_task"] = "pickup_storage"
		worker["job_target"] = restock_job["storage_cell"]
		worker["storage_key"] = restock_job["storage_key"]
		worker["shelf_target"] = restock_job["shelf_cell"]
		return
	_clear_staff_job(worker)


func _clear_staff_job(worker: Dictionary) -> void:
	worker["retail_task"] = ""
	worker["job_target"] = Vector2i(-1, -1)
	worker["storage_key"] = ""
	worker["storage_target"] = Vector2i(-1, -1)
	worker["shelf_target"] = Vector2i(-1, -1)


func _find_stocked_droppoint() -> Vector2i:
	for cell in world.get_cells_with_feature("droppoint"):
		if world.get_merch_stock(cell) > 0:
			return cell
	return Vector2i(-1, -1)


func _storage_needs_supply(storage_key: String) -> bool:
	for shop_key_variant in shop_storage_links.keys():
		var shop_key: String = String(shop_key_variant)
		if String(shop_storage_links[shop_key]) != storage_key:
			continue
		if _shop_needs_stock(shop_key):
			return true
	return false


func _shop_needs_stock(shop_key: String) -> bool:
	var shop_anchor: Vector2i = _room_key_to_anchor(shop_key)
	if shop_anchor.x < 0:
		return false
	for shelf_cell in world.get_cells_with_feature("shelf", "shop"):
		if world.room_key(shelf_cell, "shop") == shop_key and world.get_merch_stock(shelf_cell) < 4:
			return true
	return false


func _find_shelf_restock_job() -> Dictionary:
	for shop_key_variant in shop_storage_links.keys():
		var shop_key: String = String(shop_key_variant)
		var storage_key: String = String(shop_storage_links[shop_key])
		if int(storage_inventories.get(storage_key, 0)) <= 0:
			continue
		for shelf_cell in world.get_cells_with_feature("shelf", "shop"):
			if world.room_key(shelf_cell, "shop") != shop_key:
				continue
			if world.get_merch_stock(shelf_cell) >= 8:
				continue
			return {
				"storage_key": storage_key,
				"storage_cell": _room_key_to_anchor(storage_key),
				"shelf_cell": shelf_cell,
			}
	return {}


func _find_checkout_for_cashier(claimed_checkouts: Dictionary) -> Vector2i:
	for checkout_cell in world.get_cells_with_feature("checkout", "shop"):
		var key: String = "%s,%s" % [checkout_cell.x, checkout_cell.y]
		if claimed_checkouts.has(key):
			continue
		return checkout_cell
	return Vector2i(-1, -1)


func _has_cashier_at_checkout(checkout_cell: Vector2i) -> bool:
	for worker in workers:
		if String(worker.get("role_id", "")) != "cashier":
			continue
		var assigned_checkout: Vector2i = worker.get("assigned_checkout", Vector2i(-1, -1))
		if assigned_checkout != checkout_cell:
			continue
		var node: SimCharacter = worker["node"]
		if world.get_character_cell(node) == checkout_cell:
			return true
	return false


func _try_spawn_customer() -> void:
	var target_shop_key: String = _find_active_shop_for_customer()
	if target_shop_key == "":
		return
	var shelf_cell: Vector2i = Vector2i(-1, -1)
	var checkout_cell: Vector2i = Vector2i(-1, -1)
	for cell in world.get_cells_with_feature("shelf", "shop"):
		if world.room_key(cell, "shop") == target_shop_key and world.get_merch_stock(cell) > 0:
			shelf_cell = cell
			break
	for cell in world.get_cells_with_feature("checkout", "shop"):
		if world.room_key(cell, "shop") == target_shop_key:
			checkout_cell = cell
			break
	if shelf_cell.x < 0 or checkout_cell.x < 0:
		return
	var customer_data: Dictionary = {
		"name": "Customer",
		"node": world.add_character(CharacterScene, "Customer", "customer", mascot_sprites[rng.randi_range(0, mascot_sprites.size() - 1)], Color("fff2c2")),
		"state": "browse",
		"target_cell": shelf_cell,
		"shelf_cell": shelf_cell,
		"checkout_cell": checkout_cell,
		"units": rng.randi_range(1, 2),
	}
	var customer_node: SimCharacter = customer_data["node"]
	customer_node.set_simulation_speed(_get_active_time_scale())
	customers.append(customer_data)


func _try_handle_shop_link_target(cell: Vector2i) -> bool:
	if pending_shop_link_source == "":
		return false
	var storage_room_key: String = world.room_key(cell, "storage")
	if storage_room_key == "":
		pending_shop_link_source = ""
		_refresh_ui()
		return true
	shop_storage_links[pending_shop_link_source] = storage_room_key
	if not storage_inventories.has(storage_room_key):
		storage_inventories[storage_room_key] = 0
	pending_shop_link_source = ""
	pending_shop_context_shop = ""
	_refresh_ui()
	return true


func _try_open_shop_context(cell: Vector2i, screen_position: Vector2) -> bool:
	var shop_room_key: String = world.room_key(cell, "shop")
	if shop_room_key == "":
		return false
	pending_shop_context_shop = shop_room_key
	if shop_storage_links.has(shop_room_key):
		hud.show_area_context_menu(screen_position, "shop_unlink", loc)
	else:
		hud.show_area_context_menu(screen_position, "shop_link", loc)
	return true


func _on_area_context_action(action_id: String) -> void:
	if pending_shop_context_shop == "":
		return
	if action_id == "shop_link":
		pending_shop_link_source = pending_shop_context_shop
	elif action_id == "shop_unlink":
		shop_storage_links.erase(pending_shop_context_shop)
		pending_shop_link_source = ""
	pending_shop_context_shop = ""
	_refresh_ui()


func _find_active_shop_for_customer() -> String:
	for shop_key_variant in shop_storage_links.keys():
		var shop_key: String = String(shop_key_variant)
		if not _shop_has_checkout(shop_key):
			continue
		for shelf_cell in world.get_cells_with_feature("shelf", "shop"):
			if world.room_key(shelf_cell, "shop") == shop_key and world.get_merch_stock(shelf_cell) > 0:
				return shop_key
	return ""


func _shop_has_checkout(shop_key: String) -> bool:
	for checkout_cell in world.get_cells_with_feature("checkout", "shop"):
		if world.room_key(checkout_cell, "shop") == shop_key:
			return true
	return false


func _shop_has_checkout_and_cashier(shop_key: String) -> bool:
	for checkout_cell in world.get_cells_with_feature("checkout", "shop"):
		if world.room_key(checkout_cell, "shop") != shop_key:
			continue
		if _has_cashier_at_checkout(checkout_cell):
			return true
	return false


func _room_key_to_anchor(room_key: String) -> Vector2i:
	if room_key == "":
		return Vector2i(-1, -1)
	var parts: PackedStringArray = room_key.split(":")
	if parts.size() != 2:
		return Vector2i(-1, -1)
	var coords: PackedStringArray = parts[1].split(",")
	if coords.size() != 2:
		return Vector2i(-1, -1)
	return Vector2i(int(coords[0]), int(coords[1]))


func _update_talents(delta_scaled: float) -> void:
	for talent in talents:
		var node: SimCharacter = talent["node"]
		var booth_cell: Vector2i = talent.get("assigned_booth", Vector2i(-1, -1))
		if booth_cell.x < 0:
			continue
		var booth_summary: Dictionary = world.get_recording_booth_summary(booth_cell)
		if not bool(booth_summary.get("has_requirements", false)):
			continue
		var work_cell: Vector2i = booth_summary.get("work_cell", Vector2i(-1, -1))
		if work_cell.x < 0:
			continue
		var current_cell: Vector2i = world.get_character_cell(node)
		if current_cell != work_cell:
			if node.path_points.is_empty():
				world.assign_character_destination(node, work_cell)
			continue
		talent["task"] = "recording_booth"
		var productivity: float = float(talent.get("recording_skill", 1)) * 0.25
		if bool(booth_summary.get("fully_padded", false)):
			productivity *= 1.15
		recording_value_progress += productivity * delta_scaled
	while recording_value_progress >= 10.0:
		recording_value_progress -= 10.0
		_add_income("recording", 25)
		reputation += 1
	company_level = maxi(1, 1 + int(reputation / 100))


func _assign_builder_job(worker: Dictionary) -> void:
	var node: SimCharacter = worker["node"]
	var current_cell: Vector2i = world.get_character_cell(node)
	var claimed_cells: Array[Vector2i] = []
	for other in workers:
		if other == worker:
			continue
		var other_target: Vector2i = other.get("job_target", Vector2i(-1, -1))
		if other_target.x >= 0:
			claimed_cells.append(other_target)
	var job: Dictionary = world.get_nearest_blueprint_job(current_cell, claimed_cells)
	if job.is_empty() and not claimed_cells.is_empty():
		# All unclaimed jobs are unreachable; share a job with another builder as fallback.
		job = world.get_nearest_blueprint_job(current_cell)
	if job.is_empty():
		worker["job_target"] = Vector2i(-1, -1)
		worker["job_stand"] = Vector2i(-1, -1)
		worker["job_cooldown"] = 1.0
		_recover_builder_if_inside_wall(worker)
		return
	worker["job_target"] = job["target_cell"]
	worker["job_stand"] = job["stand_cell"]
	worker["travel_timer"] = 0.0
	worker["job_cooldown"] = 0.0
	world.assign_character_destination(node, worker["job_stand"])


func _recover_builder_if_inside_wall(worker: Dictionary) -> void:
	var node: SimCharacter = worker["node"]
	var actual_cell: Vector2i = world.screen_to_cell(node.global_position)
	if world.is_cell_walkable(actual_cell):
		return
	var recovery_cell: Vector2i = world.get_nearest_walkable_cell(actual_cell)
	if recovery_cell.x >= 0:
		node.position = world.cell_center(recovery_cell)
		node.path_points.clear()


func _assign_janitor_job(worker: Dictionary) -> void:
	var node: SimCharacter = worker["node"]
	var current_cell: Vector2i = world.get_character_cell(node)
	var job: Dictionary = world.get_nearest_dirty_job(current_cell)
	if job.is_empty():
		worker["job_target"] = Vector2i(-1, -1)
		worker["job_stand"] = Vector2i(-1, -1)
		return
	worker["job_target"] = job["target_cell"]
	worker["job_stand"] = job["target_cell"]
	world.assign_character_destination(node, worker["job_target"])


func _try_assign_selected_talent_to_booth(cell: Vector2i) -> void:
	if selected_entity.is_empty() or bool(selected_entity.get("is_worker", true)):
		return
	var room_cells: Array[Vector2i] = world.get_designated_room_cells(cell, "recording_booth")
	if room_cells.is_empty():
		return
	var entry: Dictionary = selected_entity["entry"]
	entry["assigned_booth"] = cell
	entry["task"] = "recording_booth"


func _try_open_talent_booth_context(cell: Vector2i, screen_position: Vector2) -> bool:
	if selected_entity.is_empty() or bool(selected_entity.get("is_worker", true)):
		return false
	var room_cells: Array[Vector2i] = world.get_designated_room_cells(cell, "recording_booth")
	if room_cells.is_empty():
		return false
	var entry: Dictionary = selected_entity["entry"]
	var assigned_booth: Vector2i = entry.get("assigned_booth", Vector2i(-1, -1))
	var is_assigned_here: bool = assigned_booth == cell
	pending_talent_context_booth = cell
	hud.show_talent_context_menu(screen_position, is_assigned_here, loc)
	return true


func _on_talent_context_action(action_id: String) -> void:
	if selected_entity.is_empty() or bool(selected_entity.get("is_worker", true)):
		return
	var entry: Dictionary = selected_entity["entry"]
	if action_id == "assign_booth":
		_try_assign_selected_talent_to_booth(pending_talent_context_booth)
	elif action_id == "unassign_booth":
		var assigned_booth: Vector2i = entry.get("assigned_booth", Vector2i(-1, -1))
		if assigned_booth == pending_talent_context_booth:
			entry["assigned_booth"] = Vector2i(-1, -1)
			entry["task"] = "idle"
	_refresh_ui()


func _reassign_office_chairs() -> void:
	var available_chairs: Array[Vector2i] = world.get_cells_with_chairs("office")
	for worker in workers:
		worker["assigned_chair"] = Vector2i(-1, -1)
	var chair_index: int = 0
	for worker in workers:
		if String(worker.get("role_id", "")) != "researcher":
			continue
		if chair_index >= available_chairs.size():
			break
		worker["assigned_chair"] = available_chairs[chair_index]
		chair_index += 1


func _get_research_work_cell(worker: Dictionary) -> Vector2i:
	var chair_cell: Vector2i = worker.get("assigned_chair", Vector2i(-1, -1))
	if chair_cell.x >= 0:
		return chair_cell
	var office_cells: Array[Vector2i] = world.get_cells_in_designation("office")
	if office_cells.is_empty():
		return Vector2i(-1, -1)
	var node: SimCharacter = worker["node"]
	var current_cell: Vector2i = world.get_character_cell(node)
	var best_cell: Vector2i = office_cells[0]
	var best_distance: int = 999999
	for office_cell in office_cells:
		var distance: int = absi(office_cell.x - current_cell.x) + absi(office_cell.y - current_cell.y)
		if distance < best_distance:
			best_distance = distance
			best_cell = office_cell
	return best_cell


func _finish_day() -> void:
	current_day += 1
	current_month_day += 1
	finance_stats["today_income"] = 0
	finance_stats["today_expenses"] = 0
	finance_stats["net_today"] = 0
	if current_month_day > 30:
		current_month_day = 1
		var payroll: int = _calculate_monthly_payroll()
		_add_expense("payroll", payroll)
		finance_stats["month_income"] = 0
		finance_stats["month_expenses"] = 0
		finance_stats["net_month"] = 0
	var research_sum: int = 0
	for worker in workers:
		research_sum += int(worker.get("research_skill", 0))
	reputation += int(research_sum / 3)
	company_level = maxi(1, 1 + int(reputation / 100))
	_refresh_ui()


func _calculate_monthly_payroll() -> int:
	var total: int = 0
	for worker in workers:
		total += int(worker.get("salary", 0))
	for talent in talents:
		total += int(talent.get("salary", 0))
	return total


func _update_camera(delta: float) -> void:
	var move_direction: Vector2 = Vector2.ZERO
	if Input.is_key_pressed(KEY_W):
		move_direction.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		move_direction.y += 1.0
	if Input.is_key_pressed(KEY_A):
		move_direction.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		move_direction.x += 1.0
	if move_direction != Vector2.ZERO:
		camera_2d.position += move_direction.normalized() * 2200.0 * delta


func _set_camera_zoom(value: float) -> void:
	camera_2d.zoom = Vector2(value, value)


func _format_time_of_day() -> String:
	var normalized: float = sim_time / seconds_per_day
	var minutes_total: int = int(round(normalized * 24.0 * 60.0))
	var hours: int = int(minutes_total / 60) % 24
	var minutes: int = minutes_total % 60
	return "%02d:%02d" % [hours, minutes]


func _reset_finance_stats() -> void:
	finance_stats = {
		"today_income": 0,
		"today_expenses": 0,
		"month_income": 0,
		"month_expenses": 0,
		"lifetime_income": 0,
		"lifetime_expenses": 0,
		"recording_income": 0,
		"shop_sales_income": 0,
		"payroll_expense": 0,
		"last_payroll": 0,
		"net_today": 0,
		"net_month": 0,
		"net_lifetime": 0,
	}


func _add_income(source: String, amount: int) -> void:
	money += amount
	finance_stats["today_income"] = int(finance_stats.get("today_income", 0)) + amount
	finance_stats["month_income"] = int(finance_stats.get("month_income", 0)) + amount
	finance_stats["lifetime_income"] = int(finance_stats.get("lifetime_income", 0)) + amount
	if source == "recording":
		finance_stats["recording_income"] = int(finance_stats.get("recording_income", 0)) + amount
	elif source == "shop_sales":
		finance_stats["shop_sales_income"] = int(finance_stats.get("shop_sales_income", 0)) + amount
	_update_finance_net_values()


func _add_expense(source: String, amount: int) -> void:
	money -= amount
	finance_stats["today_expenses"] = int(finance_stats.get("today_expenses", 0)) + amount
	finance_stats["month_expenses"] = int(finance_stats.get("month_expenses", 0)) + amount
	finance_stats["lifetime_expenses"] = int(finance_stats.get("lifetime_expenses", 0)) + amount
	if source == "payroll":
		finance_stats["payroll_expense"] = int(finance_stats.get("payroll_expense", 0)) + amount
		finance_stats["last_payroll"] = amount
	_update_finance_net_values()


func _update_finance_net_values() -> void:
	finance_stats["net_today"] = int(finance_stats.get("today_income", 0)) - int(finance_stats.get("today_expenses", 0))
	finance_stats["net_month"] = int(finance_stats.get("month_income", 0)) - int(finance_stats.get("month_expenses", 0))
	finance_stats["net_lifetime"] = int(finance_stats.get("lifetime_income", 0)) - int(finance_stats.get("lifetime_expenses", 0))


func _sync_character_time_scale() -> void:
	var active_scale: float = _get_active_time_scale()
	for worker in workers:
		var node: SimCharacter = worker.get("node", null)
		if node != null:
			node.set_simulation_speed(active_scale)
	for talent in talents:
		var talent_node: SimCharacter = talent.get("node", null)
		if talent_node != null:
			talent_node.set_simulation_speed(active_scale)
	for customer in customers:
		var customer_node: SimCharacter = customer.get("node", null)
		if customer_node != null:
			customer_node.set_simulation_speed(active_scale)


func _get_active_time_scale() -> float:
	if is_paused:
		return 0.0
	return time_scales[speed_index]


func _refresh_ui() -> void:
	var stats_text: String = "%s | %s | %s | %s | %s" % [
		loc.translate_key("hud.money", {"amount": money}),
		loc.translate_key("hud.day", {"day": current_day}),
		loc.translate_key("hud.level", {"level": company_level}),
		"%s / %s" % [
			loc.translate_key("hud.staff", {"count": workers.size()}),
			loc.translate_key("hud.talents", {"count": talents.size()}),
		],
		loc.translate_key("hud.room_summary", {
			"office": world.count_designation("office"),
			"bathroom": world.count_designation("bathroom"),
			"storage": world.count_designation("storage"),
			"shop": world.count_designation("shop"),
			"recording_booth": world.count_designation("recording_booth"),
		}),
	]
	var time_text: String = "%s | %s | %s" % [
		loc.translate_key("hud.time", {"time": _format_time_of_day(), "speed": "Paused" if is_paused else "x%s" % int(time_scales[speed_index])}),
		loc.translate_key("hud.payroll", {"amount": _calculate_monthly_payroll()}),
		_mode_text(),
	]
	var context_title_text: String = loc.translate_key("hud.selected.none")
	var context_body_text: String = ""
	if not selected_entity.is_empty():
		var entry: Dictionary = selected_entity["entry"]
		if bool(selected_entity.get("is_worker", false)):
			context_title_text = "%s (%s)" % [entry["name"], loc.translate_key(entry["role_key"])]
			var chair_cell: Vector2i = entry.get("assigned_chair", Vector2i(-1, -1))
			var chair_text: String = "-"
			if chair_cell.x >= 0:
				chair_text = "(%s, %s)" % [chair_cell.x, chair_cell.y]
			var current_job: String = String(entry.get("role_id", ""))
			var dirt_target: Vector2i = entry.get("job_target", Vector2i(-1, -1))
			var job_text: String = current_job
			if current_job == "janitor" and dirt_target.x >= 0:
				job_text = "%s (%s, %s)" % [current_job, dirt_target.x, dirt_target.y]
			context_body_text = "%s: %s\n%s: %s\n%s: %s\nSalary: %s\n%s" % [
				loc.translate_key("stat.research"), entry.get("research_skill", 0),
				loc.translate_key("stat.build"), entry.get("build_skill", 0),
				loc.translate_key("stat.clean"), entry.get("clean_skill", 0),
				entry.get("salary", 0),
				loc.translate_key("hud.worker_assignment", {"value": chair_text}),
			]
		else:
			context_title_text = entry.get("name", "")
			var assigned_booth: Vector2i = entry.get("assigned_booth", Vector2i(-1, -1))
			var booth_text: String = "-"
			if assigned_booth.x >= 0:
				booth_text = "(%s, %s)" % [assigned_booth.x, assigned_booth.y]
			context_body_text = "%s\nRecording: %s\nContract: %s\nBooth: %s" % [
				loc.translate_key("hud.selected.talent", {"name": entry.get("name", ""), "task": String(entry.get("task", "idle"))}),
				entry.get("recording_skill", 0),
				entry.get("salary", 0),
				booth_text,
			]
	var active_research_id: String = String(research_state.get("active_id", ""))
	var research_progress_value: float = 0.0
	var research_progress_text: String = loc.translate_key("research.none")
	var research_description_text: String = loc.translate_key(research_definitions["chairs"]["description_key"])
	var start_research_text: String = loc.translate_key("button.research.start")
	if active_research_id != "":
		var def: Dictionary = research_definitions[active_research_id]
		var cost: float = float(def["cost"])
		var progress: float = float(research_state.get("progress", 0.0))
		research_progress_value = (progress / cost) * 100.0
		research_progress_text = "%s %s%%" % [loc.translate_key(def["name_key"]), int(research_progress_value)]
		research_description_text = loc.translate_key(def["description_key"])
	elif bool(unlocked_features.get("chairs", false)):
		research_progress_value = 100.0
		research_progress_text = loc.translate_key("research.completed")
	var candidate_button_texts: Array[String] = []
	for candidate in recruit_candidates:
		candidate_button_texts.append(loc.translate_key("recruit.candidate", {
			"name": candidate["name"],
			"role": loc.translate_key(candidate["role_key"]),
			"research": candidate["research_skill"],
			"build": candidate["build_skill"],
			"clean": candidate["clean_skill"],
			"salary": candidate["salary"],
		}))
	var talent_candidate_button_texts: Array[String] = []
	for candidate in talent_candidates:
		talent_candidate_button_texts.append("%s | Recording %s | Contract $%s" % [
			candidate["name"],
			candidate["recording_skill"],
			candidate["salary"],
		])
	var finance_body_text: String = "%s: $%s\n%s: $%s\n%s: $%s\n\n%s: $%s\n%s: $%s\n%s: $%s\n\n%s: $%s\n%s: $%s\n%s: $%s\n\n%s: $%s\n%s: $%s\n%s: $%s\n%s: $%s\n%s: $%s" % [
		loc.translate_key("finance.today_income"), int(finance_stats.get("today_income", 0)),
		loc.translate_key("finance.today_expenses"), int(finance_stats.get("today_expenses", 0)),
		loc.translate_key("finance.today_net"), int(finance_stats.get("net_today", 0)),
		loc.translate_key("finance.month_income"), int(finance_stats.get("month_income", 0)),
		loc.translate_key("finance.month_expenses"), int(finance_stats.get("month_expenses", 0)),
		loc.translate_key("finance.month_net"), int(finance_stats.get("net_month", 0)),
		loc.translate_key("finance.lifetime_income"), int(finance_stats.get("lifetime_income", 0)),
		loc.translate_key("finance.lifetime_expenses"), int(finance_stats.get("lifetime_expenses", 0)),
		loc.translate_key("finance.lifetime_net"), int(finance_stats.get("net_lifetime", 0)),
		loc.translate_key("finance.recording_income"), int(finance_stats.get("recording_income", 0)),
		loc.translate_key("finance.shop_sales"), int(finance_stats.get("shop_sales_income", 0)),
		loc.translate_key("finance.last_payroll"), int(finance_stats.get("last_payroll", 0)),
		loc.translate_key("finance.monthly_payroll_due"), _calculate_monthly_payroll(),
		loc.translate_key("finance.active_talents"), talents.size(),
	]
	hud.update_ui({
		"stats_text": stats_text,
		"time_text": time_text,
		"context_title": context_title_text,
		"context_body": context_body_text,
		"research_menu_text": loc.translate_key("menu.research"),
		"recruit_menu_text": loc.translate_key("menu.recruit"),
		"talent_menu_text": loc.translate_key("menu.talent"),
		"areas_tab_text": loc.translate_key("panel.areas"),
		"structures_tab_text": loc.translate_key("panel.structures"),
		"furniture_tab_text": loc.translate_key("panel.furniture"),
		"research_window_title": loc.translate_key("menu.research"),
		"research_description_text": research_description_text,
		"research_progress_value": research_progress_value,
		"research_progress_text": research_progress_text,
		"start_research_text": start_research_text,
		"close_text": loc.translate_key("button.close"),
		"recruit_window_title": loc.translate_key("menu.recruit.title"),
		"researcher_role_text": loc.translate_key("button.recruit.researcher"),
		"janitor_role_text": loc.translate_key("button.recruit.janitor"),
		"builder_role_text": loc.translate_key("button.recruit.builder"),
		"staff_role_text": loc.translate_key("button.recruit.staff"),
		"cashier_role_text": loc.translate_key("button.recruit.cashier"),
		"recruit_info_text": loc.translate_key("recruit.info") if recruit_candidates.is_empty() else "",
		"candidate_button_texts": candidate_button_texts,
		"talent_window_title": loc.translate_key("menu.talent"),
		"talent_info_text": loc.translate_key("talent.info") if talent_candidates.is_empty() else "",
		"talent_candidate_button_texts": talent_candidate_button_texts,
		"finance_menu_text": loc.translate_key("menu.finance"),
		"finance_window_title": loc.translate_key("menu.finance"),
		"finance_body_text": finance_body_text,
		"pause_button_text": ">" if is_paused else "||",
	}, loc)


func _mode_text() -> String:
	match build_mode:
		"office":
			return loc.translate_key("mode.designate_office")
		"bathroom":
			return loc.translate_key("mode.designate_bathroom")
		"storage":
			return loc.translate_key("mode.designate_storage")
		"shop":
			return loc.translate_key("mode.designate_shop")
		"recording_booth":
			return loc.translate_key("mode.designate_recording_booth")
		"clear_area":
			return loc.translate_key("mode.clear_area")
		"wall":
			return loc.translate_key("mode.wall")
		"door":
			return loc.translate_key("mode.door")
		"floor":
			return loc.translate_key("mode.floor")
		"chair":
			return loc.translate_key("mode.chair")
		"table":
			return loc.translate_key("mode.table")
		"wall_pad":
			return loc.translate_key("mode.wall_pad")
		"shelf":
			return loc.translate_key("mode.shelf")
		"droppoint":
			return loc.translate_key("mode.droppoint")
		"checkout":
			return loc.translate_key("mode.checkout")
		"erase":
			return loc.translate_key("mode.erase")
	return loc.translate_key("mode.none")


func _log_blueprint(cell: Vector2i) -> void:
	var blueprint_type: String = world.get_blueprint_type(cell)
	var key: String = "blueprint.%s" % blueprint_type
	if blueprint_type == "":
		return
	# Placeholder for future in-world notifications.
	var _text: String = loc.translate_key("log.blueprint_created", {"name": loc.translate_key(key), "x": cell.x, "y": cell.y})
