class_name ShapeKeySet
extends Resource
## All shape key rules for one base character.

@export var definitions: Array[ShapeKeyDefinition] = []
## Key animated by automatic blinking. Leave empty to disable blinking.
@export var blink_key: StringName = &"blink"


## Returns the definition for [param key], or null if there is none.
func get_definition(key: StringName) -> ShapeKeyDefinition:
	for definition in definitions:
		if definition.key == key:
			return definition
	return null


## Returns every definition in [param category], in list order.
func get_by_category(category: ShapeKeyDefinition.Category) -> Array[ShapeKeyDefinition]:
	var result: Array[ShapeKeyDefinition] = []
	for definition in definitions:
		if definition.category == category:
			result.append(definition)
	return result
