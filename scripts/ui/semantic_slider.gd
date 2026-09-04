class_name SemanticSlider
extends HSlider

const Palette := preload("res://scripts/ui/ui_palette.gd")
const ThemeController := preload("res://scripts/ui/ui_theme_controller.gd")

var semantic_context := Palette.WARM_ARCHIVE
var hovered := false
var rail_normal: StyleBoxFlat
var rail_hover: StyleBoxFlat
var rail_disabled: StyleBoxFlat
var fill_normal: StyleBoxFlat
var fill_hover: StyleBoxFlat
var fill_disabled: StyleBoxFlat
var grabber_normal: Texture2D
var grabber_hover: Texture2D
var grabber_disabled: Texture2D
var focus_style: StyleBoxFlat


func _ready() -> void:
	theme_type_variation = "SemanticSlider"
	focus_mode = Control.FOCUS_ALL
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))
	resized.connect(queue_redraw)
	_cache_resources()
	_apply_visual_state()


func set_semantic_context(context: String) -> void:
	semantic_context = Palette.normalized_context(context)
	theme = ThemeController.theme_for(semantic_context)
	_cache_resources()
	_apply_visual_state()
	queue_redraw()


func set_semantic_enabled(value: bool) -> void:
	editable = value
	focus_mode = Control.FOCUS_ALL if value else Control.FOCUS_NONE
	_apply_visual_state()
	queue_redraw()


func _set_hovered(value: bool) -> void:
	hovered = value
	_apply_visual_state()


func _cache_resources() -> void:
	rail_normal = ThemeController.style_for(semantic_context, "slider_rail", "normal")
	rail_hover = ThemeController.style_for(semantic_context, "slider_rail", "hover")
	rail_disabled = ThemeController.style_for(semantic_context, "slider_rail", "disabled")
	fill_normal = ThemeController.style_for(semantic_context, "slider_fill", "normal")
	fill_hover = ThemeController.style_for(semantic_context, "slider_fill", "hover")
	fill_disabled = ThemeController.style_for(semantic_context, "slider_fill", "disabled")
	grabber_normal = ThemeController.texture_for(semantic_context, "slider_grabber", "normal")
	grabber_hover = ThemeController.texture_for(semantic_context, "slider_grabber", "hover")
	grabber_disabled = ThemeController.texture_for(semantic_context, "slider_grabber", "disabled")
	focus_style = ThemeController.style_for(semantic_context, "slider", "focus")


func _apply_visual_state() -> void:
	if rail_normal == null:
		return
	var rail := rail_disabled if not editable else (rail_hover if hovered else rail_normal)
	var fill := fill_disabled if not editable else (fill_hover if hovered else fill_normal)
	var grabber := grabber_disabled if not editable else (grabber_hover if hovered else grabber_normal)
	add_theme_stylebox_override("slider", rail)
	add_theme_stylebox_override("grabber_area", fill)
	add_theme_stylebox_override("grabber_area_highlight", fill_hover if editable else fill_disabled)
	add_theme_icon_override("grabber", grabber)
	add_theme_icon_override("grabber_highlight", grabber_hover if editable else grabber_disabled)
	add_theme_icon_override("grabber_disabled", grabber_disabled)
	queue_redraw()


func _draw() -> void:
	if has_focus():
		draw_style_box(
			focus_style,
			Rect2(Vector2(6, 7), Vector2(maxf(1.0, size.x - 12.0), maxf(1.0, size.y - 14.0))),
		)
