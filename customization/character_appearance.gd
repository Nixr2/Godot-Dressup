class_name CharacterAppearance
extends Resource
## A saved look: body colors plus which [OutfitItem] is worn in each slot.
##
## Save with [method ResourceSaver.save] to persist a player's look.

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
