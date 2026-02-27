extends Node2D

enum State { IDLE, IN_USE }
var current_state: State = State.IDLE

# --- Texture Exports ---
@export_group("Drug Textures")
@export var invigirol_texture: Texture2D
@export var cannathink_texture: Texture2D
@export var zanopram_texture: Texture2D

# --- References ---
@onready var anim_player_glow: AnimationPlayer = $AnimationPlayerGlow
@onready var anim_player_sprite: AnimationPlayer = $AnimationPlayerSprite
@onready var pulse_overlay: ColorRect = $PulseOverlay
@onready var vitals_label: Label = $VitalsLabel
@onready var drug_display: Sprite2D = $DrugDisplay

var _screen_tween: Tween
# Variable to store the size you set in the Inspector
var _target_drug_scale: Vector2 

func _ready():
	_update_screen_visuals("normal")
	
	if drug_display:
		# 1. Capture the scale you set in the Inspector BEFORE hiding it
		_target_drug_scale = drug_display.scale
		drug_display.visible = false

func on_drug_used(_item_id: String):
	print("Dispenser: Request to use '%s'." % _item_id)

	if current_state == State.IN_USE:
		print("Dispenser is busy processing!")
		return
	
	current_state = State.IN_USE
	
	if anim_player_glow: anim_player_glow.play("in_use")
	if anim_player_sprite: anim_player_sprite.play("in_use")
	
	_update_screen_visuals(_item_id)
	_update_drug_sprite(_item_id)

	await get_tree().create_timer(1.5).timeout
	
	current_state = State.IDLE 
	print("Dispenser: Processing complete.")

func _update_drug_sprite(drug_type: String):
	if not drug_display: return
	
	var new_texture: Texture2D = null
	
	match drug_type:
		"invigirol": new_texture = invigirol_texture
		"cannathink": new_texture = cannathink_texture
		"zanopram": new_texture = zanopram_texture
	
	if new_texture:
		drug_display.texture = new_texture
		drug_display.visible = true
		
		# --- Pop Animation Fixed ---
		# Start at 10% of your desired size
		drug_display.scale = _target_drug_scale * 0.1 
		
		var pop_tween = create_tween()
		
		# Animate to the captured Inspector scale (_target_drug_scale) instead of (1,1)
		pop_tween.tween_property(drug_display, "scale", _target_drug_scale, 0.4)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			
	else:
		drug_display.visible = false

func _update_screen_visuals(drug_type: String):
	var mat: ShaderMaterial = pulse_overlay.material
	
	if _screen_tween and _screen_tween.is_valid():
		_screen_tween.kill()
	
	_screen_tween = create_tween().set_parallel(true)
	
	var target_color: Color
	var target_speed: float
	var target_height: float
	var target_text: String
	
	match drug_type:
		"normal":
			target_color = Color.CYAN
			target_speed = 0.6
			target_height = 0.18
			target_text = "72\n98\n124/78"
		"invigirol":
			target_color = Color(1.0, 0.2, 0.2, 1.0)
			target_speed = 1.3
			target_height = 0.35
			target_text = "115\n99\n145/92"
		"cannathink":
			target_color = Color.CYAN
			target_speed = 0.45
			target_height = 0.15
			target_text = "60\n97\n110/70"
		"zanopram":
			target_color = Color.CYAN
			target_speed = 0.3
			target_height = 0.10
			target_text = "42\n94\n90/60"

	vitals_label.text = target_text
	_screen_tween.tween_property(mat, "shader_parameter/line_color", target_color, 2.0)
	_screen_tween.tween_property(mat, "shader_parameter/speed", target_speed, 2.0)
	_screen_tween.tween_property(mat, "shader_parameter/height", target_height, 2.0)
