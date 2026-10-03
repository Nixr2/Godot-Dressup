class_name BodyCustomizer
extends Node
## Tints a character's skin and hair.
##
## Meshes are found by material under [member mesh_root], so body parts split
## into separate meshes (head, feet, hair pieces) are picked up automatically.
## The materials must use toon.gdshader, which exposes the [code]tint[/code]
## instance uniform.

const TINT_PARAMETER := &"tint"

@export var palette: SkinTonePalette
@export var mesh_root: Node3D
## Meshes using this material get the skin tone.
@export var skin_material: Material
## Meshes using this material get the hair color.
@export var hair_material: Material

var skin_tone := 0.0
var skin_undertone := 0.0
var hair_color := Color("c3c3c3")


## Tints the skin with [member palette]'s color for [param tone] and
## [param undertone].
func set_skin_tone(tone: float, undertone: float) -> void:
	skin_tone = tone
	skin_undertone = undertone
	_apply_tint(skin_material, palette.get_color(tone, undertone))


## Tints the hair with [param color].
func set_hair_color(color: Color) -> void:
	hair_color = color
	_apply_tint(hair_material, color)


## Applies the skin and hair colors of [param appearance].
func apply_appearance(appearance: CharacterAppearance) -> void:
	set_skin_tone(appearance.skin_tone, appearance.skin_undertone)
	set_hair_color(appearance.hair_color)


## Stores the current skin and hair colors in [param appearance].
func write_to_appearance(appearance: CharacterAppearance) -> void:
	appearance.skin_tone = skin_tone
	appearance.skin_undertone = skin_undertone
	appearance.hair_color = hair_color


func _apply_tint(material: Material, color: Color) -> void:
	for mesh: MeshInstance3D in mesh_root.find_children("*", "MeshInstance3D", true, false):
		if _uses_material(mesh, material):
			mesh.set_instance_shader_parameter(TINT_PARAMETER, Color(color, 1.0))


func _uses_material(mesh: MeshInstance3D, material: Material) -> bool:
	for surface in mesh.get_surface_override_material_count():
		if mesh.get_active_material(surface) == material:
			return true
	return false
