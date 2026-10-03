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

enum Slot {
	HEAD,
	TORSO,
	LEGS,
	FEET,
	ACCESSORY,
}

@export var id: StringName
@export var display_name: String
@export var slot: Slot = Slot.TORSO
## Scene whose root is a [Node3D] containing the item's mesh(es). An imported
## .glb works directly.
@export var scene: PackedScene
## Bone to rigidly attach to. Leave empty for skinned meshes.
@export var attach_bone: StringName

@export_group("Body Hiding")
## Skin hidden while this item is worn, so the body can't poke through it:
## white texels over the body's UVs are not drawn. Generate it with
## "Bake Hide Mask" below, then touch it up in any paint program if needed.
@export var hide_mask: Texture2D
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
## Whether players can recolor this item.
@export var tintable := true
## Tint applied when the item is first equipped.
@export var default_tint := Color.WHITE
## The main color of the item's (desaturated) texture. Texels of this color
## become exactly the chosen tint.
@export var texture_base_color := Color.WHITE


## Bakes [member hide_mask] from the garment's shape and saves it as
## "<id>_hide_mask.png" next to this resource.
func bake_hide_mask() -> void:
	if scene == null or hide_mask_body == null or hide_mask_body.scene == null:
		push_error("Outfit item '%s' needs a scene and a hide mask body to bake." % id)
		return
	if resource_path.is_empty() or resource_path.contains("::"):
		push_error("Save outfit item '%s' to its own .tres file before baking." % id)
		return

	var path := resource_path.get_base_dir().path_join("%s_hide_mask.png" % id)
	var error := HideMaskBaker.bake(self).save_png(path)
	if error != OK:
		push_error("Couldn't save hide mask to '%s': %s" % [path, error_string(error)])
		return
	print("Baked hide mask for '%s' to %s" % [id, path])

	if Engine.is_editor_hint():
		# Editor classes are looked up dynamically: they don't exist in exported games.
		var file_system: Object = Engine.get_singleton(&"EditorInterface").get_resource_filesystem()
		file_system.update_file(path)
		file_system.reimport_files(PackedStringArray([path]))
		hide_mask = load(path)
		ResourceSaver.save(self)
