class_name UiPalette
extends RefCounted

## Stage 1C semantic color contract. Base tokens are literal, shared design data:
## callers can read colors through [color] but never receive the backing dictionaries.

const WARM_ARCHIVE := "warm_archive"
const COLD_DUNGEON := "cold_dungeon"

const WARM_TOKENS := {
	"background": Color("100f0d"),
	"panel": Color("2a251e"),
	"inset": Color("18140f"),
	"raised": Color("342e25"),
	"primary": Color("f2e8d4"),
	"secondary": Color("baab91"),
	"neutral_border": Color("806f53"),
	"selected_fill": Color("263b35"),
	"soul": Color("67cdc5"),
	"focus": Color("e1b965"),
	"copper": Color("a96d4c"),
	"danger": Color("d87568"),
	"disabled": Color("847a6b"),
	"disabled_text_contrast": Color("a49784"),
	"danger_surface": Color("38231f"),
}

const COLD_TOKENS := {
	"background": Color("070c11"),
	"panel": Color("142733"),
	"inset": Color("0d161f"),
	"raised": Color("18303a"),
	"primary": Color("e9f1ef"),
	"secondary": Color("9ab0b5"),
	"neutral_border": Color("557d91"),
	"selected_fill": Color("123b3a"),
	"soul": Color("55e0d4"),
	"focus": Color("ffd078"),
	"magic": Color("aa96d5"),
	"danger": Color("ff7b72"),
	"disabled": Color("70838b"),
	"disabled_text_contrast": Color("8298a0"),
	"danger_surface": Color("392224"),
}

const OVERLAY_SCRIM := Color(0.0, 0.0, 0.0, 0.72)


static func normalized_context(context: String) -> String:
	return COLD_DUNGEON if context == COLD_DUNGEON else WARM_ARCHIVE


static func color(context: String, role: String) -> Color:
	var source: Dictionary = COLD_TOKENS if normalized_context(context) == COLD_DUNGEON else WARM_TOKENS
	return source.get(role, source.primary)


static func snapshot(context: String) -> Dictionary:
	var source: Dictionary = COLD_TOKENS if normalized_context(context) == COLD_DUNGEON else WARM_TOKENS
	return source.duplicate(true)

