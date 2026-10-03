# Godot Dressup

A 3D dress-up and character customization test project for **Godot 4.7**
(Forward+, Jolt Physics).

- Toon-shaded character, lit only by ambient light, with crisp pixel-art textures
- Realistic skin tones with an undertone slider, tintable hair and clothing
- Clothing on its own rigs, retargeted to the body at runtime
- Per-garment hide masks, baked automatically, so skin never pokes through clothes
- Body shape sliders, expressions, automatic blinking and clothing-dependent shape keys
- Idle, body poses and independent arm poses, plus a stride-matched walk
- Camera that focuses on whichever section of the menu you hover
- Head and eyes that can follow the camera
- A walkable bedroom stage to try the outfit on the move

## Getting started

1. Open the project in Godot 4.7 or newer.
2. Run it (F5). Character creation opens in the dressing room.
3. Press **Play** to walk around the bedroom. Use WASD or the left stick to
   move, right-drag to orbit and the mouse wheel to zoom.

## Adding clothing

1. Model the garment on the same armature as the doll and export it as a
   `.glb` into `outfits/<slot>/<item_name>/`.
2. Create an `OutfitItem` resource next to it. Set its `scene`, `slot` and
   **Hide Mask Body** (`characters/mannequin/doll_hide_mask_body.tres`).
3. Click **Bake Hide Mask** in the Inspector. If skin still pokes through,
   raise **Hide Distance** and bake again, or paint the PNG by hand
   (white = hidden).
4. Add the item to `outfits/outfit_catalog.tres`.

## Documentation

- [docs/code_map.md](docs/code_map.md) covers the folder layout, the scenes, how the
  systems talk to each other, and every script's signals and functions,
  linked to the exact line.
- Each script carries `##` doc comments. You can read them in the editor
  under **Help → Search Help** by class name, e.g. `Wardrobe`.

## Conventions

The project follows the
[GDScript style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html)
and the
[project organization](https://docs.godotengine.org/en/stable/tutorials/best_practices/project_organization.html)
best practices:

- Folders are organized by feature: a scene sits next to its script and the
  assets only it uses.
- Files and folders are `snake_case`; nodes and `class_name`s are
  `PascalCase`.
- Code is statically typed. The project warns on untyped declarations.
- Nodes call down and signal up. `main.gd` is the only place the UI and the
  3D world are wired together.
