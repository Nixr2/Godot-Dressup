class_name ShapeKeyDefinition
extends Resource
## Describes one blend shape (shape key) and the rules for using it.
##
## The key is applied by name to every character and clothing mesh that has
## it, so garments with matching shape keys follow the body automatically.

enum Category {
	## Customization slider saved with the character's appearance.
	BODY,
	## Facial expression, previewed one at a time.
	EXPRESSION,
	## Not shown in the UI; set only by clothing overrides or other keys'
	## [member drives] (e.g. a shirt's "tuck_upper" while a skirt is worn).
	CONDITIONAL,
}

## Blend shape name, as exported from Blender.
@export var key: StringName
@export var display_name: String
@export var category := Category.BODY
## If set, the key only takes effect while an equipped [OutfitItem] has this
## tag in [member OutfitItem.tags].
@export var required_tag: StringName
## Other keys set by this one, as key -> weight multiplier. For example an
## "anger" expression can also drive "brow_upset" at 1.0.
@export var drives: Dictionary[StringName, float] = {}
## Pauses automatic blinking while this expression is active.
@export var blocks_blink := false
