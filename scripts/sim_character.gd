extends Node2D
class_name SimCharacter

var character_name := ""
var character_kind := ""
var role_key := ""
var task_key := "task.idle"
var target_position := Vector2.ZERO
var move_speed := 48.0
var selected := false

var sprite: Sprite2D
var label: Label


func _ready() -> void:
	_ensure_nodes()


func _ensure_nodes() -> void:
	if sprite != null:
		return
	sprite = Sprite2D.new()
	label = Label.new()
	add_child(sprite)
	add_child(label)
	label.position = Vector2(-44, 26)
	label.size = Vector2(88, 22)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)


func configure(display_name: String, kind: String, texture: Texture2D, label_color: Color) -> void:
	_ensure_nodes()
	character_name = display_name
	character_kind = kind
	sprite.texture = texture
	sprite.centered = true
	if texture != null and texture.get_size().x > 0.0:
		var largest_axis := max(texture.get_size().x, texture.get_size().y)
		var scale_factor := 28.0 / largest_axis
		sprite.scale = Vector2.ONE * scale_factor
	label.text = display_name
	label.modulate = label_color
	target_position = position
	queue_redraw()


func set_selected(value: bool) -> void:
	selected = value
	queue_redraw()


func set_task(task: String) -> void:
	task_key = task


func _process(delta: float) -> void:
	position = position.move_toward(target_position, move_speed * delta)


func _draw() -> void:
	if selected:
		draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 36, Color(1.0, 0.92, 0.3), 3.0)
