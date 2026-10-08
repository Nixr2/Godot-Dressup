@tool
class_name OutfitItem
extends Resource
## A single wearable piece of clothing or accessory.
##
## Skinned items (shirts, skirts) keep their own [Skeleton3D] and leave
## [member attach_bone] empty. Their bones follow the body wherever the names
## match the base rig's [SkeletonProfile]; extra bones (e.g. skirt chains) can
## be driven by physics nodes such as [SpringBoneSimulator3D] placed under the
## item's skeleton. Rigid items (hats, glasses) set [member attach_bone] and
## are parented to a [BoneAttachment3D].

## Values are saved in item resources, so only ever add new slots at the end.
enum Slot {
	HEAD,
	TORSO,
	LEGS,
	FEET,
	ACCESSORY,
	## Worn under the torso and legs layers, e.g. swimsuits.
	UNDERWEAR,
	## Hair is split into front (fringe) and back pieces that mix and match.
	HAIR_FRONT,
	HAIR_BACK,
	SOCKS,
	## Decals drawn over the face, e.g. blush.
	FACE_OVERLAY,
}

@export var id: StringName
@export var display_name: String
@export var slot: Slot = Slot.TORSO
## Scene whose root is a [Node3D] containing the item's mesh(es). An imported
## .glb works directly.
@export var scene: PackedScene
## Bone to rigidly attach to. Leave empty for skinned meshes.
@export var attach_bone: StringName
## Material the item's imported surfaces are converted to. Empty uses the
## Wardrobe's toon material; decals use the transparent toon overlay.
@export var material_template: ShaderMaterial

@export_group("Hiding")
## Skin hidden while this item is worn, so the body can't poke through it:
## white texels over the body's UVs are not drawn. Generate it with
## "Bake Hide Mask" below, then touch it up in any paint program if needed.
@export var hide_mask: Texture2D
## Items hide what they cover of worn items on lower layers, just like skin.
## Underwear is 0, regular clothes 1, outerwear (jackets) 2.
@export_range(0, 10) var layer := 1
## Parts of this item hidden while an item on a higher layer is worn, as that
## item's id -> mask over this item's UVs. Baked by the [OutfitCatalog]'s
## "Bake Hide Masks" button.
@export var covered_masks: Dictionary[StringName, Texture2D] = {}
## The body to bake [member hide_mask] against.
@export var hide_mask_body: HideMaskBody
## Skin is hidden where the garment sits at most this far outside it. Keep it
## small for loose items (skirts) so only the tight parts hide skin.
@export_range(0.0, 0.05, 0.001, "or_greater", "suffix:m") var hide_distance := 0.01
## Skin is also hidden where it pokes through the garment by up to this much.
@export_range(0.0, 0.05, 0.001, "or_greater", "suffix:m") var hide_depth := 0.02
@export_tool_button("Bake Hide Mask", "Bake") var bake_hide_mask_button := bake_hide_mask

@export_group("Shape Keys")
## Labels that shape key rules can require, see
## [member ShapeKeyDefinition.required_tag] (e.g. &"shows_cleavage").
@export var tags: Array[StringName] = []
## Shape keys forced to a value while this item is worn, as key -> weight.
@export var shape_key_overrides: Dictionary[StringName, float] = {}

@export_group("Color")
## Whether players can recolor this item on its own.
@export var tintable := true
## Items in a tint group share one color, set with
## [method Wardrobe.set_group_tint] (e.g. every hair piece follows the hair
## color). Grouped items ignore [member tintable] and [member default_tint].
@export var tint_group: StringName
## Tint applied when the item is first equipped.
@export var default_tint := Color.WHITE
## The main color of the item's (desaturated) texture. Texels of this color
## become exactly the chosen tint.
@export var texture_base_color := Color.WHITE


## Bakes [member hide_mask] from the garment's shape and saves it as
## "<id>_hide_mask.png" next to this resource.
func bake_hide_mask() -> void:
	if not can_bake():
		return
	var texture := HideMaskBaker.save_mask(HideMaskBaker.bake(self), get_mask_path(&"hide_mask"))
	if texture:
		hide_mask = texture
		ResourceSaver.save(self)


## Bakes what [param over] covers of this item into [member covered_masks],
## saved as "<id>_covered_by_<over id>.png" next to this resource.
func bake_covered_mask(over: OutfitItem) -> void:
	if not can_bake() or not over.can_bake():
		return
	var image := HideMaskBaker.bake_over(over, self)
	if image.get_data().find(255) < 0:
		covered_masks.erase(over.id) # They don't overlap; nothing to hide.
		return
	var texture := HideMaskBaker.save_mask(image, get_mask_path(&"covered_by_" + over.id))
	if texture:
		covered_masks[over.id] = texture
		ResourceSaver.save(self)


## Whether this item has what baking needs, reporting what's missing if not.
func can_bake() -> bool:
	if scene == null or hide_mask_body == null or hide_mask_body.scene == null:
		push_error("Outfit item '%s' needs a scene and a hide mask body to bake." % id)
		return false
	if resource_path.is_empty() or resource_path.contains("::"):
		push_error("Save outfit item '%s' to its own .tres file before baking." % id)
		return false
	return true


## Path of this item's mask named "<id>_<suffix>.png", next to the resource.
func get_mask_path(suffix: StringName) -> String:
	return resource_path.get_base_dir().path_join("%s_%s.png" % [id, suffix])
