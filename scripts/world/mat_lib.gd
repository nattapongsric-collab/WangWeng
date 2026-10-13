@tool
class_name MatLib
## ตัวช่วยสร้าง material + mesh ใช้ซ้ำ (cache) สำหรับวัตถุที่สร้างด้วยโค้ด

# แคชวัสดุ — วัสดุที่พารามิเตอร์เหมือนกันใช้ตัวเดียวร่วมกัน (ประหยัดหน่วยความจำและช่วยให้รวม mesh ได้)
static var _cache := {}


# วัสดุสีล้วน: ความหยาบ (rough) ความเป็นโลหะ (metal) และแสงเรืองในตัว (emission) ถ้ามี
static func color(c: Color, rough: float = 0.8, metal: float = 0.0, emission: Color = Color.BLACK, emission_energy: float = 0.0) -> StandardMaterial3D:
	var key := "c_%s_%s_%s_%s_%s" % [c.to_html(), rough, metal, emission.to_html(), emission_energy]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if emission_energy > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = emission_energy
	_cache[key] = m
	return m


# วัสดุติดพื้นผิวจากไฟล์ assets/textures/<ชื่อ>.png — triplanar = ฉายพื้นผิวตามขนาดวัตถุ ไม่ต้องทำ UV
static func textured(tex_name: String, uv_scale: float = 1.0, tint: Color = Color.WHITE, triplanar: bool = true) -> StandardMaterial3D:
	var key := "t_%s_%s_%s_%s" % [tex_name, uv_scale, tint.to_html(), triplanar]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/textures/%s.png" % tex_name)
	m.albedo_color = tint
	m.roughness = 0.85
	if triplanar:
		m.uv1_triplanar = true
		m.uv1_world_triplanar = false
		m.uv1_scale = Vector3.ONE * uv_scale
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_cache[key] = m
	return m


# วัสดุเรืองแสงที่ไม่แชร์ (สร้างใหม่ทุกครั้ง) เพราะต้องปรับความสว่างแยกกัน เช่น เปลวเทียน ประกายของที่เก็บได้
static func unique_emissive(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


# สร้างกล่องสี่เหลี่ยมใต้ parent ที่ตำแหน่ง/มุมหมุน (องศา) ที่กำหนด — ใช้ประกอบเฟอร์นิเจอร์ด้วยโค้ด
static func box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


# สร้างทรงกระบอก/กรวยตัด (รัศมีบนและล่างต่างกันได้) segs = จำนวนด้านของวงกลม
static func cyl(parent: Node3D, r_top: float, r_bot: float, h: float, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO, segs: int = 16) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = h
	cm.radial_segments = segs
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


# สร้างทรงกลม (h_scale ยืด/บีบแนวสูงให้เป็นไข่ได้) ความละเอียดต่ำเพื่อประหยัดทรัพยากร
static func sphere(parent: Node3D, r: float, pos: Vector3, mat: Material, h_scale: float = 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0 * h_scale
	sm.radial_segments = 12
	sm.rings = 6
	mi.mesh = sm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


# สร้างกล่องชนที่อยู่นิ่ง (มองไม่เห็น) ให้ผู้เล่นและผีเดินทะลุไม่ได้
static func static_box(parent: Node3D, size: Vector3, pos: Vector3, layer: int = 1) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.collision_layer = layer
	sb.collision_mask = 0
	sb.position = pos
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	sb.add_child(cs)
	parent.add_child(sb)
	return sb


## รวม MeshInstance3D ลูกทั้งหมดของ node (แยกตาม material) เพื่อลด draw call
# รวมโมเดลลูกทั้งหมดที่วัสดุเหมือนกันให้เป็นก้อนเดียว (ลดจำนวนครั้งที่ต้องวาด = เกมลื่นขึ้น โดยเฉพาะบนเว็บ)
# ข้ามวัสดุแบบ unshaded (เช่น เปลวไฟ) เพราะต้องปรับแยก
static func merge_children(node: Node3D, recursive: bool = false) -> void:
	var tools := {}
	var mats := {}
	var inv := node.global_transform.affine_inverse() if node.is_inside_tree() else Transform3D.IDENTITY
	var list: Array = node.find_children("*", "MeshInstance3D", recursive, false)
	for mi in list:
		var m := mi as MeshInstance3D
		if m.mesh == null or m.material_override == null or m.mesh.get_surface_count() != 1:
			continue
		if m.material_override is StandardMaterial3D and (m.material_override as StandardMaterial3D).shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
			continue
		var key := m.material_override.get_instance_id()
		if not tools.has(key):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			tools[key] = st
			mats[key] = m.material_override
		var xf: Transform3D = (inv * m.global_transform) if node.is_inside_tree() else _rel_xform(node, m)
		(tools[key] as SurfaceTool).append_from(m.mesh, 0, xf)
		m.get_parent().remove_child(m)
		m.queue_free()
	for key in tools:
		var nmi := MeshInstance3D.new()
		nmi.mesh = (tools[key] as SurfaceTool).commit()
		nmi.material_override = mats[key]
		node.add_child(nmi)


# คำนวณตำแหน่ง/มุมของ n เทียบกับ root เมื่อยังไม่ได้อยู่ในฉาก (ไล่คูณจาก n ขึ้นไปหาแม่)
static func _rel_xform(root: Node3D, n: Node3D) -> Transform3D:
	var xf := n.transform
	var p := n.get_parent()
	while p != null and p != root:
		if p is Node3D:
			xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf
