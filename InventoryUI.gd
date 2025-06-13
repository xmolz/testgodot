# InventoryUI.gd
extends CanvasLayer

# --- Node References ---
@onready var item_name_hover_label: Label = $ItemNameHoverLabel
@onready var inventory_grid_container: GridContainer = $InventoryGridPanel/InventoryGridContainer
@onready var up_button: Button = $InventoryGridPanel/UpButton
@onready var down_button: Button = $InventoryGridPanel/DownButton
# @onready var examine_item_label: Label = $ExamineItemLabel # Uncomment if you have this

# --- Configuration ---
const ITEMS_PER_PAGE: int = 6 # 3 columns * 2 rows

# --- State Variables ---
var all_inventory_slots: Array[Button] = [] # Will hold the 6 Button nodes for slots
var current_player_inventory_cache: Array[ItemData] = [] # Local cache of player's items
var current_page_index: int = 0
var total_pages: int = 0

# To avoid constant reallocation for hover label background if using a StyleBoxFlat
var _hover_label_stylebox: StyleBoxFlat = null


func _ready():
	# Validate node paths
	if not item_name_hover_label: print_rich("[color=red]InventoryUI: ItemNameHoverLabel not found![/color]")
	if not inventory_grid_container: print_rich("[color=red]InventoryUI: InventoryGridContainer not found![/color]"); return
	if not up_button: print_rich("[color=red]InventoryUI: UpButton not found![/color]")
	if not down_button: print_rich("[color=red]InventoryUI: DownButton not found![/color]")

	if inventory_grid_container:
		inventory_grid_container.columns = 3 # Ensuring 3 columns for 3x2 layout

	# --- Initialize Hover Label ---
	if item_name_hover_label:
		item_name_hover_label.visible = false
		_hover_label_stylebox = StyleBoxFlat.new()
		_hover_label_stylebox.bg_color = Color(0.1, 0.1, 0.1, 0.8)
		_hover_label_stylebox.set_content_margin_all(5)
		_hover_label_stylebox.corner_radius_top_left = 3
		_hover_label_stylebox.corner_radius_top_right = 3
		_hover_label_stylebox.corner_radius_bottom_left = 3
		_hover_label_stylebox.corner_radius_bottom_right = 3
		item_name_hover_label.add_theme_stylebox_override("panel", _hover_label_stylebox)

	# --- Initialize exactly ITEMS_PER_PAGE slot buttons ---
	for child in inventory_grid_container.get_children():
		inventory_grid_container.remove_child(child)
		child.queue_free()
	all_inventory_slots.clear()

	for i in range(ITEMS_PER_PAGE):
		var slot_button = Button.new()
		slot_button.name = "InventorySlotButton_" + str(i)
		slot_button.custom_minimum_size = Vector2(50, 50)
		slot_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		slot_button.disabled = true
		slot_button.focus_mode = Control.FOCUS_NONE

		var icon_rect = TextureRect.new()
		icon_rect.name = "ItemIcon"
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 2)
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_button.add_child(icon_rect)

		all_inventory_slots.append(slot_button)
		inventory_grid_container.add_child(slot_button)

	# --- Connect to GameManager Signals ---
	if GameManager:
		GameManager.inventory_updated.connect(_on_game_manager_inventory_updated)
		GameManager.selected_inventory_item_changed.connect(_on_game_manager_selected_item_changed)
		GameManager.interaction_complete.connect(_on_interaction_complete)

		if GameManager.has_method("get_player_inventory"):
			_on_game_manager_inventory_updated(GameManager.get_player_inventory())
		else:
			print_rich("[color=orange]InventoryUI: GameManager has no get_player_inventory method.[/color]")
	else:
		print_rich("[color=red]InventoryUI: GameManager not found![/color]")

	# --- Connect Pagination Buttons ---
	if up_button: up_button.pressed.connect(_on_up_button_pressed)
	if down_button: down_button.pressed.connect(_on_down_button_pressed)

	_update_pagination_buttons_state()


func _process(_delta: float) -> void:
	if item_name_hover_label and item_name_hover_label.visible:
		item_name_hover_label.global_position = get_viewport().get_mouse_position() + Vector2(20, -30)


func _on_game_manager_inventory_updated(full_inventory_data: Array[ItemData]):
	current_player_inventory_cache = full_inventory_data.duplicate()
	total_pages = 1 if current_player_inventory_cache.is_empty() else ceil(float(current_player_inventory_cache.size()) / ITEMS_PER_PAGE)
	current_page_index = clamp(current_page_index, 0, max(0, total_pages - 1))
	_render_current_page()
	_update_pagination_buttons_state()
	_update_slot_selected_visual_state(GameManager.current_selected_item_data if GameManager else null)


func _render_current_page():
	if not is_instance_valid(inventory_grid_container):
		print_rich("[color=red]InventoryUI: _render_current_page - InventoryGridContainer is null or invalid![/color]")
		return
	if all_inventory_slots.is_empty():
		print_rich("[color=yellow]InventoryUI: _render_current_page - all_inventory_slots is empty.[/color]")
		return

	var start_index = current_page_index * ITEMS_PER_PAGE

	for i in range(all_inventory_slots.size()):
		var slot_button: Button = all_inventory_slots[i]
		if not is_instance_valid(slot_button): continue

		var icon_rect: TextureRect = slot_button.get_node_or_null("ItemIcon")

		# --- CORRECTED SIGNAL DISCONNECTION ---
		# Disconnect old signals using string names
		var pressed_callable = Callable(self, "_on_inventory_slot_pressed")
		if slot_button.is_connected("pressed", pressed_callable):
			slot_button.disconnect("pressed", pressed_callable)

		var mouse_entered_callable = Callable(self, "_on_slot_mouse_entered")
		if slot_button.is_connected("mouse_entered", mouse_entered_callable):
			slot_button.disconnect("mouse_entered", mouse_entered_callable)

		var mouse_exited_callable = Callable(self, "_on_slot_mouse_exited")
		if slot_button.is_connected("mouse_exited", mouse_exited_callable):
			slot_button.disconnect("mouse_exited", mouse_exited_callable)
		# --- END CORRECTED SIGNAL DISCONNECTION ---

		var inventory_item_index = start_index + i
		if inventory_item_index < current_player_inventory_cache.size():
			var item_data: ItemData = current_player_inventory_cache[inventory_item_index]

			if not is_instance_valid(item_data):
				print_rich("[color=red]InventoryUI: _render_current_page - ItemData at inventory index %s is invalid![/color]" % inventory_item_index)
				slot_button.disabled = true
				slot_button.set_meta("item_data", null)
				if icon_rect: icon_rect.texture = null; icon_rect.visible = false
				slot_button.text = "ERR"
				continue

			slot_button.disabled = false
			slot_button.set_meta("item_data", item_data)

			if icon_rect:
				icon_rect.texture = item_data.icon
				icon_rect.visible = (item_data.icon != null)

				if icon_rect.visible:
					slot_button.text = "" # <<--- FIX: Clear button text if icon is visible
				else:
					slot_button.text = item_data.display_name.substr(0, 3) if item_data.display_name else "???"
			else:
				print_rich("[color=yellow]InventoryUI: _render_current_page - ItemIcon TextureRect missing in slot %s.[/color]" % i)
				slot_button.text = item_data.display_name.substr(0,3) if item_data.display_name else "???"

			slot_button.pressed.connect(_on_inventory_slot_pressed.bind(item_data))
			slot_button.mouse_entered.connect(_on_slot_mouse_entered.bind(item_data, slot_button))
			slot_button.mouse_exited.connect(_on_slot_mouse_exited)
		else:
			slot_button.disabled = true
			slot_button.set_meta("item_data", null)
			if icon_rect:
				icon_rect.texture = null
				icon_rect.visible = false
			slot_button.text = "-" # Placeholder for empty slot

	if GameManager:
		_update_slot_selected_visual_state(GameManager.current_selected_item_data)
	else:
		_update_slot_selected_visual_state(null)


func _on_inventory_slot_pressed(item_data_pressed: ItemData):
	if GameManager and item_data_pressed:
		GameManager.select_inventory_item(item_data_pressed)


func _on_slot_mouse_entered(item_data_hovered: ItemData, _slot_button_node: Button):
	if item_name_hover_label and item_data_hovered:
		item_name_hover_label.text = item_data_hovered.display_name
		item_name_hover_label.visible = true


func _on_slot_mouse_exited():
	if item_name_hover_label:
		item_name_hover_label.visible = false


func _on_game_manager_selected_item_changed(selected_item: ItemData):
	_update_slot_selected_visual_state(selected_item)
	if item_name_hover_label and selected_item == null :
		item_name_hover_label.visible = false


func _on_interaction_complete():
	if item_name_hover_label:
		item_name_hover_label.visible = false


func _update_slot_selected_visual_state(selected_item_data: ItemData):
	for slot_button in all_inventory_slots:
		if not is_instance_valid(slot_button): continue
		var slot_item_data = slot_button.get_meta("item_data", null)
		if slot_item_data and selected_item_data and slot_item_data.item_id == selected_item_data.item_id:
			slot_button.modulate = Color(0.7, 0.7, 1.0, 1.0)
		else:
			slot_button.modulate = Color(1.0, 1.0, 1.0, 1.0)


# --- Pagination Logic ---
func _on_up_button_pressed():
	if current_page_index > 0:
		current_page_index -= 1
		_render_current_page()
		_update_pagination_buttons_state()

func _on_down_button_pressed():
	if current_page_index < total_pages - 1:
		current_page_index += 1
		_render_current_page()
		_update_pagination_buttons_state()

func _update_pagination_buttons_state():
	if up_button: up_button.disabled = (current_page_index == 0)
	if down_button: down_button.disabled = (current_page_index >= total_pages - 1)
