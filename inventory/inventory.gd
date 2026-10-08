class_name Inventory
extends RefCounted
## The clothing the player owns, which they can put on in game (see
## PhoneMenu). Each item is owned at most once.
##
## Saved by [PlayerSection] as a list of item ids.

## Emitted when an item is added or removed.
signal changed

var _items: Array[OutfitItem] = []


## Returns every owned item, in the order they were added.
func get_items() -> Array[OutfitItem]:
	return _items.duplicate()


## Returns the owned items worn in [param slot].
func get_items_for_slot(slot: OutfitItem.Slot) -> Array[OutfitItem]:
	var result: Array[OutfitItem] = []
	result.assign(_items.filter(func(item: OutfitItem) -> bool: return item.slot == slot))
	return result


func has(item: OutfitItem) -> bool:
	return item in _items


## Adds [param item] if it isn't owned yet. Returns true if it was added.
func add(item: OutfitItem) -> bool:
	if item == null or has(item):
		return false
	_items.append(item)
	changed.emit()
	return true


## Adds every item in [param items] that isn't owned yet.
func add_all(items: Array[OutfitItem]) -> void:
	var added := false
	for item in items:
		if item and not has(item):
			_items.append(item)
			added = true
	if added:
		changed.emit()


## Removes [param item]. Returns true if it was owned.
func remove(item: OutfitItem) -> bool:
	if not has(item):
		return false
	_items.erase(item)
	changed.emit()
	return true


## Returns the owned items' ids, for saving.
func to_ids() -> Array[String]:
	var ids: Array[String] = []
	for item in _items:
		ids.append(String(item.id))
	return ids


## Replaces the owned items with those in [param ids]; [param find_item] turns
## an id into its [OutfitItem] (or null), and unknown ids are skipped.
func load_ids(ids: Array, find_item: Callable) -> void:
	_items.clear()
	for id: Variant in ids:
		var item: OutfitItem = find_item.call(StringName(str(id)))
		if item and not has(item):
			_items.append(item)
		elif item == null:
			push_warning("Inventory: unknown item '%s' skipped." % id)
	changed.emit()
