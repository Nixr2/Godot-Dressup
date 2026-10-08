# Code Map

Where everything lives in the Dressup project: folders, scenes, how data
flows between them, and every script's signals and functions with links to
the exact line.

> Line numbers are accurate as of the commit that last updated this file. If
> a link lands a few lines off, the function has moved; search the file for
> its name.

## Folder layout

The project is organized **by feature**, following Godot's
[project organization](https://docs.godotengine.org/en/stable/tutorials/best_practices/project_organization.html)
guide: each scene sits next to its script and the assets only it uses.
Files and folders are `snake_case`; nodes and `class_name`s are `PascalCase`.

| Folder | Contents |
|---|---|
| `main/` | The entry scene. Wires the UI to the 3D world and swaps between character creation and a stage. |
| `character/` | The customizable doll (`mannequin.tscn`). `model/` holds the Blender export (`doll.glb`, its textures) and the data tied to it: skeleton profile, shape key rules, hide mask body. `materials/` has the skin and eye materials; `animation/` has the animation scripts, the clips (`clips/`) and the poses (`arm_poses/`, `body_poses/`). |
| `customization/` | The reusable customization systems, scripts only: `wardrobe/` (equipping, outfit items and catalogs, hide mask baking), `shape_keys/` (body sliders, expressions, blinking), `body/` (skin tone and hair/eye color) and the saved `CharacterAppearance`. |
| `outfits/` | Everything the Wardrobe can put on, one folder per item, grouped by slot: `tops/`, `bottoms/`, `underwear/`, `socks/`, `shoes/`, `hats/`, `face/` (decals such as blush) and `hair/` (`front/` and `back/` pieces, their shared `hair_material.tres` and `hair_catalog.tres`). Each item folder holds the `.glb`, its textures, its `OutfitItem` `.tres` and its baked hide masks. `outfit_catalog.tres` lists the clothes players can pick. |
| `inventory/` | The player's `Inventory` of owned clothing, saved with their data and used by the in-game phone. |
| `save/` | The save system: the `SaveManager` autoload (saves and presets as JSON in `user://`), `SaveGame` and its `SaveSection`s (`sections/`, e.g. the player's data). |
| `common/` | Building blocks shared by several features: the toon shaders and base materials (`toon/`), the day/night cycle and its sky (`day_night/`), the grass field (`grass/`), effects such as the running dust trail (`effects/`) and import scripts (`import/`). |
| `stages/` | 3D places: the `dressing_room/` (character creation) and the walkable stages (`meadow/`, the one Play opens; `bedroom/`; `playground/`), which share `walkable_stage.gd`. Shaders only one stage uses live in its folder. |
| `player/` | The playable character body and its third-person camera. |
| `ui/` | The character creation menu, the stage HUD, the in-game `phone_menu/` and the shared dreamy `theme/`. |
| `docs/` | This file. |
| `addons/` | Third-party editor plugins (currently empty). |

## Scenes

| Scene | Root script | Other scripts used |
|---|---|---|
| [main/main.tscn](../main/main.tscn) (main scene) | `main.gd` | Instances the dressing room and the customization menu. |
| [character/mannequin.tscn](../character/mannequin.tscn) | `Mannequin` | `Wardrobe`, `BodyCustomizer`, `ShapeKeyController`, `CharacterAnimator`, `LookAtController`, `HeldPropController` (one child node each). |
| [stages/dressing_room/dressing_room.tscn](../stages/dressing_room/dressing_room.tscn) | `DressingRoom` | `OrbitCamera` with its `CameraFocus` presets; instances the mannequin. |
| [stages/meadow/meadow.tscn](../stages/meadow/meadow.tscn) (opened by Play) | `WalkableStage` | `GrassField`, `DayNightCycle` driving the Sun and Moon lights and the sky; instances the player and the stage HUD. |
| [stages/bedroom/bedroom.tscn](../stages/bedroom/bedroom.tscn), [stages/playground/playground.tscn](../stages/playground/playground.tscn) | `WalkableStage` | Instance the player and the stage HUD. |
| [save/save_manager.tscn](../save/save_manager.tscn) (autoload `SaveManager`) | `SaveManager` | Lists the item catalogs used to restore saved items, and the built-in presets. |
| [player/player.tscn](../player/player.tscn) | `Player` | `ThirdPersonCamera`; instances the mannequin and the `DustTrail`. |
| [ui/customization_menu/customization_menu.tscn](../ui/customization_menu/customization_menu.tscn) | `CustomizationMenu` | |
| [ui/stage_hud/stage_hud.tscn](../ui/stage_hud/stage_hud.tscn) | `StageHud` | |
| [ui/phone_menu/phone_menu.tscn](../ui/phone_menu/phone_menu.tscn) | `PhoneMenu` | The in-game phone's wardrobe screen (instanced by the meadow). |

## How the pieces talk

Nodes follow Godot's **"call down, signal up"** rule: parents call methods on
their children, and children report changes with signals. `main.gd` is the
only place the UI and the 3D world are connected.

```text
CustomizationMenu ──signals──► main.gd ──calls──► Mannequin components
   (UI only)                  (wiring)            Wardrobe, BodyCustomizer,
       ▲                                          ShapeKeyController,
       └──── set_*() state ◄── main.gd ◄─signals── CharacterAnimator, LookAtController
```

- **Play:** `main.gd` reads the look with `Mannequin.get_appearance()`,
  removes character creation from the tree (keeping it in memory), dresses the
  new stage's mannequin with `WalkableStage.setup()`, then adds the stage. "Back" reverses this.
- **Clothing:** `Wardrobe.equip()` moves the garment's own skeleton under
  the `ClothingRig` (a `RetargetModifier3D`) so it follows the body, converts
  its materials to the toon shader and sends its hide mask to the skin shader.
- **Hide masks:** `OutfitItem.bake_hide_mask()` (the "Bake Hide Mask" button
  in the Inspector) runs `HideMaskBaker.bake()` and saves
  `<id>_hide_mask.png` next to the item. Items also hide what they cover of
  worn items on lower layers (`OutfitItem.layer`, e.g. a swimsuit under a
  shirt): `OutfitCatalog.bake_hide_masks()` (the catalog's "Bake Hide Masks"
  button) bakes every item's body mask plus `<under>_covered_by_<over>.png`
  for each overlapping pair, and the Wardrobe applies them to the lower
  item's materials.
- **Hair:** hair is split into front and back pieces, each an `OutfitItem` in
  the `HAIR_FRONT` / `HAIR_BACK` slots, listed in `outfits/hair/hair_catalog.tres`
  and shown in the Hair card. They share the `hair` tint group, so
  `BodyCustomizer.set_hair_color()` recolors every piece through
  `Wardrobe.set_group_tint()`.
- **Day/night:** `DayNightCycle` advances `time_of_day`, aims the Sun and Moon
  lights, and samples its gradients for the sky, sun and ambient colors. The
  character's toon shader takes its color from the ambient light, so the
  ambient gradient is what tints her; the Sun and Moon only add a pale shaded
  side. `WalkableStage` gives the HUD time controls when the stage
  has a node named `DayNightCycle`.
- **Saving:** `main.gd` loads the autosave on start and, when Play is
  pressed or the window closes, stores the look in
  `SaveManager.current.player` and calls `SaveManager.save_game()`. A save
  is a `SaveGame` made of `SaveSection`s, each converting its own data to
  JSON; to save something new, add a section class to
  `SaveManager.SECTION_TYPES`. Looks are stored with
  `CharacterAppearance.to_dict()` (items by id) and restored with
  `from_dict()`.
- **Presets:** the Presets card asks `main.gd` to save, load or delete; it
  calls `SaveManager.save_preset()` / `load_preset()` / `delete_preset()`
  and applies a loaded look with `Mannequin.apply_appearance()`.
- **Phone and inventory:** pressing `toggle_phone` makes the `Player` play
  its phone arm pose, stop and pause mouse look; when the phone is open it
  emits `phone_opened` and the `WalkableStage` fills its `PhoneMenu` from the
  player's `Inventory` (handed over in `setup()`) and slides it in. The menu's
  choices go to the player's `Wardrobe`. Its Camera tab calls
  `Player.set_selfie_mode()`: the `SelfieCamera` adds a `TwoBoneIK3D` and a
  hand `LookAtModifier3D` before the clothing rig, reaches the arm to the
  aimed spot and makes the head look into the lens; the phone's viewfinder
  renders from it live into its own SubViewport. Take Photo renders that
  view at 1080x1440 (`PhoneMenu.capture_photo()`) and saves it with
  `PhotoAlbum`. `main.gd` adds the clothes worn in
  character creation to the inventory on Play, and copies the in-game outfit
  back to character creation on Back.
- **Held props:** picking an arm pose makes `CharacterAnimator` emit
  `arm_pose_changed`; the `Mannequin` hands the pose's `HeldProp` to
  `HeldPropController.hold()`, which attaches the prop to the hand bone,
  shows it at `show_time`, plays its cues in time with the pose, from
  `look_time` steers the head and eyes to it (`look_target_changed` →
  `LookAtController.set_override_target()`) and, when the
  pose ends, plays its `release_animation` (closing the phone) before removing it.
- **Shape keys:** `ShapeKeyController` merges body sliders, expressions,
  clothing overrides and blinking into blend shape weights every frame that
  something changes.

## Resources (data types)

Custom `Resource` scripts hold data that is edited in the Inspector and saved
as `.tres` files:

| Type | Saved as | Purpose |
|---|---|---|
| `OutfitItem` | `outfits/**/<item>.tres` | One wearable piece (clothing, hair or decal): scene, slot, hide mask, tags, shape key overrides, tint. |
| `OutfitCatalog` | `outfits/outfit_catalog.tres` | Every item players can choose. |
| `Inventory` | Inside `PlayerSection` (saved as item ids) | The clothing the player owns. |
| `CharacterAppearance` | `character/default_appearance.tres`; saves and presets as JSON | A look. Converted to and from save data with `to_dict()` / `from_dict()`. |
| `HideMaskBody` | `character/model/doll_hide_mask_body.tres` | Which body and skin material hide masks are baked against. |
| `ShapeKeySet` / `ShapeKeyDefinition` | `character/model/doll_shape_keys.tres` | Shape key rules: categories, clothing conditions, driven keys, blinking. |
| `SkinTonePalette` | `customization/body/default_skin_tone_palette.tres` | Realistic skin tone gradient plus undertone shift. |
| `ArmPose` / `BodyPose` | `character/animation/arm_poses/`, `body_poses/` | Which animations a pose button plays; an arm pose can play once (`loop` off) and hold a prop. |
| `HeldProp` | Inside an arm pose, e.g. `take_out_phone.tres` | A prop held during an arm pose: its scene, hand bone and placement, when it appears, and its animation cues (e.g. flip the phone open at 0.85 s). |
| `CameraFocus` | Inside `dressing_room.tscn` | Camera framings (face, torso, legs, ...). |

## Shaders

| Shader | Used by | Purpose |
|---|---|---|
| [common/toon/toon.gdshader](../common/toon/toon.gdshader) | Character, hair, eyes and all clothing | Ambient-lit color with a pale, hard-edged two-tone shaded side and a dithered edge (settings in `toon_shading.gdshaderinc`), crisp pixel-art sampling, per-instance `tint` (optionally limited by a `tint_mask`, e.g. to the irises), and up to 8 clothing hide masks (`hide_masks`) on the skin. |
| [common/toon/toon_overlay.gdshader](../common/toon/toon_overlay.gdshader) | Face decals | Transparent version of the toon look, blended over the skin. |
| [common/toon/toon_shading.gdshaderinc](../common/toon/toon_shading.gdshaderinc) | Both toon shaders | Shared two-tone shading with a Bayer-dithered edge. Its settings are global shader parameters (`toon_shade_color`, `toon_shade_threshold`, `toon_dither_width`, `toon_dither_pixel_size`, `toon_shade_light_energy`), edited for every toon material at once in **Project Settings → Globals → Shader Globals**. |
| [common/grass/grass.gdshader](../common/grass/grass.gdshader) | Meadow grass (`GrassField`) | Wind and gusts, bending away from the player, root-to-tip shading. |
| [stages/meadow/meadow_ground.gdshader](../stages/meadow/meadow_ground.gdshader) | Meadow ground | Soft non-tiling green patches under the grass. |
| [common/day_night/day_night_sky.gdshader](../common/day_night/day_night_sky.gdshader) | Meadow sky | Gradient, sun and moon disks, clouds and stars; colors set by `DayNightCycle`. |
| [stages/playground/grid_floor.gdshader](../stages/playground/grid_floor.gdshader) | Playground floor | Procedural grid. |

# Script reference

Each script lists its **public API** (signals and functions other scripts
may use), followed by its engine callbacks and internal helpers (names
starting with `_`, private by convention).

## Entry point

### `main.gd`

[main/main.gd](../main/main.gd) · extends `Node`

Entry point. Wires the GUI to the 3D world (signals up, calls down) and swaps between character creation and a walkable stage.

**Engine callbacks:** [`_ready`](../main/main.gd#L18), [`_notification`](../main/main.gd#L60)

**Internal:** [`_sync_menu`](../main/main.gd#L72), [`_save_game`](../main/main.gd#L95), [`_refresh_presets`](../main/main.gd#L103), [`_update_shape_key_availability`](../main/main.gd#L109), [`_on_item_equipped`](../main/main.gd#L117), [`_on_item_unequipped`](../main/main.gd#L122), [`_on_preset_save_requested`](../main/main.gd#L126), [`_on_preset_load_requested`](../main/main.gd#L137), [`_on_play_requested`](../main/main.gd#L147), [`_on_stage_exit_requested`](../main/main.gd#L167)

## Character

### `ArmPose`

[character/animation/arm_pose.gd](../character/animation/arm_pose.gd) · extends `Resource`

An arm layer played on top of the full-body idle, e.g. "hand on hip".

### `BodyPose`

[character/animation/body_pose.gd](../character/animation/body_pose.gd) · extends `Resource`

A full-body pose or loop that replaces the idle as the character's base animation. Arm poses and walking still layer on top.

### `CharacterAnimator`

[character/animation/character_animator.gd](../character/animation/character_animator.gd) · extends `AnimationTree`

Plays the character's base animation (idle or a BodyPose), blends in stride-matched gaits (walk, then optional jog and sprint), and layers independent left/right arm poses on top.

| Signal | Line | Description |
|---|---|---|
| `arm_pose_changed` | [38](../character/animation/character_animator.gd#L38) | Emitted when `set_arm_pose` changes the arm pose (null = none). |

| Function | Line | Description |
|---|---|---|
| `set_move_speed()` | [150](../character/animation/character_animator.gd#L150) | Horizontal movement speed in m/s; drives the walk/jog blend and playback rate. |
| `set_gait_speeds()` | [159](../character/animation/character_animator.gd#L159) | Sets the movement speeds (m/s) at which each gait is fully blended in, slowest first: walk, then jog and sprint if present. |
| `set_body_pose()` | [166](../character/animation/character_animator.gd#L166) | Cross-fades the base animation to `pose`. |
| `get_body_pose()` | [175](../character/animation/character_animator.gd#L175) | Returns the active body pose, or null while idling. |
| `set_arm_pose()` | [180](../character/animation/character_animator.gd#L180) | Cross-fades the arms to `pose`. |
| `get_arm_pose()` | [188](../character/animation/character_animator.gd#L188) | Returns the active arm pose, or null when the arms follow the body. |
| `measure_stride_speed()` | [195](../character/animation/character_animator.gd#L195) | Measures how fast `animation`'s feet travel backward while touching the ground, in m/s: net distance / time over each contact. |
| `measure_contact_phase()` | [216](../character/animation/character_animator.gd#L216) | Where in `animation_name`'s cycle (0-1) the first contact bone touches down, or 0 if it never does. |

**Engine callbacks:** [`_ready`](../character/animation/character_animator.gd#L109), [`_process`](../character/animation/character_animator.gd#L131)

**Internal:** [`_update_gait`](../character/animation/character_animator.gd#L228), [`_get_gait_position`](../character/animation/character_animator.gd#L244), [`_get_cycle_rate`](../character/animation/character_animator.gd#L254), [`_add_gait`](../character/animation/character_animator.gd#L264), [`_request_arm`](../character/animation/character_animator.gd#L281), [`_build_tree`](../character/animation/character_animator.gd#L291), [`_add_transition`](../character/animation/character_animator.gd#L353), [`_collect_arm_inputs`](../character/animation/character_animator.gd#L374), [`_get_looping_animations`](../character/animation/character_animator.gd#L387), [`_gait_node`](../character/animation/character_animator.gd#L406), [`_animation_node`](../character/animation/character_animator.gd#L421), [`_step_toward`](../character/animation/character_animator.gd#L427), [`_sample_contact_bone`](../character/animation/character_animator.gd#L435), [`_find_contacts`](../character/animation/character_animator.gd#L451), [`_get_bone_chain`](../character/animation/character_animator.gd#L476), [`_index_bone_tracks`](../character/animation/character_animator.gd#L491), [`_sample_bone_transform`](../character/animation/character_animator.gd#L504), [`_bone_path`](../character/animation/character_animator.gd#L528), [`_merge_libraries`](../character/animation/character_animator.gd#L532), [`_retarget_library`](../character/animation/character_animator.gd#L546), [`_find_idle_animation`](../character/animation/character_animator.gd#L568)

### `HeldProp`

[character/animation/held_prop.gd](../character/animation/held_prop.gd) · extends `Resource`

A prop held in the hand during an ArmPose, such as a phone.

### `HeldPropController`

[character/animation/held_prop_controller.gd](../character/animation/held_prop_controller.gd) · extends `Node`

Puts an arm pose's HeldProp in the character's hand and plays the prop's animation cues in time with the pose.

| Signal | Line | Description |
|---|---|---|
| `look_target_changed` | [15](../character/animation/held_prop_controller.gd#L15) | Emitted with the point to look at once the prop should be looked at, and with null when it shouldn't be any more. |

| Function | Line | Description |
|---|---|---|
| `hold()` | [56](../character/animation/held_prop_controller.gd#L56) | Attaches `prop` to its bone and restarts its timeline. |
| `release()` | [83](../character/animation/held_prop_controller.gd#L83) | Removes the held prop, if any, after its release animation. |
| `get_prop_instance()` | [105](../character/animation/held_prop_controller.gd#L105) | Returns the held prop's scene instance, or null. |
| `get_look_target()` | [111](../character/animation/held_prop_controller.gd#L111) | Returns the point on the prop the character looks at, or null before its look time (or with no prop). |
| `get_look_offset()` | [117](../character/animation/held_prop_controller.gd#L117) | Returns the held prop's `HeldProp.look_offset` (e.g. |

**Engine callbacks:** [`_ready`](../character/animation/held_prop_controller.gd#L31), [`_process`](../character/animation/held_prop_controller.gd#L35)

**Internal:** [`_play`](../character/animation/held_prop_controller.gd#L123), [`_find_animation_player`](../character/animation/held_prop_controller.gd#L135), [`_convert_materials`](../character/animation/held_prop_controller.gd#L140)

### `LookAtController`

[character/animation/look_at_controller.gd](../character/animation/look_at_controller.gd) · extends `Node`

Makes a character's head and eyes follow a target (e.g. the camera).

| Function | Line | Description |
|---|---|---|
| `set_target()` | [40](../character/animation/look_at_controller.gd#L40) | Follows `target`. |
| `set_override_target()` | [48](../character/animation/look_at_controller.gd#L48) | Looks at `target` with head and eyes, whatever the follow toggles say, until called with null. |
| `set_head_follow()` | [55](../character/animation/look_at_controller.gd#L55) | Fades head following on or off. |
| `set_eyes_follow()` | [60](../character/animation/look_at_controller.gd#L60) | Fades eye following on or off. |

**Engine callbacks:** [`_ready`](../character/animation/look_at_controller.gd#L27), [`_process`](../character/animation/look_at_controller.gd#L32)

**Internal:** [`_point_modifiers`](../character/animation/look_at_controller.gd#L66), [`_get_look_target`](../character/animation/look_at_controller.gd#L74), [`_hold_current_point`](../character/animation/look_at_controller.gd#L80), [`_get_fade_anchor`](../character/animation/look_at_controller.gd#L86), [`_fade`](../character/animation/look_at_controller.gd#L95), [`_all_modifiers`](../character/animation/look_at_controller.gd#L102)

### `Mannequin`

[character/mannequin.gd](../character/mannequin.gd) · extends `Node3D`

Customizable base character: the Doll model plus its Wardrobe, BodyCustomizer, ShapeKeyController, CharacterAnimator, LookAtController and HeldPropController components.

| Function | Line | Description |
|---|---|---|
| `apply_appearance()` | [26](../character/mannequin.gd#L26) | Applies a saved look: colors, body shapes and worn items. |
| `get_appearance()` | [33](../character/mannequin.gd#L33) | Returns the current look as a new CharacterAppearance. |

**Engine callbacks:** [`_ready`](../character/mannequin.gd#L18)

**Internal:** [`_on_arm_pose_changed`](../character/mannequin.gd#L41)

## Customization module

### `BodyCustomizer`

[customization/body/body_customizer.gd](../customization/body/body_customizer.gd) · extends `Node`

Tints a character's skin, hair and eyes.

| Function | Line | Description |
|---|---|---|
| `set_skin_tone()` | [33](../customization/body/body_customizer.gd#L33) | Tints the skin with `palette`'s color for `tone` and `undertone`. |
| `set_hair_color()` | [40](../customization/body/body_customizer.gd#L40) | Tints the hair with `color`. |
| `set_eye_color()` | [46](../customization/body/body_customizer.gd#L46) | Tints the irises with `color`. |
| `apply_appearance()` | [52](../customization/body/body_customizer.gd#L52) | Applies the skin, hair and eye colors of `appearance`. |
| `write_to_appearance()` | [59](../customization/body/body_customizer.gd#L59) | Stores the current skin, hair and eye colors in `appearance`. |

**Internal:** [`_apply_tint`](../customization/body/body_customizer.gd#L66), [`_uses_material`](../customization/body/body_customizer.gd#L72)

### `SkinTonePalette`

[customization/body/skin_tone_palette.gd](../customization/body/skin_tone_palette.gd) · extends `Resource`

Maps a tone value (0 = lightest, 1 = deepest) and an undertone value (-1 = cool/rosy, 1 = warm/golden) to a realistic skin color.

| Function | Line | Description |
|---|---|---|
| `get_color()` | [18](../customization/body/skin_tone_palette.gd#L18) | Returns the skin color for `tone` (0-1) shifted by `undertone` (-1 to 1). |

### `CharacterAppearance`

[customization/character_appearance.gd](../customization/character_appearance.gd) · extends `Resource`

A saved look: body colors plus which OutfitItem is worn in each slot.

| Function | Line | Description |
|---|---|---|
| `to_dict()` | [24](../customization/character_appearance.gd#L24) | Returns this look as JSON-safe data: items by id, colors as hex strings. |
| `static from_dict()` | [48](../customization/character_appearance.gd#L48) | Builds a look from `to_dict` data. |

**Internal:** [`_get_float`](../customization/character_appearance.gd#L77), [`_get_color`](../customization/character_appearance.gd#L82)

### `ShapeKeyController`

[customization/shape_keys/shape_key_controller.gd](../customization/shape_keys/shape_key_controller.gd) · extends `Node`

Resolves body sliders, the active expression, clothing conditions and automatic blinking into final blend shape weights, then applies them by name to every mesh under `mesh_root`: body parts, hair and all equipped garments, so newly split body parts need no setup.

| Signal | Line | Description |
|---|---|---|
| `availability_changed` | [12](../customization/shape_keys/shape_key_controller.gd#L12) | Emitted when equipping or removing clothing changes which keys apply. |

| Function | Line | Description |
|---|---|---|
| `set_body_value()` | [52](../customization/shape_keys/shape_key_controller.gd#L52) | Sets a body shape slider, clamped to 0-1. |
| `get_body_value()` | [58](../customization/shape_keys/shape_key_controller.gd#L58) | Returns a body shape slider's value. |
| `set_expression()` | [63](../customization/shape_keys/shape_key_controller.gd#L63) | Blends to `key`'s expression. |
| `get_expression()` | [69](../customization/shape_keys/shape_key_controller.gd#L69) | Returns the active expression's key, or an empty key for neutral. |
| `set_auto_blink()` | [74](../customization/shape_keys/shape_key_controller.gd#L74) | Turns automatic blinking on or off. |
| `is_available()` | [81](../customization/shape_keys/shape_key_controller.gd#L81) | Whether `key`'s clothing condition is met. |
| `apply_appearance()` | [92](../customization/shape_keys/shape_key_controller.gd#L92) | Applies the body shape sliders of `appearance`. |
| `write_to_appearance()` | [98](../customization/shape_keys/shape_key_controller.gd#L98) | Stores the body shape sliders in `appearance`. |

**Engine callbacks:** [`_ready`](../customization/shape_keys/shape_key_controller.gd#L37), [`_process`](../customization/shape_keys/shape_key_controller.gd#L44)

**Internal:** [`_update_expression_weights`](../customization/shape_keys/shape_key_controller.gd#L102), [`_update_blink`](../customization/shape_keys/shape_key_controller.gd#L112), [`_schedule_next_blink`](../customization/shape_keys/shape_key_controller.gd#L127), [`_is_blink_blocked`](../customization/shape_keys/shape_key_controller.gd#L131), [`_get_blink_weight`](../customization/shape_keys/shape_key_controller.gd#L136), [`_resolve_weights`](../customization/shape_keys/shape_key_controller.gd#L142), [`_apply`](../customization/shape_keys/shape_key_controller.gd#L169), [`_on_wardrobe_changed`](../customization/shape_keys/shape_key_controller.gd#L185)

### `ShapeKeyDefinition`

[customization/shape_keys/shape_key_definition.gd](../customization/shape_keys/shape_key_definition.gd) · extends `Resource`

Describes one blend shape (shape key) and the rules for using it.

### `ShapeKeySet`

[customization/shape_keys/shape_key_set.gd](../customization/shape_keys/shape_key_set.gd) · extends `Resource`

All shape key rules for one base character.

| Function | Line | Description |
|---|---|---|
| `get_definition()` | [11](../customization/shape_keys/shape_key_set.gd#L11) | Returns the definition for `key`, or null if there is none. |
| `get_by_category()` | [19](../customization/shape_keys/shape_key_set.gd#L19) | Returns every definition in `category`, in list order. |

### `HideMaskBaker`

[customization/wardrobe/hide_mask_baker.gd](../customization/wardrobe/hide_mask_baker.gd) · extends `RefCounted`

Bakes what an OutfitItem covers into a black/white mask over the UVs of the surface beneath it: the body's skin, or a garment on a lower `OutfitItem.layer` (e.g. a swimsuit under a shirt).

| Function | Line | Description |
|---|---|---|
| `static bake()` | [28](../customization/wardrobe/hide_mask_baker.gd#L28) | Returns `item`'s body hide mask as an L8 image, white where skin is hidden. |
| `static bake_over()` | [35](../customization/wardrobe/hide_mask_baker.gd#L35) | Returns the mask of what `item` covers of `under`, over `under`'s UVs, as an L8 image. |
| `static save_mask()` | [41](../customization/wardrobe/hide_mask_baker.gd#L41) | Saves `image` as a PNG at `path`. |

**Internal:** [`_bake`](../customization/wardrobe/hide_mask_baker.gd#L58), [`_rasterize_triangle`](../customization/wardrobe/hide_mask_baker.gd#L96), [`_shrink_hidden`](../customization/wardrobe/hide_mask_baker.gd#L145), [`_pad_islands`](../customization/wardrobe/hide_mask_baker.gd#L168), [`_collect_triangles`](../customization/wardrobe/hide_mask_baker.gd#L191), [`_append_surface`](../customization/wardrobe/hide_mask_baker.gd#L212), [`_triangle_bounds`](../customization/wardrobe/hide_mask_baker.gd#L251), [`_transform_to`](../customization/wardrobe/hide_mask_baker.gd#L256), [`_TriangleGrid._init`](../customization/wardrobe/hide_mask_baker.gd#L281), [`_TriangleGrid.segment_hits`](../customization/wardrobe/hide_mask_baker.gd#L299), [`_TriangleGrid._cell_of`](../customization/wardrobe/hide_mask_baker.gd#L312), [`_TriangleGrid._segment_hits_triangle`](../customization/wardrobe/hide_mask_baker.gd#L316)

### `HideMaskBody`

[customization/wardrobe/hide_mask_body.gd](../customization/wardrobe/hide_mask_body.gd) · extends `Resource`

The body that OutfitItem hide masks are baked against.

### `OutfitCatalog`

[customization/wardrobe/outfit_catalog.gd](../customization/wardrobe/outfit_catalog.gd) · extends `Resource`

The list of every OutfitItem a player can choose from.

| Function | Line | Description |
|---|---|---|
| `get_items_for_slot()` | [11](../customization/wardrobe/outfit_catalog.gd#L11) | Returns every item that is worn in `slot`. |
| `find_item()` | [18](../customization/wardrobe/outfit_catalog.gd#L18) | Returns the item whose `OutfitItem.id` is `id`, or null. |
| `bake_hide_masks()` | [27](../customization/wardrobe/outfit_catalog.gd#L27) | Bakes every item's body hide mask, plus a covered mask for every pair of skinned items on different layers (what the higher one hides of the lower). |

### `OutfitItem`

[customization/wardrobe/outfit_item.gd](../customization/wardrobe/outfit_item.gd) · extends `Resource`

A single wearable piece of clothing or accessory.

| Function | Line | Description |
|---|---|---|
| `bake_hide_mask()` | [90](../customization/wardrobe/outfit_item.gd#L90) | Bakes `hide_mask` from the garment's shape and saves it as "<id>_hide_mask.png" next to this resource. |
| `bake_covered_mask()` | [101](../customization/wardrobe/outfit_item.gd#L101) | Bakes what `over` covers of this item into `covered_masks`, saved as "<id>_covered_by_<over id>.png" next to this resource. |
| `can_bake()` | [115](../customization/wardrobe/outfit_item.gd#L115) | Whether this item has what baking needs, reporting what's missing if not. |
| `get_mask_path()` | [126](../customization/wardrobe/outfit_item.gd#L126) | Path of this item's mask named "<id>_<suffix>.png", next to the resource. |

### `Wardrobe`

[customization/wardrobe/wardrobe.gd](../customization/wardrobe/wardrobe.gd) · extends `Node`

Equips, removes and recolors OutfitItems on a character.

| Signal | Line | Description |
|---|---|---|
| `item_equipped` | [16](../customization/wardrobe/wardrobe.gd#L16) |  |
| `item_unequipped` | [18](../customization/wardrobe/wardrobe.gd#L18) | Emitted after `item` is taken off. |

| Function | Line | Description |
|---|---|---|
| `equip()` | [50](../customization/wardrobe/wardrobe.gd#L50) | Puts `item` on, replacing whatever is worn in its slot. |
| `unequip()` | [75](../customization/wardrobe/wardrobe.gd#L75) | Takes off the item worn in `slot`, if any. |
| `get_equipped()` | [88](../customization/wardrobe/wardrobe.gd#L88) | Returns the item worn in `slot`, or null. |
| `get_equipped_items()` | [93](../customization/wardrobe/wardrobe.gd#L93) | Returns every worn item. |
| `get_equipped_meshes()` | [100](../customization/wardrobe/wardrobe.gd#L100) | Returns the meshes of every worn item. |
| `set_item_tint()` | [108](../customization/wardrobe/wardrobe.gd#L108) | Recolors the item worn in `slot`, if it is tintable. |
| `set_group_tint()` | [119](../customization/wardrobe/wardrobe.gd#L119) | Recolors every worn item in tint group `group` (see `OutfitItem.tint_group`), and items of that group equipped later. |
| `get_item_tint()` | [127](../customization/wardrobe/wardrobe.gd#L127) | Returns the tint of the item worn in `slot`. |
| `apply_appearance()` | [135](../customization/wardrobe/wardrobe.gd#L135) | Replaces everything worn with `appearance`'s items and tints. |
| `write_to_appearance()` | [144](../customization/wardrobe/wardrobe.gd#L144) | Stores the worn items and their tints in `appearance`. |

**Engine callbacks:** [`_ready`](../customization/wardrobe/wardrobe.gd#L42)

**Internal:** [`_update_hide_masks`](../customization/wardrobe/wardrobe.gd#L154), [`_set_hide_masks`](../customization/wardrobe/wardrobe.gd#L172), [`_get_toon_materials`](../customization/wardrobe/wardrobe.gd#L180), [`_attach_skinned`](../customization/wardrobe/wardrobe.gd#L192), [`_attach_rigid`](../customization/wardrobe/wardrobe.gd#L220), [`_convert_materials`](../customization/wardrobe/wardrobe.gd#L229), [`_apply_tint`](../customization/wardrobe/wardrobe.gd#L242), [`_create_toon_material`](../customization/wardrobe/wardrobe.gd#L247), [`_find_skeleton`](../customization/wardrobe/wardrobe.gd#L256), [`_shares_bones_with_rig`](../customization/wardrobe/wardrobe.gd#L263), [`_find_meshes`](../customization/wardrobe/wardrobe.gd#L271)

## Shared building blocks

### `DayNightCycle`

[common/day_night/day_night_cycle.gd](../common/day_night/day_night_cycle.gd) · extends `Node`

Drives a sun, a moon, the sky and the ambient light through a 24-hour day.

| Signal | Line | Description |
|---|---|---|
| `time_changed` | [19](../common/day_night/day_night_cycle.gd#L19) | Emitted when the in-game minute changes. |

| Function | Line | Description |
|---|---|---|
| `get_sun_height()` | [82](../common/day_night/day_night_cycle.gd#L82) | How far the sun is above the horizon, from -1 (midnight) to 1 (noon). |

**Engine callbacks:** [`_ready`](../common/day_night/day_night_cycle.gd#L55), [`_exit_tree`](../common/day_night/day_night_cycle.gd#L64), [`_process`](../common/day_night/day_night_cycle.gd#L71)

**Internal:** [`_apply`](../common/day_night/day_night_cycle.gd#L86), [`_point_light`](../common/day_night/day_night_cycle.gd#L133), [`_sample`](../common/day_night/day_night_cycle.gd#L138)

### `DustTrail`

[common/effects/dust_trail/dust_trail.gd](../common/effects/dust_trail/dust_trail.gd) · extends `GPUParticles3D`

Puffs of dust kicked up behind a running character.

| Function | Line | Description |
|---|---|---|
| `set_motion()` | [25](../common/effects/dust_trail/dust_trail.gd#L25) | Sets how much dust to kick up from the character's ground `speed`. |

**Engine callbacks:** [`_ready`](../common/effects/dust_trail/dust_trail.gd#L19)

### `GrassField`

[common/grass/grass_field.gd](../common/grass/grass_field.gd) · extends `Node3D`

Scatters short grass blades over a square area made of chunks.

**Engine callbacks:** [`_ready`](../common/grass/grass_field.gd#L74), [`_process`](../common/grass/grass_field.gd#L78)

**Internal:** [`_queue_rebuild`](../common/grass/grass_field.gd#L90), [`_rebuild`](../common/grass/grass_field.gd#L97), [`_recenter`](../common/grass/grass_field.gd#L132), [`_make_layout`](../common/grass/grass_field.gd#L144), [`_make_blade_mesh`](../common/grass/grass_field.gd#L168)

### `set_piece_import.gd`

[common/import/set_piece_import.gd](../common/import/set_piece_import.gd) · extends `EditorScenePostImport`

Post-import script for set pieces (rooms, props).

**Engine callbacks:** [`_post_import`](../common/import/set_piece_import.gd#L12)

**Internal:** [`_use_nearest_filtering`](../common/import/set_piece_import.gd#L18), [`_make_collision_two_sided`](../common/import/set_piece_import.gd#L29)

## Inventory

### `Inventory`

[inventory/inventory.gd](../inventory/inventory.gd) · extends `RefCounted`

The clothing the player owns, which they can put on in game (see PhoneMenu). Each item is owned at most once.

| Signal | Line | Description |
|---|---|---|
| `changed` | [9](../inventory/inventory.gd#L9) | Emitted when an item is added or removed. |

| Function | Line | Description |
|---|---|---|
| `get_items()` | [15](../inventory/inventory.gd#L15) | Returns every owned item, in the order they were added. |
| `get_items_for_slot()` | [20](../inventory/inventory.gd#L20) | Returns the owned items worn in `slot`. |
| `has()` | [26](../inventory/inventory.gd#L26) |  |
| `add()` | [31](../inventory/inventory.gd#L31) | Adds `item` if it isn't owned yet. |
| `add_all()` | [40](../inventory/inventory.gd#L40) | Adds every item in `items` that isn't owned yet. |
| `remove()` | [51](../inventory/inventory.gd#L51) | Removes `item`. |
| `to_ids()` | [60](../inventory/inventory.gd#L60) | Returns the owned items' ids, for saving. |
| `load_ids()` | [69](../inventory/inventory.gd#L69) | Replaces the owned items with those in `ids`; `find_item` turns an id into its OutfitItem (or null), and unknown ids are skipped. |

## Save system

### `SaveGame`

[save/save_game.gd](../save/save_game.gd) · extends `RefCounted`

Everything saved in one save slot: a set of SaveSections.

| Function | Line | Description |
|---|---|---|
| `get_section()` | [24](../save/save_game.gd#L24) | Returns the section named `key`, or null. |
| `add_section()` | [28](../save/save_game.gd#L28) |  |
| `to_dict()` | [33](../save/save_game.gd#L33) | Returns the whole save as JSON-safe data, stamped with `version`. |
| `load_dict()` | [41](../save/save_game.gd#L41) | Fills the sections from `to_dict` data. |

### `save_manager.gd`

[save/save_manager.gd](../save/save_manager.gd) · extends `Node`

Saves and loads the game and character creation presets (autoload "SaveManager").

| Signal | Line | Description |
|---|---|---|
| `game_saved` | [16](../save/save_manager.gd#L16) |  |
| `game_loaded` | [17](../save/save_manager.gd#L17) |  |
| `presets_changed` | [19](../save/save_manager.gd#L19) | Emitted when a user preset is saved or deleted. |

| Function | Line | Description |
|---|---|---|
| `new_game()` | [55](../save/save_manager.gd#L55) | Returns a new game with every section, the player owning `starting_inventory`. |
| `save_game()` | [65](../save/save_manager.gd#L65) | Writes `current` to `slot`. |
| `load_game()` | [77](../save/save_manager.gd#L77) | Replaces `current` with the game in `slot`. |
| `has_save()` | [88](../save/save_manager.gd#L88) |  |
| `delete_save()` | [92](../save/save_manager.gd#L92) |  |
| `get_save_slots()` | [97](../save/save_manager.gd#L97) | Returns the names of every saved slot. |
| `find_item()` | [102](../save/save_manager.gd#L102) | Returns the item with `id` from `item_catalogs`, or null. |
| `get_preset_names()` | [107](../save/save_manager.gd#L107) | Returns the names of the user's presets, sorted. |
| `get_builtin_preset_names()` | [118](../save/save_manager.gd#L118) | Returns the names of `builtin_presets`, sorted. |
| `is_builtin_preset()` | [124](../save/save_manager.gd#L124) |  |
| `save_preset()` | [130](../save/save_manager.gd#L130) | Saves `appearance` as a user preset, replacing one with the same name. |
| `load_preset()` | [143](../save/save_manager.gd#L143) | Returns the preset named `preset_name` (built-in or user), or null. |
| `delete_preset()` | [154](../save/save_manager.gd#L154) | Deletes a user preset. |

**Engine callbacks:** [`_ready`](../save/save_manager.gd#L46)

**Internal:** [`_slot_path`](../save/save_manager.gd#L163), [`_preset_path`](../save/save_manager.gd#L167), [`_write_json`](../save/save_manager.gd#L173), [`_read_json`](../save/save_manager.gd#L191), [`_delete_file`](../save/save_manager.gd#L202), [`_list_json_files`](../save/save_manager.gd#L211)

### `SaveSection`

[save/save_section.gd](../save/save_section.gd) · extends `RefCounted`

One independent part of a SaveGame, such as the player's data.

| Function | Line | Description |
|---|---|---|
| `get_key()` | [14](../save/save_section.gd#L14) | Unique name of this section in the save file. |
| `to_dict()` | [19](../save/save_section.gd#L19) | Returns this section's data as JSON-safe values. |
| `from_dict()` | [26](../save/save_section.gd#L26) | Restores this section from `to_dict` data written by save format `version`; convert older layouts here when the format changes. |

### `PlayerSection`

[save/sections/player_section.gd](../save/sections/player_section.gd) · extends `SaveSection`

The player's own data: their character's look, the clothing they own and their attributes.

| Function | Line | Description |
|---|---|---|
| `get_key()` | [18](../save/sections/player_section.gd#L18) |  |
| `to_dict()` | [22](../save/sections/player_section.gd#L22) |  |
| `from_dict()` | [33](../save/sections/player_section.gd#L33) |  |

## Stages

### `CameraFocus`

[stages/dressing_room/camera_focus.gd](../stages/dressing_room/camera_focus.gd) · extends `Resource`

A framing the dressing room camera can glide to, e.g. "face" or "torso".

### `DressingRoom`

[stages/dressing_room/dressing_room.gd](../stages/dressing_room/dressing_room.gd) · extends `Node3D`

3D stage that displays the character being customized. The character's head and eyes can follow the camera.

**Engine callbacks:** [`_ready`](../stages/dressing_room/dressing_room.gd#L10)

### `OrbitCamera`

[stages/dressing_room/orbit_camera.gd](../stages/dressing_room/orbit_camera.gd) · extends `Node3D`

Orbits a child Camera3D around a CameraFocus point on the character.

| Function | Line | Description |
|---|---|---|
| `focus()` | [67](../stages/dressing_room/orbit_camera.gd#L67) | Glides to the focus preset named `id`. |
| `reset_focus()` | [80](../stages/dressing_room/orbit_camera.gd#L80) | Glides back to `default_focus`. |
| `get_focus()` | [85](../stages/dressing_room/orbit_camera.gd#L85) | Returns the current focus preset's id. |
| `get_camera()` | [90](../stages/dressing_room/orbit_camera.gd#L90) | Returns the orbiting camera. |

**Engine callbacks:** [`_ready`](../stages/dressing_room/orbit_camera.gd#L34), [`_process`](../stages/dressing_room/orbit_camera.gd#L42), [`_unhandled_input`](../stages/dressing_room/orbit_camera.gd#L55)

**Internal:** [`_get_focus_point`](../stages/dressing_room/orbit_camera.gd#L94), [`_get_target_distance`](../stages/dressing_room/orbit_camera.gd#L104), [`_set_pitch`](../stages/dressing_room/orbit_camera.gd#L108), [`_snap`](../stages/dressing_room/orbit_camera.gd#L112)

### `WalkableStage`

[stages/walkable_stage.gd](../stages/walkable_stage.gd) · extends `Node3D`

A stage the customized character can walk around in.

| Signal | Line | Description |
|---|---|---|
| `exit_requested` | [13](../stages/walkable_stage.gd#L13) | Emitted when the player asks to return to character creation. |

| Function | Line | Description |
|---|---|---|
| `setup()` | [62](../stages/walkable_stage.gd#L62) | Dresses the player's character and gives the phone menu the clothes they own. |
| `get_player_appearance()` | [69](../stages/walkable_stage.gd#L69) | Returns the player character's current look. |

**Engine callbacks:** [`_ready`](../stages/walkable_stage.gd#L23)

**Internal:** [`_on_move_speed_changed`](../stages/walkable_stage.gd#L73), [`_on_jog_speed_changed`](../stages/walkable_stage.gd#L77), [`_on_sprint_speed_changed`](../stages/walkable_stage.gd#L81), [`_on_time_of_day_changed`](../stages/walkable_stage.gd#L85), [`_on_time_paused_toggled`](../stages/walkable_stage.gd#L89), [`_on_walk_playback_multiplier_changed`](../stages/walkable_stage.gd#L93), [`_on_phone_opened`](../stages/walkable_stage.gd#L97), [`_on_item_equipped`](../stages/walkable_stage.gd#L103), [`_on_item_unequipped`](../stages/walkable_stage.gd#L107), [`_on_camera_toggled`](../stages/walkable_stage.gd#L111), [`_take_photo`](../stages/walkable_stage.gd#L115)

## Player

### `PhotoAlbum`

[player/photo_album.gd](../player/photo_album.gd) · extends `RefCounted`

Saves photos taken with the in-game phone as PNGs in user://photos (on Windows, %APPDATA%/Godot/app_userdata/Dressup/photos).

| Function | Line | Description |
|---|---|---|
| `static save()` | [11](../player/photo_album.gd#L11) | Saves `image` with a timestamped name and returns its path, or an empty string if it couldn't be saved. |

### `Player`

[player/player.gd](../player/player.gd) · extends `CharacterBody3D`

Walks a customized Mannequin around, relative to the camera.

| Signal | Line | Description |
|---|---|---|
| `phone_opened` | [24](../player/player.gd#L24) | Emitted once the phone is out and open, ready for its menu. |
| `phone_closed` | [26](../player/player.gd#L26) | Emitted when the phone is put away. |

| Function | Line | Description |
|---|---|---|
| `take_out_phone()` | [126](../player/player.gd#L126) | Takes the phone out: plays `phone_pose`, stops the character and pauses mouse look. |
| `put_away_phone()` | [140](../player/player.gd#L140) | Puts the phone away and resumes mouse look. |
| `is_phone_out()` | [150](../player/player.gd#L150) |  |
| `set_selfie_mode()` | [156](../player/player.gd#L156) | Holds the phone out for a selfie with its front camera (only while the phone is out), or back in the phone pose. |
| `get_selfie_camera()` | [163](../player/player.gd#L163) | Returns the phone's front camera, for a viewfinder to render from. |
| `is_selfie_mode()` | [167](../player/player.gd#L167) |  |
| `set_wide_lens()` | [172](../player/player.gd#L172) | Switches the phone camera between its normal and wide (0.5x) lens. |
| `get_effective_move_speed()` | [183](../player/player.gd#L183) | Returns the speed the player walks at, in m/s, resolving `move_speed` = 0 to the walk's stride speed. |
| `get_effective_jog_speed()` | [193](../player/player.gd#L193) | Returns the speed the player jogs at, in m/s, resolving `jog_speed` = 0 to the jog's stride speed. |
| `get_effective_sprint_speed()` | [203](../player/player.gd#L203) | Returns the speed the player sprints at, in m/s, resolving `sprint_speed` = 0 to the sprint's stride speed. |

**Engine callbacks:** [`_ready`](../player/player.gd#L66), [`_input`](../player/player.gd#L72), [`_unhandled_input`](../player/player.gd#L81), [`_physics_process`](../player/player.gd#L90)

**Internal:** [`_on_phone_open_delay_elapsed`](../player/player.gd#L176), [`_update_gait_speeds`](../player/player.gd#L211)

### `SelfieCamera`

[player/selfie_camera.gd](../player/selfie_camera.gd) · extends `Camera3D`

The phone's front camera: while active, the character holds the phone out at arm's length, this camera sits on the phone looking back at them, and their head and eyes look into the lens. It doesn't take over the main view: a viewfinder (see PhoneMenu) renders from it.

| Function | Line | Description |
|---|---|---|
| `setup()` | [85](../player/selfie_camera.gd#L85) | Points this camera at `mannequin`'s skeleton. |
| `is_active()` | [90](../player/selfie_camera.gd#L90) |  |
| `set_wide_lens()` | [95](../player/selfie_camera.gd#L95) | Switches between the normal and the wide (0.5x) lens. |
| `is_wide_lens()` | [99](../player/selfie_camera.gd#L99) |  |
| `activate()` | [104](../player/selfie_camera.gd#L104) | Turns the selfie camera on or off. |

**Engine callbacks:** [`_ready`](../player/selfie_camera.gd#L76), [`_unhandled_input`](../player/selfie_camera.gd#L122), [`_process`](../player/selfie_camera.gd#L136)

**Internal:** [`_update_markers`](../player/selfie_camera.gd#L152), [`_place_lens`](../player/selfie_camera.gd#L170), [`_create_modifiers`](../player/selfie_camera.gd#L187), [`_free_modifiers`](../player/selfie_camera.gd#L230), [`_add_marker`](../player/selfie_camera.gd#L241), [`_bone_position`](../player/selfie_camera.gd#L249)

### `ThirdPersonCamera`

[player/third_person_camera.gd](../player/third_person_camera.gd) · extends `Node3D`

Smooth, cinematic third-person camera (in the style of Skyrim) orbiting a point on its parent on a SpringArm3D.

| Function | Line | Description |
|---|---|---|
| `set_motion()` | [138](../player/third_person_camera.gd#L138) | Tells the camera how the character moves, for its framing: over the shoulder while moving, a wider view while jogging, wider still sprinting. |
| `get_camera()` | [148](../player/third_person_camera.gd#L148) | Returns the camera at the end of the spring arm. |
| `set_look_enabled()` | [155](../player/third_person_camera.gd#L155) | Pauses or resumes mouse look. |
| `is_mouse_captured()` | [161](../player/third_person_camera.gd#L161) |  |
| `set_mouse_captured()` | [165](../player/third_person_camera.gd#L165) |  |

**Engine callbacks:** [`_ready`](../player/third_person_camera.gd#L66), [`_exit_tree`](../player/third_person_camera.gd#L80), [`_process`](../player/third_person_camera.gd#L86), [`_unhandled_input`](../player/third_person_camera.gd#L99), [`_input`](../player/third_person_camera.gd#L128)

**Internal:** [`_get_pivot`](../player/third_person_camera.gd#L171), [`_apply_rotation`](../player/third_person_camera.gd#L175), [`_smooth`](../player/third_person_camera.gd#L180)

## User interface

### `CustomizationMenu`

[ui/customization_menu/customization_menu.gd](../ui/customization_menu/customization_menu.gd) · extends `Control`

Character creation UI: appearance cards on the left, the wardrobe on the right.

| Signal | Line | Description |
|---|---|---|
| `skin_tone_changed` | [16](../ui/customization_menu/customization_menu.gd#L16) | Emitted when either skin slider changes. |
| `hair_color_changed` | [18](../ui/customization_menu/customization_menu.gd#L18) | Emitted when a hair swatch or the custom hair color is picked. |
| `eye_color_changed` | [20](../ui/customization_menu/customization_menu.gd#L20) | Emitted when an eye swatch or the custom eye color is picked. |
| `item_selected` | [22](../ui/customization_menu/customization_menu.gd#L22) | Emitted when an item button is pressed. |
| `slot_cleared` | [24](../ui/customization_menu/customization_menu.gd#L24) | Emitted when a slot's "None" button is pressed. |
| `item_tint_changed` | [26](../ui/customization_menu/customization_menu.gd#L26) | Emitted when a slot's color picker changes. |
| `body_shape_changed` | [28](../ui/customization_menu/customization_menu.gd#L28) | Emitted when a body shape slider changes. |
| `expression_selected` | [30](../ui/customization_menu/customization_menu.gd#L30) | Emitted when an expression button is pressed. |
| `auto_blink_toggled` | [32](../ui/customization_menu/customization_menu.gd#L32) | Emitted when the auto blink checkbox is toggled. |
| `arm_pose_selected` | [34](../ui/customization_menu/customization_menu.gd#L34) | Emitted when an arm pose button is pressed. |
| `body_pose_selected` | [36](../ui/customization_menu/customization_menu.gd#L36) | Emitted when a body pose button is pressed. |
| `play_requested` | [38](../ui/customization_menu/customization_menu.gd#L38) | Emitted when the Play button is pressed. |
| `focus_requested` | [40](../ui/customization_menu/customization_menu.gd#L40) | Emitted with the camera framing of a newly hovered section. |
| `head_follow_toggled` | [42](../ui/customization_menu/customization_menu.gd#L42) | Emitted when the head follow chip is toggled. |
| `eyes_follow_toggled` | [44](../ui/customization_menu/customization_menu.gd#L44) | Emitted when the eyes follow chip is toggled. |
| `preset_save_requested` | [46](../ui/customization_menu/customization_menu.gd#L46) | Emitted when the player saves the current look as a preset. |
| `preset_load_requested` | [48](../ui/customization_menu/customization_menu.gd#L48) | Emitted when the player picks a preset to load. |
| `preset_delete_requested` | [50](../ui/customization_menu/customization_menu.gd#L50) | Emitted when the player confirms deleting one of their presets. |

| Function | Line | Description |
|---|---|---|
| `set_presets()` | [185](../ui/customization_menu/customization_menu.gd#L185) | Lists the presets: `builtin_names` can only be loaded, the player's own `user_names` can also be deleted. |
| `show_preset_saved()` | [195](../ui/customization_menu/customization_menu.gd#L195) | Confirms that `preset_name` was saved and clears the name field. |
| `show_preset_status()` | [203](../ui/customization_menu/customization_menu.gd#L203) | Shows a short note under the preset name field, e.g. |
| `set_body_values()` | [209](../ui/customization_menu/customization_menu.gd#L209) | Shows the current skin tone, undertone, hair and eye colors. |
| `set_follow_state()` | [217](../ui/customization_menu/customization_menu.gd#L217) | Shows whether the head and eyes follow the camera. |
| `set_arm_poses()` | [223](../ui/customization_menu/customization_menu.gd#L223) | Lists `poses` as arm pose buttons, after "Default". |
| `set_body_poses()` | [233](../ui/customization_menu/customization_menu.gd#L233) | Lists `poses` as body pose buttons, after "Idle". |
| `set_body_shape_values()` | [243](../ui/customization_menu/customization_menu.gd#L243) | Shows the current body shape sliders and auto blink state. |
| `set_body_shape_available()` | [250](../ui/customization_menu/customization_menu.gd#L250) | Disables a body shape slider whose clothing condition isn't met. |
| `set_slot_state()` | [262](../ui/customization_menu/customization_menu.gd#L262) | Shows which item is worn in `slot` and its tint. |

**Engine callbacks:** [`_ready`](../ui/customization_menu/customization_menu.gd#L150), [`_process`](../ui/customization_menu/customization_menu.gd#L179)

**Internal:** [`_update_hover`](../ui/customization_menu/customization_menu.gd#L278), [`_focus_card`](../ui/customization_menu/customization_menu.gd#L287), [`_is_hover_blocked`](../ui/customization_menu/customization_menu.gd#L299), [`_find_hovered_card`](../ui/customization_menu/customization_menu.gd#L310), [`_build_swatches`](../ui/customization_menu/customization_menu.gd#L322), [`_build_hair_styles`](../ui/customization_menu/customization_menu.gd#L344), [`_build_body_shape_sliders`](../ui/customization_menu/customization_menu.gd#L358), [`_build_expression_buttons`](../ui/customization_menu/customization_menu.gd#L373), [`_add_toggle_button`](../ui/customization_menu/customization_menu.gd#L384), [`_build_slot_list`](../ui/customization_menu/customization_menu.gd#L397), [`_clear`](../ui/customization_menu/customization_menu.gd#L436), [`_on_skin_slider_changed`](../ui/customization_menu/customization_menu.gd#L442), [`_on_body_shape_slider_changed`](../ui/customization_menu/customization_menu.gd#L446), [`_on_swatch_pressed`](../ui/customization_menu/customization_menu.gd#L450), [`_on_tint_picker_changed`](../ui/customization_menu/customization_menu.gd#L455), [`_add_preset_row`](../ui/customization_menu/customization_menu.gd#L459), [`_on_preset_name_changed`](../ui/customization_menu/customization_menu.gd#L478), [`_on_save_preset_pressed`](../ui/customization_menu/customization_menu.gd#L483), [`_on_delete_preset_pressed`](../ui/customization_menu/customization_menu.gd#L491), [`_disarm_delete_button`](../ui/customization_menu/customization_menu.gd#L500)

### `PhoneMenu`

[ui/phone_menu/phone_menu.gd](../ui/phone_menu/phone_menu.gd) · extends `Control`

The in-game phone, with two tabs: Wardrobe lists the clothing in the player's Inventory by slot to put on or take off, and Camera shows the phone's front camera live on its screen and takes photos with it (see SelfieCamera).

| Signal | Line | Description |
|---|---|---|
| `item_selected` | [15](../ui/phone_menu/phone_menu.gd#L15) | Emitted when the player picks an item to wear. |
| `slot_cleared` | [17](../ui/phone_menu/phone_menu.gd#L17) | Emitted when the player takes off what's worn in `slot`. |
| `close_requested` | [19](../ui/phone_menu/phone_menu.gd#L19) | Emitted when the player asks to put the phone away. |
| `camera_toggled` | [21](../ui/phone_menu/phone_menu.gd#L21) | Emitted when the Camera tab is opened (true) or left (false). |
| `photo_requested` | [23](../ui/phone_menu/phone_menu.gd#L23) | Emitted when the player presses Take Photo. |
| `wide_lens_toggled` | [25](../ui/phone_menu/phone_menu.gd#L25) | Emitted when the wide (0.5x) lens is switched on or off. |

| Function | Line | Description |
|---|---|---|
| `show_inventory()` | [92](../ui/phone_menu/phone_menu.gd#L92) | Lists the items in `inventory`, marking what `wardrobe` has on. |
| `set_equipped()` | [107](../ui/phone_menu/phone_menu.gd#L107) | Marks `item` as worn in `slot` (null = nothing worn). |
| `open()` | [117](../ui/phone_menu/phone_menu.gd#L117) | Slides the phone up into view, on the Wardrobe tab. |
| `close()` | [126](../ui/phone_menu/phone_menu.gd#L126) | Slides the phone down out of view, then hides it. |
| `set_preview_camera()` | [136](../ui/phone_menu/phone_menu.gd#L136) | Sets the camera the viewfinder shows (e.g. |
| `capture_photo()` | [142](../ui/phone_menu/phone_menu.gd#L142) | Renders the viewfinder's view at `PHOTO_SIZE` and returns it, flashing the viewfinder. |
| `flash()` | [155](../ui/phone_menu/phone_menu.gd#L155) | Shows a white flash over the viewfinder, like a camera flash. |
| `show_photo_status()` | [164](../ui/phone_menu/phone_menu.gd#L164) | Shows where the last photo was saved (or why it wasn't). |

**Engine callbacks:** [`_ready`](../ui/phone_menu/phone_menu.gd#L71), [`_process`](../ui/phone_menu/phone_menu.gd#L84)

**Internal:** [`_show_tab`](../ui/phone_menu/phone_menu.gd#L168), [`_set_tab_state`](../ui/phone_menu/phone_menu.gd#L175), [`_slide_to`](../ui/phone_menu/phone_menu.gd#L183), [`_get_rest_y`](../ui/phone_menu/phone_menu.gd#L196), [`_add_slot_card`](../ui/phone_menu/phone_menu.gd#L200), [`_add_button`](../ui/phone_menu/phone_menu.gd#L219)

### `StageHud`

[ui/stage_hud/stage_hud.gd](../ui/stage_hud/stage_hud.gd) · extends `Control`

Back button plus live tuning for walk, jog and sprint speed and stride matching, and time-of-day controls on stages with a DayNightCycle.

| Signal | Line | Description |
|---|---|---|
| `back_pressed` | [7](../ui/stage_hud/stage_hud.gd#L7) | Emitted when the back button is pressed. |
| `move_speed_changed` | [9](../ui/stage_hud/stage_hud.gd#L9) | Emitted when the move speed slider changes, in m/s. |
| `jog_speed_changed` | [11](../ui/stage_hud/stage_hud.gd#L11) | Emitted when the jog speed slider changes, in m/s. |
| `sprint_speed_changed` | [13](../ui/stage_hud/stage_hud.gd#L13) | Emitted when the sprint speed slider changes, in m/s. |
| `walk_playback_multiplier_changed` | [15](../ui/stage_hud/stage_hud.gd#L15) | Emitted when the walk playback slider changes. |
| `time_of_day_changed` | [17](../ui/stage_hud/stage_hud.gd#L17) | Emitted when the time of day slider is dragged, in hours. |
| `time_paused_toggled` | [19](../ui/stage_hud/stage_hud.gd#L19) | Emitted when the pause time toggle changes. |

| Function | Line | Description |
|---|---|---|
| `set_values()` | [51](../ui/stage_hud/stage_hud.gd#L51) | Shows the current tuning values without emitting change signals. |
| `show_time_controls()` | [82](../ui/stage_hud/stage_hud.gd#L82) | Shows the time-of-day controls with the cycle's current state. |
| `show_time()` | [89](../ui/stage_hud/stage_hud.gd#L89) | Shows the current time of day without emitting change signals. |

**Engine callbacks:** [`_ready`](../ui/stage_hud/stage_hud.gd#L39)

**Internal:** [`_format_time`](../ui/stage_hud/stage_hud.gd#L94), [`_on_time_slider_changed`](../ui/stage_hud/stage_hud.gd#L99), [`_on_move_speed_changed`](../ui/stage_hud/stage_hud.gd#L104), [`_on_jog_speed_changed`](../ui/stage_hud/stage_hud.gd#L109), [`_on_sprint_speed_changed`](../ui/stage_hud/stage_hud.gd#L114), [`_on_playback_changed`](../ui/stage_hud/stage_hud.gd#L119)

