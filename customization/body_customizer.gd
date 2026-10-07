class_name BodyCustomizer
extends Node
## Tints a character's skin, hair and eyes.
##
## Skin and eye meshes are found by material under [member mesh_root], so body
## parts split into separate meshes are picked up automatically. Hair pieces
## are worn items: the hair color goes to every item in [member wardrobe]'s
## [constant HAIR_TINT_GROUP].
## The materials must use toon.gdshader, which exposes the [code]tint[/code]
## instance uniform.

const TINT_PARAMETER := &"tint"
const HAIR_TINT_GROUP := &"hair"

@export var palette: SkinTonePalette
@export var mesh_root: Node3D
## Meshes using this material get the skin tone.
@export var skin_material: Material
## Wears the hair pieces; receives the hair color.
@export var wardrobe: Wardrobe
## Meshes using this material get the eye color. Give it a tint mask so only
## the irises change.
@export var eye_material: Material

var skin_tone := 0.0
var skin_undertone := 0.0
var hair_color := Color("c3c3c3")
var eye_color := Color("313131")


## Tints the skin with [member palette]'s color for [param tone] and
## [param undertone].
func set_skin_tone(tone: float, undertone: float) -> void:
	skin_tone = tone
	skin_undertone = undertone
	_apply_tint(skin_material, palette.get_color(tone, undertone))


## Tints the hair with [param color].
func set_hair_color(color: Color) -> void:
	hair_color = color
	wardrobe.set_group_tint(HAIR_TINT_GROUP, color)


## Tints the irises with [param color].
func set_eye_color(color: Color) -> void:
	eye_color = color
	_apply_tint(eye_material, color)


## Applies the skin, hair and eye colors of [param appearance].
func apply_appearance(appearance: CharacterAppearance) -> void:
	set_skin_tone(appearance.skin_tone, appearance.skin_undertone)
	set_hair_color(appearance.hair_color)
	set_eye_color(appearance.eye_color)


## Stores the current skin, hair and eye colors in [param appearance].
func write_to_appearance(appearance: CharacterAppearance) -> void:
	appearance.skin_tone = skin_tone
	appearance.skin_undertone = skin_undertone
	appearance.hair_color = hair_color
	appearance.eye_color = eye_color


func _apply_tint(material: Material, color: Color) -> void:
	for mesh: MeshInstance3D in mesh_root.find_children("*", "MeshInstance3D", true, false):
		if _uses_material(mesh, material):
			mesh.set_instance_shader_parameter(TINT_PARAMETER, Color(color, 1.0))


func _uses_material(mesh: MeshInstance3D, material: Material) -> bool:
	for surface in mesh.get_surface_override_material_count():
		if mesh.get_active_material(surface) == material:
			return true
	return false
