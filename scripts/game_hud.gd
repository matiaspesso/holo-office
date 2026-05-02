extends CanvasLayer
class_name GameHud

signal build_mode_selected(mode_name: String)
signal pause_toggled
signal speed_pressed
signal hire_worker_requested
signal hire_talent_requested
signal task_requested(task_key: String)
signal locale_requested(locale_code: String)

@onready var stats_label: Label = $Root/TopPanel/TopMargin/TopRow/StatsBox/StatsLabel
@onready var time_label: Label = $Root/TopPanel/TopMargin/TopRow/StatsBox/TimeLabel
@onready var room_label: Label = $Root/TopPanel/TopMargin/TopRow/StatsBox/RoomLabel
@onready var mode_label: Label = $Root/TopPanel/TopMargin/TopRow/InfoBox/ModeLabel
@onready var selected_label: Label = $Root/TopPanel/TopMargin/TopRow/InfoBox/SelectedLabel
@onready var instructions_label: Label = $Root/TopPanel/TopMargin/TopRow/InstructionsLabel
@onready var build_title: Label = $Root/SidePanel/SideMargin/SideColumn/BuildSection/BuildTitle
@onready var staff_title: Label = $Root/SidePanel/SideMargin/SideColumn/StaffSection/StaffTitle
@onready var assignment_title: Label = $Root/SidePanel/SideMargin/SideColumn/AssignmentSection/AssignmentTitle
@onready var language_title: Label = $Root/SidePanel/SideMargin/SideColumn/LanguageSection/LanguageTitle
@onready var log_title: Label = $Root/SidePanel/SideMargin/SideColumn/LogSection/LogTitle
@onready var worker_offer_label: Label = $Root/SidePanel/SideMargin/SideColumn/StaffSection/WorkerOfferLabel
@onready var talent_offer_label: Label = $Root/SidePanel/SideMargin/SideColumn/StaffSection/TalentOfferLabel
@onready var logs_label: RichTextLabel = $Root/SidePanel/SideMargin/SideColumn/LogSection/LogsLabel
@onready var pause_button: Button = $Root/SidePanel/SideMargin/SideColumn/BuildSection/TimeRow/PauseButton
@onready var speed_button: Button = $Root/SidePanel/SideMargin/SideColumn/BuildSection/TimeRow/SpeedButton
@onready var hire_worker_button: Button = $Root/SidePanel/SideMargin/SideColumn/StaffSection/HireWorkerButton
@onready var hire_talent_button: Button = $Root/SidePanel/SideMargin/SideColumn/StaffSection/HireTalentButton
@onready var wall_button: Button = $Root/SidePanel/SideMargin/SideColumn/BuildSection/BuildGrid/WallButton
@onready var door_button: Button = $Root/SidePanel/SideMargin/SideColumn/BuildSection/BuildGrid/DoorButton
@onready var floor_button: Button = $Root/SidePanel/SideMargin/SideColumn/BuildSection/BuildGrid/FloorButton
@onready var erase_button: Button = $Root/SidePanel/SideMargin/SideColumn/BuildSection/BuildGrid/EraseButton
@onready var office_button: Button = $Root/SidePanel/SideMargin/SideColumn/BuildSection/BuildGrid/OfficeButton
@onready var bathroom_button: Button = $Root/SidePanel/SideMargin/SideColumn/BuildSection/BuildGrid/BathroomButton
@onready var storage_button: Button = $Root/SidePanel/SideMargin/SideColumn/BuildSection/BuildGrid/StorageButton
@onready var stream_button: Button = $Root/SidePanel/SideMargin/SideColumn/AssignmentSection/StreamButton
@onready var concert_button: Button = $Root/SidePanel/SideMargin/SideColumn/AssignmentSection/ConcertButton
@onready var merch_button: Button = $Root/SidePanel/SideMargin/SideColumn/AssignmentSection/MerchButton
@onready var idle_button: Button = $Root/SidePanel/SideMargin/SideColumn/AssignmentSection/IdleButton
@onready var english_button: Button = $Root/SidePanel/SideMargin/SideColumn/LanguageSection/LanguageRow/EnglishButton
@onready var spanish_button: Button = $Root/SidePanel/SideMargin/SideColumn/LanguageSection/LanguageRow/SpanishButton
@onready var japanese_button: Button = $Root/SidePanel/SideMargin/SideColumn/LanguageSection/LanguageRow/JapaneseButton


func _ready() -> void:
	wall_button.pressed.connect(func() -> void: build_mode_selected.emit("wall"))
	door_button.pressed.connect(func() -> void: build_mode_selected.emit("door"))
	floor_button.pressed.connect(func() -> void: build_mode_selected.emit("floor"))
	erase_button.pressed.connect(func() -> void: build_mode_selected.emit("erase"))
	office_button.pressed.connect(func() -> void: build_mode_selected.emit("office"))
	bathroom_button.pressed.connect(func() -> void: build_mode_selected.emit("bathroom"))
	storage_button.pressed.connect(func() -> void: build_mode_selected.emit("storage"))
	pause_button.pressed.connect(func() -> void: pause_toggled.emit())
	speed_button.pressed.connect(func() -> void: speed_pressed.emit())
	hire_worker_button.pressed.connect(func() -> void: hire_worker_requested.emit())
	hire_talent_button.pressed.connect(func() -> void: hire_talent_requested.emit())
	stream_button.pressed.connect(func() -> void: task_requested.emit("task.stream"))
	concert_button.pressed.connect(func() -> void: task_requested.emit("task.concert"))
	merch_button.pressed.connect(func() -> void: task_requested.emit("task.merch"))
	idle_button.pressed.connect(func() -> void: task_requested.emit("task.idle"))
	english_button.pressed.connect(func() -> void: locale_requested.emit("en"))
	spanish_button.pressed.connect(func() -> void: locale_requested.emit("es"))
	japanese_button.pressed.connect(func() -> void: locale_requested.emit("ja"))


func update_texts(data: Dictionary, loc: HoloLocalization) -> void:
	stats_label.text = data["stats_text"]
	time_label.text = data["time_text"]
	room_label.text = data["room_text"]
	mode_label.text = data["mode_text"]
	selected_label.text = data["selected_text"]
	instructions_label.text = loc.translate_key("hud.instructions")
	worker_offer_label.text = data["worker_offer_text"]
	talent_offer_label.text = data["talent_offer_text"]
	pause_button.text = data["pause_text"]
	speed_button.text = data["speed_text"]
	hire_worker_button.text = loc.translate_key("button.hire_worker")
	hire_talent_button.text = loc.translate_key("button.hire_talent")
	build_title.text = loc.translate_key("panel.build")
	staff_title.text = loc.translate_key("panel.staff")
	assignment_title.text = loc.translate_key("panel.assignment")
	language_title.text = loc.translate_key("panel.language")
	log_title.text = loc.translate_key("panel.logs")
	wall_button.text = loc.translate_key("button.mode.wall")
	door_button.text = loc.translate_key("button.mode.door")
	floor_button.text = loc.translate_key("button.mode.floor")
	erase_button.text = loc.translate_key("button.mode.erase")
	office_button.text = loc.translate_key("button.mode.office")
	bathroom_button.text = loc.translate_key("button.mode.bathroom")
	storage_button.text = loc.translate_key("button.mode.storage")
	stream_button.text = loc.translate_key("button.task.stream")
	concert_button.text = loc.translate_key("button.task.concert")
	merch_button.text = loc.translate_key("button.task.merch")
	idle_button.text = loc.translate_key("button.task.idle")


func update_logs(entries: Array[String]) -> void:
	logs_label.clear()
	var combined := ""
	for entry in entries:
		combined += "- %s\n" % entry
	logs_label.append_text(combined)
