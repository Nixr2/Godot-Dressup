class_name ShapeKeyController
extends Node
## Resolves body sliders, the active expression, clothing conditions and
## automatic blinking into final blend shape weights, then applies them by
## name to every mesh under [member mesh_root]: body parts, hair and all
## equipped garments, so newly split body parts need no setup.
##
## Place after any AnimationPlayer in the scene tree so these weights are
## applied after animation playback each frame.

## Emitted when equipping or removing clothing changes which keys apply.
signal availability_changed

@export var shape_key_set: ShapeKeySet
@export var wardrobe: Wardrobe
## Every MeshInstance3D below this node receives the weights.
@export var mesh_root: Node3D
## Seconds for an expression to blend fully in or out.
@export_range(0.0, 1.0, 0.01) var expression_blend_time := 0.15

@export_group("Blinking")
@export var auto_blink := true
@export var blink_interval_min := 2.0
@export var blink_interval_max := 6.0
@export var blink_duration := 0.15

var _body_values: Dictionary[StringName, float] = {}
var _expression: StringName
var _expression_weights: Dictionary[StringName, float] = {}
var _blink_timer := 0.0
var _blink_elapsed := -1.0
var _dirty := true
## Keys applied last time, so keys that drop out are reset to 0.
var _applied_keys: Dictionary[StringName, bool] = {}


func _ready() -> void:
	assert(shape_key_set != null, "ShapeKeyController requires a ShapeKeySet.")
	wardrobe.item_equipped.connect(_on_wardrobe_changed.unbind(1))
	wardrobe.item_unequipped.connect(_on_wardrobe_changed.unbind(1))
	_schedule_next_blink()


func _process(delta: float) -> void:
	_update_expression_weights(delta)
	_update_blink(delta)
	if _dirty:
		_apply()


## Sets a body shape slider, clamped to 0-1.
func set_body_value(key: StringName, value: float) -> void:
	_body_values[key] = clampf(value, 0.0, 1.0)
	_dirty = true


## Returns a body shape slider's value.
func get_body_value(key: StringName) -> float:
	return _body_values.get(key, 0.0)


## Blends to [param key]'s expression. Pass an empty key for neutral.
func set_expression(key: StringName) -> void:
	_expression = key
	_dirty = true


## Returns the active expression's key, or an empty key for neutral.
func get_expression() -> StringName:
	return _expression


## Turns automatic blinking on or off.
func set_auto_blink(enabled: bool) -> void:
	auto_blink = enabled
	_blink_elapsed = -1.0
	_dirty = true


## Whether [param key]'s clothing condition is met.
func is_available(key: StringName) -> bool:
	var definition := shape_key_set.get_definition(key)
	if definition == null or definition.required_tag.is_empty():
		return true
	for item in wardrobe.get_equipped_items():
		if definition.required_tag in item.tags:
			return true
	return false


## Applies the body shape sliders of [param appearance].
func apply_appearance(appearance: CharacterAppearance) -> void:
	_body_values = appearance.body_shapes.duplicate()
	_dirty = true


## Stores the body shape sliders in [param appearance].
func write_to_appearance(appearance: CharacterAppearance) -> void:
	appearance.body_shapes = _body_values.duplicate()


func _update_expression_weights(delta: float) -> void:
	var step := 1.0 if is_zero_approx(expression_blend_time) else delta / expression_blend_time
	for definition in shape_key_set.get_by_category(ShapeKeyDefinition.Category.EXPRESSION):
		var current: float = _expression_weights.get(definition.key, 0.0)
		var target := 1.0 if definition.key == _expression else 0.0
		if not is_equal_approx(current, target):
			_expression_weights[definition.key] = move_toward(current, target, step)
			_dirty = true


func _update_blink(delta: float) -> void:
	if not auto_blink or shape_key_set.blink_key.is_empty() or _is_blink_blocked():
		return
	if _blink_elapsed >= 0.0:
		_blink_elapsed += delta
		if _blink_elapsed >= blink_duration:
			_blink_elapsed = -1.0
			_schedule_next_blink()
		_dirty = true
		return
	_blink_timer -= delta
	if _blink_timer <= 0.0:
		_blink_elapsed = 0.0


func _schedule_next_blink() -> void:
	_blink_timer = randf_range(blink_interval_min, blink_interval_max)


func _is_blink_blocked() -> bool:
	var definition := shape_key_set.get_definition(_expression)
	return definition != null and definition.blocks_blink


func _get_blink_weight() -> float:
	if _blink_elapsed < 0.0 or _is_blink_blocked():
		return 0.0
	return sin(_blink_elapsed / blink_duration * PI)


func _resolve_weights() -> Dictionary[StringName, float]:
	var weights: Dictionary[StringName, float] = {}
	for definition in shape_key_set.definitions:
		weights[definition.key] = 0.0

	for key: StringName in _body_values:
		if is_available(key):
			weights[key] = _body_values[key]

	for key: StringName in _expression_weights:
		var weight: float = _expression_weights[key]
		weights[key] = weights.get(key, 0.0) + weight
		var definition := shape_key_set.get_definition(key)
		for driven: StringName in definition.drives:
			weights[driven] = weights.get(driven, 0.0) + weight * definition.drives[driven]

	for item in wardrobe.get_equipped_items():
		for key: StringName in item.shape_key_overrides:
			weights[key] = item.shape_key_overrides[key]

	if not shape_key_set.blink_key.is_empty():
		weights[shape_key_set.blink_key] = maxf(
				weights.get(shape_key_set.blink_key, 0.0), _get_blink_weight()
		)
	return weights


func _apply() -> void:
	_dirty = false
	var weights := _resolve_weights()
	for key: StringName in _applied_keys:
		if not weights.has(key):
			weights[key] = 0.0
	_applied_keys.clear()
	for key: StringName in weights:
		_applied_keys[key] = true
	for mesh: MeshInstance3D in mesh_root.find_children("*", "MeshInstance3D", true, false):
		for key: StringName in weights:
			var index := mesh.find_blend_shape_by_name(key)
			if index >= 0:
				mesh.set_blend_shape_value(index, clampf(weights[key], 0.0, 1.0))


func _on_wardrobe_changed() -> void:
	_dirty = true
	availability_changed.emit()
