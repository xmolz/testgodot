# game_ui.gd — owns visibility and
# gamemanager no longer holds references
# the events bus and dialoguemanager,
# it is freed together with
extends Node

const ZOOM_CONTROLS_UI_SCENE = preload("res://ui/zoom_controls_ui.tscn")

@onready var verb_ui: CanvasLayer = %VerbUI_CanvasLayer
@onready var inventory_ui: CanvasLayer = %InventoryUI_CanvasLayer
@onready var journal_button_ui: CanvasLayer = %JournalButtonUI
@onready var insurance_form_button_ui: CanvasLayer = %InsuranceFormButtonUI
@onready var explanation_layer: CanvasLayer = %ExplanationLayer

var zoom_controls_ui: CanvasLayer = null

var _zoom_show_verb_panel: bool = true
var _zoom_show_inventory: bool = true
var _dialogue_active: bool = false


func _ready() -> void:
	add_to_group("game_ui_nodes")
	Events.game_state_changed.connect(_on_game_state_changed)
	Events.interaction_state_changed.connect(_on_interaction_state_changed)
	Events.explanation_started.connect(_on_explanation_started)
	Events.gameplay_ui_visibility_requested.connect(_set_gameplay_ui_visible)
	Events.zoom_hud_config_requested.connect(_on_zoom_hud_config_requested)
	
	# single init path (see step 1.6): re-derive the hud once saved level
	# flags have been applied. fires on fresh runs too; recompute is idempotent.
	Events.level_state_ready.connect(_refresh_hud)

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


# applied once on scene load
# normal boot: change_game_state(in_game_play) instantiates main.tscn
# emitting game_state_changed, so we missed
# direct scene run (f6 on
func _sync_initial_visibility() -> void:
	_zoom_show_verb_panel = true
	_zoom_show_inventory = true
	_refresh_hud()


func _on_zoom_hud_config_requested(show_verb_panel: bool, show_inventory: bool) -> void:
	_zoom_show_verb_panel = show_verb_panel
	_zoom_show_inventory = show_inventory
	_refresh_hud()


# what the hud should look
func _apply_zoom_hud_visibility() -> void:
	if is_instance_valid(verb_ui):
		verb_ui.visible = true
		verb_ui.set_panel_visible(_zoom_show_verb_panel)
	if is_instance_valid(inventory_ui):
		inventory_ui.visible = _zoom_show_inventory
	if is_instance_valid(journal_button_ui):
		journal_button_ui.visible = false
	if is_instance_valid(insurance_form_button_ui):
		insurance_form_button_ui.visible = false


func _refresh_hud() -> void:
	if not GameManager: return
	var state = GameManager.current_game_state
	var interaction = GameManager.current_interaction_state

	if state == GameManager.GameState.CUTSCENE or _dialogue_active:
		_set_gameplay_ui_visible(false)
		return

	match interaction:
		GameManager.InteractionState.ZOOM_VIEW:
			if is_instance_valid(verb_ui): verb_ui.layer = 3
			if is_instance_valid(inventory_ui): inventory_ui.layer = 3
			_apply_zoom_hud_visibility()
		GameManager.InteractionState.CONVERSATION:
			_set_gameplay_ui_visible(false)
		GameManager.InteractionState.WORLD:
			if is_instance_valid(verb_ui):
				verb_ui.layer = 1
				verb_ui.set_panel_visible(true)
			if is_instance_valid(inventory_ui): inventory_ui.layer = 1
			_set_gameplay_ui_visible(state == GameManager.GameState.IN_GAME_PLAY)
		_:
			pass


# ///////////////// event handlers

func _on_game_state_changed(new_state: int) -> void:
	_refresh_hud()


func _on_interaction_state_changed(new_state: int) -> void:
	if new_state == GameManager.InteractionState.ZOOM_VIEW or new_state == GameManager.InteractionState.WORLD:
		_zoom_show_verb_panel = true
		_zoom_show_inventory = true
	_refresh_hud()


func _on_dialogue_started(_resource: Resource) -> void:
	_dialogue_active = true
	_refresh_hud()


func _on_dialogue_ended(_resource: Resource) -> void:
	_dialogue_active = false
	_refresh_hud()


func notify_dialogue_force_cleared() -> void:
	_dialogue_active = false
	_refresh_hud()


func _on_explanation_started(data: ExplanationData, root_node_to_search: Node) -> void:
	# moved verbatim from gamemanager.start_explanation(): hide
	# for the nodes the explanationdata
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


# ------------------ core visibility helper (moved from gamemanager, minus the global patreon
# ////////////[button, which stays with gamemanager)]

func _set_gameplay_ui_visible(show: bool) -> void:
	print_rich("[color=gray]GameUI: hud visible=%s (state=%s interaction=%s dialogue=%s)[/color]" % [show, GameManager.current_game_state, GameManager.current_interaction_state, _dialogue_active])
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
