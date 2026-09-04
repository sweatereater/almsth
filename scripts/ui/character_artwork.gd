extends RefCounted

## UI-only artwork. World sprites deliberately remain in GameRenderer.PLAYER_SPRITES.
const SEXES := ["female", "male"]
const FORMS := ["skeleton", "zombie", "ghoul", "revenant", "almost_human"]
static var textures: Dictionary = {}
const Layout := preload("res://scripts/ui/character_sheet_layout.gd")
const BODY_LANDMARKS := {
	"male": [[146, 810, 752], [147, 847, 766], [152, 857, 776], [144, 863, 773], [179, 863, 782]],
	"female": [[181, 863, 797], [174, 871, 800.5], [211, 889, 810], [211, 894, 822], [405, 1445, 1330.5]],
}
static var sheet_placements: Dictionary = {}


static func body_path(sex: String, form: String) -> String:
	return "res://assets/ui/character-sheet/%s/%s.png" % [
		sex if sex in SEXES else "male", form.replace("_", "-"),
	]


static func head_path(sex: String) -> String:
	return "res://assets/portraits/%s/form-almost-human.png" % [sex if sex in SEXES else "male"]


static func texture(path: String) -> Texture2D:
	if not textures.has(path):
		textures[path] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return textures[path]


static func body(state: RunState) -> Texture2D:
	return texture(body_path(state.character_sex, state.get_display_form_id()))


static func prepare_sheet() -> void:
	## Run on modal construction, never from drawing. Preserve one anatomical
	## eye-to-foot span per sex, constrained by every complete alpha silhouette.
	if not sheet_placements.is_empty():
		return
	var safe := Layout.FIGURE_RECT.grow(-4.0)
	for sex: String in SEXES:
		var anchor := Vector2(484.0 if sex == "female" else 472.5, Layout.FIGURE_BASELINE_Y)
		var span := 480.0
		var entries: Array[Dictionary] = []
		for index in FORMS.size():
			var art := texture(body_path(sex, FORMS[index]))
			assert(art != null, "Missing native character sheet artwork")
			var bounds := Rect2(art.get_image().get_used_rect())
			var landmark: Array = BODY_LANDMARKS[sex][index]
			var foot := Vector2(landmark[0], landmark[1])
			var anatomical_span: float = landmark[2]
			for constraint in [
				[foot.x - bounds.position.x, anchor.x - safe.position.x],
				[bounds.end.x - foot.x, safe.end.x - anchor.x],
				[foot.y - bounds.position.y, anchor.y - safe.position.y],
				[bounds.end.y - foot.y, safe.end.y - anchor.y],
			]:
				if constraint[0] > 0.0:
					span = minf(span, anatomical_span * constraint[1] / constraint[0])
			entries.append({"texture": art, "source": bounds, "foot": foot, "anatomical_span": anatomical_span})
		for index in entries.size():
			var entry := entries[index]
			var scale_value: float = span / entry.anatomical_span
			entry.destination = Rect2(anchor + (entry.source.position - entry.foot) * scale_value, entry.source.size * scale_value)
			entry.anchor = anchor
			entry.eye_to_foot = span
			entry.scale = scale_value
			sheet_placements[body_path(sex, FORMS[index])] = entry


static func sheet_placement(state: RunState) -> Dictionary:
	return sheet_placements.get(body_path(state.character_sex, state.get_display_form_id()), {})
