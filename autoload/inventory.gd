# inventory.gd (autoload) — the player's
extends Node

signal inventory_updated(items: Array[ItemData])

var items: Array[ItemData] = []
var _item_data_map: Dictionary = {}


func setup(all_item_data_resources: Array[ItemData]):
	_item_data_map.clear()
	for item_data_res in all_item_data_resources:
		if item_data_res and item_data_res.item_id != "" and not _item_data_map.has(item_data_res.item_id):
			_item_data_map[item_data_res.item_id] = item_data_res


func add_item(item_id_to_add: String):
	var item_data = get_item_data_by_id(item_id_to_add)
	if not item_data:
		return
	if not item_data.is_stackable and has_item(item_id_to_add):
		return
	items.append(item_data)
	inventory_updated.emit(items.duplicate())
	Events.item_added.emit(item_id_to_add)
	Events.notification_requested.emit("Picked up: " + item_data.display_name)


func remove_item(item_id_to_remove: String):
	var item_data_ref = get_item_data_by_id(item_id_to_remove)
	if not item_data_ref:
		return
	var removed_any: bool = false
	for i in range(items.size() - 1, -1, -1):
		if items[i].item_id == item_id_to_remove:
			items.remove_at(i)
			removed_any = true
			inventory_updated.emit(items.duplicate())
			Events.item_removed.emit(item_id_to_remove)
			if not item_data_ref.is_stackable:
				break
	if removed_any:
		SoundManager.play_sfx("item_remove", 1.0, -3.0)


func has_item(item_id_to_check: String) -> bool:
	for item_data_in_inv in items:
		if item_data_in_inv.item_id == item_id_to_check:
			return true
	return false


func get_item_data_by_id(item_id_to_find: String) -> ItemData:
	if _item_data_map.has(item_id_to_find):
		return _item_data_map[item_id_to_find]
	return null


func get_items() -> Array[ItemData]:
	return items.duplicate()


func is_empty() -> bool:
	return items.is_empty()


func reset():
	items.clear()
	inventory_updated.emit(items.duplicate())
