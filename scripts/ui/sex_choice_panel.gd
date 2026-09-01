extends Control

signal sex_selected(sex: String)

const Loc := preload("res://scripts/localization/localization.gd")
const Ui := preload("res://scripts/ui/ui_factory.gd")
const Artwork := preload("res://scripts/ui/character_artwork.gd")

var selected_sex := "male"
var buttons: Dictionary = {}
var labels: Dictionary = {}


func _init() -> void:
	size = Vector2(332, 160)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var group := ButtonGroup.new()
	for index in range(Artwork.SEXES.size()):
		var sex: String = Artwork.SEXES[index]
		var button := Ui.make_button(self, Vector2(index * 176, 0), "", Vector2(156, 160))
		button.name = sex.capitalize()
		button.toggle_mode = true
		button.button_group = group
		Ui.enable_keyboard_focus(button)
		var focus := Ui.make_button_style(Color.TRANSPARENT, Color("f3d393"), 2)
		focus.set_corner_radius_all(8)
		button.add_theme_stylebox_override("focus", focus)
		button.pressed.connect(_select.bind(sex))
		buttons[sex] = button
		var portrait := TextureRect.new()
		portrait.position = Vector2(22, 8)
		portrait.size = Vector2(112, 112)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait.flip_h = sex == "male"
		button.add_child(portrait)
		portrait.texture = Artwork.texture(Artwork.head_path(sex))
		if portrait.texture == null:
			portrait.texture = preload("res://assets/portraits/form-almost-human.png")
		var label := Ui.make_label(button, Vector2(4, 124), Vector2(148, 28), 17)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.visible = false
		labels[sex] = label
	set_sex(selected_sex)


func set_sex(sex: String) -> void:
	selected_sex = sex if sex in Artwork.SEXES else "male"
	for id in buttons:
		buttons[id].set_pressed_no_signal(id == selected_sex)
	apply_locale()


func apply_locale() -> void:
	for sex in buttons:
		var label := Loc.text("SEX_FEMALE" if sex == "female" else "SEX_MALE")
		labels[sex].text = ("✓ " if sex == selected_sex else "") + label
		buttons[sex].tooltip_text = Loc.text("SEX_CHOICE_HINT", [label])


func _select(sex: String) -> void:
	set_sex(sex)
	sex_selected.emit(sex)
