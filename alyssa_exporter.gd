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
	tex_rect.texture = load("res://Backgrounds/layla_marketing_image.png")
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(tex_rect)

	# 3. Increase font size dynamically for the 1800x2400 resolution
	if GameManager:
		GameManager.dialogue_text_scale = 2.2 # Increased slightly

	# 4. Instantiate the balloon inside the viewport
	var dialogue_res = load("res://dialogue/alyssa_marketing.dialogue")
	var balloon = preload("res://conversationballoon.tscn").instantiate()
	viewport.add_child(balloon)
	balloon.start(dialogue_res, "start")

	# Wait for typing to initialize so we can safely override margins
	# (conversationballoon.gd modifies dialogue margins dynamically when it starts)
	await get_tree().create_timer(0.5).timeout

	# 5. Customize the Balloon layout for this exact aspect ratio!
	var panel = balloon.get_node("%Balloon/Panel")
	var diag = balloon.get_node("%Balloon/Dialogue")
	var name_panel = balloon.get_node("%Balloon/NamePanel")
	var quick_menu = balloon.get_node_or_null("%QuickMenu")
	var portrait_container = balloon.get_node_or_null("%PortraitContainer")

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
		panel.offset_top = -450 # Increased height
		panel.offset_bottom = -40

	if diag:
		diag.anchor_left = 0.0
		diag.anchor_right = 1.0
		diag.anchor_top = 1.0
		diag.anchor_bottom = 1.0
		diag.offset_left = 80
		diag.offset_right = -80
		diag.offset_top = -450
		diag.offset_bottom = -40
		# Ensure internal text padding is nice and clears the portrait
		diag.add_theme_constant_override("margin_left", 380)
		diag.add_theme_constant_override("margin_right", 60)
		diag.add_theme_constant_override("margin_top", 40)

	# Align the name plate perfectly on top of the new box bounds
	if name_panel:
		name_panel.anchor_left = 0.0
		name_panel.anchor_right = 0.0
		name_panel.anchor_top = 1.0
		name_panel.anchor_bottom = 1.0
		name_panel.offset_left = 80
		name_panel.offset_right = 550 # Widened to fit scaled text
		name_panel.offset_top = -450 - 90
		name_panel.offset_bottom = -450 + 5

	# Fix portrait container scaling and layout
	if portrait_container:
		portrait_container.anchor_left = 0.0
		portrait_container.anchor_right = 0.0
		portrait_container.anchor_top = 1.0
		portrait_container.anchor_bottom = 1.0
		# Make it a 300x300 box, centered in the 410px high panel
		portrait_container.offset_left = 120
		portrait_container.offset_top = -395
		portrait_container.offset_right = 420
		portrait_container.offset_bottom = -95

	# 6. Skip typing
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
