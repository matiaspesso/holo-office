extends CanvasLayer
class_name GameHud

signal build_mode_selected(mode_name: String)
signal research_requested(research_id: String)
signal recruit_role_requested(role_id: String)
signal hire_candidate_requested(candidate_index: int)
signal hire_talent_candidate_requested(candidate_index: int)
signal talent_recruit_requested
signal talent_context_action(action_id: String)
signal area_context_action(action_id: String)
signal pause_toggled
signal speed_selected(speed_index: int)

@onready var research_menu_button: Button = $Root/TopBar/TopMargin/TopColumn/TopButtons/ResearchMenuButton
@onready var recruit_menu_button: Button = $Root/TopBar/TopMargin/TopColumn/TopButtons/RecruitMenuButton
@onready var talent_menu_button: Button = $Root/TopBar/TopMargin/TopColumn/TopButtons/TalentMenuButton
@onready var finance_menu_button: Button = $Root/TopBar/TopMargin/TopColumn/TopButtons/FinanceMenuButton
@onready var stats_label: Label = $Root/TopBar/TopMargin/TopColumn/StatsLabel
@onready var time_label: Label = $Root/TopBar/TopMargin/TopColumn/TimeLabel
@onready var pause_button: Button = $Root/TopBar/TopMargin/TopColumn/SpeedRow/PauseButton
@onready var speed1_button: Button = $Root/TopBar/TopMargin/TopColumn/SpeedRow/Speed1Button
@onready var speed2_button: Button = $Root/TopBar/TopMargin/TopColumn/SpeedRow/Speed2Button
@onready var speed3_button: Button = $Root/TopBar/TopMargin/TopColumn/SpeedRow/Speed3Button
@onready var speed4_button: Button = $Root/TopBar/TopMargin/TopColumn/SpeedRow/Speed4Button
@onready var context_title: Label = $Root/ContextPanel/ContextMargin/ContextColumn/ContextTitle
@onready var context_body: Label = $Root/ContextPanel/ContextMargin/ContextColumn/ContextBody
@onready var areas_tab_button: Button = $Root/BottomBar/BottomMargin/BottomColumn/TabButtons/AreasTabButton
@onready var structures_tab_button: Button = $Root/BottomBar/BottomMargin/BottomColumn/TabButtons/StructuresTabButton
@onready var furniture_tab_button: Button = $Root/BottomBar/BottomMargin/BottomColumn/TabButtons/FurnitureTabButton
@onready var areas_row: HBoxContainer = $Root/BottomBar/BottomMargin/BottomColumn/TabContent/AreasRow
@onready var structures_row: HBoxContainer = $Root/BottomBar/BottomMargin/BottomColumn/TabContent/StructuresRow
@onready var furniture_row: HBoxContainer = $Root/BottomBar/BottomMargin/BottomColumn/TabContent/FurnitureRow
@onready var office_button: Button = $Root/BottomBar/BottomMargin/BottomColumn/TabContent/AreasRow/OfficeButton
@onready var bathroom_button: Button = $Root/BottomBar/BottomMargin/BottomColumn/TabContent/AreasRow/BathroomButton
@onready var storage_button: Button = $Root/BottomBar/BottomMargin/BottomColumn/TabContent/AreasRow/StorageButton
@onready var shop_button: Button = $Root/BottomBar/BottomMargin/BottomColumn/TabContent/AreasRow/ShopButton
@onready var recording_booth_button: Button = $Root/BottomBar/BottomMargin/BottomColumn/TabContent/AreasRow/RecordingBoothButton
@onready var clear_area_button: Button = $Root/BottomBar/BottomMargin/BottomColumn/TabContent/AreasRow/ClearAreaButton
@onready var wall_button: Button = $Root/BottomBar/BottomMargin/BottomColumn/TabContent/StructuresRow/WallButton
@onready var door_button: Button = $Root/BottomBar/BottomMargin/BottomColumn/TabContent/StructuresRow/DoorButton
@onready var floor_button: Button = $Root/BottomBar/BottomMargin/BottomColumn/TabContent/StructuresRow/FloorButton
@onready var erase_button: Button = $Root/BottomBar/BottomMargin/BottomColumn/TabContent/StructuresRow/EraseButton
@onready var chair_button: Button = $Root/BottomBar/BottomMargin/BottomColumn/TabContent/FurnitureRow/ChairButton
@onready var table_button: Button = $Root/BottomBar/BottomMargin/BottomColumn/TabContent/FurnitureRow/TableButton
@onready var wall_pad_button: Button = $Root/BottomBar/BottomMargin/BottomColumn/TabContent/FurnitureRow/WallPadButton
@onready var shelf_button: Button = $Root/BottomBar/BottomMargin/BottomColumn/TabContent/FurnitureRow/ShelfButton
@onready var drop_point_button: Button = $Root/BottomBar/BottomMargin/BottomColumn/TabContent/FurnitureRow/DropPointButton
@onready var checkout_button: Button = $Root/BottomBar/BottomMargin/BottomColumn/TabContent/FurnitureRow/CheckoutButton
@onready var research_window: PanelContainer = $Root/ResearchWindow
@onready var research_title: Label = $Root/ResearchWindow/ResearchMargin/ResearchColumn/ResearchTitle
@onready var research_description: Label = $Root/ResearchWindow/ResearchMargin/ResearchColumn/ResearchDescription
@onready var research_progress_bar: ProgressBar = $Root/ResearchWindow/ResearchMargin/ResearchColumn/ResearchProgressBar
@onready var research_progress_label: Label = $Root/ResearchWindow/ResearchMargin/ResearchColumn/ResearchProgressLabel
@onready var start_research_button: Button = $Root/ResearchWindow/ResearchMargin/ResearchColumn/ResearchButtons/StartResearchButton
@onready var close_research_button: Button = $Root/ResearchWindow/ResearchMargin/ResearchColumn/ResearchButtons/CloseResearchButton
@onready var recruit_window: PanelContainer = $Root/RecruitWindow
@onready var recruit_title: Label = $Root/RecruitWindow/RecruitMargin/RecruitColumn/RecruitTitle
@onready var researcher_role_button: Button = $Root/RecruitWindow/RecruitMargin/RecruitColumn/RecruitRoleButtons/ResearcherRoleButton
@onready var janitor_role_button: Button = $Root/RecruitWindow/RecruitMargin/RecruitColumn/RecruitRoleButtons/JanitorRoleButton
@onready var builder_role_button: Button = $Root/RecruitWindow/RecruitMargin/RecruitColumn/RecruitRoleButtons/BuilderRoleButton
@onready var staff_role_button: Button = $Root/RecruitWindow/RecruitMargin/RecruitColumn/RecruitRoleButtons/StaffRoleButton
@onready var cashier_role_button: Button = $Root/RecruitWindow/RecruitMargin/RecruitColumn/RecruitRoleButtons/CashierRoleButton
@onready var recruit_info_label: Label = $Root/RecruitWindow/RecruitMargin/RecruitColumn/RecruitInfoLabel
@onready var candidate_buttons: Array[Button] = [
	$Root/RecruitWindow/RecruitMargin/RecruitColumn/CandidateButtons/CandidateButton0,
	$Root/RecruitWindow/RecruitMargin/RecruitColumn/CandidateButtons/CandidateButton1,
	$Root/RecruitWindow/RecruitMargin/RecruitColumn/CandidateButtons/CandidateButton2,
]
@onready var close_recruit_button: Button = $Root/RecruitWindow/RecruitMargin/RecruitColumn/CloseRecruitButton
@onready var talent_window: PanelContainer = $Root/TalentWindow
@onready var talent_title: Label = $Root/TalentWindow/TalentMargin/TalentColumn/TalentTitle
@onready var talent_info_label: Label = $Root/TalentWindow/TalentMargin/TalentColumn/TalentInfoLabel
@onready var talent_candidate_buttons: Array[Button] = [
	$Root/TalentWindow/TalentMargin/TalentColumn/TalentCandidateButtons/TalentCandidateButton0,
	$Root/TalentWindow/TalentMargin/TalentColumn/TalentCandidateButtons/TalentCandidateButton1,
	$Root/TalentWindow/TalentMargin/TalentColumn/TalentCandidateButtons/TalentCandidateButton2,
]
@onready var close_talent_button: Button = $Root/TalentWindow/TalentMargin/TalentColumn/CloseTalentButton
@onready var talent_context_menu: PopupMenu = $Root/TalentContextMenu
@onready var area_context_menu: PopupMenu = $Root/AreaContextMenu
@onready var finance_window: PanelContainer = $Root/FinanceWindow
@onready var finance_title: Label = $Root/FinanceWindow/FinanceMargin/FinanceColumn/FinanceTitle
@onready var finance_body: Label = $Root/FinanceWindow/FinanceMargin/FinanceColumn/FinanceBody
@onready var close_finance_button: Button = $Root/FinanceWindow/FinanceMargin/FinanceColumn/CloseFinanceButton

var current_tab: String = "areas"


func _ready() -> void:
	research_menu_button.pressed.connect(func() -> void:
		research_window.visible = not research_window.visible
		recruit_window.visible = false
	)
	recruit_menu_button.pressed.connect(func() -> void:
		recruit_window.visible = not recruit_window.visible
		research_window.visible = false
		talent_window.visible = false
		finance_window.visible = false
	)
	talent_menu_button.pressed.connect(func() -> void:
		talent_window.visible = not talent_window.visible
		research_window.visible = false
		recruit_window.visible = false
		finance_window.visible = false
		if talent_window.visible:
			talent_recruit_requested.emit()
	)
	finance_menu_button.pressed.connect(func() -> void:
		finance_window.visible = not finance_window.visible
		research_window.visible = false
		recruit_window.visible = false
		talent_window.visible = false
	)
	areas_tab_button.pressed.connect(func() -> void: _set_tab("areas"))
	pause_button.pressed.connect(func() -> void: pause_toggled.emit())
	speed1_button.pressed.connect(func() -> void: speed_selected.emit(0))
	speed2_button.pressed.connect(func() -> void: speed_selected.emit(1))
	speed3_button.pressed.connect(func() -> void: speed_selected.emit(2))
	speed4_button.pressed.connect(func() -> void: speed_selected.emit(3))
	structures_tab_button.pressed.connect(func() -> void: _set_tab("structures"))
	furniture_tab_button.pressed.connect(func() -> void: _set_tab("furniture"))
	office_button.pressed.connect(func() -> void: build_mode_selected.emit("office"))
	bathroom_button.pressed.connect(func() -> void: build_mode_selected.emit("bathroom"))
	storage_button.pressed.connect(func() -> void: build_mode_selected.emit("storage"))
	shop_button.pressed.connect(func() -> void: build_mode_selected.emit("shop"))
	recording_booth_button.pressed.connect(func() -> void: build_mode_selected.emit("recording_booth"))
	clear_area_button.pressed.connect(func() -> void: build_mode_selected.emit("clear_area"))
	wall_button.pressed.connect(func() -> void: build_mode_selected.emit("wall"))
	door_button.pressed.connect(func() -> void: build_mode_selected.emit("door"))
	floor_button.pressed.connect(func() -> void: build_mode_selected.emit("floor"))
	erase_button.pressed.connect(func() -> void: build_mode_selected.emit("erase"))
	chair_button.pressed.connect(func() -> void: build_mode_selected.emit("chair"))
	table_button.pressed.connect(func() -> void: build_mode_selected.emit("table"))
	wall_pad_button.pressed.connect(func() -> void: build_mode_selected.emit("wall_pad"))
	shelf_button.pressed.connect(func() -> void: build_mode_selected.emit("shelf"))
	drop_point_button.pressed.connect(func() -> void: build_mode_selected.emit("droppoint"))
	checkout_button.pressed.connect(func() -> void: build_mode_selected.emit("checkout"))
	start_research_button.pressed.connect(func() -> void: research_requested.emit("chairs"))
	close_research_button.pressed.connect(func() -> void: research_window.visible = false)
	researcher_role_button.pressed.connect(func() -> void: recruit_role_requested.emit("researcher"))
	janitor_role_button.pressed.connect(func() -> void: recruit_role_requested.emit("janitor"))
	builder_role_button.pressed.connect(func() -> void: recruit_role_requested.emit("builder"))
	staff_role_button.pressed.connect(func() -> void: recruit_role_requested.emit("staff"))
	cashier_role_button.pressed.connect(func() -> void: recruit_role_requested.emit("cashier"))
	for index in range(candidate_buttons.size()):
		var captured_index: int = index
		candidate_buttons[index].pressed.connect(func() -> void:
			hire_candidate_requested.emit(captured_index)
		)
	close_recruit_button.pressed.connect(func() -> void: recruit_window.visible = false)
	for index in range(talent_candidate_buttons.size()):
		var talent_index: int = index
		talent_candidate_buttons[index].pressed.connect(func() -> void:
			hire_talent_candidate_requested.emit(talent_index)
		)
	close_talent_button.pressed.connect(func() -> void: talent_window.visible = false)
	close_finance_button.pressed.connect(func() -> void: finance_window.visible = false)
	talent_context_menu.id_pressed.connect(_on_talent_context_menu_id_pressed)
	area_context_menu.id_pressed.connect(_on_area_context_menu_id_pressed)
	_set_tab("areas")


func update_ui(data: Dictionary, loc: HoloLocalization) -> void:
	stats_label.text = String(data.get("stats_text", ""))
	time_label.text = String(data.get("time_text", ""))
	pause_button.text = String(data.get("pause_button_text", "Pause"))
	speed1_button.text = "1"
	speed2_button.text = "2"
	speed3_button.text = "3"
	speed4_button.text = "4"
	context_title.text = String(data.get("context_title", ""))
	context_body.text = String(data.get("context_body", ""))
	research_menu_button.text = String(data.get("research_menu_text", "Research"))
	recruit_menu_button.text = String(data.get("recruit_menu_text", "Hire Workers"))
	talent_menu_button.text = String(data.get("talent_menu_text", "Sign Talent"))
	finance_menu_button.text = String(data.get("finance_menu_text", "Finances"))
	areas_tab_button.text = String(data.get("areas_tab_text", "Areas"))
	structures_tab_button.text = String(data.get("structures_tab_text", "Structures"))
	furniture_tab_button.text = String(data.get("furniture_tab_text", "Furniture"))
	office_button.text = loc.translate_key("button.mode.office")
	bathroom_button.text = loc.translate_key("button.mode.bathroom")
	storage_button.text = loc.translate_key("button.mode.storage")
	shop_button.text = loc.translate_key("button.mode.shop")
	recording_booth_button.text = loc.translate_key("button.mode.recording_booth")
	clear_area_button.text = loc.translate_key("button.mode.clear_area")
	wall_button.text = loc.translate_key("button.mode.wall")
	door_button.text = loc.translate_key("button.mode.door")
	floor_button.text = loc.translate_key("button.mode.floor")
	erase_button.text = loc.translate_key("button.mode.erase")
	chair_button.text = loc.translate_key("button.mode.chair")
	table_button.text = loc.translate_key("button.mode.table")
	wall_pad_button.text = loc.translate_key("button.mode.wall_pad")
	shelf_button.text = loc.translate_key("button.mode.shelf")
	drop_point_button.text = loc.translate_key("button.mode.droppoint")
	checkout_button.text = loc.translate_key("button.mode.checkout")
	research_title.text = String(data.get("research_window_title", "Research"))
	research_description.text = String(data.get("research_description_text", ""))
	research_progress_bar.value = float(data.get("research_progress_value", 0.0))
	research_progress_label.text = String(data.get("research_progress_text", ""))
	start_research_button.text = String(data.get("start_research_text", "Start"))
	close_research_button.text = String(data.get("close_text", "Close"))
	recruit_title.text = String(data.get("recruit_window_title", "Hire Workers"))
	researcher_role_button.text = String(data.get("researcher_role_text", "Researcher"))
	janitor_role_button.text = String(data.get("janitor_role_text", "Janitor"))
	builder_role_button.text = String(data.get("builder_role_text", "Constructor"))
	staff_role_button.text = String(data.get("staff_role_text", "Staff"))
	cashier_role_button.text = String(data.get("cashier_role_text", "Cashier"))
	recruit_info_label.text = String(data.get("recruit_info_text", ""))
	var candidate_texts: Array = data.get("candidate_button_texts", [])
	for index in range(candidate_buttons.size()):
		var button: Button = candidate_buttons[index]
		if index < candidate_texts.size():
			button.text = String(candidate_texts[index])
			button.visible = true
			button.disabled = false
		else:
			button.text = ""
			button.visible = false
	close_recruit_button.text = String(data.get("close_text", "Close"))
	talent_title.text = String(data.get("talent_window_title", "Sign Talent"))
	talent_info_label.text = String(data.get("talent_info_text", ""))
	var talent_candidate_texts: Array = data.get("talent_candidate_button_texts", [])
	for index in range(talent_candidate_buttons.size()):
		var talent_button: Button = talent_candidate_buttons[index]
		if index < talent_candidate_texts.size():
			talent_button.text = String(talent_candidate_texts[index])
			talent_button.visible = true
			talent_button.disabled = false
		else:
			talent_button.text = ""
			talent_button.visible = false
	close_talent_button.text = String(data.get("close_text", "Close"))
	finance_title.text = String(data.get("finance_window_title", "Finances"))
	finance_body.text = String(data.get("finance_body_text", ""))
	close_finance_button.text = String(data.get("close_text", "Close"))


func set_window_visibility(show_research: bool, show_recruit: bool) -> void:
	research_window.visible = show_research
	recruit_window.visible = show_recruit
	talent_window.visible = false
	finance_window.visible = false


func show_talent_context_menu(screen_position: Vector2, is_assigned_here: bool, loc: HoloLocalization) -> void:
	talent_context_menu.clear()
	if is_assigned_here:
		talent_context_menu.add_item(loc.translate_key("button.talent.unassign_booth"), 1)
	else:
		talent_context_menu.add_item(loc.translate_key("button.talent.assign_booth"), 0)
	talent_context_menu.position = Vector2i(screen_position)
	talent_context_menu.popup()


func _on_talent_context_menu_id_pressed(id: int) -> void:
	if id == 0:
		talent_context_action.emit("assign_booth")
	elif id == 1:
		talent_context_action.emit("unassign_booth")


func show_area_context_menu(screen_position: Vector2, mode_name: String, loc: HoloLocalization) -> void:
	area_context_menu.clear()
	if mode_name == "shop_link":
		area_context_menu.add_item(loc.translate_key("button.shop.link_storage"), 0)
	elif mode_name == "shop_unlink":
		area_context_menu.add_item(loc.translate_key("button.shop.unlink_storage"), 1)
	area_context_menu.position = Vector2i(screen_position)
	area_context_menu.popup()


func _on_area_context_menu_id_pressed(id: int) -> void:
	if id == 0:
		area_context_action.emit("shop_link")
	elif id == 1:
		area_context_action.emit("shop_unlink")


func _set_tab(tab_name: String) -> void:
	current_tab = tab_name
	areas_row.visible = tab_name == "areas"
	structures_row.visible = tab_name == "structures"
	furniture_row.visible = tab_name == "furniture"
