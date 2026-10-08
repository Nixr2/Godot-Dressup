class_name CharacterAppearance
extends Resource
## A saved look: body colors plus which [OutfitItem] is worn in each slot.
##
## [method to_dict] and [method from_dict] convert it to and from plain data
## (items by id, colors as hex) for save files and presets; see SaveManager.

## 0 = lightest, 1 = deepest. See [SkinTonePalette].
@export_range(0.0, 1.0, 0.01) var skin_tone := 0.0
## -1 = cool, 0 = neutral, 1 = warm. See [SkinTonePalette].
@export_range(-1.0, 1.0, 0.01) var skin_undertone := 0.0
## Defaults to the hair texture's own gray, i.e. untinted.
@export var hair_color := Color("c3c3c3")
## Iris color. Defaults to the eye texture's own gray, i.e. untinted.
@export var eye_color := Color("313131")
## Body shape key slider values, keyed by blend shape name.
@export var body_shapes: Dictionary[StringName, float] = {}
@export var items: Array[OutfitItem] = []
## Tint per worn item, keyed by [member OutfitItem.id].
@export var item_tints: Dictionary[StringName, Color] = {}


## Returns this look as JSON-safe data: items by id, colors as hex strings.
func to_dict() -> Dictionary:
	var item_ids: Array[String] = []
	for item in items:
		item_ids.append(String(item.id))
	var tints := {}
	for id in item_tints:
		tints[String(id)] = item_tints[id].to_html(false)
	var shapes := {}
	for key in body_shapes:
		shapes[String(key)] = body_shapes[key]
	return {
		"skin_tone": skin_tone,
		"skin_undertone": skin_undertone,
		"hair_color": hair_color.to_html(false),
		"eye_color": eye_color.to_html(false),
		"body_shapes": shapes,
		"items": item_ids,
		"item_tints": tints,
	}


## Builds a look from [method to_dict] data. [param find_item] turns an item
## id into its [OutfitItem] (or null); unknown items and malformed values are
## skipped, so old or hand-edited data still loads.
static func from_dict(data: Dictionary, find_item: Callable) -> CharacterAppearance:
	var appearance := CharacterAppearance.new()
	appearance.skin_tone = clampf(_get_float(data, "skin_tone", appearance.skin_tone), 0.0, 1.0)
	appearance.skin_undertone = clampf(
			_get_float(data, "skin_undertone", appearance.skin_undertone), -1.0, 1.0
	)
	appearance.hair_color = _get_color(data, "hair_color", appearance.hair_color)
	appearance.eye_color = _get_color(data, "eye_color", appearance.eye_color)
	var shapes: Variant = data.get("body_shapes")
	if shapes is Dictionary:
		for key: Variant in shapes:
			if shapes[key] is float or shapes[key] is int:
				appearance.body_shapes[StringName(str(key))] = float(shapes[key])
	var item_ids: Variant = data.get("items")
	if item_ids is Array:
		for id: Variant in item_ids:
			var item: OutfitItem = find_item.call(StringName(str(id)))
			if item:
				appearance.items.append(item)
			else:
				push_warning("CharacterAppearance: unknown item '%s' skipped." % id)
	var tints: Variant = data.get("item_tints")
	if tints is Dictionary:
		for id: Variant in tints:
			if tints[id] is String:
				appearance.item_tints[StringName(str(id))] = Color.from_string(tints[id], Color.WHITE)
	return appearance


static func _get_float(data: Dictionary, key: String, fallback: float) -> float:
	var value: Variant = data.get(key)
	return float(value) if value is float or value is int else fallback


static func _get_color(data: Dictionary, key: String, fallback: Color) -> Color:
	var value: Variant = data.get(key)
	return Color.from_string(value, fallback) if value is String else fallback
