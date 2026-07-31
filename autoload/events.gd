# events.gd (autoload) — global signal bus.
# declare broadcast signals here. anything
# rule of thumb: notifications ("x
# commands ("do x") are direct
extends Node

# //////////////// game flow (values are gamemanager.gamestate / gamemanager.interactionstate ints)
signal game_state_changed(new_state: int)
signal interaction_state_changed(new_state: int)

# /////////// inventory
signal item_added(item_id: String)
signal item_removed(item_id: String)
signal room_changed

# ------------- ui
signal notification_requested(message: String)
signal explanation_started(data: ExplanationData, root_node: Node)
signal gameplay_ui_visibility_requested(visible: bool)
signal zoom_hud_config_requested(show_verb_panel: bool, show_inventory: bool)
