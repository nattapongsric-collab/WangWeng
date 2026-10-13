extends Control
## เมนูหลัก — วังเวง (WANG WENG: The House That Remembers)

# ฟอนต์ชื่อเกม
const FONT_TITLE := preload("res://assets/fonts/Charmonman-Bold.ttf")

# shader พื้นหลังเมนู (วาดด้วยสูตรล้วน ไม่ใช้ภาพ): ควันเคลื่อนที่ช้า ๆ (noise ซ้อนหลายชั้น), แสงสีส้มกะพริบจากด้านล่างเหมือนไฟเทียน,
# เงาผู้หญิงยืนไกล ๆ ที่ปรากฏจางเป็นช่วง ๆ, ขอบภาพมืด และเม็ดนอยส์ฟิล์ม
const BG_SHADER := """
shader_type canvas_item;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) { float v = 0.0; float a = 0.5; for (int i = 0; i < 5; i++) { v += a * noise(p); p *= 2.0; a *= 0.5; } return v; }
void fragment() {
	vec2 uv = UV;
	float t = TIME * 0.05;
	float smoke = fbm(uv * vec2(3.0, 2.0) + vec2(t, -t * 0.6)) * fbm(uv * 5.0 - vec2(t * 0.7, t));
	float flick = 0.85 + 0.1 * sin(TIME * 9.0) + 0.05 * sin(TIME * 23.0);
	float glow = exp(-pow(length((uv - vec2(0.5, 1.05)) * vec2(1.4, 1.0)) * 2.2, 2.0)) * flick;
	vec3 col = vec3(0.02, 0.015, 0.02) + vec3(0.25, 0.1, 0.05) * glow + vec3(0.1, 0.1, 0.12) * smoke;
	// เงาผู้หญิงยืนไกล ๆ
	vec2 g = (uv - vec2(0.77, 0.62)) * vec2(9.0, 3.2);
	float body = smoothstep(0.55, 0.45, length(vec2(g.x * (1.0 + g.y * 0.6), max(g.y, 0.0) * 0.35 + min(g.y, 0.0))));
	float show = step(0.97, fract(sin(floor(TIME * 0.5) * 12.9) * 43758.5)) * 0.0 + 0.35 + 0.25 * sin(TIME * 0.4);
	col = mix(col, vec3(0.32, 0.32, 0.3), body * show * 0.22 * step(0.25, fract(TIME * 0.13)));
	vec2 d = uv - 0.5;
	col *= 1.0 - smoothstep(0.3, 0.8, length(d * vec2(1.2, 1.0)));
	col += (hash(uv * 600.0 + TIME) - 0.5) * 0.04;
	COLOR = vec4(col, 1.0);
}
"""

# ตัวเล่นเสียงบรรยากาศบ้าน, แผงวิธีเล่น, แผงตั้งค่า, กลุ่มปุ่มเมนู
var _amb: AudioStreamPlayer
var _help: PanelContainer
var _settings: PanelContainer
var _buttons: VBoxContainer


# สร้างเมนูหลักด้วยโค้ด: ล้างตัวอ้างอิงเกมเดิม → พื้นหลัง shader → ชื่อเกม → ปุ่ม (เล่นต่อ ถ้ามีจุดเซฟ / เริ่มใหม่ / วิธีเล่น / ตั้งค่า / ออก — ปุ่มออกซ่อนในเวอร์ชันเว็บ)
# → แผงวิธีเล่น → แผงตั้งค่า (ความไวเมาส์ ระดับเสียง กลับแกน เต็มจอ ซึ่งบันทึกทันทีที่เปลี่ยน) → เสียงบรรยากาศ
func _ready() -> void:
	get_tree().paused = false
	GameState.level = null
	GameState.player = null
	GameState.ghost = null
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var m := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = BG_SHADER
	m.shader = sh
	bg.material = m
	add_child(bg)

	var v := VBoxContainer.new()
	v.position = Vector2(110, 90)
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	var title := Label.new()
	title.text = "วังเวง"
	title.add_theme_font_override("font", FONT_TITLE)
	title.add_theme_font_size_override("font_size", 120)
	title.add_theme_color_override("font_color", Color(0.85, 0.82, 0.76))
	title.add_theme_color_override("font_shadow_color", Color(0.6, 0.0, 0.0, 0.8))
	title.add_theme_constant_override("shadow_offset_x", 4)
	title.add_theme_constant_override("shadow_offset_y", 4)
	v.add_child(title)
	var sub := Label.new()
	sub.text = "WANG WENG : The House That Remembers"
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_color", Color(0.65, 0.55, 0.45))
	v.add_child(sub)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 40
	v.add_child(spacer)

	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 10)
	v.add_child(_buttons)
	if GameState.has_checkpoint() and GameState.ending == "":
		_btn("เล่นต่อ (จุดเซฟล่าสุด)", _continue)
	_btn("เริ่มเกมใหม่", _new_game)
	_btn("วิธีเล่น", func(): _toggle(_help))
	_btn("ตั้งค่า", func(): _toggle(_settings))
	if OS.get_name() != "Web":
		_btn("ออกจากเกม", func(): get_tree().quit())

	var credit := Label.new()
	credit.text = "CP410844 Computer Game Development — ภาคต้น ปีการศึกษา 2569  |  ใส่หูฟังเพื่อประสบการณ์ที่ดีที่สุด"
	credit.add_theme_font_size_override("font_size", 14)
	credit.add_theme_color_override("font_color", Color(0.45, 0.42, 0.4))
	credit.anchor_top = 1.0
	credit.anchor_bottom = 1.0
	credit.offset_left = 110
	credit.offset_top = -44
	add_child(credit)

	_help = _side_panel()
	var ht := Label.new()
	ht.text = "เป้าหมาย\nไขปริศนาในบ้านของยาย รวบรวมเศษรูปถ่าย และค้นหาความจริงของ \"คำสาปตระกูล\"\nไม่มีการต่อสู้ — หลบ ซ่อน และหนี\n\nการควบคุม\nWASD เดิน   Shift วิ่ง (เสียงดัง)   Ctrl/C ย่อ (เงียบ)\nF ไฟฉาย   E โต้ตอบ/ซ่อน   Space(ค้าง) กลั้นหายใจ\nTab สมุดบันทึก   Esc หยุดเกม\n\nกฎการเอาตัวรอด\n• เสียงฝีเท้าตอนวิ่ง และการชนของ ดึงดูดแม่หญิงชุดขาว\n• เปิดไฟฉายนานเกินไป แสงจะดึงดูดเธอ\n• อยู่ในความมืดนาน สติจะลดลงจนเห็นภาพหลอน — จุดเทียนเพื่อฟื้นสติ\n• ซ่อนในตู้หรือใต้เตียง เมื่อเธอเข้าใกล้ให้กลั้นหายใจ\n• ห้องพระที่จุดเทียนไว้ เธอเข้ามาไม่ได้"
	ht.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ht.custom_minimum_size.x = 520
	ht.add_theme_font_size_override("font_size", 17)
	_help.add_child(ht)

	_settings = _side_panel()
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 8)
	_settings.add_child(sv)
	var l1 := Label.new()
	l1.text = "ความไวเมาส์"
	sv.add_child(l1)
	var sens := HSlider.new()
	sens.min_value = 0.0005
	sens.max_value = 0.006
	sens.step = 0.0001
	sens.value = GameState.mouse_sensitivity
	sens.custom_minimum_size.x = 400
	sens.value_changed.connect(func(val):
		GameState.mouse_sensitivity = val
		GameState.save_settings())
	sv.add_child(sens)
	var l2 := Label.new()
	l2.text = "ระดับเสียง"
	sv.add_child(l2)
	var vol := HSlider.new()
	vol.min_value = 0.0
	vol.max_value = 1.0
	vol.step = 0.05
	vol.value = GameState.master_volume
	vol.value_changed.connect(func(val):
		GameState.master_volume = val
		GameState.save_settings())
	sv.add_child(vol)
	var inv := CheckBox.new()
	inv.text = "กลับแกนเมาส์ขึ้น-ลง"
	inv.button_pressed = GameState.invert_y
	inv.toggled.connect(func(on):
		GameState.invert_y = on
		GameState.save_settings())
	sv.add_child(inv)
	var fs := CheckBox.new()
	fs.text = "เต็มจอ"
	fs.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fs.toggled.connect(func(on):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED))
	sv.add_child(fs)

	_amb = AudioStreamPlayer.new()
	_amb.stream = load("res://assets/audio/amb_house.wav")
	_amb.volume_db = -6.0
	_amb.bus = "Ambience"
	add_child(_amb)
	_amb.play()


# สร้างปุ่มเมนู: โปร่งใส ไฮไลต์แดงเมื่อเมาส์ชี้ พร้อมเสียงคลิกเบา ๆ cb = สิ่งที่ทำเมื่อกด
func _btn(text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(340, 48)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 24)
	var n := StyleBoxFlat.new()
	n.bg_color = Color(0, 0, 0, 0.0)
	n.content_margin_left = 16
	var h := StyleBoxFlat.new()
	h.bg_color = Color(0.45, 0.06, 0.04, 0.55)
	h.content_margin_left = 16
	h.border_color = Color(0.8, 0.3, 0.2)
	h.border_width_left = 3
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", h)
	b.add_theme_stylebox_override("focus", h)
	b.add_theme_color_override("font_color", Color(0.82, 0.78, 0.72))
	b.add_theme_color_override("font_hover_color", Color(1, 0.95, 0.9))
	b.mouse_entered.connect(func(): Sfx.play("click", -14.0, 0.7))
	b.pressed.connect(cb)
	_buttons.add_child(b)


# สร้างแผงข้างด้านขวา (ซ่อนไว้ก่อน) ใช้ใส่วิธีเล่นและการตั้งค่า
func _side_panel() -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.03, 0.02, 0.02, 0.88)
	s.border_color = Color(0.45, 0.3, 0.2)
	s.set_border_width_all(1)
	s.content_margin_left = 26
	s.content_margin_right = 26
	s.content_margin_top = 20
	s.content_margin_bottom = 20
	p.add_theme_stylebox_override("panel", s)
	p.anchor_left = 1.0
	p.anchor_right = 1.0
	p.offset_left = -640
	p.offset_right = -60
	p.offset_top = 110
	p.visible = false
	add_child(p)
	return p


# สลับแสดง/ซ่อนแผงข้าง (เปิดได้ทีละแผง)
func _toggle(panel: Control) -> void:
	var was := panel.visible
	_help.visible = false
	_settings.visible = false
	panel.visible = not was


# ปุ่ม "เริ่มเกมใหม่": ล้างสถานะ แล้วเข้าเกม
func _new_game() -> void:
	GameState.new_game()
	_start()


# ปุ่ม "เล่นต่อ": กู้จุดเซฟล่าสุด แล้วเข้าเกม
func _continue() -> void:
	GameState.restore_checkpoint()
	_start()


# เข้าเกม: เสียงประตูปิด จอค่อย ๆ มืดแล้วโหลดฉากหลัก (main.tscn)
func _start() -> void:
	Sfx.play("door_slam", -6.0)
	var fade := ColorRect.new()
	fade.color = Color.BLACK
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.modulate.a = 0.0
	add_child(fade)
	var t := create_tween()
	t.tween_property(fade, "modulate:a", 1.0, 0.8)
	t.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))
