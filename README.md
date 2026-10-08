# Godot Dressup

A 3D dress-up and character customization test project for **Godot 4.7**
(Forward+, Jolt Physics).

- Toon-shaded character with hard, pale two-tone shading and a dithered edge, tinted by the ambient light, with crisp pixel-art textures
- Realistic skin tones with an undertone slider, tintable hair, eyes and clothing
- Mix-and-match hair: pick front and back pieces separately, one shared hair color
- Layered clothing (underwear, socks, clothes) and face decals such as blush
- Clothing on its own rigs, retargeted to the body at runtime
- Per-garment hide masks, baked automatically, so skin never pokes through clothes
- Body shape sliders, expressions, automatic blinking and clothing-dependent shape keys
- Idle, body poses and independent arm poses, plus a stride-matched walk, jog and sprint
  that blend by speed with their footfalls kept in step
- Camera that focuses on whichever section of the menu you hover
- Smooth, Skyrim-style stage camera: steer with the mouse while moving, orbit freely while standing
- Head and eyes that can follow the camera
- Dust kicked up behind the feet when jogging and sprinting
- Autosave plus named character presets (JSON, versioned, with backups)
- A walkable meadow with endless wind-swept grass and a day/night cycle (plus a bedroom stage)

## Getting started

1. Open the project in Godot 4.7 or newer.
2. Run it (F5). Character creation opens in the dressing room.
3. Press **Play** to walk around the meadow with a smooth third-person
   camera (in the style of Skyrim):

   | Input | Action |
   |---|---|
   | WASD / left stick | Move where the camera looks |
   | Shift / click the left stick | Jog |
   | Ctrl / right bumper | Sprint |
   | Mouse | Look; steers while moving, orbits freely while standing |
   | R / middle click | Toggle autorun (W or S cancels) |
   | Mouse wheel | Zoom |
   | Hold Alt | Show the cursor to use the panel; let go to look again |
   | Esc / click the world | Free the cursor until you click the world |

   The panel's Time of Day slider scrubs or pauses the day/night cycle.

## Saving

The game autosaves the player's look when you press Play and when you close
the window, and loads it on start. Character creation's Presets card saves
and loads named looks. Everything is JSON in `user://` (on Windows,
`%APPDATA%/Godot/app_userdata/Dressup`): saves in `saves/`, presets in
`presets/`.

To save new data, extend `SaveSection` (see `save/sections/player_section.gd`)
and add it to `SaveManager.SECTION_TYPES`; player attributes can go straight
into `SaveManager.current.player.stats`. Bump `SaveManager.VERSION` when a
section's layout changes and convert old data in its `from_dict()`. To ship
a preset, add a `CharacterAppearance` to the SaveManager scene's
**Builtin Presets**.

## Tuning the toon look

The character's shading settings (shade color, edge position, dither width
and dot size, light strength) are global shader parameters shared by every
toon material. Change them in **Project Settings → Globals → Shader
Globals** (the `toon_*` entries), or at runtime with
`RenderingServer.global_shader_parameter_set()`.

## Adding clothing

1. Model the garment on the same armature as the doll and export it as a
   `.glb` into `outfits/<slot>/<item_name>/` (e.g. `outfits/tops/school_top/`).
   Hair pieces go in `outfits/hair/front/<name>/` or `outfits/hair/back/<name>/`.
2. Create an `OutfitItem` resource next to it. Set its `scene`, `slot` and
   **Hide Mask Body** (`character/model/doll_hide_mask_body.tres`).
3. Set its **Layer**: 0 for underwear, 1 for regular clothes, 2 for
   outerwear. Items hide what they cover of worn items on lower layers.
4. Add the item to `outfits/outfit_catalog.tres`, then click **Bake Hide
   Masks** on the catalog. That bakes every item's body mask plus what each
   item hides of the items under it. If something still pokes through, raise
   the item's **Hide Distance** and bake again, or paint the PNG by hand
   (white = hidden).

## Where to export from Blender

| Export | Goes to |
|---|---|
| The doll | `character/model/doll.glb` |
| Animations | `character/animation/clips/<name>.glb` |
| Clothing | `outfits/<slot>/<item>/<item>.glb` |
| Hair | `outfits/hair/front/<name>/<name>.glb`, `outfits/hair/back/<name>/<name>.glb` |
| Face decals | `outfits/face/<name>/<name>.glb` |
| Handheld props | `outfits/handheld/<name>/<name>.glb` |

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
