@tool
class_name HideMaskBody
extends Resource
## The body that [OutfitItem] hide masks are baked against.
##
## A hide mask is painted over the UVs of the body's skin texture, so only
## meshes using [member skin_material] are considered when baking.

## The character model the garments were made for, in its rest pose.
@export var scene: PackedScene
## The skin material whose meshes (and UVs) the mask covers.
@export var skin_material: Material
## Width and height of baked masks, in pixels.
@export_range(64, 4096, 1, "suffix:px") var resolution := 512
