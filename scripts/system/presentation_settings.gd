class_name PresentationSettings
extends RefCounted

## Dungeon zoom is presentation-only. Keeping validation here gives settings,
## camera helpers, UI and tests one shared contract.

const CELL_SIZE_MAP := 44
const CELL_SIZE_TACTICS := 66
const CELL_SIZE_DETAILS := 88
const DEFAULT_CELL_SIZE := CELL_SIZE_TACTICS
const CELL_SIZES: Array[int] = [CELL_SIZE_MAP, CELL_SIZE_TACTICS, CELL_SIZE_DETAILS]

const AUTO_MOVEMENT_SPEED_NORMAL := 100
const AUTO_MOVEMENT_SPEED_FASTER := 150
const AUTO_MOVEMENT_SPEED_VERY_FAST := 200
const AUTO_MOVEMENT_SPEED_MAXIMUM := 225
const DEFAULT_AUTO_MOVEMENT_SPEED_PERCENT := AUTO_MOVEMENT_SPEED_NORMAL
const AUTO_MOVEMENT_SPEED_PERCENTS: Array[int] = [
	AUTO_MOVEMENT_SPEED_NORMAL,
	AUTO_MOVEMENT_SPEED_FASTER,
	AUTO_MOVEMENT_SPEED_VERY_FAST,
	AUTO_MOVEMENT_SPEED_MAXIMUM,
]


static func sanitize_cell_size(value: Variant) -> int:
	if not value is int and not value is float:
		return DEFAULT_CELL_SIZE
	var rounded := roundi(float(value))
	return rounded if CELL_SIZES.has(rounded) else DEFAULT_CELL_SIZE


static func next_cell_size(current: int, direction := 1) -> int:
	var sanitized := sanitize_cell_size(current)
	var index := CELL_SIZES.find(sanitized)
	return CELL_SIZES[posmod(index + direction, CELL_SIZES.size())]


static func clamped_cell_size_step(current: int, direction: int) -> int:
	var sanitized := sanitize_cell_size(current)
	var index := CELL_SIZES.find(sanitized)
	return CELL_SIZES[clampi(index + signi(direction), 0, CELL_SIZES.size() - 1)]


static func locale_key(cell_size: int) -> String:
	match sanitize_cell_size(cell_size):
		CELL_SIZE_MAP: return "SETTINGS_ZOOM_MAP"
		CELL_SIZE_DETAILS: return "SETTINGS_ZOOM_DETAILS"
	return "SETTINGS_ZOOM_TACTICS"


static func sanitize_auto_movement_speed_percent(value: Variant) -> int:
	if not value is int and not value is float:
		return DEFAULT_AUTO_MOVEMENT_SPEED_PERCENT
	var numeric := float(value)
	if numeric != roundf(numeric):
		return DEFAULT_AUTO_MOVEMENT_SPEED_PERCENT
	var percent := roundi(numeric)
	return (
		percent
		if AUTO_MOVEMENT_SPEED_PERCENTS.has(percent)
		else DEFAULT_AUTO_MOVEMENT_SPEED_PERCENT
	)


static func next_auto_movement_speed_percent(current: Variant) -> int:
	var sanitized := sanitize_auto_movement_speed_percent(current)
	var index := AUTO_MOVEMENT_SPEED_PERCENTS.find(sanitized)
	return AUTO_MOVEMENT_SPEED_PERCENTS[(index + 1) % AUTO_MOVEMENT_SPEED_PERCENTS.size()]


static func auto_movement_speed_multiplier(percent: Variant) -> float:
	return sanitize_auto_movement_speed_percent(percent) / 100.0


static func auto_movement_speed_locale_key(percent: Variant) -> String:
	match sanitize_auto_movement_speed_percent(percent):
		AUTO_MOVEMENT_SPEED_FASTER: return "SETTINGS_AUTO_SPEED_FASTER"
		AUTO_MOVEMENT_SPEED_VERY_FAST: return "SETTINGS_AUTO_SPEED_VERY_FAST"
		AUTO_MOVEMENT_SPEED_MAXIMUM: return "SETTINGS_AUTO_SPEED_MAXIMUM"
	return "SETTINGS_AUTO_SPEED_NORMAL"
