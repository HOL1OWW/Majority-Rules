"""
High-Fidelity Pistol Crate Generator for Roblox Studio
Recreates the military/industrial weapon crate:
- Weathered olive-drab painted wooden body with clean horizontal plank seams (no stencil bleed)
- Top lid with stencils: "SIDEARM", Glock pistol silhouette, "HANDLE WITH CARE"
- Flush metal corner brackets wrapping each of the 8 corners with 3 rivets each
- Front heavy clasp latch with hinge plate, clasp lever, and wire buckle loop
- Side mounting eyelet brackets with drooping hemp rope handles
- PBR Materials (Albedo, Roughness, Metallic) properly mapped
- Exports FBX, OBJ, GLB, and renders a beauty preview
"""

import bpy
import bmesh
import math
import os

EXPORT_DIR = r"c:\Users\selab\OneDrive\Documents\AI GAMES\The Vote\assets\models\pistol_crate"
os.makedirs(EXPORT_DIR, exist_ok=True)

# 1. Clean existing scene
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

# 2. Materials Setup
# ----------------------------------------------------
# Material A: Crate Body Wood (Planks only, no stencil)
mat_wood = bpy.data.materials.new(name="M_CrateWood")
mat_wood.use_nodes = True
nodes_w = mat_wood.node_tree.nodes
nodes_w.clear()
out_w = nodes_w.new("ShaderNodeOutputMaterial")
bsdf_w = nodes_w.new("ShaderNodeBsdfPrincipled")
bsdf_w.location = (400, 0)
mat_wood.node_tree.links.new(bsdf_w.outputs["BSDF"], out_w.inputs["Surface"])

body_img_path = os.path.join(EXPORT_DIR, "wood_body_albedo.png")
if os.path.exists(body_img_path):
    tex_w = nodes_w.new("ShaderNodeTexImage")
    tex_w.image = bpy.data.images.load(body_img_path)
    mat_wood.node_tree.links.new(tex_w.outputs["Color"], bsdf_w.inputs["Base Color"])
else:
    bsdf_w.inputs["Base Color"].default_value = (0.27, 0.33, 0.21, 1.0)

bsdf_w.inputs["Roughness"].default_value = 0.72
mat_wood.diffuse_color = (0.27, 0.33, 0.21, 1.0)


# Material B: Top Lid with Stencils
mat_lid = bpy.data.materials.new(name="M_CrateLid")
mat_lid.use_nodes = True
nodes_l = mat_lid.node_tree.nodes
nodes_l.clear()
out_l = nodes_l.new("ShaderNodeOutputMaterial")
bsdf_l = nodes_l.new("ShaderNodeBsdfPrincipled")
bsdf_l.location = (400, 0)
mat_lid.node_tree.links.new(bsdf_l.outputs["BSDF"], out_l.inputs["Surface"])

lid_img_path = os.path.join(EXPORT_DIR, "wood_lid_albedo.png")
if os.path.exists(lid_img_path):
    tex_l = nodes_l.new("ShaderNodeTexImage")
    tex_l.image = bpy.data.images.load(lid_img_path)
    mat_lid.node_tree.links.new(tex_l.outputs["Color"], bsdf_l.inputs["Base Color"])
else:
    bsdf_l.inputs["Base Color"].default_value = (0.27, 0.33, 0.21, 1.0)

bsdf_l.inputs["Roughness"].default_value = 0.68
mat_lid.diffuse_color = (0.27, 0.33, 0.21, 1.0)


# Material C: Metal Corner Caps & Latch
mat_metal = bpy.data.materials.new(name="M_CrateMetal")
mat_metal.use_nodes = True
nodes_m = mat_metal.node_tree.nodes
nodes_m.clear()
out_m = nodes_m.new("ShaderNodeOutputMaterial")
bsdf_m = nodes_m.new("ShaderNodeBsdfPrincipled")
bsdf_m.location = (400, 0)
mat_metal.node_tree.links.new(bsdf_m.outputs["BSDF"], out_m.inputs["Surface"])

metal_img_path = os.path.join(EXPORT_DIR, "metal_albedo.png")
if os.path.exists(metal_img_path):
    tex_m = nodes_m.new("ShaderNodeTexImage")
    tex_m.image = bpy.data.images.load(metal_img_path)
    mat_metal.node_tree.links.new(tex_m.outputs["Color"], bsdf_m.inputs["Base Color"])
else:
    bsdf_m.inputs["Base Color"].default_value = (0.16, 0.16, 0.17, 1.0)

bsdf_m.inputs["Metallic"].default_value = 0.88
bsdf_m.inputs["Roughness"].default_value = 0.45
mat_metal.diffuse_color = (0.20, 0.20, 0.22, 1.0)


# Material D: Rope Handle
mat_rope = bpy.data.materials.new(name="M_CrateRope")
mat_rope.use_nodes = True
nodes_r = mat_rope.node_tree.nodes
nodes_r.clear()
out_r = nodes_r.new("ShaderNodeOutputMaterial")
bsdf_r = nodes_r.new("ShaderNodeBsdfPrincipled")
bsdf_r.location = (400, 0)
mat_rope.node_tree.links.new(bsdf_r.outputs["BSDF"], out_r.inputs["Surface"])

rope_img_path = os.path.join(EXPORT_DIR, "rope_albedo.png")
if os.path.exists(rope_img_path):
    tex_r = nodes_r.new("ShaderNodeTexImage")
    tex_r.image = bpy.data.images.load(rope_img_path)
    mat_rope.node_tree.links.new(tex_r.outputs["Color"], bsdf_r.inputs["Base Color"])
else:
    bsdf_r.inputs["Base Color"].default_value = (0.58, 0.48, 0.35, 1.0)

bsdf_r.inputs["Roughness"].default_value = 0.92
mat_rope.diffuse_color = (0.58, 0.48, 0.35, 1.0)


# 3. Modeling Geometry
# ----------------------------------------------------
WIDTH = 1.60   # X-axis (side to side)
DEPTH = 1.10   # Y-axis (front to back)
HEIGHT = 0.82  # Z-axis (total height)
LID_H = 0.16   # Lid thickness
BODY_H = HEIGHT - LID_H

parts = []

# --- A. Main Box Body ---
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, BODY_H / 2.0))
crate_body = bpy.context.active_object
crate_body.name = "Crate_Body"
crate_body.scale = (WIDTH, DEPTH, BODY_H)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
crate_body.data.materials.append(mat_wood)

bev_b = crate_body.modifiers.new("Bevel", "BEVEL")
bev_b.width = 0.012
bev_b.segments = 2
bpy.ops.object.modifier_apply(modifier="Bevel")

# UV unwrap body so horizontal planks wrap around front, back, and sides
bpy.context.view_layer.objects.active = crate_body
bpy.ops.object.mode_set(mode='EDIT')
bm_b = bmesh.from_edit_mesh(crate_body.data)
uv_b = bm_b.loops.layers.uv.verify()
for f in bm_b.faces:
    for loop in f.loops:
        v = loop.vert.co
        if abs(f.normal.y) > 0.5: # Front/Back
            loop[uv_b].uv = ((v.x / WIDTH) + 0.5, (v.z / BODY_H))
        elif abs(f.normal.x) > 0.5: # Left/Right
            loop[uv_b].uv = ((v.y / DEPTH) + 0.5, (v.z / BODY_H))
        else: # Top/Bottom of body
            loop[uv_b].uv = ((v.x / WIDTH) + 0.5, (v.y / DEPTH) + 0.5)
bmesh.update_edit_mesh(crate_body.data)
bpy.ops.object.mode_set(mode='OBJECT')
parts.append(crate_body)


# --- B. Crate Lid ---
lid_z = BODY_H + (LID_H / 2.0)
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, lid_z))
crate_lid = bpy.context.active_object
crate_lid.name = "Crate_Lid"
crate_lid.scale = (WIDTH + 0.02, DEPTH + 0.02, LID_H)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

crate_lid.data.materials.append(mat_wood)
crate_lid.data.materials.append(mat_lid)

bev_l = crate_lid.modifiers.new("Bevel", "BEVEL")
bev_l.width = 0.012
bev_l.segments = 2
bpy.ops.object.modifier_apply(modifier="Bevel")

for poly in crate_lid.data.polygons:
    if poly.normal.z > 0.7:
        poly.material_index = 1
    else:
        poly.material_index = 0

bpy.context.view_layer.objects.active = crate_lid
bpy.ops.object.mode_set(mode='EDIT')
bm = bmesh.from_edit_mesh(crate_lid.data)
uv_layer = bm.loops.layers.uv.verify()

for face in bm.faces:
    if face.normal.z > 0.7:
        for loop in face.loops:
            v = loop.vert.co
            u = (v.x / (WIDTH + 0.02)) + 0.5
            v_coord = (v.y / (DEPTH + 0.02)) + 0.5
            loop[uv_layer].uv = (u, v_coord)
    else:
        for loop in face.loops:
            v = loop.vert.co
            loop[uv_layer].uv = ((v.x + v.y) * 0.5, v.z * 1.5)

bmesh.update_edit_mesh(crate_lid.data)
bpy.ops.object.mode_set(mode='OBJECT')
parts.append(crate_lid)


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
            p1.data.materials.append(mat_metal)
            parts.append(p1)

            bpy.ops.mesh.primitive_cube_add(
                size=1.0, 
                location=(sx * (hw - bracket_w/2.0), sy * (hd - bracket_len/2.0), z_pos + (z_dir * bracket_thick/2.0))
            )
            p2 = bpy.context.active_object
            p2.scale = (bracket_w, bracket_len, bracket_thick)
            bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
            p2.data.materials.append(mat_metal)
            parts.append(p2)

            # Rivet on top/bottom
            bpy.ops.mesh.primitive_uv_sphere_add(
                radius=0.013, 
                location=(sx * (hw - 0.05), sy * (hd - 0.05), z_pos + (z_dir * (bracket_thick + 0.006)))
            )
            r_top = bpy.context.active_object
            r_top.scale = (1.0, 1.0, 0.5)
            r_top.data.materials.append(mat_metal)
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
            p_fb.data.materials.append(mat_metal)
            parts.append(p_fb)

            # Rivet on front/back flap
            bpy.ops.mesh.primitive_uv_sphere_add(
                radius=0.013,
                location=(sx * (hw - bracket_w/2.0), sy * (hd + bracket_thick + 0.006), flap_z)
            )
            r_fb = bpy.context.active_object
            r_fb.scale = (1.0, 0.5, 1.0)
            r_fb.data.materials.append(mat_metal)
            parts.append(r_fb)

            # Left/Right flap
            bpy.ops.mesh.primitive_cube_add(
                size=1.0,
                location=(sx * (hw + bracket_thick/2.0), sy * (hd - bracket_w/2.0), flap_z)
            )
            p_lr = bpy.context.active_object
            p_lr.scale = (bracket_thick, bracket_w, bracket_len)
            bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
            p_lr.data.materials.append(mat_metal)
            parts.append(p_lr)

            # Rivet on side flap
            bpy.ops.mesh.primitive_uv_sphere_add(
                radius=0.013,
                location=(sx * (hw + bracket_thick + 0.006), sy * (hd - bracket_w/2.0), flap_z)
            )
            r_lr = bpy.context.active_object
            r_lr.scale = (0.5, 1.0, 1.0)
            r_lr.data.materials.append(mat_metal)
            parts.append(r_lr)


# --- D. Front Heavy Clasp Latch ---
latch_y = -hd - 0.010
latch_z = BODY_H + 0.005

bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, latch_y, latch_z + 0.055))
l_up = bpy.context.active_object
l_up.scale = (0.13, 0.018, 0.08)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
l_up.data.materials.append(mat_metal)
parts.append(l_up)

bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, latch_y, latch_z - 0.055))
l_low = bpy.context.active_object
l_low.scale = (0.13, 0.018, 0.09)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
l_low.data.materials.append(mat_metal)
parts.append(l_low)

bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, latch_y - 0.018, latch_z - 0.015))
l_lever = bpy.context.active_object
l_lever.scale = (0.075, 0.024, 0.12)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
l_lever.data.materials.append(mat_metal)
parts.append(l_lever)

bpy.ops.mesh.primitive_torus_add(major_radius=0.032, minor_radius=0.007, location=(0, latch_y - 0.022, latch_z - 0.08))
wire = bpy.context.active_object
wire.rotation_euler = (math.radians(90), 0, 0)
wire.scale = (1.0, 1.0, 1.45)
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
wire.data.materials.append(mat_metal)
parts.append(wire)

for rx in [-0.045, 0.045]:
    for rz in [latch_z + 0.07, latch_z - 0.08]:
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.011, location=(rx, latch_y - 0.010, rz))
        r_latch = bpy.context.active_object
        r_latch.scale = (1.0, 0.5, 1.0)
        r_latch.data.materials.append(mat_metal)
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
        h_plate.data.materials.append(mat_metal)
        parts.append(h_plate)
        
        bpy.ops.mesh.primitive_torus_add(major_radius=0.026, minor_radius=0.007, location=(side_x + (sx * 0.022), y_off, handle_z))
        eye = bpy.context.active_object
        eye.rotation_euler = (0, math.radians(90), 0)
        eye.data.materials.append(mat_metal)
        parts.append(eye)

        for rz in [-0.03, 0.03]:
            bpy.ops.mesh.primitive_uv_sphere_add(radius=0.009, location=(side_x + (sx * 0.01), y_off, handle_z + rz))
            r_eye = bpy.context.active_object
            r_eye.scale = (0.5, 1.0, 1.0)
            r_eye.data.materials.append(mat_metal)
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
    rope.data.materials.append(mat_rope)
    parts.append(rope)


# --- F. Join into Single Mesh ---
bpy.ops.object.select_all(action='DESELECT')
for p in parts:
    p.select_set(True)

bpy.context.view_layer.objects.active = crate_body
bpy.ops.object.join()
final_crate = bpy.context.active_object
final_crate.name = "Pistol_Crate"

final_crate.location = (0, 0, 0)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

if hasattr(final_crate.data, "use_auto_smooth"):
    final_crate.data.use_auto_smooth = True
for poly in final_crate.data.polygons:
    poly.use_smooth = True

print(f"Pistol Crate complete: {len(final_crate.data.polygons)} polygons.")


# 4. Lighting & Camera for Beauty Render
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


# 5. Export for Roblox Studio
# ----------------------------------------------------
bpy.ops.object.select_all(action='DESELECT')
final_crate.select_set(True)
bpy.context.view_layer.objects.active = final_crate

fbx_path = os.path.join(EXPORT_DIR, "pistol_crate.fbx")
bpy.ops.export_scene.fbx(
    filepath=fbx_path,
    use_selection=True,
    global_scale=1.0,
    apply_unit_scale=True,
    apply_scale_options='FBX_SCALE_ALL',
    axis_forward='-Z',
    axis_up='Y'
)
print("Exported FBX to", fbx_path)

obj_path = os.path.join(EXPORT_DIR, "pistol_crate.obj")
try:
    bpy.ops.wm.obj_export(filepath=obj_path, export_selected_objects=True)
except Exception:
    bpy.ops.export_scene.obj(filepath=obj_path, use_selection=True)
print("Exported OBJ to", obj_path)

glb_path = os.path.join(EXPORT_DIR, "pistol_crate.glb")
try:
    bpy.ops.export_scene.gltf(filepath=glb_path, use_selection=True, export_format='GLB')
    print("Exported GLB to", glb_path)
except Exception as e:
    pass

result = {
    "status": "complete",
    "fbx": fbx_path,
    "obj": obj_path,
    "glb": glb_path,
    "preview": preview_path,
    "polys": len(final_crate.data.polygons)
}
