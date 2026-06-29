extends Node

func _ready():
	# 1. Create a SubViewport with exact 1800x2400 dimensions
	var viewport = SubViewport.new()
	viewport.size = Vector2(1800, 2400)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	add_child(viewport)

	# 2. Add the background image
	var tex_rect = TextureRect.new()
	tex_rect.texture = load("res://Backgrounds/alyssa marketing post.png")
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(tex_rect)

	# 3. Increase font size dynamically for the 1800x2400 resolution
	if GameManager:
		GameManager.dialogue_text_scale = 1.8

	# 4. Instantiate the balloon inside the viewport
	var dialogue_res = load("res://dialogue/alyssa_marketing.dialogue")
	var balloon = preload("res://conversationballoon.tscn").instantiate()
	viewport.add_child(balloon)
	balloon.start(dialogue_res, "start")

	# Wait a frame for layout to initialize
	await get_tree().process_frame
	await get_tree().process_frame

	# 5. Customize the Balloon layout for this exact aspect ratio!
	var panel = balloon.get_node("%Balloon/Panel")
	var diag = balloon.get_node("%Balloon/Dialogue")
	var name_panel = balloon.get_node("%Balloon/NamePanel")
	var quick_menu = balloon.get_node_or_null("%QuickMenu")

	# Hide the bottom quick menu (Menu, Log, Auto, Hide)
	if quick_menu:
		quick_menu.hide()

	# Adjust the main box to have nice padding and be taller
	if panel:
		panel.anchor_left = 0.0
		panel.anchor_right = 1.0
		panel.anchor_top = 1.0
		panel.anchor_bottom = 1.0
		panel.offset_left = 80
		panel.offset_right = -80
		panel.offset_top = -350
		panel.offset_bottom = -40

	if diag:
		diag.anchor_left = 0.0
		diag.anchor_right = 1.0
		diag.anchor_top = 1.0
		diag.anchor_bottom = 1.0
		diag.offset_left = 80
		diag.offset_right = -80
		diag.offset_top = -350
		diag.offset_bottom = -40
		# Ensure internal text padding is nice
		diag.add_theme_constant_override("margin_left", 60)
		diag.add_theme_constant_override("margin_right", 60)
		diag.add_theme_constant_override("margin_top", 40)

	# Align the name plate perfectly on top of the new box bounds
	if name_panel:
		name_panel.anchor_left = 0.0
		name_panel.anchor_right = 0.0
		name_panel.anchor_top = 1.0
		name_panel.anchor_bottom = 1.0
		name_panel.offset_left = 80
		name_panel.offset_right = 450
		name_panel.offset_top = -350 - 70
		name_panel.offset_bottom = -350 + 5

	# 6. Wait for typing to initialize, then skip it
	await get_tree().create_timer(0.5).timeout
	if is_instance_valid(balloon.dialogue_label):
		balloon.dialogue_label.skip_typing()

	# 7. Wait another moment to ensure text is fully rendered on screen
	await get_tree().create_timer(0.5).timeout

	# 8. Capture and Save
	var img = viewport.get_texture().get_image()
	var export_path = "res://alyssa_marketing_post_final.png"
	img.save_png(export_path)

	print("\n===========================================")
	print("SUCCESS! Image automatically exported to:")
	print(ProjectSettings.globalize_path(export_path))
	print("===========================================\n")

	if GameManager:
		GameManager.dialogue_text_scale = 1.0

	get_tree().quit()
