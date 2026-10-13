@tool
extends Node3D
class_name GhostSprite
## "แม่หญิงชุดขาว" แบบ billboard จากภาพตัวละคร (assets/textures/ghost_sprite.png)
## - หันหน้าเข้าหากล้องเสมอ (แกน Y) — เหมือนเธอจ้องเราตลอดเวลา
## - เงาซ้อน (afterimage) 2 ร่างด้านหลังแบบในภาพต้นฉบับ
## - glitch / สีแยก / ชายชุดพลิ้ว / หมอกจาง ๆ รอบเท้า
## เปลี่ยนภาพผีได้โดยแทนไฟล์ ghost_sprite.png (พื้นหลังโปร่งใส สัดส่วน 1:2)

# ความสูงของผี (เมตร)
@export var height := 1.8
# โหมดภาพหลอน: true = ร่างจางเบลอ (ใช้กับเงาผู้หญิงที่เห็นตอนสติต่ำ)
@export var echo := false:  # true = ร่างจาง ๆ เบลอ (ใช้กับภาพหลอน)
	set(v):
		echo = v
		if is_inside_tree():
			_build()

# ภาพของผี และพื้นผิวหมอกรอบเท้า
const TEX := preload("res://assets/textures/ghost_sprite.png")
const MIST := preload("res://assets/textures/mist.png")

# ชุดคำสั่งแสดงผล (shader) ของผี — เขียนเป็นข้อความ
# vertex: หันหน้าเข้าหากล้องเสมอ (เฉพาะแกน Y) + ชายชุดพลิ้วตามเวลา
# fragment: glitch = บางแถบของภาพเลื่อนสลับ + สีแดง/น้ำเงินแยกจากกัน, ปรับความสว่างและความโปร่งใส
const SHADER_CODE := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, blend_mix;
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float fade = 1.0;
uniform float glitch = 0.0;
uniform float brightness = 0.6;
uniform float blur = 0.0;
uniform float side_offset = 0.0;
uniform float depth_offset = 0.0;
uniform float phase = 0.0;
uniform vec4 tint : source_color = vec4(0.84, 0.92, 1.0, 1.0);
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void vertex() {
	// billboard แกน Y
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
		vec4(0.0, 1.0, 0.0, 0.0),
		vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
		MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	float low = UV.y * UV.y;
	VERTEX.x += side_offset + sin(TIME * 0.7 + phase) * 0.06 * step(0.001, abs(side_offset));
	VERTEX.x += sin(TIME * 1.7 + VERTEX.y * 3.0 + phase) * 0.035 * low;
	VERTEX.z += depth_offset;
}
void fragment() {
	vec2 uv = UV;
	float t = floor(TIME * 14.0);
	float row = floor(uv.y * 48.0);
	float band = step(0.94 - glitch * 0.25, hash(vec2(row, t)));
	uv.x += (hash(vec2(t, row)) - 0.5) * 0.09 * band * glitch;
	vec4 c = textureLod(tex, uv, blur);
	if (glitch > 0.01) {
		float ca = 0.008 * glitch;
		c.r = textureLod(tex, uv + vec2(ca, 0.0), blur).r;
		c.b = textureLod(tex, uv - vec2(ca, 0.0), blur).b;
	}
	ALBEDO = c.rgb * tint.rgb * brightness;
	float a = c.a * fade;
	a *= 1.0 - band * glitch * 0.5;
	ALPHA = clamp(a, 0.0, 1.0);
}
"""

# ตัวแปรภายใน: shader, วัสดุของร่างหลัก, วัสดุของเงาซ้อน, หมอก, ค่า fade/glitch/แสงไฟฉาย
var _shader: Shader
var _main_mat: ShaderMaterial
var _echo_mats: Array[ShaderMaterial] = []
var _mist: CPUParticles3D
var _fade := 1.0
var _glitch := 0.0
var _lit := 0.0
# จุดศีรษะของผี (ใช้เล็งกล้องตอน jumpscare)
var head_pivot: Node3D  # จุดศีรษะ (ใช้เล็งกล้องตอน jumpscare)


# เริ่มต้น: สร้างภาพผีทั้งหมด
func _ready() -> void:
	_build()


# สร้างวัสดุ shader ด้วยพารามิเตอร์: ความจาง ความเบลอ ระยะเยื้องข้าง/ลึก และเฟสการพลิ้ว
func _make_mat(fade: float, blur: float, side: float, depth: float, ph: float) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER_CODE
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("tex", TEX)
	m.set_shader_parameter("fade", fade)
	m.set_shader_parameter("blur", blur)
	m.set_shader_parameter("side_offset", side)
	m.set_shader_parameter("depth_offset", depth)
	m.set_shader_parameter("phase", ph)
	return m


# สร้างแผ่นสี่เหลี่ยมสูง height ติดภาพผี (prio = ลำดับการวาดซ้อน)
func _quad(mat: Material, prio: int) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(height * 0.5, height)
	q.center_offset = Vector3(0, height * 0.5, 0)
	mi.mesh = q
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.sorting_offset = float(prio) * 0.01
	add_child(mi)
	return mi


# ประกอบตัวผี: โหมด echo = ร่างเบลอร่างเดียว
# โหมดปกติ = เงาซ้อนซ้าย/ขวา 2 ร่าง + ร่างหลัก + หมอกลอยรอบเท้า (อนุภาค)
func _build() -> void:
	for c in get_children():
		c.queue_free()
	_echo_mats.clear()
	head_pivot = Node3D.new()
	head_pivot.name = "HeadPivot"
	head_pivot.position = Vector3(0, height * 0.86, 0)
	add_child(head_pivot)
	if echo:
		# ภาพหลอน: ร่างเบลอจาง ๆ แบบเงาด้านหลังในภาพต้นฉบับ
		_main_mat = _make_mat(0.45, 2.2, 0.0, 0.0, 1.3)
		_main_mat.set_shader_parameter("brightness", 0.5)
		_quad(_main_mat, 0)
		return
	# เงาซ้อน 2 ร่าง (ด้านหลัง ซ้าย/ขวา)
	for i in 2:
		var side := -0.38 if i == 0 else 0.4
		var em := _make_mat(0.16, 2.5, side, -0.25, float(i) * 2.1)
		em.set_shader_parameter("brightness", 0.55)
		_echo_mats.append(em)
		_quad(em, -1)
	_main_mat = _make_mat(1.0, 0.0, 0.0, 0.0, 0.0)
	_quad(_main_mat, 1)
	# หมอกรอบเท้า
	_mist = CPUParticles3D.new()
	_mist.amount = 14
	_mist.lifetime = 3.2
	_mist.preprocess = 3.0
	_mist.local_coords = false
	_mist.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_mist.emission_sphere_radius = 0.35
	_mist.position = Vector3(0, 0.25, 0)
	_mist.direction = Vector3(0, 1, 0)
	_mist.spread = 50.0
	_mist.gravity = Vector3(0, 0.08, 0)
	_mist.initial_velocity_min = 0.05
	_mist.initial_velocity_max = 0.15
	_mist.scale_amount_min = 0.7
	_mist.scale_amount_max = 1.4
	var grad := Gradient.new()
	grad.set_color(0, Color(0.75, 0.85, 1.0, 0.0))
	grad.set_color(1, Color(0.75, 0.85, 1.0, 0.0))
	grad.add_point(0.35, Color(0.75, 0.85, 1.0, 0.18))
	_mist.color_ramp = grad
	var q := QuadMesh.new()
	q.size = Vector2(0.9, 0.9)
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.albedo_texture = MIST
	mm.vertex_color_use_as_albedo = true
	mm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mm.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = mm
	_mist.mesh = q
	_mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mist)


# ตั้งความจาง 0-1 (ร่างหลักตามค่า, เงาซ้อนจางกว่ามาก, ซ่อนหมอกเมื่อจางเกินไป)
func set_fade(f: float) -> void:
	_fade = f
	if _main_mat:
		_main_mat.set_shader_parameter("fade", f * (0.45 if echo else 1.0))
	for m in _echo_mats:
		m.set_shader_parameter("fade", f * 0.16)
	if _mist:
		_mist.visible = f > 0.3


# อ่านค่าความจางปัจจุบัน
func get_fade() -> float:
	return _fade


## ความแรงของ glitch (0-1) — ผีเรียกตามสถานะ/ระยะห่าง
func set_glitch(g: float) -> void:
	_glitch = g
	if _main_mat:
		_main_mat.set_shader_parameter("glitch", g)


## ถูกไฟฉายส่อง (0-1) → สว่างขึ้น
# ตั้งความสว่างเมื่อโดนไฟฉายส่อง (ค่อย ๆ เปลี่ยน)
func set_lit(l: float) -> void:
	_lit = lerpf(_lit, l, 0.2)
	if _main_mat and not echo:
		_main_mat.set_shader_parameter("brightness", 0.55 + 0.5 * _lit)


# ตั้งความเข้มของเงาซ้อน (ไล่ล่า = เข้มขึ้น)
func set_echo_strength(s: float) -> void:
	for m in _echo_mats:
		m.set_shader_parameter("fade", _fade * s)
