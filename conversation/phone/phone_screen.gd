extends Control
## step 2.185: the dumbphone's LCD, drawn at native resolution inside phone_cg.tscn's
## ScreenViewport (194 x 262 px). Every element is drawn in _draw() from the exports below,
## so changing any of them (in the Inspector, from phone_cg.gd, or later from dialogue)
## redraws the screen. phone_cg.tscn scales it up 5x and runs it through lcd_screen.gdshader.
## Add more screens by extending ScreenMode and _draw().

signal selection_changed(index: int)

const PhoneFont := preload("res://conversation/phone/phone_font.gd")
const TEXT_PX := 2 # screen pixels per font pixel
const STATUS_H := 22
const HEADER_H := 24
const ROW_H := 26
const SCROLLBAR_W := 9

enum ScreenMode { CONTACTS }

@export var screen_mode: ScreenMode = ScreenMode.CONTACTS:
	set(v):
		screen_mode = v
		queue_redraw()
@export var contacts: PackedStringArray = PackedStringArray(["Mom", "Layla", "Prof. Greene"]):
	set(v):
		contacts = v
		selected_index = clampi(selected_index, 0, maxi(contacts.size() - 1, 0))
		queue_redraw()
@export var selected_index := 0:
	set(v):
		var clamped := clampi(v, 0, maxi(contacts.size() - 1, 0))
		var changed := clamped != selected_index
		selected_index = clamped
		queue_redraw()
		if changed:
			selection_changed.emit(selected_index)
## "%d" is replaced by the number of contacts.
@export var header_text := "Contacts (%d)":
	set(v):
		header_text = v
		queue_redraw()
@export var clock_text := "11:47 PM":
	set(v):
		clock_text = v
		queue_redraw()
@export_range(0.0, 1.0, 0.01) var battery_level := 0.15:
	set(v):
		battery_level = v
		queue_redraw()
@export_range(0, 4) var signal_bars := 4:
	set(v):
		signal_bars = v
		queue_redraw()
## How many list rows fit; empty rows are drawn as ruled lines.
@export_range(1, 12) var visible_rows := 8:
	set(v):
		visible_rows = v
		queue_redraw()

@export_group("Palette")
@export var col_bg := Color("c9ddff")
@export var col_ink := Color("0c1a4d")
@export var col_band := Color("aac6f4")
@export var col_rule := Color("8daee6")
@export var col_select := Color("1c3cb6")
@export var col_select_ink := Color("eef4ff")
@export var col_battery_low := Color("c8323c")

const PERSON_ICON := [
	"..###..",
	".#####.",
	".#####.",
	"..###..",
	".......",
	".#####.",
	"#######",
]


func step_selection(delta: int) -> void:
	selected_index = selected_index + delta


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), col_bg)
	match screen_mode:
		ScreenMode.CONTACTS:
			_draw_status_bar()
			_draw_contacts()


func _draw_status_bar() -> void:
	var w := size.x
	# signal: four rising bars, the missing ones drawn faint
	for i in 4:
		var h := 4 + i * 3
		var col := col_ink if i < signal_bars else col_rule
		draw_rect(Rect2(6 + i * 5, STATUS_H - 4 - h, 4, h), col)
	# battery: outline, tip, fill
	var bx := w - 27.0
	var low := battery_level < 0.2
	draw_rect(Rect2(bx, 6, 18, 11), col_ink, false, 1.0)
	draw_rect(Rect2(bx + 18, 9, 2, 5), col_ink)
	var fill := roundi(14.0 * battery_level)
	if fill > 0:
		draw_rect(Rect2(bx + 2, 8, fill, 7), col_battery_low if low else col_ink)
	# clock, right-aligned before the battery
	var tw := PhoneFont.text_width(clock_text, TEXT_PX)
	PhoneFont.draw_text(self, Vector2(bx - 6 - tw, 4), clock_text, col_ink, TEXT_PX)


func _draw_contacts() -> void:
	var w := size.x
	var top := float(STATUS_H)
	# header band
	draw_rect(Rect2(0, top, w, HEADER_H), col_band)
	var title := header_text.replace("%d", str(contacts.size()))
	PhoneFont.draw_text(self, Vector2(6, top + 4), title, col_ink, TEXT_PX)
	draw_rect(Rect2(0, top + HEADER_H - 1, w, 1), col_ink)

	var list_top := top + HEADER_H + 2
	var list_w := w - SCROLLBAR_W - 6
	for i in visible_rows:
		var y := list_top + i * ROW_H
		if i < contacts.size():
			var selected := i == selected_index
			var ink := col_select_ink if selected else col_ink
			if selected:
				draw_rect(Rect2(2, y + 1, list_w - 2, ROW_H - 3), col_select)
			_draw_icon(Vector2(7, y + 5), ink)
			PhoneFont.draw_text(self, Vector2(27, y + 5), contacts[i], ink, TEXT_PX)
		draw_rect(Rect2(4, y + ROW_H - 1, list_w - 6, 1), col_rule)
	_draw_scrollbar(Vector2(w - SCROLLBAR_W - 3, list_top), visible_rows * ROW_H - 2)


func _draw_icon(pos: Vector2, col: Color) -> void:
	for r in PERSON_ICON.size():
		var row: String = PERSON_ICON[r]
		for c in row.length():
			if row[c] == "#":
				draw_rect(Rect2(pos.x + c * 2, pos.y + r * 2, 2, 2), col)


func _draw_scrollbar(pos: Vector2, h: float) -> void:
	var w := float(SCROLLBAR_W)
	draw_rect(Rect2(pos, Vector2(w, h)), col_ink, false, 1.0)
	# arrows
	var cx := pos.x + w * 0.5
	draw_colored_polygon(PackedVector2Array([Vector2(cx, pos.y + 2), Vector2(pos.x + 1.5, pos.y + 7), Vector2(pos.x + w - 1.5, pos.y + 7)]), col_ink)
	var by := pos.y + h
	draw_colored_polygon(PackedVector2Array([Vector2(cx, by - 2), Vector2(pos.x + 1.5, by - 7), Vector2(pos.x + w - 1.5, by - 7)]), col_ink)
	# thumb: the whole list fits, so it fills the track (nothing to scroll to)
	var track_top := pos.y + 9
	var track_h := h - 18
	var frac := 1.0 if contacts.size() <= visible_rows else float(visible_rows) / contacts.size()
	draw_rect(Rect2(pos.x + 2, track_top, w - 4, track_h * frac), col_band)
	draw_rect(Rect2(pos.x + 2, track_top, w - 4, track_h * frac), col_ink, false, 1.0)
