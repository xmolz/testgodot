# Events.gd (Autoload) — global signal bus.
# Declare broadcast signals here. Anything may emit them; anything may connect.
# Rule of thumb: notifications ("X happened") go through Events.
# Commands ("do X") are direct calls on the service autoloads (Inventory, Flags, ...).
extends Node

# --- Game flow (values are GameManager.GameState / GameManager.InteractionState ints) ---
signal game_state_changed(new_state: int)
signal interaction_state_changed(new_state: int)

# --- Inventory ---
signal item_added(item_id: String)
signal item_removed(item_id: String)

# --- UI ---
signal notification_requested(message: String)
