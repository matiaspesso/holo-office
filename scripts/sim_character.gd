extends Node2D
class_name SimCharacter

@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $NameLabel

var character_name: String = ""
var character_kind: String = ""
var role_key: String = ""
var task_key: String = "task.idle"
var target_position: Vector2 = Vector2.ZERO
var move_speed: float = 280.0
var simulation_speed: float = 1.0
var selected: bool = false
var path_points: Array[Vector2] = []


func configure(display_name: String, kind: String, texture: Texture2D, label_color: Color) -> void:
	character_name = display_name
	character_kind = kind
	sprite.texture = texture
	sprite.centered = true
	if texture != null and texture.get_size().x > 0.0:
		var largest_axis: float = maxf(texture.get_size().x, texture.get_size().y)
		var scale_factor: float = 96.0 / largest_axis
		sprite.scale = Vector2.ONE * scale_factor
	label.text = display_name
	label.modulate = label_color
	label.position = Vector2(-96, 76)
	label.size = Vector2(192, 32)
	label.add_theme_font_size_override("font_size", 18)
	target_position = position
	path_points.clear()
	queue_redraw()


func set_selected(value: bool) -> void:
	selected = value
	queue_redraw()


func set_task(task: String) -> void:
	task_key = task


func set_path(points: Array[Vector2]) -> void:
	path_points = points.duplicate()
	if not path_points.is_empty():
		target_position = path_points[0]


func set_simulation_speed(value: float) -> void:
	simulation_speed = maxf(0.0, value)


func _process(delta: float) -> void:
	if path_points.is_empty():
		return
	target_position = path_points[0]
	position = position.move_toward(target_position, move_speed * delta * simulation_speed)
	if position.distance_to(target_position) <= 1.0:
		position = target_position
		path_points.remove_at(0)
		if not path_points.is_empty():
			target_position = path_points[0]


func _draw() -> void:
	if selected:
		draw_arc(Vector2.ZERO, 60.0, 0.0, TAU, 48, Color(1.0, 0.92, 0.3), 5.0)
