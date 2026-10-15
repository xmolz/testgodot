# text_fx.gd — helpers for the dialogue text-effect tags (step 2.215).
#   [small=0.85]...[/small]  text at 85% of the label's base size. NOT compounding: nested
#                            tags are each relative to the base. bare [small] = 0.85.
#   [mutter]...[/mutter]     rushed / under-the-breath twitch + dim (mutter_effect.gd).
# dialogue manager strips every non-marker tag when it works out where [speed]/[wait] land,
# so every tag here must render as nothing: [small] is expanded to [font_size] before the
# text is set, and [mutter] is an installed effect on the dialogue label (stripped in the log).
extends RefCounted

const DEFAULT_SMALL := 0.85
const MIN_SIZE := 8


static func expand_small(text: String, base_size: int) -> String:
	if not ("[small" in text):
		return text
	if base_size <= 0:
		base_size = 28
	var re := RegEx.new()
	re.compile("\\[small(?:=([0-9]*\\.?[0-9]+))?\\]")
	var out := ""
	var last := 0
	for m in re.search_all(text):
		var ratio := DEFAULT_SMALL
		if m.get_string(1) != "":
			ratio = m.get_string(1).to_float()
		var size: int = maxi(MIN_SIZE, roundi(base_size * ratio))
		out += text.substr(last, m.get_start() - last) + ("[font_size=%d]" % size)
		last = m.get_end()
	out += text.substr(last)
	return out.replace("[/small]", "[/font_size]")


# for places that should show the words but not the motion (the log).
static func strip_motion(text: String) -> String:
	var re := RegEx.new()
	re.compile("\\[/?(?:mutter|wave|shake)(?:[ =][^\\]]*)?\\]")
	return re.sub(text, "", true)
