extends Control

signal sex_selected(sex: String)

const Loc := preload("res://scripts/localization/localization.gd")
const Ui := preload("res://scripts/ui/ui_factory.gd")
const Palette := preload("res://scripts/ui/ui_palette.gd")
const ThemeController := preload("res://scripts/ui/ui_theme_controller.gd")
const Artwork := preload("res://scripts/ui/character_artwork.gd")

var selected_sex := "female"
var buttons: Dictionary = {}
var labels: Dictionary = {}
var selection_markers: Dictionary = {}


func _init() -> void:
	size = Vector2(332, 160)
	theme = ThemeController.theme_for(Palette.WARM_ARCHIVE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for index in range(Artwork.SEXES.size()):
		var sex: String = Artwork.SEXES[index]
		var button := Ui.make_button(self, Vector2(index * 176, 0), "", Vector2(156, 160))
		button.name = sex.capitalize()
		button.toggle_mode = false
		Ui.enable_keyboard_focus(button)
		button.pressed.connect(_select.bind(sex))
		buttons[sex] = button
		var portrait := TextureRect.new()
		portrait.position = Vector2(18, 22)
		portrait.size = Vector2(120, 120)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait.flip_h = sex == "male"
		button.add_child(portrait)
		portrait.texture = Artwork.texture(Artwork.head_path(sex))
		if portrait.texture == null:
			portrait.texture = preload("res://assets/portraits/form-almost-human.png")
		var label := Ui.make_label(button, Vector2(4, 124), Vector2(148, 28), 16)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.visible = false
		labels[sex] = label
		var marker := ColorRect.new()
		marker.name = "SelectionMarker"
		marker.position = Vector2(3, 6)
		marker.size = Vector2(4, 148)
		marker.color = Palette.color(Palette.WARM_ARCHIVE, "soul")
		marker.visible = false
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(marker)
		selection_markers[sex] = marker
	set_sex(selected_sex)


func set_sex(sex: String) -> void:
	selected_sex = sex if sex in Artwork.SEXES else "female"
	for id: String in buttons:
		var marker: ColorRect = selection_markers[id]
		var button: Button = buttons[id]
		var is_selected: bool = (id == selected_sex)
		var hover_style: StyleBox = button.get_theme_stylebox("hover")
		if hover_style == null:
			hover_style = button.get_theme_stylebox("normal")
		if hover_style == null:
			hover_style = button.get_theme_stylebox("pressed")
		marker.visible = is_selected
		if is_selected:
			if hover_style != null:
				button.add_theme_stylebox_override("normal", hover_style)
				button.add_theme_stylebox_override("pressed", hover_style)
				button.add_theme_stylebox_override("focus", hover_style)
		else:
			button.remove_theme_stylebox_override("normal")
			button.remove_theme_stylebox_override("pressed")
		if hover_style != null:
			button.add_theme_stylebox_override("focus", hover_style)
	apply_locale()


func apply_locale() -> void:
	for sex in buttons:
		var label := Loc.text("SEX_FEMALE" if sex == "female" else "SEX_MALE")
		labels[sex].text = label
		buttons[sex].tooltip_text = Loc.text("SEX_CHOICE_HINT", [label])
		buttons[sex].accessibility_name = labels[sex].text
		buttons[sex].accessibility_description = buttons[sex].tooltip_text


func _select(sex: String) -> void:
	set_sex(sex)
	sex_selected.emit(sex)

