extends CanvasLayer
class_name HUD
## HUD + เมนูในเกมทั้งหมด (สร้างด้วยโค้ด): แถบสติ/แรง/ไฟฉาย, ตัวบอกเสียง, คำบรรยาย, ภารกิจ,
## สมุดบันทึก (Tab), อ่านจดหมาย, หยุดเกม (Esc), จบเกม, เปิดเรื่อง, ฟิลเตอร์ภาพตามค่าสติ

# สัญญาณ: ฉากเปิดเรื่องจบแล้ว (level.gd รอสัญญาณนี้ก่อนให้ผู้เล่นเริ่มเดิน)
signal intro_finished

# ฟอนต์และภาพที่ใช้ใน HUD: ฟอนต์หัวข้อ ฟอนต์ตัวหนา พื้นกระดาษจดหมาย ภาพหน้าผีตอน jumpscare
const FONT_TITLE := preload("res://assets/fonts/Charmonman-Bold.ttf")
const FONT_BOLD := preload("res://assets/fonts/Sarabun-Bold.ttf")
const PAPER := preload("res://assets/textures/paper.png")
const GHOST_FACE := preload("res://assets/textures/ghost_face.png")

# shader ซี่ตู้ตอนซ่อน: mode 1 = มองลอดช่องซี่ตู้เสื้อผ้า (แถบมืดสลับแถบโปร่ง) / mode 2 = มองจากใต้เตียง (มืดด้านบนและด้านล่าง เหลือช่องแคบตรงกลาง)
const HIDE_SHADER := """
shader_type canvas_item;
uniform float mode = 1.0;
void fragment() {
	float a;
	if (mode < 1.5) {
		float s = fract(UV.y * 13.0);
		a = smoothstep(0.30, 0.42, s) * 0.93;
		a = max(a, smoothstep(0.30, 0.46, abs(UV.x - 0.5)));
		a = max(a, step(abs(UV.x - 0.5), 0.012) * 0.95);
	} else {
		a = smoothstep(0.40, 0.30, UV.y) * 0.97;
		a = max(a, smoothstep(0.88, 1.0, UV.y) * 0.6);
	}
	COLOR = vec4(0.01, 0.008, 0.006, a);
}
"""

# shader เอฟเฟกต์หน้าจอทั้งภาพ (post-process) ตัวแปรที่ควบคุม:
# insanity = ภาพบิดเบี้ยว สีแยก ขาวดำ ขอบมืดแคบลง (ตามสติที่ต่ำ) | hurt = แดงวาบเมื่อตกใจ | chase = แดงและขอบมืดตอนถูกไล่ | blood = โทนแดงในบทที่ 3
# ท้ายสุดเติมเม็ดนอยส์ฟิล์มให้ภาพดูหลอน
const POST_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float insanity = 0.0;
uniform float hurt = 0.0;
uniform float chase = 0.0;
uniform float blood = 0.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	float k = insanity;
	vec2 uv = SCREEN_UV;
	uv += vec2(sin(uv.y * 18.0 + TIME * 2.1), cos(uv.x * 14.0 + TIME * 1.6)) * 0.0045 * k;
	float ca = 0.002 + 0.007 * k + 0.004 * chase;
	vec3 col;
	col.r = texture(screen_tex, uv + vec2(ca, 0.0)).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - vec2(ca, 0.0)).b;
	float gray = dot(col, vec3(0.3, 0.59, 0.11));
	col = mix(col, vec3(gray) * vec3(1.0, 0.95, 0.9), 0.15 + k * 0.55);
	vec2 d = SCREEN_UV - 0.5;
	d.x *= 1.3;
	float v = 1.0 - smoothstep(0.32 - 0.14 * k - 0.08 * chase, 0.82 - 0.2 * k, length(d));
	col *= mix(0.08, 1.0, v);
	col = mix(col, vec3(0.35, 0.0, 0.0) * (1.0 - v * 0.5), clamp(hurt + chase * 0.12 * (1.0 - v), 0.0, 1.0));
	col = mix(col, col * vec3(1.35, 0.55, 0.5), blood);
	float n = hash(SCREEN_UV * 431.0 + vec2(TIME * 13.0, TIME * 7.0));
	col += (n - 0.5) * (0.05 + 0.08 * k);
	COLOR = vec4(col, 1.0);
}
"""

# โหนดและป้ายข้อความของ HUD ทั้งหมด (สร้างใน _build): แถบสติ/แรง/ความร้อนไฟฉาย/ลมหายใจ, เป้าเล็ง, ข้อความโต้ตอบ, คำบรรยาย, ภารกิจ, ชื่อบท, ภาพ jumpscare
var root: Control
var post_mat: ShaderMaterial
var hide_mat: ShaderMaterial
var hide_rect: ColorRect
var crosshair: Label
var prompt_label: Label
var subtitle_label: Label
var objective_label: Label
var sanity_bar: ProgressBar
var stamina_bar: ProgressBar
var heat_bar: ProgressBar
var breath_bar: ProgressBar
var noise_label: Label
var status_label: Label
var chapter_box: VBoxContainer
var chapter_title: Label
var chapter_sub: Label
var screen_text: Label
var fade: ColorRect
var scare: TextureRect
var help_panel: PanelContainer

# หน้าต่างย่อย: อ่านจดหมาย, สมุดบันทึก (ไอเทม+จดหมาย), หยุดเกม, จบเกม (ตาย), ฉากเปิดเรื่อง
var note_panel: Control
var note_title: Label
var note_body: Label
var note_image: TextureRect
var journal_panel: Control
var journal_items: VBoxContainer
var journal_notes: VBoxContainer
var journal_desc: Label
var pause_panel: Control
var gameover_panel: Control
var gameover_title: Label
var gameover_sub: Label
var intro_panel: ColorRect
var intro_label: Label

# ตัวแปรภายใน: หน้าต่างที่เปิดอยู่ตอนนี้ ("" = ไม่มี), เปิดจดหมายมาจากสมุดบันทึกไหม, ตัวนับเวลาของคำบรรยาย/แสงวาบ/ไล่ล่า/คำแนะนำ, ข้อมูลฉากเปิดเรื่อง
var _modal := ""
var _note_from_journal := false
var _sub_time := 0.0
var _hurt := 0.0
var _chase := 0.0
var _intro_lines: Array = []
var _intro_idx := 0
var _intro_tween: Tween
var _help_time := 0.0


# เริ่มต้น: สร้าง UI ทั้งหมด แล้วเชื่อมสัญญาณจาก GameState (คำบรรยาย ภารกิจ เปิดจดหมาย ผู้เล่นตาย jumpscare)
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_build()
	GameState.subtitle.connect(show_subtitle)
	GameState.objective_changed.connect(set_objective)
	GameState.note_opened.connect(open_note)
	GameState.player_died.connect(_on_player_died)
	GameState.jumpscare.connect(show_jumpscare)
	set_objective(GameState.objective)


# ================================================================== สร้าง UI
# ตัวช่วยสร้างป้ายข้อความ (มีเงาให้อ่านง่ายบนพื้นหลังทุกแบบ ไม่รับการคลิก)
func _label(parent: Node, text: String = "", size: int = 20, color: Color = Color(0.9, 0.88, 0.82)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


# ตัวช่วยสร้างแถบค่า (ชื่อ + แถบสี) เช่น สติ แรง
func _bar(parent: Node, caption: String, color: Color) -> ProgressBar:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var l := _label(row, caption, 16)
	l.custom_minimum_size.x = 64
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(190, 12)
	b.show_percentage = false
	b.max_value = 100
	b.value = 100
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.55)
	bg.set_corner_radius_all(2)
	var fg := StyleBoxFlat.new()
	fg.bg_color = color
	fg.set_corner_radius_all(2)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(b)
	return b


# สไตล์กรอบหน้าต่างสีเข้ม ขอบน้ำตาล มุมมน
func _panel_style(alpha: float = 0.88) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.04, 0.03, 0.03, alpha)
	s.border_color = Color(0.45, 0.32, 0.2, 0.8)
	s.set_border_width_all(1)
	s.set_corner_radius_all(4)
	s.content_margin_left = 24
	s.content_margin_right = 24
	s.content_margin_top = 18
	s.content_margin_bottom = 18
	return s


# ตัวช่วยสร้างปุ่ม (ปกติ/โดนเมาส์ชี้ต่างสี) cb = ฟังก์ชันที่ทำเมื่อกด
func _button(parent: Node, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 44)
	b.add_theme_font_size_override("font_size", 20)
	var n := StyleBoxFlat.new()
	n.bg_color = Color(0.12, 0.08, 0.06, 0.9)
	n.border_color = Color(0.5, 0.35, 0.22)
	n.set_border_width_all(1)
	n.set_corner_radius_all(3)
	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = Color(0.35, 0.12, 0.08, 0.95)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", h)
	b.add_theme_stylebox_override("focus", h)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


# ทำให้ Control เต็มจอ
func _full(c: Control) -> void:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


# สร้าง UI ทั้งหมดด้วยโค้ด: ฟิลเตอร์ภาพ → ซี่ตู้ตอนซ่อน → แถบค่าต่าง ๆ → ข้อความกลางจอ/คำบรรยาย/ภารกิจ → ภาพ jumpscare → จอดำสำหรับ fade → หน้าต่างย่อยทั้งหมด
func _build() -> void:
	root = Control.new()
	_full(root)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# ฟิลเตอร์ภาพ (vignette / สติ / โดนไล่)
	var post := ColorRect.new()
	_full(post)
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = POST_SHADER
	post_mat.shader = sh
	post.material = post_mat
	root.add_child(post)

	# มุมมองตอนซ่อน (ซี่ตู้ / ขอบเตียง)
	hide_rect = ColorRect.new()
	_full(hide_rect)
	hide_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide_mat = ShaderMaterial.new()
	var hs := Shader.new()
	hs.code = HIDE_SHADER
	hide_mat.shader = hs
	hide_rect.material = hide_mat
	hide_rect.visible = false
	root.add_child(hide_rect)

	# เป้าเล็ง + ข้อความโต้ตอบ
	crosshair = _label(root, "·", 28, Color(1, 1, 1, 0.6))
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.position -= Vector2(4, 20)
	prompt_label = _label(root, "", 20)
	prompt_label.anchor_left = 0.5
	prompt_label.anchor_right = 0.5
	prompt_label.anchor_top = 0.5
	prompt_label.anchor_bottom = 0.5
	prompt_label.offset_left = -400
	prompt_label.offset_right = 400
	prompt_label.offset_top = 34
	prompt_label.offset_bottom = 64
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# คำบรรยาย
	subtitle_label = _label(root, "", 22, Color(0.95, 0.92, 0.85))
	subtitle_label.anchor_left = 0.0
	subtitle_label.anchor_right = 1.0
	subtitle_label.anchor_top = 1.0
	subtitle_label.anchor_bottom = 1.0
	subtitle_label.offset_top = -130
	subtitle_label.offset_bottom = -90
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# ภารกิจ
	var obj_box := VBoxContainer.new()
	obj_box.position = Vector2(28, 22)
	obj_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(obj_box)
	var ot := _label(obj_box, "ภารกิจ", 15, Color(0.75, 0.55, 0.35))
	ot.add_theme_font_override("font", FONT_BOLD)
	objective_label = _label(obj_box, "", 19)
	objective_label.custom_minimum_size.x = 520
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# แถบสถานะ มุมซ้ายล่าง
	var bars := VBoxContainer.new()
	bars.anchor_top = 1.0
	bars.anchor_bottom = 1.0
	bars.offset_left = 28
	bars.offset_top = -150
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bars.add_theme_constant_override("separation", 6)
	root.add_child(bars)
	sanity_bar = _bar(bars, "สติ", Color(0.75, 0.72, 0.9))
	stamina_bar = _bar(bars, "แรง", Color(0.7, 0.75, 0.55))
	heat_bar = _bar(bars, "ไฟฉาย", Color(0.95, 0.6, 0.2))
	breath_bar = _bar(bars, "ลมหายใจ", Color(0.5, 0.75, 0.9))
	breath_bar.get_parent().visible = false

	# ตัวบอกเสียง + สถานะ มุมขวาล่าง
	var right := VBoxContainer.new()
	right.anchor_left = 1.0
	right.anchor_right = 1.0
	right.anchor_top = 1.0
	right.anchor_bottom = 1.0
	right.offset_left = -330
	right.offset_top = -110
	right.offset_right = -28
	right.alignment = BoxContainer.ALIGNMENT_END
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(right)
	status_label = _label(right, "", 17, Color(0.75, 0.85, 1.0))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	noise_label = _label(right, "", 18)
	noise_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	# การ์ดชื่อบท
	chapter_box = VBoxContainer.new()
	_full(chapter_box)
	chapter_box.alignment = BoxContainer.ALIGNMENT_CENTER
	chapter_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(chapter_box)
	chapter_title = _label(chapter_box, "", 64, Color(0.85, 0.15, 0.1))
	chapter_title.add_theme_font_override("font", FONT_TITLE)
	chapter_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chapter_sub = _label(chapter_box, "", 22, Color(0.85, 0.8, 0.75))
	chapter_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chapter_box.modulate.a = 0.0

	# ข้อความหลอนกลางจอ
	screen_text = _label(root, "", 72, Color(0.6, 0.0, 0.0, 0.8))
	screen_text.add_theme_font_override("font", FONT_TITLE)
	_full(screen_text)
	screen_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	screen_text.modulate.a = 0.0

	# วิธีเล่น
	help_panel = PanelContainer.new()
	help_panel.add_theme_stylebox_override("panel", _panel_style(0.7))
	help_panel.anchor_left = 1.0
	help_panel.anchor_right = 1.0
	help_panel.offset_left = -430
	help_panel.offset_right = -24
	help_panel.offset_top = 22
	help_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(help_panel)
	var ht := _label(help_panel, CONTROLS_TEXT, 16)
	ht.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_panel.modulate.a = 0.0

	_build_note()
	_build_journal()
	_build_pause()
	_build_gameover()
	_build_intro()

	scare = TextureRect.new()
	_full(scare)
	scare.texture = GHOST_FACE
	scare.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scare.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	scare.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scare.visible = false
	add_child(scare)

	fade = ColorRect.new()
	_full(fade)
	fade.color = Color.BLACK
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.modulate.a = 0.0
	add_child(fade)


# ข้อความสรุปปุ่มควบคุมที่แสดงตอนเริ่มเกม
const CONTROLS_TEXT := "WASD  เดิน\nShift  วิ่ง (เสียงดัง!)\nCtrl / C  ย่อตัว (เงียบ)\nF  ไฟฉาย (อย่าเปิดนาน)\nE  โต้ตอบ / ซ่อน / ออกจากที่ซ่อน\nSpace (ค้าง)  กลั้นหายใจตอนซ่อน\nTab  สมุดบันทึก     Esc  หยุดเกม"


# สร้างพื้นหลังมืดเต็มจอสำหรับหน้าต่างย่อย (ซ่อนอยู่ก่อน)
func _modal_root(alpha: float = 0.75) -> ColorRect:
	var c := ColorRect.new()
	_full(c)
	c.color = Color(0, 0, 0, alpha)
	c.visible = false
	root.add_child(c)
	return c


# สร้างหน้าต่างอ่านจดหมาย (กระดาษ หัวข้อ เนื้อหา รูปประกอบถ้ามี)
func _build_note() -> void:
	note_panel = _modal_root(0.8)
	var center := CenterContainer.new()
	_full(center)
	note_panel.add_child(center)
	var paper := PanelContainer.new()
	var st := StyleBoxTexture.new()
	st.texture = PAPER
	st.content_margin_left = 48
	st.content_margin_right = 48
	st.content_margin_top = 36
	st.content_margin_bottom = 36
	paper.add_theme_stylebox_override("panel", st)
	paper.custom_minimum_size = Vector2(760, 0)
	center.add_child(paper)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	paper.add_child(v)
	note_title = Label.new()
	note_title.add_theme_font_override("font", FONT_TITLE)
	note_title.add_theme_font_size_override("font_size", 34)
	note_title.add_theme_color_override("font_color", Color(0.25, 0.12, 0.06))
	note_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(note_title)
	note_image = TextureRect.new()
	note_image.custom_minimum_size = Vector2(0, 220)
	note_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	note_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	v.add_child(note_image)
	note_body = Label.new()
	note_body.add_theme_font_size_override("font_size", 20)
	note_body.add_theme_color_override("font_color", Color(0.18, 0.1, 0.05))
	note_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note_body.custom_minimum_size.x = 660
	v.add_child(note_body)
	var hint := Label.new()
	hint.text = "[E / Esc] ปิด"
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(0.35, 0.2, 0.1))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(hint)


# สร้างสมุดบันทึก: ซ้าย = รายการไอเทม ขวา = จดหมาย ล่าง = คำอธิบายเมื่อเอาเมาส์ชี้
func _build_journal() -> void:
	journal_panel = _modal_root(0.82)
	var margin := MarginContainer.new()
	_full(margin)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 70)
	journal_panel.add_child(margin)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(0.92))
	margin.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var t := _label(v, "สมุดบันทึกของข้าวฟ่าง", 34, Color(0.85, 0.7, 0.5))
	t.add_theme_font_override("font", FONT_TITLE)
	var h := HBoxContainer.new()
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h.add_theme_constant_override("separation", 40)
	v.add_child(h)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(left)
	var li := _label(left, "ของที่มี", 20, Color(0.75, 0.55, 0.35))
	li.add_theme_font_override("font", FONT_BOLD)
	journal_items = VBoxContainer.new()
	left.add_child(journal_items)
	journal_desc = _label(left, "", 16, Color(0.7, 0.68, 0.62))
	journal_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	journal_desc.custom_minimum_size.x = 400
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(right)
	var ln := _label(right, "จดหมายและบันทึก (คลิกเพื่ออ่าน)", 20, Color(0.75, 0.55, 0.35))
	ln.add_theme_font_override("font", FONT_BOLD)
	journal_notes = VBoxContainer.new()
	journal_notes.add_theme_constant_override("separation", 6)
	right.add_child(journal_notes)
	_label(v, "[Tab / Esc] ปิด", 15, Color(0.6, 0.55, 0.5))


# สร้างเมนูหยุดเกม (Esc): ปุ่มเล่นต่อ / เริ่มใหม่จากจุดเซฟ / กลับเมนูหลัก, ตั้งความไวเมาส์ ระดับเสียง กลับแกนเมาส์ และสรุปปุ่มควบคุม
func _build_pause() -> void:
	pause_panel = _modal_root(0.78)
	var center := CenterContainer.new()
	_full(center)
	pause_panel.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(0.94))
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var t := _label(v, "หยุดชั่วคราว", 40, Color(0.85, 0.2, 0.12))
	t.add_theme_font_override("font", FONT_TITLE)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_button(v, "เล่นต่อ", close_modal)
	_button(v, "เริ่มใหม่จากจุดเซฟล่าสุด", _retry)
	_button(v, "กลับเมนูหลัก", _to_menu)
	_label(v, "ความไวเมาส์", 16)
	var sens := HSlider.new()
	sens.min_value = 0.0005
	sens.max_value = 0.006
	sens.step = 0.0001
	sens.value = GameState.mouse_sensitivity
	sens.value_changed.connect(func(val):
		GameState.mouse_sensitivity = val
		GameState.save_settings())
	v.add_child(sens)
	_label(v, "ระดับเสียง", 16)
	var vol := HSlider.new()
	vol.min_value = 0.0
	vol.max_value = 1.0
	vol.step = 0.05
	vol.value = GameState.master_volume
	vol.value_changed.connect(func(val):
		GameState.master_volume = val
		GameState.save_settings())
	v.add_child(vol)
	var inv := CheckBox.new()
	inv.text = "กลับแกนเมาส์ขึ้น-ลง"
	inv.button_pressed = GameState.invert_y
	inv.toggled.connect(func(on):
		GameState.invert_y = on
		GameState.save_settings())
	v.add_child(inv)
	var help := _label(v, CONTROLS_TEXT, 14, Color(0.7, 0.68, 0.62))
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


# สร้างหน้าจอเมื่อตาย: ข้อความ + ปุ่มลองใหม่จากจุดเซฟ / กลับเมนู
func _build_gameover() -> void:
	gameover_panel = _modal_root(0.0)
	var bg := ColorRect.new()
	_full(bg)
	bg.color = Color(0.12, 0.0, 0.0, 0.85)
	gameover_panel.add_child(bg)
	var center := CenterContainer.new()
	_full(center)
	gameover_panel.add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	center.add_child(v)
	gameover_title = _label(v, "", 72, Color(0.9, 0.1, 0.05))
	gameover_title.add_theme_font_override("font", FONT_TITLE)
	gameover_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gameover_sub = _label(v, "", 22)
	gameover_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 20
	v.add_child(spacer)
	var b := _button(v, "ลองอีกครั้ง (จุดเซฟล่าสุด)", _retry)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var b2 := _button(v, "กลับเมนูหลัก", _to_menu)
	b2.size_flags_horizontal = Control.SIZE_SHRINK_CENTER


# สร้างหน้าจอดำสำหรับข้อความเปิดเรื่อง
func _build_intro() -> void:
	intro_panel = ColorRect.new()
	_full(intro_panel)
	intro_panel.color = Color.BLACK
	intro_panel.visible = false
	root.add_child(intro_panel)
	intro_label = _label(intro_panel, "", 28, Color(0.88, 0.84, 0.78))
	_full(intro_label)
	intro_label.offset_left = 140
	intro_label.offset_right = -140
	intro_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	intro_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var skip := _label(intro_panel, "[คลิก / Space] ต่อไป", 15, Color(0.5, 0.48, 0.45))
	skip.anchor_left = 1.0
	skip.anchor_right = 1.0
	skip.anchor_top = 1.0
	skip.anchor_bottom = 1.0
	skip.offset_left = -260
	skip.offset_top = -50


# ================================================================== ต่อเฟรม
# อัปเดต HUD ทุกเฟรม: ค่าสติ/แรง/ความร้อน/ลมหายใจ, ข้อความปุ่มโต้ตอบ, ตัวบอกระดับเสียงที่ผู้เล่นกำลังทำ (เงียบ/เบา/ดัง),
# ข้อความสถานะ (ซ่อนอยู่ / ห้องพระปลอดภัย / แสงเทียน / ย่อ), และส่งค่า insanity/chase/hurt/blood ให้ shader หน้าจอ
# insanity = (55 - สติ) / 55 → สติต่ำกว่า 55 ภาพเริ่มบิด; คำบรรยายและคำแนะนำจางหายเมื่อหมดเวลา
func _process(delta: float) -> void:
	var p := GameState.player as Player
	var s := GameState.sanity
	sanity_bar.value = s
	if p != null:
		stamina_bar.value = p.stamina
		heat_bar.value = p.flash_heat
		heat_bar.get_parent().visible = GameState.has_item("flashlight")
		breath_bar.value = p.breath
		breath_bar.get_parent().visible = p.is_hidden()
		hide_rect.visible = p.is_hidden() and not p.dead
		if p.is_hidden():
			hide_mat.set_shader_parameter("mode", 1.0 if p.hidden_in.kind == "wardrobe" else 2.0)
		var pr := p.get_prompt()
		prompt_label.text = ("[E]  " + pr) if pr != "" else ""
		crosshair.visible = _modal == "" and not p.dead
		# เสียง
		var lvl := p.noise_level
		var noise_txt := "เงียบ"
		var noise_col := Color(0.6, 0.8, 0.6)
		if lvl > 0.7:
			noise_txt = "เสียงดัง!"
			noise_col = Color(1.0, 0.35, 0.25)
		elif lvl > 0.2:
			noise_txt = "เสียงเบา"
			noise_col = Color(0.95, 0.85, 0.5)
		noise_label.text = "เสียง: " + noise_txt
		noise_label.add_theme_color_override("font_color", noise_col)
		var st := ""
		if p.is_hidden():
			st = "กำลังซ่อน"
			var g := GameState.ghost
			if g != null and g.is_active() and g.global_position.distance_to(p.global_position) < 6.0:
				st = "เธออยู่ใกล้... ค้าง [Space] กลั้นหายใจ!" if not p.holding_breath else "กลั้นหายใจ..."
		elif p.in_safe:
			st = "ห้องพระ — ปลอดภัย"
		elif p.in_light:
			st = "แสงเทียน — สติฟื้นคืน"
		elif p.crouching:
			st = "ย่อตัว"
		status_label.text = st
		var chase := 1.0 if (GameState.ghost != null and GameState.ghost.is_chasing()) else 0.0
		_chase = lerpf(_chase, chase, delta * 3.0)
		post_mat.set_shader_parameter("chase", _chase)
	var insanity := clampf((55.0 - s) / 55.0, 0.0, 1.0)
	post_mat.set_shader_parameter("blood", 1.0 if GameState.phase >= 3 and GameState.ending == "" else 0.0)
	post_mat.set_shader_parameter("insanity", insanity)
	_hurt = maxf(_hurt - delta * 0.8, 0.0)
	post_mat.set_shader_parameter("hurt", _hurt)

	if _sub_time > 0.0:
		_sub_time -= delta
		if _sub_time <= 0.0:
			var t := create_tween()
			t.tween_property(subtitle_label, "modulate:a", 0.0, 0.5)
	if _help_time > 0.0:
		_help_time -= delta
		if _help_time <= 0.0:
			create_tween().tween_property(help_panel, "modulate:a", 0.0, 1.0)


# ================================================================== API
# แสดงภารกิจมุมจอ (กะพริบสว่างครู่หนึ่งเมื่อเปลี่ยน)
func set_objective(text: String) -> void:
	if objective_label == null:
		return
	objective_label.text = text
	if text != "":
		var t := create_tween()
		objective_label.modulate = Color(1.6, 1.2, 0.8)
		t.tween_property(objective_label, "modulate", Color.WHITE, 1.5)


# แสดงคำบรรยายล่างจอ duration วินาที
func show_subtitle(text: String, duration: float = 3.0) -> void:
	subtitle_label.text = text
	subtitle_label.modulate.a = 1.0
	_sub_time = duration


# แสดงแผงสรุปปุ่มควบคุม แล้วจางหายเอง
func show_help(duration: float = 14.0) -> void:
	help_panel.modulate.a = 1.0
	_help_time = duration


# แสดงชื่อบทกลางจอ (ค่อย ๆ ปรากฏ ค้างไว้ แล้วจาง)
func show_chapter(title: String, sub: String) -> void:
	chapter_title.text = title
	chapter_sub.text = sub
	var t := create_tween()
	t.tween_property(chapter_box, "modulate:a", 1.0, 0.6)
	t.tween_interval(2.6)
	t.tween_property(chapter_box, "modulate:a", 0.0, 1.2)


# ข้อความหลอนวาบกลางจอ (เอียงเล็กน้อย แล้วจางเร็ว) — เรียกจากภาพหลอนตอนสติต่ำ
func flash_screen_text(text: String) -> void:
	screen_text.text = text
	screen_text.modulate.a = 0.9
	screen_text.rotation = randf_range(-0.05, 0.05)
	var t := create_tween()
	t.tween_property(screen_text, "modulate:a", 0.0, 1.4).set_trans(Tween.TRANS_EXPO)


# jumpscare: ภาพหน้าผีขยายเต็มจอ สั่นและกะพริบสี ตามด้วยจางหาย
func show_jumpscare() -> void:
	scare.visible = true
	scare.pivot_offset = get_viewport().get_visible_rect().size * 0.5
	scare.scale = Vector2(0.55, 0.55)
	scare.modulate = Color(1.3, 1.1, 1.1, 1.0)
	_hurt = 0.8
	var t := create_tween()
	t.tween_property(scare, "scale", Vector2(1.18, 1.18), 0.18).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	for i in 6:
		t.tween_property(scare, "position", Vector2(randf_range(-30, 30), randf_range(-30, 30)), 0.04)
		t.tween_property(scare, "modulate", Color(1.0, 0.6, 0.6, 1.0) if i % 2 == 0 else Color(1.4, 1.3, 1.3, 1.0), 0.04)
	t.tween_property(scare, "scale", Vector2(1.3, 1.3), 0.6)
	t.parallel().tween_property(scare, "modulate", Color(0.4, 0.0, 0.0, 0.0), 0.6)
	t.tween_callback(func(): scare.visible = false)


# ทำจอแดงวาบ (ตกใจ/บทเปลี่ยน)
func hurt_flash(amount: float = 0.6) -> void:
	_hurt = amount


# ทำจอดำค่อย ๆ มืด/สว่างใน duration วินาที (คืน Tween ให้รอจบได้)
func fade_to(alpha: float, duration: float) -> Tween:
	var t := create_tween()
	t.tween_property(fade, "modulate:a", alpha, duration)
	return t


# ---------------------------------------------------------------- modal
# เปิดหน้าต่างย่อย: หยุดเกม (ยกเว้นหน้าจอตาย) และแสดงเมาส์
func _open_modal(m: String) -> void:
	_modal = m
	get_tree().paused = m != "gameover"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# ปิดหน้าต่างย่อยทั้งหมด เล่นเกมต่อ และซ่อนเมาส์กลับเข้าโหมดควบคุม
func close_modal() -> void:
	note_panel.visible = false
	journal_panel.visible = false
	pause_panel.visible = false
	_modal = ""
	get_tree().paused = false
	var p := GameState.player as Player
	if p != null and not p.dead:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# เปิดอ่านจดหมาย note_id (ข้อมูลจาก GameState.NOTES) — from_journal = เปิดจากสมุดบันทึก ปิดแล้วกลับไปสมุด
func open_note(note_id: String, from_journal: bool = false) -> void:
	var n: Dictionary = GameState.NOTES.get(note_id, {})
	if n.is_empty():
		return
	journal_panel.visible = false
	_note_from_journal = from_journal
	note_title.text = n.get("title", "")
	note_body.text = n.get("body", "")
	if n.has("image"):
		note_image.texture = load(n.image)
		note_image.visible = true
	else:
		note_image.visible = false
	note_panel.visible = true
	_open_modal("note")


# ปิดหน้าอ่านจดหมาย (กลับสมุดบันทึกหรือกลับเข้าเกม)
func _close_note() -> void:
	note_panel.visible = false
	if _note_from_journal:
		open_journal()
	else:
		close_modal()


# เปิดสมุดบันทึก: สร้างรายการไอเทมที่มี (พร้อมคำอธิบายเมื่อเมาส์ชี้) และจดหมายที่เคยอ่าน
func open_journal() -> void:
	for c in journal_items.get_children():
		c.queue_free()
	for c in journal_notes.get_children():
		c.queue_free()
	journal_desc.text = ""
	if GameState.inventory.is_empty():
		_label(journal_items, "(ว่างเปล่า)", 18, Color(0.6, 0.6, 0.6))
	for id in GameState.inventory.keys():
		var cnt := GameState.item_count(id)
		var txt := GameState.item_name(id) + ((" x%d" % cnt) if cnt > 1 or id == "matches" or id == "photo_piece" else "")
		var b := Button.new()
		b.text = "•  " + txt
		b.flat = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 19)
		var desc: String = GameState.ITEMS.get(id, {}).get("desc", "")
		b.mouse_entered.connect(func(): journal_desc.text = desc)
		b.pressed.connect(func(): journal_desc.text = desc)
		journal_items.add_child(b)
	if GameState.notes.is_empty():
		_label(journal_notes, "(ยังไม่มี)", 18, Color(0.6, 0.6, 0.6))
	for nid in GameState.notes:
		var b := Button.new()
		b.text = "✉  " + GameState.NOTES.get(nid, {}).get("title", nid)
		b.flat = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 19)
		b.pressed.connect(open_note.bind(nid, true))
		journal_notes.add_child(b)
	journal_panel.visible = true
	_open_modal("journal")


# เปิดเมนูหยุดเกม
func open_pause() -> void:
	pause_panel.visible = true
	_open_modal("pause")


# ผู้เล่นตาย: แสดงหน้าจอตาย ข้อความต่างกันตามสาเหตุ (ถูกผีจับ / สติแตก)
func _on_player_died(reason: String) -> void:
	await get_tree().create_timer(0.2).timeout
	note_panel.visible = false
	journal_panel.visible = false
	pause_panel.visible = false
	if reason == "caught":
		gameover_title.text = "เธอจับคุณได้"
		gameover_sub.text = "หนี้... ต้องถูกชำระ"
	else:
		gameover_title.text = "สติแตก"
		gameover_sub.text = "คุณอยู่ในความมืดนานเกินไป"
	gameover_panel.visible = true
	gameover_panel.modulate.a = 0.0
	create_tween().tween_property(gameover_panel, "modulate:a", 1.0, 0.8)
	_open_modal("gameover")


# ปุ่ม "ลองใหม่": เริ่มจากจุดเซฟล่าสุด
func _retry() -> void:
	get_tree().paused = false
	GameState.retry_from_checkpoint()


# ปุ่มกลับเมนูหลัก
func _to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


# ---------------------------------------------------------------- intro
# เริ่มฉากเปิดเรื่อง: แสดงข้อความทีละบรรทัด
func play_intro(lines: Array) -> void:
	_intro_lines = lines
	_intro_idx = -1
	intro_panel.visible = true
	intro_panel.modulate.a = 1.0
	_modal = "intro"
	_next_intro_line()


# แสดงบรรทัดถัดไป (พิมพ์ทีละตัวอักษร ค้างไว้ 2.2 วินาที) พอหมดทุกบรรทัดจอจางหายและส่งสัญญาณ intro_finished
func _next_intro_line() -> void:
	_intro_idx += 1
	if _intro_idx >= _intro_lines.size():
		_modal = ""
		var t := create_tween()
		t.tween_property(intro_panel, "modulate:a", 0.0, 1.5)
		t.tween_callback(func(): intro_panel.visible = false)
		intro_finished.emit()
		return
	intro_label.text = _intro_lines[_intro_idx]
	intro_label.visible_ratio = 0.0
	if _intro_tween:
		_intro_tween.kill()
	_intro_tween = create_tween()
	_intro_tween.tween_property(intro_label, "visible_ratio", 1.0, 0.04 * intro_label.text.length())
	_intro_tween.tween_interval(2.2)
	_intro_tween.tween_callback(_next_intro_line)


# ---------------------------------------------------------------- input
# รับปุ่มของ HUD:
# ฉากเปิดเรื่อง = คลิก/E/Space ข้ามไปบรรทัดถัดไป | Esc = เปิดเมนูหยุดเกม/ปิดหน้าต่าง | Tab = เปิด/ปิดสมุดบันทึก | E = ปิดจดหมาย
# คลิกเมาส์เมื่อเมาส์หลุดจากเกม (เช่น เว็บเบราว์เซอร์ปล่อยเมาส์) = กลับเข้าโหมดควบคุม
func _input(event: InputEvent) -> void:
	if _modal == "intro":
		var adv: bool = (event is InputEventMouseButton and event.pressed) or event.is_action_pressed("hold_breath") or event.is_action_pressed("interact")
		if adv:
			if intro_label.visible_ratio < 1.0:
				if _intro_tween:
					_intro_tween.kill()
				intro_label.visible_ratio = 1.0
				_intro_tween = create_tween()
				_intro_tween.tween_interval(2.0)
				_intro_tween.tween_callback(_next_intro_line)
			else:
				_next_intro_line()
			get_viewport().set_input_as_handled()
		return
	if _modal == "gameover":
		return
	if event.is_action_pressed("pause"):
		match _modal:
			"":
				open_pause()
			"note":
				_close_note()
			_:
				close_modal()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("journal"):
		match _modal:
			"":
				open_journal()
			"journal":
				close_modal()
			"note":
				_close_note()
		get_viewport().set_input_as_handled()
	elif _modal == "note" and event.is_action_pressed("interact"):
		_close_note()
		get_viewport().set_input_as_handled()
	elif _modal == "" and event is InputEventMouseButton and event.pressed:
		var p := GameState.player as Player
		if p != null and not p.dead and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
