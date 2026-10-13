extends Control
## ฉากจบ — escape (หนีออกประตูหน้า) / redeem (เผาสัญญา = จบแท้)

# ฟอนต์หัวข้อฉากจบ
const FONT_TITLE := preload("res://assets/fonts/Charmonman-Bold.ttf")

# ข้อความของฉากจบทั้ง 2 แบบ: ชื่อ สีหัวข้อ เนื้อเรื่อง และข้อความใบ้ท้ายจอ (escape = หนี / redeem = ใช้หนี้ จบแท้)
const ENDINGS := {
	"escape": {
		"title": "ฉากจบที่ ๑ : หนี",
		"color": Color(0.75, 0.15, 0.1),
		"text": "ข้าวฟ่างผลักประตูออกไป วิ่งฝ่าความมืดโดยไม่หันหลังกลับ\n\nรุ่งเช้า เธอนั่งอยู่บนรถทัวร์กลับกรุงเทพฯ มือยังสั่นไม่หยุด\nเธอไม่เคยกลับไปที่บ้านหลังนั้นอีกเลย\n\nแต่ทุกคืน... เมื่อไฟในห้องดับลง\nเธอยังได้ยินเสียงกระซิบเบา ๆ ข้างหู\n\n\"หนี้... ยังไม่หมดนะ\"",
		"hint": "ยังมีอีกฉากจบหนึ่ง... ลองจุดเทียนบนโต๊ะหมู่แล้วเผาสัญญาดูสิ",
	},
	"redeem": {
		"title": "ฉากจบที่ ๒ : ใช้หนี้",
		"color": Color(0.9, 0.75, 0.4),
		"text": "เปลวไฟจากเทียนบนโต๊ะหมู่ค่อย ๆ กลืนกินผ้ายันต์\nข้าวฟ่างพนมมือ น้ำตาไหลโดยไม่รู้ตัว\n\"ขอขมาแม่หญิง... ขอให้พี่ไปสู่ที่ชอบเถิด\"\n\nลมเย็นพัดผ่านห้องพระ เสียงกระซิบเงียบหายไป\nที่หน้าประตู ผู้หญิงชุดขาวยืนนิ่ง\nใบหน้าที่เคยถูกเส้นผมปกปิด บัดนี้สงบและอ่อนโยน\nเธอยิ้มให้ แล้วเลือนหายไปกับแสงแรกของเช้า\n\nหนี้ได้รับการชดใช้แล้ว\nบ้านหลังนี้... ไม่ต้องจำอะไรอีกต่อไป",
		"hint": "ขอบคุณที่เล่น",
	},
}

# เครดิตผู้จัดทำ
const CREDITS := "วังเวง (WANG WENG: The House That Remembers) — CP410844 Computer Game Development สาขาวิชาปัญญาประดิษฐ์\n673380440-6 นายณัฐพงษ์ ศรีเชียงสา   •   673380437-5 นายจิตติพัฒน์ มูลศรี\n673380630-1 นายธนโชติ กมลเลิศ   •   673380636-9 นางสาวภูริชญา โมรา\nสร้างด้วย Godot Engine  •  ฟอนต์ Sarabun / Charmonman (SIL OFL)"


# สร้างหน้าจอฉากจบด้วยโค้ด: พื้นหลัง → หัวข้อ → เนื้อเรื่อง (ค่อย ๆ พิมพ์ทีละตัวอักษร) → เวลาเล่น/จำนวนครั้งที่ตาย → ข้อความใบ้ → เครดิต → ปุ่มกลับเมนู
# ล้างตัวอ้างอิงผู้เล่น/ผี/ด่านเดิมออกจาก GameState และคืนเมาส์ให้ใช้ได้
func _ready() -> void:
	get_tree().paused = false
	GameState.level = null
	GameState.player = null
	GameState.ghost = null
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var e: Dictionary = ENDINGS.get(GameState.ending, ENDINGS.escape)
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.015, 0.015) if GameState.ending != "redeem" else Color(0.06, 0.05, 0.04)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	center.add_child(v)
	var title := Label.new()
	title.text = e.title
	title.add_theme_font_override("font", FONT_TITLE)
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", e.color)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var body := Label.new()
	body.text = e.text
	body.add_theme_font_size_override("font_size", 19)
	body.add_theme_color_override("font_color", Color(0.85, 0.82, 0.76))
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.visible_ratio = 0.0
	v.add_child(body)
	var stats := Label.new()
	var mins := int(GameState.play_time) / 60
	var secs := int(GameState.play_time) % 60
	stats.text = "เวลาเล่น %d:%02d นาที   •   ถูกจับ/สติแตก %d ครั้ง" % [mins, secs, GameState.deaths]
	stats.add_theme_font_size_override("font_size", 16)
	stats.add_theme_color_override("font_color", Color(0.55, 0.52, 0.48))
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.modulate.a = 0.0
	v.add_child(stats)
	var hint := Label.new()
	hint.text = e.hint
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(0.7, 0.6, 0.45))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate.a = 0.0
	v.add_child(hint)
	var credits := Label.new()
	credits.text = CREDITS
	credits.add_theme_font_size_override("font_size", 13)
	credits.add_theme_color_override("font_color", Color(0.5, 0.48, 0.45))
	credits.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credits.modulate.a = 0.0
	v.add_child(credits)
	var b := Button.new()
	b.text = "กลับเมนูหลัก"
	b.custom_minimum_size = Vector2(260, 44)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", 20)
	b.modulate.a = 0.0
	b.pressed.connect(func():
		GameState.checkpoint = {}
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	v.add_child(b)

	if GameState.ending == "redeem":
		Sfx.play("temple_bell", -4.0)
	else:
		Sfx.play("whisper", -8.0)
	# แอนิเมชันเข้าฉาก: ข้อความค่อย ๆ ปรากฏ แล้วสถิติ/ข้อความใบ้ เครดิต และปุ่มค่อย ๆ จางเข้ามาตามลำดับ
	var t := create_tween()
	t.tween_property(body, "visible_ratio", 1.0, 0.035 * body.text.length())
	t.tween_property(stats, "modulate:a", 1.0, 1.0)
	t.parallel().tween_property(hint, "modulate:a", 1.0, 1.0)
	t.tween_property(credits, "modulate:a", 1.0, 1.5)
	t.parallel().tween_property(b, "modulate:a", 1.0, 1.5)
