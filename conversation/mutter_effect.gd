@tool
# mutter_effect.gd — [mutter] BBCode effect for rushed, under-the-breath lines (step 2.215).
# installed on the conversation DialogueLabel only (custom_dialogue_label.gd); the log strips it.
# params: jitter (px, default 1.2), rate (twitches per second, default 16),
#         dim (alpha multiplier, default 0.8). e.g. [mutter jitter=2 dim=0.7]
extends RichTextEffect

var bbcode := "mutter"


func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	var jitter: float = float(char_fx.env.get("jitter", 1.2))
	var rate: float = float(char_fx.env.get("rate", 16.0))
	var dim: float = float(char_fx.env.get("dim", 0.8))
	# stepped time, so each glyph twitches between spots instead of floating
	var tick: int = int(floor(char_fx.elapsed_time * rate))
	var n: int = char_fx.relative_index * 131 + tick * 7919
	char_fx.offset = Vector2((_hash01(n) - 0.5) * 2.0 * jitter, (_hash01(n + 57) - 0.5) * 2.0 * jitter)
	char_fx.color.a *= dim
	return true


static func _hash01(n: int) -> float:
	return fposmod(sin(float(n) * 12.9898) * 43758.5453, 1.0)
