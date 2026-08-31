class_name FloorDecoration
extends RefCounted

## Cosmetic RNG is independent of combat, layout and loot. All choices are saved
## once with the floor, never reconstructed from its surviving enemies.
static func populate(floor: Dictionary, floor_number: int) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = int(floor.get("seed", 0)) ^ 0x413C76B2
	floor["biome"] = GameRules.biome_id(floor_number)
	var kinds: Array[String] = []
	for enemy in floor.get("enemies", []):
		if not kinds.has(String(enemy.id)):
			kinds.append(String(enemy.id))
	floor["initial_enemy_kinds"] = kinds
	for item in floor.get("items", []):
		item["appearance"] = "crypt" if floor_number >= GameRules.CRYPT_MIN_FLOOR and floor_number <= GameRules.CRYPT_MAX_FLOOR and random.randf() < GameRules.CRYPT_CHANCE else "chest"
	var decorations := {}
	var excluded := {}
	for field in ["start", "exit", "base_gate", "cradle"]:
		excluded[floor.get(field, Vector2i(-1, -1))] = true
	var candidates: Array[Vector2i] = []
	for cell in floor.tiles:
		if floor.tiles[cell] == "floor" and not excluded.has(cell):
			candidates.append(cell)
	# Fisher-Yates using the local RNG, preserving deterministic insertion order.
	for index in range(candidates.size() - 1, 0, -1):
		var other := random.randi_range(0, index)
		var swap := candidates[index]
		candidates[index] = candidates[other]
		candidates[other] = swap
	if kinds.has("skeletal_archer") or kinds.has("bone_crossbowman"):
		var desired := random.randi_range(1, 2)
		var patches := 0
		for origin in candidates:
			var width := random.randi_range(3, 4)
			var height := random.randi_range(3, 4)
			var cells: Array[Vector2i] = []
			var clear := true
			for y in range(height):
				for x in range(width):
					var cell := origin + Vector2i(x, y)
					if floor.tiles.get(cell) != "floor" or excluded.has(cell) or decorations.has(cell):
						clear = false
					cells.append(cell)
			if not clear:
				continue
			# Small corner omissions make an approximately square ragged boundary.
			if random.randf() < 0.7:
				cells.erase(origin)
			if cells.size() > 9 and random.randf() < 0.5:
				cells.erase(origin + Vector2i(width - 1, height - 1))
			for cell in cells:
				decorations[cell] = {"kind": "mosaic", "variant": random.randi_range(0, 2), "patch": patches}
			patches += 1
			if patches >= desired:
				break
	if floor.biome == "weaving_crypts" and not bool(floor.get("fixed_layout", false)):
		var remaining := random.randi_range(2, 4)
		for cell in candidates:
			if decorations.has(cell):
				continue
			decorations[cell] = {"kind": "cocoon", "variant": random.randi_range(0, 1)}
			remaining -= 1
			if remaining == 0:
				break
	floor["decorations"] = decorations
