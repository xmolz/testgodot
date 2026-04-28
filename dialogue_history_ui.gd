extends CanvasLayer

@onready var scroll_container: ScrollContainer = $ColorRect/MarginContainer/VBoxContainer/ScrollContainer
@onready var history_list: VBoxContainer = $ColorRect/MarginContainer/VBoxContainer/ScrollContainer/HistoryList
@onready var close_button: Button = $ColorRect/MarginContainer/VBoxContainer/Header/CloseButton
@onready var title_label: Label = $ColorRect/MarginContainer/VBoxContainer/Header/Title

const PLAYER_NAMES = ["Player", "Fiona", "???"]
var custom_font = preload("res://Fonts/VarelaRound-Regular.ttf")

var character_colors: Dictionary = {
	"AIda": Color("#20B2AA"),
	"Sergey": Color("#DAA520"),
	"McBucket": Color("#6B8E23"),
	"Nathan": Color("#FF69B4"),
	"Dread": Color("#4B0082"),
	"The... Toilet?": Color("#DC143C"),
	"Player": Color("#FFD65C"),
	"Fiona": Color("#FFD65C"),
	"???": Color("#FFD65C")
}

var character_portraits: Dictionary = {
	"AIda": preload("res://Sprites/dialogue sprites/aida_dialogue_sprite.PNG"),
	"Sergey": preload("res://Sprites/dialogue sprites/sergey_dialogue_sprite.png"),
	"McBucket": preload("res://mcbucket.png"),
	"Nathan": preload("res://icon.svg"),
	"The... Toilet?": preload("res://Sprites/dialogue sprites/toilet_dialogue_sprite.png"),
	"Player": preload("res://Sprites/dialogue sprites/protag_dialogue_sprite.png"),
	"Fiona": preload("res://Sprites/dialogue sprites/protag_dialogue_sprite.png"),
	"???": preload("res://Sprites/dialogue sprites/protag_dialogue_sprite.png")
}

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 115 # Above the dialogue balloon and Pause Menu (110)
	close_button.pressed.connect(_close_log)
	_populate_log()

	# --- UI POLISH: Title Label ---
	title_label.add_theme_font_override("font", custom_font)
	title_label.add_theme_font_size_override("font_size", 36)
	title_label.add_theme_color_override("font_color", Color(0.2, 0.85, 1.0, 1.0)) # Cyan accent

	# --- UI POLISH: Close Button ---
	close_button.text = "Close"
	close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_button.add_theme_font_override("font", custom_font)
	close_button.add_theme_font_size_override("font_size", 24)

	# Remove the "flat" property if it was set in the inspector so our styleboxes work
	close_button.flat = false

	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.15, 0.15, 0.15, 0.85)
	normal_style.corner_radius_top_left = 6
	normal_style.corner_radius_top_right = 6
	normal_style.corner_radius_bottom_left = 6
	normal_style.corner_radius_bottom_right = 6
	normal_style.content_margin_left = 25
	normal_style.content_margin_right = 25
	normal_style.content_margin_top = 10
	normal_style.content_margin_bottom = 10
	normal_style.border_width_left = 2
	normal_style.border_width_top = 2
	normal_style.border_width_right = 2
	normal_style.border_width_bottom = 2
	normal_style.border_color = Color(1.0, 1.0, 1.0, 0.0) # Invisible border to prevent jitter

	var hover_style = normal_style.duplicate()
	hover_style.bg_color = Color(0.1, 0.25, 0.3, 0.9) # Subtle cyan tint
	hover_style.border_color = Color(0.2, 0.85, 1.0, 0.8) # Crisp cyan border

	close_button.add_theme_stylebox_override("normal", normal_style)
	close_button.add_theme_stylebox_override("hover", hover_style)
	close_button.add_theme_stylebox_override("focus", hover_style)
	close_button.add_theme_stylebox_override("pressed", hover_style)

	close_button.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1.0))
	close_button.add_theme_color_override("font_hover_color", Color.WHITE)
	close_button.add_theme_color_override("font_pressed_color", Color.WHITE)
	# ------------------------------

	$ColorRect.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
			_close_log()
	)

	# Wait one frame for the VBoxContainer to calculate its size, then scroll to bottom
	await get_tree().process_frame
	scroll_container.scroll_vertical = int(scroll_container.get_v_scroll_bar().max_value)

func _input(event):
	# Close on Right Click
	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_RIGHT:
			get_viewport().set_input_as_handled()
			_close_log()
	# Close on Escape or H
	elif event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_H:
			get_viewport().set_input_as_handled()
			_close_log()

func _populate_log():
	if not GameManager: return

	var previous_character = ""
	var custom_font = preload("res://Fonts/VarelaRound-Regular.ttf")

	for entry in GameManager.dialogue_history:
		var align_right = false
		var char_name = entry.get("character", "")

		# Determine if this is a continuation of the same speaker
		var is_continuation = (char_name == previous_character and char_name != "")
		previous_character = char_name

		# --- ACTION LOGGING LOGIC (FIXED) ---
		if entry["type"] == "action":
			var action_label = RichTextLabel.new()
			action_label.bbcode_enabled = true
			action_label.fit_content = true
			action_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			action_label.add_theme_font_override("normal_font", custom_font)
			action_label.add_theme_font_size_override("normal_font_size", 20)

			var v = entry["verb"]
			var o = entry["object"]
			var i = entry["item"]

			var text = ""
			if i != "":
				text = "[center][color=#888888]— Used [color=#33d9ff]'%s'[/color] on [color=#33d9ff]'%s'[/color] —[/color][/center]" % [i, o]
			else:
				text = "[center][color=#888888]— Performed [color=#33d9ff]'%s'[/color] on [color=#33d9ff]'%s'[/color] —[/color][/center]" % [v, o]

			action_label.text = text

			var action_margin = MarginContainer.new()
			action_margin.add_theme_constant_override("margin_top", 10)
			action_margin.add_theme_constant_override("margin_bottom", 15)
			action_margin.add_child(action_label)

			history_list.add_child(action_margin)

			# Reset previous character so the next dialogue line forces a nameplate/portrait
			previous_character = ""
			continue
		# -----------------------------

		if char_name in PLAYER_NAMES:
			align_right = true

		var row_box = HBoxContainer.new()
		row_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_box.add_theme_constant_override("separation", 20)

		var portrait = TextureRect.new()
		portrait.custom_minimum_size = Vector2(80, 80)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

		if not is_continuation and character_portraits.has(char_name):
			portrait.texture = character_portraits[char_name]

		var text_vbox = VBoxContainer.new()
		# Allow the VBox to take up the entire screen width so text never squishes
		text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		if not is_continuation and char_name != "":
			var name_label = Label.new()
			name_label.text = char_name
			name_label.add_theme_font_override("font", custom_font)
			name_label.add_theme_font_size_override("font_size", 24)

			if character_colors.has(char_name):
				name_label.add_theme_color_override("font_color", character_colors[char_name])
			else:
				name_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))

			if align_right:
				name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			text_vbox.add_child(name_label)

		if entry["type"] == "line":
			var text = entry["text"]
			var text_label = RichTextLabel.new()
			text_label.bbcode_enabled = true
			text_label.fit_content = true
			text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			text_label.add_theme_font_override("normal_font", custom_font)
			text_label.add_theme_font_size_override("normal_font_size", 28)
			text_label.add_theme_color_override("default_color", Color(0.9, 0.9, 0.9))

			if align_right:
				text_label.text = "[right]" + text + "[/right]"
			else:
				text_label.text = text

			text_vbox.add_child(text_label)

		elif entry["type"] == "choice":
			var options = entry["options"]
			var selected_index = entry["selected_index"]

			for i in range(options.size()):
				var clean_text = options[i].replacen("[proceed]", "").replacen("[back]", "").replacen("[leave]", "").strip_edges()
				var choice_label = RichTextLabel.new()
				choice_label.bbcode_enabled = true
				choice_label.fit_content = true
				choice_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				choice_label.add_theme_font_override("normal_font", custom_font)
				choice_label.add_theme_font_size_override("normal_font_size", 26)

				if i == selected_index:
					choice_label.text = "[right][color=#33d9ff]> " + clean_text + "[/color][/right]"
				else:
					choice_label.text = "[right][color=#888888][s]" + clean_text + "[/s][/color][/right]"

				text_vbox.add_child(choice_label)

		# Assemble the row
		if align_right:
			row_box.add_child(text_vbox)
			row_box.add_child(portrait)
		else:
			row_box.add_child(portrait)
			row_box.add_child(text_vbox)

		var margin = MarginContainer.new()
		margin.add_theme_constant_override("margin_bottom", 5 if is_continuation else 25)
		margin.add_child(row_box)
		history_list.add_child(margin)

func _close_log():
	if SoundManager: SoundManager.play_sfx("ui_click")
	queue_free()
