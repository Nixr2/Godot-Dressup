class_name Wardrobe
extends Node
## Equips, removes and recolors [OutfitItem]s on a character.
##
## Skinned items keep their own rig: each item's [Skeleton3D] is parented to
## [member clothing_rig], a [RetargetModifier3D] that copies the body's pose
## onto every item bone whose name is in its [SkeletonProfile]. Bones the body
## lacks (e.g. skirt chains) stay free for the item's own physics nodes.
## Rigid items (hats) are attached to [member skeleton] with a [BoneAttachment3D].

##
## Imported items that still use their original (non-toon) materials are
## converted to [member toon_material] so any .glb can be dropped in as-is.

## Emitted after [param item] is put on.
signal item_equipped(item: OutfitItem)
## Emitted after [param item] is taken off.
signal item_unequipped(item: OutfitItem)

const TINT_PARAMETER := &"tint"
const HIDE_MASKS_PARAMETER := &"hide_masks"
const HIDE_MASK_COUNT_PARAMETER := &"hide_mask_count"
## Matches MAX_HIDE_MASKS in toon.gdshader.
const MAX_HIDE_MASKS := 8

## The body skeleton. Rigid items attach to its bones.
@export var skeleton: Skeleton3D
## Child of [member skeleton] that drives the rigs of skinned items.
@export var clothing_rig: RetargetModifier3D
## Template for converting imported materials. Must use toon.gdshader.
@export var toon_material: ShaderMaterial
## The body's skin material; receives the worn items'
## [member OutfitItem.hide_mask]s.
@export var body_material: ShaderMaterial

var _equipped_items: Dictionary[OutfitItem.Slot, OutfitItem] = {}
var _equipped_nodes: Dictionary[OutfitItem.Slot, Node3D] = {}
var _item_tints: Dictionary[StringName, Color] = {}
var _group_tints: Dictionary[StringName, Color] = {}


func _ready() -> void:
	assert(skeleton != null, "Wardrobe requires a Skeleton3D.")
	assert(clothing_rig != null, "Wardrobe requires a RetargetModifier3D clothing rig.")
	assert(toon_material != null, "Wardrobe requires a toon material template.")
	_update_hide_masks()


## Puts [param item] on, replacing whatever is worn in its slot.
func equip(item: OutfitItem) -> void:
	unequip(item.slot)

	var instance: Node3D = item.scene.instantiate()
	var root: Node3D
	if item.attach_bone.is_empty():
		root = _attach_skinned(instance, item)
	else:
		root = _attach_rigid(instance, item)
	if root == null:
		return

	_convert_materials(root, item)
	_equipped_items[item.slot] = item
	_equipped_nodes[item.slot] = root
	if not item.tint_group.is_empty():
		if _group_tints.has(item.tint_group):
			_apply_tint(root, _group_tints[item.tint_group])
	elif item.tintable:
		set_item_tint(item.slot, _item_tints.get(item.id, item.default_tint))
	_update_hide_masks()
	item_equipped.emit(item)


## Takes off the item worn in [param slot], if any.
func unequip(slot: OutfitItem.Slot) -> void:
	if not _equipped_items.has(slot):
		return

	var item: OutfitItem = _equipped_items[slot]
	_equipped_nodes[slot].queue_free()
	_equipped_items.erase(slot)
	_equipped_nodes.erase(slot)
	_update_hide_masks()
	item_unequipped.emit(item)


## Returns the item worn in [param slot], or null.
func get_equipped(slot: OutfitItem.Slot) -> OutfitItem:
	return _equipped_items.get(slot)


## Returns every worn item.
func get_equipped_items() -> Array[OutfitItem]:
	var items: Array[OutfitItem] = []
	items.assign(_equipped_items.values())
	return items


## Returns the meshes of every worn item.
func get_equipped_meshes() -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	for node: Node3D in _equipped_nodes.values():
		meshes.append_array(_find_meshes(node))
	return meshes


## Recolors the item worn in [param slot], if it is tintable.
func set_item_tint(slot: OutfitItem.Slot, color: Color) -> void:
	var item := get_equipped(slot)
	if item == null or not item.tintable or not item.tint_group.is_empty():
		return

	_item_tints[item.id] = color
	_apply_tint(_equipped_nodes[slot], color)


## Recolors every worn item in tint group [param group] (see
## [member OutfitItem.tint_group]), and items of that group equipped later.
func set_group_tint(group: StringName, color: Color) -> void:
	_group_tints[group] = color
	for slot: OutfitItem.Slot in _equipped_items:
		if _equipped_items[slot].tint_group == group:
			_apply_tint(_equipped_nodes[slot], color)


## Returns the tint of the item worn in [param slot].
func get_item_tint(slot: OutfitItem.Slot) -> Color:
	var item := get_equipped(slot)
	if item == null:
		return Color.WHITE
	return _item_tints.get(item.id, item.default_tint)


## Replaces everything worn with [param appearance]'s items and tints.
func apply_appearance(appearance: CharacterAppearance) -> void:
	for slot: OutfitItem.Slot in _equipped_items.keys():
		unequip(slot)
	_item_tints = appearance.item_tints.duplicate()
	for item in appearance.items:
		equip(item)


## Stores the worn items and their tints in [param appearance].
func write_to_appearance(appearance: CharacterAppearance) -> void:
	appearance.items.assign(_equipped_items.values())
	appearance.item_tints.clear()
	for item: OutfitItem in _equipped_items.values():
		if item.tintable and item.tint_group.is_empty():
			appearance.item_tints[item.id] = get_item_tint(item.slot)


## Sends the worn items' hide masks to the skin shader, and each worn item's
## covered masks (from items worn over it) to that item's materials.
func _update_hide_masks() -> void:
	if body_material:
		var body_masks: Array[Texture2D] = []
		for item: OutfitItem in _equipped_items.values():
			if item.hide_mask:
				body_masks.append(item.hide_mask)
		_set_hide_masks(body_material, body_masks)

	for slot: OutfitItem.Slot in _equipped_items:
		var under := _equipped_items[slot]
		var masks: Array[Texture2D] = []
		for over: OutfitItem in _equipped_items.values():
			if over.layer > under.layer and under.covered_masks.has(over.id):
				masks.append(under.covered_masks[over.id])
		for material in _get_toon_materials(_equipped_nodes[slot]):
			_set_hide_masks(material, masks)


func _set_hide_masks(material: ShaderMaterial, masks: Array[Texture2D]) -> void:
	if masks.size() > MAX_HIDE_MASKS:
		push_warning("Only the first %d hide masks on a surface are applied." % MAX_HIDE_MASKS)
		masks.resize(MAX_HIDE_MASKS)
	material.set_shader_parameter(HIDE_MASKS_PARAMETER, masks)
	material.set_shader_parameter(HIDE_MASK_COUNT_PARAMETER, masks.size())


func _get_toon_materials(root: Node) -> Array[ShaderMaterial]:
	var materials: Array[ShaderMaterial] = []
	for mesh in _find_meshes(root):
		for surface in mesh.get_surface_override_material_count():
			var material := mesh.get_active_material(surface) as ShaderMaterial
			if material and material.shader == toon_material.shader and not material in materials:
				materials.append(material)
	return materials


## Moves the item's own [Skeleton3D], with its meshes and any physics nodes
## authored under it, onto [member clothing_rig] and discards the wrapper nodes.
func _attach_skinned(instance: Node3D, item: OutfitItem) -> Node3D:
	var item_skeleton := _find_skeleton(instance)
	if item_skeleton == null:
		push_error("Outfit item '%s' is skinned but its scene has no Skeleton3D." % item.id)
		instance.free()
		return null

	if item_skeleton != instance:
		# Skinned meshes outside the skeleton would lose their skeleton path.
		for mesh in _find_meshes(instance):
			var outside_skeleton := not item_skeleton.is_ancestor_of(mesh)
			if outside_skeleton and mesh.get_node_or_null(mesh.skeleton) == item_skeleton:
				mesh.reparent(item_skeleton, false)
				mesh.skeleton = mesh.get_path_to(item_skeleton)
		item_skeleton.get_parent().remove_child(item_skeleton)
		instance.free()

	item_skeleton.name = item.id.to_pascal_case()
	item_skeleton.transform = Transform3D.IDENTITY
	clothing_rig.add_child(item_skeleton)
	if not _shares_bones_with_rig(item_skeleton):
		push_warning(
				("Outfit item '%s' shares no bones with the clothing rig's profile, "
						+ "so it won't follow the body.") % item.id
		)
	return item_skeleton


func _attach_rigid(instance: Node3D, item: OutfitItem) -> Node3D:
	var attachment := BoneAttachment3D.new()
	attachment.name = "%sAttachment" % item.id.to_pascal_case()
	attachment.bone_name = item.attach_bone
	skeleton.add_child(attachment)
	attachment.add_child(instance)
	return attachment


func _convert_materials(root: Node, item: OutfitItem) -> void:
	var converted: Dictionary[Material, ShaderMaterial] = {}
	for mesh in _find_meshes(root):
		for surface in mesh.mesh.get_surface_count():
			var source := mesh.get_active_material(surface)
			if not converted.has(source):
				if source is ShaderMaterial and source.shader == toon_material.shader:
					converted[source] = source.duplicate()
				else:
					converted[source] = _create_toon_material(source, item)
			mesh.set_surface_override_material(surface, converted[source])


func _apply_tint(root: Node, color: Color) -> void:
	for mesh in _find_meshes(root):
		mesh.set_instance_shader_parameter(TINT_PARAMETER, Color(color, 1.0))


func _create_toon_material(source: Material, item: OutfitItem) -> ShaderMaterial:
	var template := item.material_template if item.material_template else toon_material
	var material: ShaderMaterial = template.duplicate()
	material.set_shader_parameter(&"texture_base_color", item.texture_base_color)
	if source is BaseMaterial3D:
		material.set_shader_parameter(&"albedo_texture", source.albedo_texture)
	return material


func _find_skeleton(root: Node) -> Skeleton3D:
	if root is Skeleton3D:
		return root
	var skeletons := root.find_children("*", "Skeleton3D", true, false)
	return null if skeletons.is_empty() else skeletons[0]


func _shares_bones_with_rig(item_skeleton: Skeleton3D) -> bool:
	var profile := clothing_rig.profile
	for i in profile.bone_size:
		if item_skeleton.find_bone(profile.get_bone_name(i)) >= 0:
			return true
	return false


func _find_meshes(root: Node) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	meshes.assign(root.find_children("*", "MeshInstance3D", true, false))
	if root is MeshInstance3D:
		meshes.append(root)
	return meshes
