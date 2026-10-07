@tool
class_name OutfitCatalog
extends Resource
## The list of every [OutfitItem] a player can choose from.

@export var items: Array[OutfitItem] = []
@export_tool_button("Bake Hide Masks", "Bake") var bake_hide_masks_button := bake_hide_masks


## Returns every item that is worn in [param slot].
func get_items_for_slot(slot: OutfitItem.Slot) -> Array[OutfitItem]:
	var result: Array[OutfitItem] = []
	result.assign(items.filter(func(item: OutfitItem) -> bool: return item.slot == slot))
	return result


## Bakes every item's body hide mask, plus a covered mask for every pair of
## skinned items on different layers (what the higher one hides of the lower).
func bake_hide_masks() -> void:
	# Only skinned items with a body to bake against hide anything.
	var skinned := items.filter(func(item: OutfitItem) -> bool:
		return item.attach_bone.is_empty() and item.hide_mask_body != null)
	for item: OutfitItem in skinned:
		item.bake_hide_mask()
	for under: OutfitItem in skinned:
		for over: OutfitItem in skinned:
			if over.layer > under.layer:
				under.bake_covered_mask(over)
