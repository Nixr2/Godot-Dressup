class_name OutfitCatalog
extends Resource
## The list of every [OutfitItem] a player can choose from.

@export var items: Array[OutfitItem] = []


## Returns every item that is worn in [param slot].
func get_items_for_slot(slot: OutfitItem.Slot) -> Array[OutfitItem]:
	var result: Array[OutfitItem] = []
	result.assign(items.filter(func(item: OutfitItem) -> bool: return item.slot == slot))
	return result
