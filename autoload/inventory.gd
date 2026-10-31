# inventory.gd (autoload) — the player's
extends Node

signal inventory_updated(items: Array[ItemData])

var items: Array[ItemData] = []
var _item_data_map: Dictionary = {}
var _counts: Dictionary = {}   # stackable item_id -> count (a stackable item uses one slot)

# step 2.394: the present and the past keep separate pockets. the hub (the clinic, the present) and a
# memory chapter (the past, relived through the memory box) each have their own inventory: entering a
# memory puts the hub's items aside and starts the chapter with empty pockets; coming back out puts the
# hub's items back exactly as they were, and whatever the memory held stays in the memory. only the item
# references move (nothing is copied or loaded), so a switch costs nothing.
var in_memory: bool = false
var _hub_items: Array[ItemData] = []
var _hub_counts: Dictionary = {}


func setup(all_item_data_resources: Array[ItemData]):
	_item_data_map.clear()
	for item_data_res in all_item_data_resources:
		if item_data_res and item_data_res.item_id != "" and not _item_data_map.has(item_data_res.item_id):
			_item_data_map[item_data_res.item_id] = item_data_res


func add_item(item_id_to_add: String, amount: int = 1):
	var item_data = get_item_data_by_id(item_id_to_add)
	if not item_data:
		return
	if item_data.is_stackable:
		# stackables share one slot; the count lives in _counts (badge in InventoryUI)
		if not has_item(item_id_to_add):
			items.append(item_data)
		_counts[item_id_to_add] = int(_counts.get(item_id_to_add, 0)) + maxi(amount, 1)
	else:
		if has_item(item_id_to_add):
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
			_counts.erase(item_id_to_remove)
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


# how many of an item the player holds: the stack count for stackables, else 1 or 0.
func get_count(item_id_to_check: String) -> int:
	if not has_item(item_id_to_check):
		return 0
	return int(_counts.get(item_id_to_check, 1))


# spends `amount` of a stackable (e.g. cents of cash). false if there isn't enough.
# the slot disappears when the count reaches zero.
func remove_amount(item_id_to_remove: String, amount: int) -> bool:
	var have: int = get_count(item_id_to_remove)
	if amount <= 0 or have < amount:
		return false
	if have == amount:
		remove_item(item_id_to_remove)
	else:
		_counts[item_id_to_remove] = have - amount
		inventory_updated.emit(items.duplicate())
	return true


# save/load support (save_manager.gd)
func get_counts() -> Dictionary:
	return _counts.duplicate()


func set_counts(saved_counts: Dictionary) -> void:
	for id in saved_counts:
		if has_item(str(id)):
			_counts[str(id)] = int(saved_counts[id])
	inventory_updated.emit(items.duplicate())


func get_item_data_by_id(item_id_to_find: String) -> ItemData:
	if _item_data_map.has(item_id_to_find):
		return _item_data_map[item_id_to_find]
	return null


func get_items() -> Array[ItemData]:
	return items.duplicate()


func is_empty() -> bool:
	return items.is_empty()


## step 2.394: entering a memory chapter (SaveManager.stash_hub_state, called by the launch pipeline
## while the hub is still loaded). the hub's items go aside; the chapter starts with empty pockets.
func enter_memory() -> void:
	if in_memory:
		return
	_drop_held_item()
	_hub_items = items.duplicate()
	_hub_counts = _counts.duplicate()
	items.clear()
	_counts.clear()
	in_memory = true
	inventory_updated.emit(items.duplicate())


## step 2.394: back to the hub (SaveManager.queue_hub_state_restore, called by the return pipeline before
## the hub is instanced). the hub's items come back as they were; the memory's items stay behind.
func leave_memory() -> void:
	if not in_memory:
		return
	_drop_held_item()
	items = _hub_items.duplicate()
	_counts = _hub_counts.duplicate()
	_hub_items.clear()
	_hub_counts.clear()
	in_memory = false
	inventory_updated.emit(items.duplicate())


## step 2.394: for a save made inside a memory: the hub's set-aside items, by id. {} in the hub.
func get_hub_stash() -> Dictionary:
	if not in_memory:
		return {}
	var ids: Array = []
	for item_data in _hub_items:
		ids.append(item_data.item_id)
	return {"item_ids": ids, "counts": _hub_counts.duplicate()}


## step 2.394: loading a save made inside a memory: the hub's items go back aside, quietly (no pick-up
## notes), to come back out on the return trip.
func set_hub_stash(stash: Dictionary) -> void:
	_hub_items.clear()
	_hub_counts.clear()
	var ids = stash.get("item_ids", [])
	if ids is Array:
		for id in ids:
			var item_data: ItemData = get_item_data_by_id(str(id))
			if item_data and not _hub_items.has(item_data):
				_hub_items.append(item_data)
	var saved_counts = stash.get("counts", {})
	if saved_counts is Dictionary:
		for id in saved_counts:
			_hub_counts[str(id)] = int(saved_counts[id])
	in_memory = true


# step 2.394: a hub item still held on the cursor would otherwise ride along into the memory (or back out)
func _drop_held_item() -> void:
	if GameManager and GameManager.current_selected_item_data != null:
		GameManager.cancel_current_action(false)


func reset():
	items.clear()
	_counts.clear()
	# step 2.394: a new run or a load starts outside any memory
	in_memory = false
	_hub_items.clear()
	_hub_counts.clear()
	inventory_updated.emit(items.duplicate())
