extends Node

const MAIN_GAME_SCENE_PATH = "res://main.tscn"
const MAIN_MENU_SCENE_PATH = "res://ui/main_menu.tscn"
const INTRO_OVERLAY_SCENE_PATH = "res://conversation/AdvancedConversationOverlay.tscn"
const GAME_OVER_SCENE = preload("res://ui/game_over.tscn")
const DIFFICULTY_SELECT_SCENE = preload("res://ui/difficulty_select_screen.tscn")

var cached_main_menu_scene: PackedScene = null
var cached_intro_overlay_scene: PackedScene = null
var cached_main_game_scene: PackedScene = null

var main_menu_scene_instance: CanvasLayer = null
var current_game_scene: Node = null
var intro_overlay: Node = null

func show_main_menu() -> Node:
	if is_instance_valid(main_menu_scene_instance):
		return main_menu_scene_instance

	var menu_packed_scene = cached_main_menu_scene
	if not menu_packed_scene:
		menu_packed_scene = load(MAIN_MENU_SCENE_PATH)
		if not menu_packed_scene:
			return null

	main_menu_scene_instance = menu_packed_scene.instantiate()
	get_tree().root.add_child(main_menu_scene_instance)
	return main_menu_scene_instance

func free_main_menu():
	if is_instance_valid(main_menu_scene_instance):
		main_menu_scene_instance.queue_free()
		main_menu_scene_instance = null

func show_difficulty_select() -> Node:
	var difficulty_screen = DIFFICULTY_SELECT_SCENE.instantiate()
	get_tree().root.add_child(difficulty_screen)
	return difficulty_screen

func start_intro_overlay(dialogue: DialogueResource, on_finished: Callable) -> Node:
	var intro_overlay_packed_scene = cached_intro_overlay_scene
	if not intro_overlay_packed_scene:
		intro_overlay_packed_scene = load(INTRO_OVERLAY_SCENE_PATH)
		if not intro_overlay_packed_scene:
			print_rich("[color=red]GM Error: Failed to load Intro Overlay Scene at path: %s[/color]" % INTRO_OVERLAY_SCENE_PATH)
			return null

	var instance = intro_overlay_packed_scene.instantiate()
	instance.is_intro_sequence = true
	instance.dialogue_resource = dialogue
	instance.conversation_finished.connect(on_finished, CONNECT_ONE_SHOT)
	get_tree().root.add_child(instance)
	intro_overlay = instance
	return instance

func free_intro_overlay():
	if is_instance_valid(intro_overlay):
		intro_overlay.queue_free()
		intro_overlay = null

func ensure_game_scene() -> bool:
	if is_instance_valid(current_game_scene):
		return false

	var main_packed_scene = cached_main_game_scene
	if not main_packed_scene:
		main_packed_scene = load(MAIN_GAME_SCENE_PATH)
		if not main_packed_scene:
			print_rich("[color=red]GameManager Error: Failed to load Main Game Scene.[/color]")
			return false

	current_game_scene = main_packed_scene.instantiate()
	get_tree().root.add_child(current_game_scene)
	return true

func teardown_game_scene():
	if is_instance_valid(current_game_scene):
		current_game_scene.queue_free()
		current_game_scene = null

func show_game_over() -> Node:
	var game_over_instance = GAME_OVER_SCENE.instantiate()
	get_tree().root.add_child(game_over_instance)
	return game_over_instance

func clear_active_dialogue_balloons(node: Node = null):
	if node == null:
		node = get_tree().root

	for child in node.get_children():
		if "Balloon" in child.name or "conversationballoon" in child.name.to_lower():
			child.queue_free()
		else:
			clear_active_dialogue_balloons(child)

func _cleanup_all_overlays(node: Node = null):
	if node == null:
		node = get_tree().root
		GameManager.force_close_tracked_overlays()

	for child in node.get_children():
		if child is CharacterConversationOverlay or child is AdvancedConversationOverlay:
			if "current_balloon" in child and is_instance_valid(child.current_balloon):
				child.current_balloon.queue_free()
			child.queue_free()
		elif child is ObjectZoomOverlay:
			child.queue_free()
		elif "MemoryBoxOverlay" in child.name:
			child.queue_free()
		elif "Balloon" in child.name or "conversationballoon" in child.name.to_lower():
			child.queue_free()
		elif "DialogueHistory" in child.name and child != DialogueHistory:
			child.queue_free()
		else:
			_cleanup_all_overlays(child)
