# game_ui.gd — owns visibility and layering of the gameplay HUD in main.tscn.
# GameManager no longer holds references to these nodes; this script reacts to
# the Events bus and DialogueManager, and manages the local UI itself.
# It is freed together with the level scene, so no manual disconnects needed.
extends Node

const ZOOM_CONTROLS_UI_SCENE = preload("res://ui/zoom_controls_ui.tscn")

@onready var verb_ui: CanvasLayer = %VerbUI_CanvasLayer
@onready var inventory_ui: CanvasLayer = %InventoryUI_CanvasLayer
@onready var journal_button_ui: CanvasLayer = %JournalButtonUI
@onready var insurance_form_button_ui: CanvasLayer = %InsuranceFormButtonUI
@onready var explanation_layer: CanvasLayer = %ExplanationLayer

var zoom_controls_ui: CanvasLayer = null


func _ready() -> void:
	Events.game_state_changed.connect(_on_game_state_changed)
	Events.interaction_state_changed.connect(_on_interaction_state_changed)
	Events.explanation_started.connect(_on_explanation_started)
	Events.gameplay_ui_visibility_requested.connect(_set_gameplay_ui_visible)

	zoom_controls_ui = ZOOM_CONTROLS_UI_SCENE.instantiate()
	add_child(zoom_controls_ui)

	if DialogueManager:
		DialogueManager.dialogue_started.connect(_on_dialogue_started)
		DialogueManager.dialogue_ended.connect(_on_dialogue_ended)

	if is_instance_valid(explanation_layer):
		explanation_layer.explanation_finished.connect(GameManager.exit_explanation_state)

	if is_instance_valid(insurance_form_button_ui):
		insurance_form_button_ui.form_button_pressed.connect(GameManager.open_insurance_form)

	if is_instance_valid(journal_button_ui):
		journal_button_ui.journal_button_pressed.connect(GameManager.open_journal)

	_sync_initial_visibility()


# Applied once on scene load so both boot paths start correct:
# - normal boot: change_game_state(IN_GAME_PLAY) instantiates main.tscn AFTER
#   emitting game_state_changed, so we missed that first emission;
# - direct scene run (F6 on main.tscn): no state event is emitted at all.
func _sync_initial_visibility() -> void:
	if not GameManager:
		return
	if GameManager.current_game_state == GameManager.GameState.CUTSCENE:
		_set_gameplay_ui_visible(false)
		return
	_set_gameplay_ui_visible(GameManager.current_interaction_state == GameManager.InteractionState.WORLD)


# --- Event handlers ---

func _on_game_state_changed(new_state: int) -> void:
	match new_state:
		GameManager.GameState.IN_GAME_PLAY:
			# Mirrors the old "restoration phase" in GameManager.change_game_state().
			_set_gameplay_ui_visible(GameManager.current_interaction_state == GameManager.InteractionState.WORLD)
		GameManager.GameState.CUTSCENE:
			_set_gameplay_ui_visible(false)
		_:
			# PAUSED, EXPLANATION, etc. deliberately leave visibility untouched,
			# exactly like the old GameManager code did.
			pass


func _on_interaction_state_changed(new_state: int) -> void:
	match new_state:
		GameManager.InteractionState.CONVERSATION:
			_set_gameplay_ui_visible(false)
		GameManager.InteractionState.ZOOM_VIEW:
			# The zoom overlay sits on CanvasLayer 2; lift verb + inventory above it.
			if is_instance_valid(verb_ui):
				verb_ui.layer = 3
				verb_ui.visible = true
			if is_instance_valid(inventory_ui):
				inventory_ui.layer = 3
				inventory_ui.visible = true
		GameManager.InteractionState.WORLD:
			if is_instance_valid(verb_ui):
				verb_ui.layer = 1
			if is_instance_valid(inventory_ui):
				inventory_ui.layer = 1
			_set_gameplay_ui_visible(true)


func _on_dialogue_started(_resource: Resource) -> void:
	# Hide the HUD whenever any dialogue line appears (world dialogue,
	# character conversations, insurance-form balloons — all of it).
	_set_gameplay_ui_visible(false)


func _on_dialogue_ended(_resource: Resource) -> void:
	# Restore-without-unpausing, with the exact guards the old
	# GameManager.restore_world_after_object_dialogue() used: never restore
	# during a full-screen conversation, and only while actually in gameplay.
	if GameManager.current_interaction_state != GameManager.InteractionState.CONVERSATION \
			and GameManager.current_game_state == GameManager.GameState.IN_GAME_PLAY:
		_set_gameplay_ui_visible(true)


func _on_explanation_started(data: ExplanationData, root_node_to_search: Node) -> void:
	# Moved verbatim from GameManager.start_explanation(): hide the HUD except
	# for the nodes the ExplanationData explicitly spotlights.
	var nodes_to_keep_visible: Array = []
	if "exceptions_to_hide" in data:
		for node_path in data.exceptions_to_hide:
			var node = root_node_to_search.get_node_or_null(node_path)
			if is_instance_valid(node):
				nodes_to_keep_visible.append(node)

	if is_instance_valid(verb_ui) and not verb_ui in nodes_to_keep_visible:
		verb_ui.hide()
	if is_instance_valid(inventory_ui) and not inventory_ui in nodes_to_keep_visible:
		inventory_ui.hide()
	if is_instance_valid(journal_button_ui) and not journal_button_ui in nodes_to_keep_visible:
		journal_button_ui.hide()
	if is_instance_valid(zoom_controls_ui) and not zoom_controls_ui in nodes_to_keep_visible:
		zoom_controls_ui.set_gameplay_ui_visible(false)
	if is_instance_valid(insurance_form_button_ui):
		if insurance_form_button_ui in nodes_to_keep_visible:
			insurance_form_button_ui.show()
		else:
			insurance_form_button_ui.hide()

	if is_instance_valid(explanation_layer):
		explanation_layer.show_explanation(data, root_node_to_search)


# --- Core visibility helper (moved from GameManager, minus the global patreon
# button, which stays with GameManager) ---

func _set_gameplay_ui_visible(show: bool) -> void:
	if is_instance_valid(verb_ui):
		verb_ui.visible = show
	if is_instance_valid(inventory_ui):
		inventory_ui.visible = show
	if is_instance_valid(journal_button_ui):
		journal_button_ui.visible = show
	if is_instance_valid(zoom_controls_ui):
		zoom_controls_ui.set_gameplay_ui_visible(show)
	if is_instance_valid(insurance_form_button_ui):
		insurance_form_button_ui.visible = Flags.get_level_flag("insurance_button_unlocked") if show else false
