"""
Single-Material Embedded FBX Pistol Crate for Roblox Studio
Builds the crate with all components mapped to a unified 2048x2048 texture atlas,
so the entire crate uses ONE single material and embeds the texture directly inside
the .fbx binary file. When dragged into Roblox Studio, no loose texture files are needed!
"""

import bpy
import bmesh
import math
import os

EXPORT_DIR = r"c:\Users\selab\OneDrive\Documents\AI GAMES\The Vote\assets\models\pistol_crate"
os.makedirs(EXPORT_DIR, exist_ok=True)

# 1. Clean existing scene safely
if bpy.context.mode != 'OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')
for obj in list(bpy.data.objects):
    bpy.data.objects.remove(obj, do_unlink=True)
for img in list(bpy.data.images):
    bpy.data.images.remove(img)

# 2. Material Setup (Single Unified Material)
# ----------------------------------------------------
mat = bpy.data.materials.new(name="M_PistolCrate")
mat.use_nodes = True
nodes = mat.node_tree.nodes
nodes.clear()

out_node = nodes.new("ShaderNodeOutputMaterial")
bsdf = nodes.new("ShaderNodeBsdfPrincipled")
bsdf.location = (400, 0)
mat.node_tree.links.new(bsdf.outputs["BSDF"], out_node.inputs["Surface"])

atlas_path = os.path.join(EXPORT_DIR, "crate_atlas_albedo.png")
if os.path.exists(atlas_path):
    img = bpy.data.images.load(atlas_path)
    img.pack() # Pack image data directly into Blender
    tex_node = nodes.new("ShaderNodeTexImage")
    tex_node.image = img
    mat.node_tree.links.new(tex_node.outputs["Color"], bsdf.inputs["Base Color"])
else:
    bsdf.inputs["Base Color"].default_value = (0.28, 0.34, 0.22, 1.0)

bsdf.inputs["Roughness"].default_value = 0.65
bsdf.inputs["Metallic"].default_value = 0.15 # Blend
mat.diffuse_color = (0.28, 0.34, 0.22, 1.0)


# 3. Geometry Construction & UV Atlas Mapping
# ----------------------------------------------------
# Dimensions:
WIDTH = 1.60   # X
DEPTH = 1.10   # Y
HEIGHT = 0.82  # Z
LID_H = 0.16
BODY_H = HEIGHT - LID_H

parts = []

# --- A. Crate Body (Region B: U: [0.0, 0.70], V: [0.0, 0.50]) ---
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, BODY_H / 2.0))
crate_body = bpy.context.active_object
crate_body.name = "Crate_Body"
crate_body.scale = (WIDTH, DEPTH, BODY_H)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
crate_body.data.materials.append(mat)

bev_b = crate_body.modifiers.new("Bevel", "BEVEL")
bev_b.width = 0.012
bev_b.segments = 2
bpy.ops.object.modifier_apply(modifier="Bevel")

# Map UVs to Region B
bpy.context.view_layer.objects.active = crate_body
bpy.ops.object.mode_set(mode='EDIT')
bm_b = bmesh.from_edit_mesh(crate_body.data)
uv_b = bm_b.loops.layers.uv.verify()
for f in bm_b.faces:
    for loop in f.loops:
        v = loop.vert.co
        # Normalize local coords to [0, 1]
        if abs(f.normal.y) > 0.5: # Front/Back
            nx = (v.x / WIDTH) + 0.5
            ny = (v.z / BODY_H) + 0.5
        elif abs(f.normal.x) > 0.5: # Left/Right
            nx = (v.y / DEPTH) + 0.5
            ny = (v.z / BODY_H) + 0.5
        else:
            nx = (v.x / WIDTH) + 0.5
            ny = (v.y / DEPTH) + 0.5
        # Map to Region B: U: [0.02, 0.68], V: [0.03, 0.47] (prevents texture wrap bleed)
        loop[uv_b].uv = (0.02 + (nx * 0.66), 0.03 + (ny * 0.44))
bmesh.update_edit_mesh(crate_body.data)
bpy.ops.object.mode_set(mode='OBJECT')
parts.append(crate_body)


# --- B. Crate Lid (Region A for Top: U: [0.0, 0.70], V: [0.50, 1.0]) ---
lid_z = BODY_H + (LID_H / 2.0)
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, lid_z))
crate_lid = bpy.context.active_object
crate_lid.name = "Crate_Lid"
crate_lid.scale = (WIDTH + 0.02, DEPTH + 0.02, LID_H)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
crate_lid.data.materials.append(mat)

bev_l = crate_lid.modifiers.new("Bevel", "BEVEL")
bev_l.width = 0.012
bev_l.segments = 2
bpy.ops.object.modifier_apply(modifier="Bevel")

bpy.context.view_layer.objects.active = crate_lid
bpy.ops.object.mode_set(mode='EDIT')
bm_l = bmesh.from_edit_mesh(crate_lid.data)
uv_l = bm_l.loops.layers.uv.verify()
for f in bm_l.faces:
    if f.normal.z > 0.7:
        # Top Face with Stencils (Region A: U: [0.0, 0.70], V: [0.50, 1.0])
        for loop in f.loops:
            v = loop.vert.co
            nx = (v.x / (WIDTH + 0.02)) + 0.5
            ny = (v.y / (DEPTH + 0.02)) + 0.5
            loop[uv_l].uv = (0.02 + (nx * 0.66), 0.52 + (ny * 0.46))
    else:
        # Sides of lid (Region B)
        for loop in f.loops:
            v = loop.vert.co
            nx = (v.x / (WIDTH + 0.02)) + 0.5
            ny = (v.z / LID_H) + 0.5
            loop[uv_l].uv = (0.02 + (nx * 0.66), 0.05 + (ny * 0.15))
bmesh.update_edit_mesh(crate_lid.data)
bpy.ops.object.mode_set(mode='OBJECT')
parts.append(crate_lid)


# --- Helper to map an object to Region C (Metal) ---
def map_to_metal(obj):
    obj.data.materials.append(mat)
    # Project into Region C: U: [0.70, 1.0], V: [0.30, 1.0]
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode='EDIT')
    bm = bmesh.from_edit_mesh(obj.data)
    uv = bm.loops.layers.uv.verify()
    for f in bm.faces:
        for loop in f.loops:
            v = loop.vert.co
            nx = (v.x * 2.5) % 1.0
            ny = (v.y * 2.5 + v.z * 2.5) % 1.0
            loop[uv].uv = (0.70 + (nx * 0.30), 0.30 + (ny * 0.70))
    bmesh.update_edit_mesh(obj.data)
    bpy.ops.object.mode_set(mode='OBJECT')

# --- Helper to map an object to Region D (Rope) ---
def map_to_rope(obj):
    obj.data.materials.append(mat)
    # Project into Region D: U: [0.70, 1.0], V: [0.0, 0.30]
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode='EDIT')
    bm = bmesh.from_edit_mesh(obj.data)
    uv = bm.loops.layers.uv.verify()
    for f in bm.faces:
        for loop in f.loops:
            v = loop.vert.co
            nx = (v.x * 3.0 + v.y * 3.0) % 1.0
            ny = (v.z * 3.0) % 1.0
            loop[uv].uv = (0.70 + (nx * 0.30), ny * 0.30)
    bmesh.update_edit_mesh(obj.data)
    bpy.ops.object.mode_set(mode='OBJECT')


# --- C. Wrap-Around Corner Brackets (8 Corners) ---
bracket_len = 0.16
bracket_thick = 0.008
bracket_w = 0.065

hw = (WIDTH + 0.02) / 2.0
hd = (DEPTH + 0.02) / 2.0

for sx in [-1, 1]:
    for sy in [-1, 1]:
        for is_top in [True, False]:
            z_pos = (HEIGHT + 0.002) if is_top else 0.002
            z_dir = -1 if is_top else 1
            
            # Top/Bottom horizontal plate
            bpy.ops.mesh.primitive_cube_add(
                size=1.0, 
                location=(sx * (hw - bracket_len/2.0), sy * (hd - bracket_w/2.0), z_pos + (z_dir * bracket_thick/2.0))
            )
            p1 = bpy.context.active_object
            p1.scale = (bracket_len, bracket_w, bracket_thick)
            bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
            map_to_metal(p1)
            parts.append(p1)

            bpy.ops.mesh.primitive_cube_add(
                size=1.0, 
                location=(sx * (hw - bracket_w/2.0), sy * (hd - bracket_len/2.0), z_pos + (z_dir * bracket_thick/2.0))
            )
            p2 = bpy.context.active_object
            p2.scale = (bracket_w, bracket_len, bracket_thick)
            bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
            map_to_metal(p2)
            parts.append(p2)

            # Rivet on top/bottom
            bpy.ops.mesh.primitive_uv_sphere_add(
                radius=0.013, 
                location=(sx * (hw - 0.05), sy * (hd - 0.05), z_pos + (z_dir * (bracket_thick + 0.006)))
            )
            r_top = bpy.context.active_object
            r_top.scale = (1.0, 1.0, 0.5)
            map_to_metal(r_top)
            parts.append(r_top)

            # Front/Back flap
            flap_z = z_pos + (z_dir * bracket_len / 2.0)
            bpy.ops.mesh.primitive_cube_add(
                size=1.0,
                location=(sx * (hw - bracket_w/2.0), sy * (hd + bracket_thick/2.0), flap_z)
            )
            p_fb = bpy.context.active_object
            p_fb.scale = (bracket_w, bracket_thick, bracket_len)
            bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
            map_to_metal(p_fb)
            parts.append(p_fb)

            # Rivet on front/back flap
            bpy.ops.mesh.primitive_uv_sphere_add(
                radius=0.013,
                location=(sx * (hw - bracket_w/2.0), sy * (hd + bracket_thick + 0.006), flap_z)
            )
            r_fb = bpy.context.active_object
            r_fb.scale = (1.0, 0.5, 1.0)
            map_to_metal(r_fb)
            parts.append(r_fb)

            # Left/Right flap
            bpy.ops.mesh.primitive_cube_add(
                size=1.0,
                location=(sx * (hw + bracket_thick/2.0), sy * (hd - bracket_w/2.0), flap_z)
            )
            p_lr = bpy.context.active_object
            p_lr.scale = (bracket_thick, bracket_w, bracket_len)
            bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
            map_to_metal(p_lr)
            parts.append(p_lr)

            # Rivet on side flap
            bpy.ops.mesh.primitive_uv_sphere_add(
                radius=0.013,
                location=(sx * (hw + bracket_thick + 0.006), sy * (hd - bracket_w/2.0), flap_z)
            )
            r_lr = bpy.context.active_object
            r_lr.scale = (0.5, 1.0, 1.0)
            map_to_metal(r_lr)
            parts.append(r_lr)


# --- D. Front Heavy Clasp Latch ---
latch_y = -hd - 0.010
latch_z = BODY_H + 0.005

bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, latch_y, latch_z + 0.055))
l_up = bpy.context.active_object
l_up.scale = (0.13, 0.018, 0.08)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
map_to_metal(l_up)
parts.append(l_up)

bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, latch_y, latch_z - 0.055))
l_low = bpy.context.active_object
l_low.scale = (0.13, 0.018, 0.09)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
map_to_metal(l_low)
parts.append(l_low)

bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, latch_y - 0.018, latch_z - 0.015))
l_lever = bpy.context.active_object
l_lever.scale = (0.075, 0.024, 0.12)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
map_to_metal(l_lever)
parts.append(l_lever)

bpy.ops.mesh.primitive_torus_add(major_radius=0.032, minor_radius=0.007, location=(0, latch_y - 0.022, latch_z - 0.08))
wire = bpy.context.active_object
wire.rotation_euler = (math.radians(90), 0, 0)
wire.scale = (1.0, 1.0, 1.45)
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
map_to_metal(wire)
parts.append(wire)

for rx in [-0.045, 0.045]:
    for rz in [latch_z + 0.07, latch_z - 0.08]:
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.011, location=(rx, latch_y - 0.010, rz))
        r_latch = bpy.context.active_object
        r_latch.scale = (1.0, 0.5, 1.0)
        map_to_metal(r_latch)
        parts.append(r_latch)


# --- E. Side Handles with Drooping Rope ---
for sx in [-1, 1]:
    side_x = sx * (hw + 0.008)
    handle_z = HEIGHT * 0.50
    
    for y_off in [-0.18, 0.18]:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(side_x, y_off, handle_z))
        h_plate = bpy.context.active_object
        h_plate.scale = (0.018, 0.065, 0.09)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        map_to_metal(h_plate)
        parts.append(h_plate)
        
        bpy.ops.mesh.primitive_torus_add(major_radius=0.026, minor_radius=0.007, location=(side_x + (sx * 0.022), y_off, handle_z))
        eye = bpy.context.active_object
        eye.rotation_euler = (0, math.radians(90), 0)
        map_to_metal(eye)
        parts.append(eye)

        for rz in [-0.03, 0.03]:
            bpy.ops.mesh.primitive_uv_sphere_add(radius=0.009, location=(side_x + (sx * 0.01), y_off, handle_z + rz))
            r_eye = bpy.context.active_object
            r_eye.scale = (0.5, 1.0, 1.0)
            map_to_metal(r_eye)
            parts.append(r_eye)

    bpy.ops.mesh.primitive_torus_add(
        major_radius=0.18, 
        minor_radius=0.024, 
        location=(side_x + (sx * 0.05), 0, handle_z - 0.02)
    )
    rope = bpy.context.active_object
    rope.rotation_euler = (0, math.radians(90), 0)
    rope.scale = (0.75, 1.0, 0.9)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    map_to_rope(rope)
    parts.append(rope)


# --- F. Join into Single Optimized Mesh ---
bpy.ops.object.select_all(action='DESELECT')
for p in parts:
    p.select_set(True)

bpy.context.view_layer.objects.active = crate_body
bpy.ops.object.join()
final_crate = bpy.context.active_object
final_crate.name = "Pistol_Crate"

final_crate.location = (0, 0, 0)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# Smooth shading
if hasattr(final_crate.data, "use_auto_smooth"):
    final_crate.data.use_auto_smooth = True
for poly in final_crate.data.polygons:
    poly.use_smooth = True

print(f"Single-material Pistol Crate complete: {len(final_crate.data.polygons)} polygons.")


# 4. Preview Render
# ----------------------------------------------------
cam_data = bpy.data.cameras.new("BeautyCam")
cam_obj = bpy.data.objects.new("BeautyCam", cam_data)
bpy.context.collection.objects.link(cam_obj)
cam_obj.location = (2.4, -2.8, 2.1)
cam_obj.rotation_euler = (math.radians(57), 0, math.radians(40))
bpy.context.scene.camera = cam_obj

l_key = bpy.data.lights.new("L_Key", 'AREA')
l_key.energy = 450.0
l_key.size = 2.5
l_key.color = (1.0, 0.98, 0.95)
obj_key = bpy.data.objects.new("L_Key", l_key)
obj_key.location = (3.2, -2.6, 3.8)
bpy.context.collection.objects.link(obj_key)

l_fill = bpy.data.lights.new("L_Fill", 'AREA')
l_fill.energy = 160.0
l_fill.size = 3.0
l_fill.color = (0.85, 0.90, 1.0)
obj_fill = bpy.data.objects.new("L_Fill", l_fill)
obj_fill.location = (-2.8, -2.2, 2.4)
bpy.context.collection.objects.link(obj_fill)

l_rim = bpy.data.lights.new("L_Rim", 'AREA')
l_rim.energy = 320.0
l_rim.size = 2.0
l_rim.color = (1.0, 1.0, 1.0)
obj_rim = bpy.data.objects.new("L_Rim", l_rim)
obj_rim.location = (0.6, 3.2, 2.8)
bpy.context.collection.objects.link(obj_rim)

world = bpy.context.scene.world or bpy.data.worlds.new("World")
bpy.context.scene.world = world
world.use_nodes = True
bg = world.node_tree.nodes.get("Background")
if bg:
    bg.inputs["Color"].default_value = (0.14, 0.15, 0.17, 1.0)
    bg.inputs["Strength"].default_value = 0.9

bpy.context.scene.render.resolution_x = 1024
bpy.context.scene.render.resolution_y = 1024
preview_path = os.path.join(EXPORT_DIR, "preview.png")
bpy.context.scene.render.filepath = preview_path
bpy.ops.render.render(write_still=True)
print("Rendered preview to", preview_path)


# 5. Export FBX with EMBEDDED TEXTURES
# ----------------------------------------------------
bpy.ops.object.select_all(action='DESELECT')
final_crate.select_set(True)
bpy.context.view_layer.objects.active = final_crate

fbx_path = os.path.join(EXPORT_DIR, "pistol_crate.fbx")
# PATH_MODE='COPY' and EMBED_TEXTURES=True puts the texture inside the FBX binary!
bpy.ops.export_scene.fbx(
    filepath=fbx_path,
    use_selection=True,
    global_scale=1.0,
    apply_unit_scale=True,
    apply_scale_options='FBX_SCALE_ALL',
    axis_forward='-Z',
    axis_up='Y',
    path_mode='COPY',
    embed_textures=True
)
print("Exported embedded FBX to:", fbx_path)

result = {
    "status": "complete",
    "fbx": fbx_path,
    "preview": preview_path,
    "embedded_textures": True,
    "polys": len(final_crate.data.polygons)
}
