extends RefCounted

## UI-only artwork. World sprites deliberately remain in GameRenderer.PLAYER_SPRITES.
const SEXES := ["female", "male"]
const FORMS := ["skeleton", "zombie", "ghoul", "revenant", "almost_human"]
static var textures: Dictionary = {}


static func body_path(sex: String, form: String) -> String:
	return "res://assets/ui/character-fullbody/%s/form-%s.png" % [
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
