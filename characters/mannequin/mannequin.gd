class_name Mannequin
extends Node3D
## Customizable base character: the Doll model plus its Wardrobe,
## BodyCustomizer, ShapeKeyController, CharacterAnimator and LookAtController
## components.

## Look applied on ready. Optional.
@export var initial_appearance: CharacterAppearance

@onready var wardrobe: Wardrobe = $Wardrobe
@onready var body_customizer: BodyCustomizer = $BodyCustomizer
@onready var shape_key_controller: ShapeKeyController = $ShapeKeyController
@onready var animator: CharacterAnimator = $CharacterAnimator
@onready var look_at: LookAtController = $LookAtController


func _ready() -> void:
	if initial_appearance:
		apply_appearance(initial_appearance)


## Applies a saved look: colors, body shapes and worn items.
func apply_appearance(appearance: CharacterAppearance) -> void:
	body_customizer.apply_appearance(appearance)
	shape_key_controller.apply_appearance(appearance)
	wardrobe.apply_appearance(appearance)


## Returns the current look as a new [CharacterAppearance].
func get_appearance() -> CharacterAppearance:
	var appearance := CharacterAppearance.new()
	body_customizer.write_to_appearance(appearance)
	shape_key_controller.write_to_appearance(appearance)
	wardrobe.write_to_appearance(appearance)
	return appearance
