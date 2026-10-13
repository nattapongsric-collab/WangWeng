"""สร้างไฟล์ตั้งค่าโปรเจค + ซีนย่อย + material (.tres)
รัน: python3 tools/gen_project.py
"""
import os

ROOT = os.path.join(os.path.dirname(__file__), "..")


def w(path, text):
    p = os.path.join(ROOT, path)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, "w", encoding="utf-8") as f:
        f.write(text)
    print("wrote", path)


# ------------------------------------------------------------------ input map
def key(code):
    return ('Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,'
            '"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,'
            f'"keycode":0,"physical_keycode":{code},"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)')


def mouse(btn):
    return ('Object(InputEventMouseButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,'
            '"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"button_mask":0,'
            f'"position":Vector2(0, 0),"global_position":Vector2(0, 0),"factor":1.0,"button_index":{btn},"canceled":false,"pressed":false,"double_click":false,"script":null)')


K = dict(W=87, A=65, S=83, D=68, C=67, E=69, F=70, SPACE=32, SHIFT=4194325, CTRL=4194326, TAB=4194306, ESC=4194305,
         UP=4194320, DOWN=4194322, LEFT=4194319, RIGHT=4194321, P=80, J=74)
actions = {
    "move_forward": [key(K["W"]), key(K["UP"])],
    "move_back": [key(K["S"]), key(K["DOWN"])],
    "move_left": [key(K["A"]), key(K["LEFT"])],
    "move_right": [key(K["D"]), key(K["RIGHT"])],
    "sprint": [key(K["SHIFT"])],
    "crouch": [key(K["CTRL"]), key(K["C"])],
    "interact": [key(K["E"]), mouse(1)],
    "flashlight": [key(K["F"]), mouse(2)],
    "hold_breath": [key(K["SPACE"])],
    "journal": [key(K["TAB"]), key(K["J"])],
    "pause": [key(K["ESC"]), key(K["P"])],
}
inp = "\n".join(
    f'{a}={{\n"deadzone": 0.2,\n"events": [{", ".join(ev)}]\n}}' for a, ev in actions.items())

w("project.godot", f'''; Engine configuration file.
; วังเวง (WANG WENG: The House That Remembers) — Godot 4.7

config_version=5

[application]

config/name="วังเวง - WANG WENG"
config/description="Survival Horror / Exploration Puzzle มุมมองบุคคลที่หนึ่ง — CP410844 Computer Game Development"
run/main_scene="res://scenes/main_menu.tscn"
config/features=PackedStringArray("4.7", "GL Compatibility")
config/icon="res://icon.svg"

[audio]

buses/default_bus_layout="res://default_bus_layout.tres"

[autoload]

GameState="*res://scripts/autoload/game_state.gd"
Sfx="*res://scripts/autoload/sfx.gd"

[display]

window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"

[gui]

theme/custom_font="res://assets/fonts/Sarabun-Regular.ttf"

[input]

{inp}

[layer_names]

3d_physics/layer_1="world"
3d_physics/layer_2="player"
3d_physics/layer_3="ghost"
3d_physics/layer_4="doors"
3d_physics/layer_5="props"
3d_physics/layer_6="interact"

[navigation]

3d/default_cell_size=0.1
3d/default_cell_height=0.1

[rendering]

renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
anti_aliasing/quality/msaa_3d=1
lights_and_shadows/directional_shadow/size=2048
limits/opengl/max_lights_per_object=16
lights_and_shadows/positional_shadow/atlas_size=2048
textures/vram_compression/import_etc2_astc=true
''')

w("default_bus_layout.tres", '''[gd_resource type="AudioBusLayout" load_steps=3 format=3]

[sub_resource type="AudioEffectReverb" id="AudioEffectReverb_sfx"]
resource_name = "Reverb"
room_size = 0.55
damping = 0.6
spread = 0.8
dry = 1.0
wet = 0.22

[sub_resource type="AudioEffectLowPassFilter" id="AudioEffectLowPassFilter_amb"]
resource_name = "LowPassFilter"
cutoff_hz = 6000.0

[resource]
bus/1/name = &"SFX"
bus/1/solo = false
bus/1/mute = false
bus/1/bypass_fx = false
bus/1/volume_db = 0.0
bus/1/send = &"Master"
bus/1/effect/0/effect = SubResource("AudioEffectReverb_sfx")
bus/1/effect/0/enabled = true
bus/2/name = &"Ambience"
bus/2/solo = false
bus/2/mute = false
bus/2/bypass_fx = false
bus/2/volume_db = 0.0
bus/2/send = &"Master"
bus/2/effect/0/effect = SubResource("AudioEffectLowPassFilter_amb")
bus/2/effect/0/enabled = true
''')

w("icon.svg", '''<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">
<rect width="128" height="128" rx="18" fill="#0d0908"/>
<path d="M20 70 L64 30 L108 70 Z" fill="#3a1d12"/>
<rect x="32" y="70" width="64" height="44" fill="#24130c"/>
<rect x="56" y="86" width="16" height="28" fill="#000"/>
<ellipse cx="64" cy="94" rx="5" ry="6" fill="#e8e4da"/>
<rect x="59" y="99" width="10" height="15" fill="#e8e4da"/>
<rect x="58" y="88" width="12" height="16" fill="#050505"/>
<circle cx="96" cy="26" r="9" fill="#c9d4f0"/>
</svg>
''')

# ------------------------------------------------------------------ export presets
w("export_presets.cfg", '''[preset.0]

name="Web"
platform="Web"
runnable=true
advanced_options=false
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter="tools/*, tests/*, docs/*"
export_path="build/web/index.html"
patches=PackedStringArray()
encryption_include_filters=""
encryption_exclude_filters=""
seed=0
encrypt_pck=false
encrypt_directory=false
script_export_mode=2

[preset.0.options]

custom_template/debug=""
custom_template/release=""
variant/extensions_support=false
variant/thread_support=false
vram_texture_compression/for_desktop=true
vram_texture_compression/for_mobile=false
html/export_icon=true
html/custom_html_shell=""
html/head_include=""
html/canvas_resize_policy=2
html/focus_canvas_on_start=true
html/experimental_virtual_keyboard=false
progressive_web_app/enabled=false

[preset.1]

name="Windows Desktop"
platform="Windows Desktop"
runnable=true
advanced_options=false
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter="tools/*, tests/*, docs/*"
export_path="build/windows/WangWeng.exe"
patches=PackedStringArray()
encryption_include_filters=""
encryption_exclude_filters=""
seed=0
encrypt_pck=false
encrypt_directory=false
script_export_mode=2

[preset.1.options]

custom_template/debug=""
custom_template/release=""
debug/export_console_wrapper=1
binary_format/embed_pck=true
texture_format/s3tc_bptc=true
texture_format/etc2_astc=false
binary_format/architecture="x86_64"
''')

# ------------------------------------------------------------------ small scenes
def script_scene(path, name, typ, script, extra=""):
    w(path, f'''[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="{script}" id="1_s"]

[node name="{name}" type="{typ}"]
script = ExtResource("1_s")
{extra}''')


script_scene("scenes/props/door.tscn", "Door", "Node3D", "res://scripts/world/door.gd")
script_scene("scenes/props/pickup.tscn", "Pickup", "Node3D", "res://scripts/world/pickup.gd")
script_scene("scenes/props/candle.tscn", "Candle", "Node3D", "res://scripts/world/candle.gd")
script_scene("scenes/props/hide_spot.tscn", "HideSpot", "Node3D", "res://scripts/world/hide_spot.gd")
script_scene("scenes/props/noisy_prop.tscn", "NoisyProp", "RigidBody3D", "res://scripts/world/noisy_prop.gd")
script_scene("scenes/props/altar.tscn", "Altar", "Node3D", "res://scripts/world/altar.gd")
script_scene("scenes/props/trigger_zone.tscn", "TriggerZone", "Area3D", "res://scripts/world/trigger_zone.gd")
script_scene("scenes/props/safe_zone.tscn", "SafeZone", "Node3D", "res://scripts/world/safe_zone.gd")
script_scene("scenes/hud.tscn", "HUD", "CanvasLayer", "res://scripts/ui/hud.gd")
script_scene("scenes/main_menu.tscn", "MainMenu", "Control", "res://scripts/ui/main_menu.gd",
             "anchors_preset = 15\nanchor_right = 1.0\nanchor_bottom = 1.0\ngrow_horizontal = 2\ngrow_vertical = 2\n")
script_scene("scenes/ending.tscn", "Ending", "Control", "res://scripts/ui/ending.gd",
             "anchors_preset = 15\nanchor_right = 1.0\nanchor_bottom = 1.0\ngrow_horizontal = 2\ngrow_vertical = 2\n")

w("scenes/player.tscn", '''[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/player/player.gd" id="1_p"]

[sub_resource type="CapsuleShape3D" id="CapsuleShape3D_p"]
radius = 0.3
height = 1.7

[node name="Player" type="CharacterBody3D" groups=["player"]]
collision_layer = 2
collision_mask = 25
floor_max_angle = 0.785398
floor_snap_length = 0.3
script = ExtResource("1_p")

[node name="Collision" type="CollisionShape3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.85, 0)
shape = SubResource("CapsuleShape3D_p")

[node name="Head" type="Node3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.6, 0)

[node name="Camera" type="Camera3D" parent="Head"]
current = true
fov = 72.0
near = 0.04
far = 120.0

[node name="Flashlight" type="SpotLight3D" parent="Head/Camera"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0.18, -0.15, 0.05)
visible = false
light_color = Color(1, 0.93, 0.8, 1)
light_energy = 3.2
light_specular = 0.3
shadow_enabled = true
shadow_bias = 0.05
spot_range = 17.0
spot_attenuation = 0.9
spot_angle = 27.0
spot_angle_attenuation = 1.6

[node name="InteractRay" type="RayCast3D" parent="Head/Camera"]
target_position = Vector3(0, 0, -2.3)
collision_mask = 57
collide_with_areas = true
''')

w("scenes/ghost.tscn", '''[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/enemy/ghost.gd" id="1_g"]
[ext_resource type="Script" path="res://scripts/enemy/ghost_model.gd" id="2_m"]
[ext_resource type="AudioStream" path="res://assets/audio/ghost_hum.wav" id="3_h"]

[node name="Ghost" type="Node3D" groups=["ghost"]]
script = ExtResource("1_g")

[node name="Model" type="Node3D" parent="."]
script = ExtResource("2_m")

[node name="Agent" type="NavigationAgent3D" parent="."]
path_desired_distance = 0.45
target_desired_distance = 0.6
path_max_distance = 3.0

[node name="Aura" type="OmniLight3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.3, -0.35)
light_color = Color(0.75, 0.82, 1, 1)
light_energy = 0.6
omni_range = 3.2
omni_attenuation = 1.5

[node name="Hum" type="AudioStreamPlayer3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.5, 0)
stream = ExtResource("3_h")
volume_db = -2.0
unit_size = 3.0
max_distance = 24.0
bus = &"SFX"
''')

# ------------------------------------------------------------------ materials
MATS = {
    # name: (texture, uv_scale, tint, roughness, world_triplanar)
    "floor_wood": ("wood_floor", 0.45, (1, 1, 1), 0.7, True),
    "wall_plaster": ("plaster_wall", 0.35, (1, 1, 1), 0.95, True),
    "wall_wood": ("wood_wall", 0.4, (1, 1, 1), 0.85, True),
    "ceiling": ("ceiling", 0.4, (0.85, 0.85, 0.85), 0.95, True),
    "tile": ("tile_floor", 0.5, (1, 1, 1), 0.5, True),
    "wood_dark": ("wood_dark", 0.8, (1, 1, 1), 0.7, True),
    "fabric": ("fabric", 0.9, (1, 1, 1), 0.95, True),
    "cloth_white": ("cloth_white", 1.0, (1, 1, 1), 0.95, True),
    "grass": ("grass", 0.25, (1, 1, 1), 1.0, True),
    "dirt": ("dirt", 0.4, (1, 1, 1), 1.0, True),
    "brick": ("brick", 0.5, (1, 1, 1), 0.95, True),
    "roof": ("brick", 0.6, (0.45, 0.28, 0.25), 0.9, True),
    "trunk": ("wood_wall", 0.8, (0.55, 0.5, 0.45), 1.0, True),
    "photo": ("family_photo", 1.0, (1, 1, 1), 0.6, None),
}
for name, (tex, sc, tint, rough, world) in MATS.items():
    if world is None:
        body = f'albedo_texture = ExtResource("1_t")\nroughness = {rough}\n'
    else:
        body = (f'albedo_color = Color({tint[0]}, {tint[1]}, {tint[2]}, 1)\nalbedo_texture = ExtResource("1_t")\n'
                f'roughness = {rough}\nuv1_scale = Vector3({sc}, {sc}, {sc})\nuv1_triplanar = true\n'
                f'uv1_world_triplanar = {"true" if world else "false"}\ntexture_filter = 5\n')
    w(f"assets/materials/{name}.tres", f'''[gd_resource type="StandardMaterial3D" load_steps=2 format=3]

[ext_resource type="Texture2D" path="res://assets/textures/{tex}.png" id="1_t"]

[resource]
{body}''')

COLORS = {
    "metal_white": ((0.62, 0.63, 0.6), 0.35, 0.4, None),
    "gold": ((0.8, 0.6, 0.25), 0.3, 0.9, None),
    "red_lacquer": ((0.35, 0.05, 0.04), 0.35, 0.1, None),
    "black": ((0.03, 0.03, 0.03), 0.5, 0.0, None),
    "water": ((0.02, 0.03, 0.04), 0.05, 0.3, None),
    "leaves": ((0.05, 0.1, 0.05), 0.95, 0.0, None),
    "plaster_white": ((0.7, 0.7, 0.66), 0.9, 0.0, None),
    "mirror": ((0.25, 0.27, 0.3), 0.05, 1.0, None),
    "clay": ((0.32, 0.2, 0.13), 0.75, 0.0, None),
    "glass_moon": ((0.05, 0.07, 0.1), 0.1, 0.0, None),
    "moon": ((0.85, 0.9, 1.0), 1.0, 0.0, 4.0),
    "toy_red": ((0.55, 0.12, 0.1), 0.7, 0.0, None),
    "toy_blue": ((0.15, 0.25, 0.5), 0.7, 0.0, None),
    "doll": ((0.75, 0.68, 0.6), 0.8, 0.0, None),
}
for name, (c, rough, metal, emis) in COLORS.items():
    extra = ""
    if emis:
        extra = f"shading_mode = 0\nemission_enabled = true\nemission = Color({c[0]}, {c[1]}, {c[2]}, 1)\nemission_energy_multiplier = {emis}\n"
    w(f"assets/materials/{name}.tres", f'''[gd_resource type="StandardMaterial3D" format=3]

[resource]
albedo_color = Color({c[0]}, {c[1]}, {c[2]}, 1)
roughness = {rough}
metallic = {metal}
{extra}''')
