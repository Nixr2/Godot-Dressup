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
| `characters/mannequin/` | The base character: `doll.glb`, its textures and materials, skeleton profile, shape key rules, animations (`animations/`), poses (`arm_poses/`, `body_poses/`) and the hide mask body. |
| `customization/` | The reusable customization module: the wardrobe, skin/hair tinting, shape keys, saved appearances and hide mask baking. Contains no scenes, only scripts and the default skin palette. |
| `hair/` | Front (`front/`) and back (`back/`) hair pieces, each a `.glb` plus its `OutfitItem`, and `hair_catalog.tres`. |
| `decal_overlays/` | Transparent face decals (e.g. blush) worn in the Face Overlay slot. |
| `outfits/` | One folder per garment, grouped by slot (`tops/`, `bottoms/`, `under/`, `leg/`, `feet/`, `hats/`). Each holds the `.glb`, its textures, its `OutfitItem` `.tres` and its baked hide mask. `outfit_catalog.tres` lists what players can pick. |
| `common/` | Code and assets shared by several features: animation (`animation/`), outdoor environment (`environment/`: grass field, day/night cycle), import scripts (`import/`), the toon shader (`shaders/`) and its base material (`materials/`). |
| `stages/` | 3D places: the `dressing_room/` (character creation) and the walkable stages (`meadow/`, the one Play opens; `bedroom/`; `playground/`), which share `walkable_stage.gd`. |
| `player/` | The playable character body and its third-person camera. |
| `ui/` | The character creation menu, the stage HUD and the shared dreamy `theme/`. |
| `addons/` | Third-party editor plugins (currently empty). |

## Scenes

| Scene | Root script | Other scripts used |
|---|---|---|
| [main/main.tscn](../main/main.tscn) (main scene) | `main.gd` | Instances the dressing room and the customization menu. |
| [characters/mannequin/mannequin.tscn](../characters/mannequin/mannequin.tscn) | `Mannequin` | `Wardrobe`, `BodyCustomizer`, `ShapeKeyController`, `CharacterAnimator`, `LookAtController` (one child node each). |
| [stages/dressing_room/dressing_room.tscn](../stages/dressing_room/dressing_room.tscn) | `DressingRoom` | `OrbitCamera` with its `CameraFocus` presets; instances the mannequin. |
| [stages/meadow/meadow.tscn](../stages/meadow/meadow.tscn) (opened by Play) | `WalkableStage` | `GrassField`, `DayNightCycle` driving the Sun and Moon lights and the sky; instances the player and the stage HUD. |
| [stages/bedroom/bedroom.tscn](../stages/bedroom/bedroom.tscn), [stages/playground/playground.tscn](../stages/playground/playground.tscn) | `WalkableStage` | Instance the player and the stage HUD. |
| [player/player.tscn](../player/player.tscn) | `Player` | `ThirdPersonCamera`; instances the mannequin. |
| [ui/customization_menu/customization_menu.tscn](../ui/customization_menu/customization_menu.tscn) | `CustomizationMenu` | |
| [ui/stage_hud/stage_hud.tscn](../ui/stage_hud/stage_hud.tscn) | `StageHud` | |

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
  the `HAIR_FRONT` / `HAIR_BACK` slots, listed in `hair/hair_catalog.tres`
  and shown in the Hair card. They share the `hair` tint group, so
  `BodyCustomizer.set_hair_color()` recolors every piece through
  `Wardrobe.set_group_tint()`.
- **Day/night:** `DayNightCycle` advances `time_of_day`, aims the Sun and Moon
  lights, and samples its gradients for the sky, sun and ambient colors. The
  character's toon shader only takes ambient light, so the ambient gradient is
  what tints her. `WalkableStage` gives the HUD time controls when the stage
  has a node named `DayNightCycle`.
- **Shape keys:** `ShapeKeyController` merges body sliders, expressions,
  clothing overrides and blinking into blend shape weights every frame that
  something changes.

## Resources (data types)

Custom `Resource` scripts hold data that is edited in the Inspector and saved
as `.tres` files:

| Type | Saved as | Purpose |
|---|---|---|
| `OutfitItem` | `outfits/**/<item>.tres` | One garment: scene, slot, hide mask, tags, shape key overrides, tint. |
| `OutfitCatalog` | `outfits/outfit_catalog.tres` | Every item players can choose. |
| `CharacterAppearance` | `characters/mannequin/default_appearance.tres` | A saved look. |
| `HideMaskBody` | `characters/mannequin/doll_hide_mask_body.tres` | Which body and skin material hide masks are baked against. |
| `ShapeKeySet` / `ShapeKeyDefinition` | `characters/mannequin/doll_shape_keys.tres` | Shape key rules: categories, clothing conditions, driven keys, blinking. |
| `SkinTonePalette` | `customization/default_skin_tone_palette.tres` | Realistic skin tone gradient plus undertone shift. |
| `ArmPose` / `BodyPose` | `characters/mannequin/arm_poses/`, `body_poses/` | Which animations a pose button plays. |
| `CameraFocus` | Inside `dressing_room.tscn` | Camera framings (face, torso, legs, ...). |

## Shaders

| Shader | Used by | Purpose |
|---|---|---|
| [common/shaders/toon.gdshader](../common/shaders/toon.gdshader) | Character, hair, eyes and all clothing | Ambient-only flat shading, crisp pixel-art sampling, per-instance `tint` (optionally limited by a `tint_mask`, e.g. to the irises), and up to 8 clothing hide masks (`hide_masks`) on the skin. |
| [common/shaders/toon_overlay.gdshader](../common/shaders/toon_overlay.gdshader) | Face decals | Transparent version of the toon look, blended over the skin. |
| [common/shaders/grass.gdshader](../common/shaders/grass.gdshader) | Meadow grass (`GrassField`) | Wind and gusts, bending away from the player, root-to-tip shading. |
| [common/shaders/meadow_ground.gdshader](../common/shaders/meadow_ground.gdshader) | Meadow ground | Soft non-tiling green patches under the grass. |
| [common/shaders/day_night_sky.gdshader](../common/shaders/day_night_sky.gdshader) | Meadow sky | Gradient, sun and moon disks, clouds and stars; colors set by `DayNightCycle`. |
| [common/shaders/grid_floor.gdshader](../common/shaders/grid_floor.gdshader) | Playground floor | Procedural grid. |

# Script reference

Each script lists its **public API** (signals and functions other scripts
may use), followed by its engine callbacks and internal helpers (names
starting with `_`, private by convention).

## Entry point

### `main.gd`

[main/main.gd](../main/main.gd) · extends `Node`

Entry point. Wires the GUI to the 3D world (signals up, calls down) and swaps between character creation and a walkable stage.

**Engine callbacks:** [`_ready`](../main/main.gd#L14), [`_notification`](../main/main.gd#L61)

**Internal:** [`_update_shape_key_availability`](../main/main.gd#L68), [`_on_item_equipped`](../main/main.gd#L76), [`_on_item_unequipped`](../main/main.gd#L81), [`_on_play_requested`](../main/main.gd#L86), [`_on_stage_exit_requested`](../main/main.gd#L96)

## Characters

### `Mannequin`

[characters/mannequin/mannequin.gd](../characters/mannequin/mannequin.gd) · extends `Node3D`

Customizable base character: the Doll model plus its Wardrobe, BodyCustomizer, ShapeKeyController, CharacterAnimator and LookAtController components.

| Function | Line | Description |
|---|---|---|
| `apply_appearance()` | [23](../characters/mannequin/mannequin.gd#L23) | Applies a saved look: colors, body shapes and worn items. |
| `get_appearance()` | [30](../characters/mannequin/mannequin.gd#L30) | Returns the current look as a new CharacterAppearance. |

**Engine callbacks:** [`_ready`](../characters/mannequin/mannequin.gd#L17)

## Customization module

### `BodyCustomizer`

[customization/body_customizer.gd](../customization/body_customizer.gd) · extends `Node`

Tints a character's skin, hair and eyes.

| Function | Line | Description |
|---|---|---|
| `set_skin_tone()` | [33](../customization/body_customizer.gd#L33) | Tints the skin with `palette`'s color for `tone` and `undertone`. |
| `set_hair_color()` | [40](../customization/body_customizer.gd#L40) | Tints the hair with `color`. |
| `set_eye_color()` | [46](../customization/body_customizer.gd#L46) | Tints the irises with `color`. |
| `apply_appearance()` | [52](../customization/body_customizer.gd#L52) | Applies the skin, hair and eye colors of `appearance`. |
| `write_to_appearance()` | [59](../customization/body_customizer.gd#L59) | Stores the current skin, hair and eye colors in `appearance`. |

**Internal:** [`_apply_tint`](../customization/body_customizer.gd#L66), [`_uses_material`](../customization/body_customizer.gd#L72)

### `CharacterAppearance`

[customization/character_appearance.gd](../customization/character_appearance.gd) · extends `Resource`

A saved look: body colors plus which OutfitItem is worn in each slot.

### `HideMaskBaker`

[customization/hide_mask_baker.gd](../customization/hide_mask_baker.gd) · extends `RefCounted`

Bakes what an OutfitItem covers into a black/white mask over the UVs of the surface beneath it: the body's skin, or a garment on a lower `OutfitItem.layer` (e.g. a swimsuit under a shirt).

| Function | Line | Description |
|---|---|---|
| `static bake()` | [26](../customization/hide_mask_baker.gd#L26) | Returns `item`'s body hide mask as an L8 image, white where skin is hidden. |
| `static bake_over()` | [33](../customization/hide_mask_baker.gd#L33) | Returns the mask of what `item` covers of `under`, over `under`'s UVs, as an L8 image. |
| `static save_mask()` | [39](../customization/hide_mask_baker.gd#L39) | Saves `image` as a PNG at `path`. |

**Internal:** [`_bake`](../customization/hide_mask_baker.gd#L56), [`_rasterize_triangle`](../customization/hide_mask_baker.gd#L93), [`_pad_islands`](../customization/hide_mask_baker.gd#L139), [`_collect_triangles`](../customization/hide_mask_baker.gd#L162), [`_append_surface`](../customization/hide_mask_baker.gd#L183), [`_triangle_bounds`](../customization/hide_mask_baker.gd#L222), [`_transform_to`](../customization/hide_mask_baker.gd#L227), [`_TriangleGrid._init`](../customization/hide_mask_baker.gd#L252), [`_TriangleGrid.segment_hits`](../customization/hide_mask_baker.gd#L270), [`_TriangleGrid._cell_of`](../customization/hide_mask_baker.gd#L283), [`_TriangleGrid._segment_hits_triangle`](../customization/hide_mask_baker.gd#L287)

### `HideMaskBody`

[customization/hide_mask_body.gd](../customization/hide_mask_body.gd) · extends `Resource`

The body that OutfitItem hide masks are baked against.

### `OutfitCatalog`

[customization/outfit_catalog.gd](../customization/outfit_catalog.gd) · extends `Resource`

The list of every OutfitItem a player can choose from.

| Function | Line | Description |
|---|---|---|
| `get_items_for_slot()` | [11](../customization/outfit_catalog.gd#L11) | Returns every item that is worn in `slot`. |
| `bake_hide_masks()` | [19](../customization/outfit_catalog.gd#L19) | Bakes every item's body hide mask, plus a covered mask for every pair of skinned items on different layers (what the higher one hides of the lower). |

### `OutfitItem`

[customization/outfit_item.gd](../customization/outfit_item.gd) · extends `Resource`

A single wearable piece of clothing or accessory.

| Function | Line | Description |
|---|---|---|
| `bake_hide_mask()` | [86](../customization/outfit_item.gd#L86) | Bakes `hide_mask` from the garment's shape and saves it as `<id>_hide_mask.png` next to this resource. |
| `bake_covered_mask()` | [97](../customization/outfit_item.gd#L97) | Bakes what `over` covers of this item into `covered_masks`, saved as `<id>_covered_by_<over id>.png` next to this resource. |
| `can_bake()` | [111](../customization/outfit_item.gd#L111) | Whether this item has what baking needs, reporting what's missing if not. |
| `get_mask_path()` | [122](../customization/outfit_item.gd#L122) | Path of this item's mask named `<id>_<suffix>.png`, next to the resource. |

### `ShapeKeyController`

[customization/shape_key_controller.gd](../customization/shape_key_controller.gd) · extends `Node`

Resolves body sliders, the active expression, clothing conditions and automatic blinking into final blend shape weights, then applies them by name to every mesh under `mesh_root`: body parts, hair and all equipped garments, so newly split body parts need no setup.

| Signal | Line | Description |
|---|---|---|
| `availability_changed` | [12](../customization/shape_key_controller.gd#L12) | Emitted when equipping or removing clothing changes which keys apply. |

| Function | Line | Description |
|---|---|---|
| `set_body_value()` | [52](../customization/shape_key_controller.gd#L52) | Sets a body shape slider, clamped to 0-1. |
| `get_body_value()` | [58](../customization/shape_key_controller.gd#L58) | Returns a body shape slider's value. |
| `set_expression()` | [63](../customization/shape_key_controller.gd#L63) | Blends to `key`'s expression. |
| `get_expression()` | [69](../customization/shape_key_controller.gd#L69) | Returns the active expression's key, or an empty key for neutral. |
| `set_auto_blink()` | [74](../customization/shape_key_controller.gd#L74) | Turns automatic blinking on or off. |
| `is_available()` | [81](../customization/shape_key_controller.gd#L81) | Whether `key`'s clothing condition is met. |
| `apply_appearance()` | [92](../customization/shape_key_controller.gd#L92) | Applies the body shape sliders of `appearance`. |
| `write_to_appearance()` | [98](../customization/shape_key_controller.gd#L98) | Stores the body shape sliders in `appearance`. |

**Engine callbacks:** [`_ready`](../customization/shape_key_controller.gd#L37), [`_process`](../customization/shape_key_controller.gd#L44)

**Internal:** [`_update_expression_weights`](../customization/shape_key_controller.gd#L102), [`_update_blink`](../customization/shape_key_controller.gd#L112), [`_schedule_next_blink`](../customization/shape_key_controller.gd#L127), [`_is_blink_blocked`](../customization/shape_key_controller.gd#L131), [`_get_blink_weight`](../customization/shape_key_controller.gd#L136), [`_resolve_weights`](../customization/shape_key_controller.gd#L142), [`_apply`](../customization/shape_key_controller.gd#L169), [`_on_wardrobe_changed`](../customization/shape_key_controller.gd#L185)

### `ShapeKeyDefinition`

[customization/shape_key_definition.gd](../customization/shape_key_definition.gd) · extends `Resource`

Describes one blend shape (shape key) and the rules for using it.

### `ShapeKeySet`

[customization/shape_key_set.gd](../customization/shape_key_set.gd) · extends `Resource`

All shape key rules for one base character.

| Function | Line | Description |
|---|---|---|
| `get_definition()` | [11](../customization/shape_key_set.gd#L11) | Returns the definition for `key`, or null if there is none. |
| `get_by_category()` | [19](../customization/shape_key_set.gd#L19) | Returns every definition in `category`, in list order. |

### `SkinTonePalette`

[customization/skin_tone_palette.gd](../customization/skin_tone_palette.gd) · extends `Resource`

Maps a tone value (0 = lightest, 1 = deepest) and an undertone value (-1 = cool/rosy, 1 = warm/golden) to a realistic skin color.

| Function | Line | Description |
|---|---|---|
| `get_color()` | [18](../customization/skin_tone_palette.gd#L18) | Returns the skin color for `tone` (0-1) shifted by `undertone` (-1 to 1). |

### `Wardrobe`

[customization/wardrobe.gd](../customization/wardrobe.gd) · extends `Node`

Equips, removes and recolors OutfitItems on a character.

| Signal | Line | Description |
|---|---|---|
| `item_equipped` | [16](../customization/wardrobe.gd#L16) |  |
| `item_unequipped` | [18](../customization/wardrobe.gd#L18) | Emitted after `item` is taken off. |

| Function | Line | Description |
|---|---|---|
| `equip()` | [50](../customization/wardrobe.gd#L50) | Puts `item` on, replacing whatever is worn in its slot. |
| `unequip()` | [75](../customization/wardrobe.gd#L75) | Takes off the item worn in `slot`, if any. |
| `get_equipped()` | [88](../customization/wardrobe.gd#L88) | Returns the item worn in `slot`, or null. |
| `get_equipped_items()` | [93](../customization/wardrobe.gd#L93) | Returns every worn item. |
| `get_equipped_meshes()` | [100](../customization/wardrobe.gd#L100) | Returns the meshes of every worn item. |
| `set_item_tint()` | [108](../customization/wardrobe.gd#L108) | Recolors the item worn in `slot`, if it is tintable. |
| `set_group_tint()` | [119](../customization/wardrobe.gd#L119) | Recolors every worn item in tint group `group` (see `OutfitItem.tint_group`), and items of that group equipped later. |
| `get_item_tint()` | [127](../customization/wardrobe.gd#L127) | Returns the tint of the item worn in `slot`. |
| `apply_appearance()` | [135](../customization/wardrobe.gd#L135) | Replaces everything worn with `appearance`'s items and tints. |
| `write_to_appearance()` | [144](../customization/wardrobe.gd#L144) | Stores the worn items and their tints in `appearance`. |

**Engine callbacks:** [`_ready`](../customization/wardrobe.gd#L42)

**Internal:** [`_update_hide_masks`](../customization/wardrobe.gd#L154), [`_set_hide_masks`](../customization/wardrobe.gd#L172), [`_get_toon_materials`](../customization/wardrobe.gd#L180), [`_attach_skinned`](../customization/wardrobe.gd#L192), [`_attach_rigid`](../customization/wardrobe.gd#L220), [`_convert_materials`](../customization/wardrobe.gd#L229), [`_apply_tint`](../customization/wardrobe.gd#L242), [`_create_toon_material`](../customization/wardrobe.gd#L247), [`_find_skeleton`](../customization/wardrobe.gd#L256), [`_shares_bones_with_rig`](../customization/wardrobe.gd#L263), [`_find_meshes`](../customization/wardrobe.gd#L271)

## Animation

### `ArmPose`

[common/animation/arm_pose.gd](../common/animation/arm_pose.gd) · extends `Resource`

An arm layer played on top of the full-body idle, e.g. "hand on hip".

### `BodyPose`

[common/animation/body_pose.gd](../common/animation/body_pose.gd) · extends `Resource`

A full-body pose or loop that replaces the idle as the character's base animation. Arm poses and walking still layer on top.

### `CharacterAnimator`

[common/animation/character_animator.gd](../common/animation/character_animator.gd) · extends `AnimationTree`

Plays the character's base animation (idle or a BodyPose), blends in a stride-matched walk and jog, and layers independent left/right arm poses on top.

| Function | Line | Description |
|---|---|---|
| `set_move_speed()` | [132](../common/animation/character_animator.gd#L132) | Horizontal movement speed in m/s; drives the walk/jog blend and playback rate. |
| `set_body_pose()` | [137](../common/animation/character_animator.gd#L137) | Cross-fades the base animation to `pose`. |
| `get_body_pose()` | [146](../common/animation/character_animator.gd#L146) | Returns the active body pose, or null while idling. |
| `set_arm_pose()` | [151](../common/animation/character_animator.gd#L151) | Cross-fades the arms to `pose`. |
| `get_arm_pose()` | [158](../common/animation/character_animator.gd#L158) | Returns the active arm pose, or null when the arms follow the body. |
| `measure_stride_speed()` | [165](../common/animation/character_animator.gd#L165) | Measures how fast `animation`'s feet travel backward while touching the ground, in m/s: net distance / time over each contact. |
| `measure_contact_phase()` | [186](../common/animation/character_animator.gd#L186) | Where in `animation_name`'s cycle (0-1) the first contact bone touches down, or 0 if it never does. |

**Engine callbacks:** [`_ready`](../common/animation/character_animator.gd#L83), [`_process`](../common/animation/character_animator.gd#L113)

**Internal:** [`_update_gait`](../common/animation/character_animator.gd#L198), [`_request_arm`](../common/animation/character_animator.gd#L221), [`_build_tree`](../common/animation/character_animator.gd#L231), [`_add_transition`](../common/animation/character_animator.gd#L290), [`_collect_arm_inputs`](../common/animation/character_animator.gd#L308), [`_get_looping_animations`](../common/animation/character_animator.gd#L321), [`_jog_node`](../common/animation/character_animator.gd#L340), [`_animation_node`](../common/animation/character_animator.gd#L352), [`_step_toward`](../common/animation/character_animator.gd#L358), [`_sample_contact_bone`](../common/animation/character_animator.gd#L366), [`_find_contacts`](../common/animation/character_animator.gd#L382), [`_get_bone_chain`](../common/animation/character_animator.gd#L407), [`_index_bone_tracks`](../common/animation/character_animator.gd#L422), [`_sample_bone_transform`](../common/animation/character_animator.gd#L435), [`_bone_path`](../common/animation/character_animator.gd#L459), [`_merge_libraries`](../common/animation/character_animator.gd#L463), [`_retarget_library`](../common/animation/character_animator.gd#L477), [`_find_idle_animation`](../common/animation/character_animator.gd#L499)

### `LookAtController`

[common/animation/look_at_controller.gd](../common/animation/look_at_controller.gd) · extends `Node`

Makes a character's head and eyes follow a target (e.g. the camera).

| Function | Line | Description |
|---|---|---|
| `set_target()` | [32](../common/animation/look_at_controller.gd#L32) | Follows `target`. |
| `set_head_follow()` | [41](../common/animation/look_at_controller.gd#L41) | Fades head following on or off. |
| `set_eyes_follow()` | [46](../common/animation/look_at_controller.gd#L46) | Fades eye following on or off. |

**Engine callbacks:** [`_ready`](../common/animation/look_at_controller.gd#L20), [`_process`](../common/animation/look_at_controller.gd#L25)

**Internal:** [`_fade`](../common/animation/look_at_controller.gd#L50), [`_all_modifiers`](../common/animation/look_at_controller.gd#L57)

## Environment

### `DayNightCycle`

[common/environment/day_night_cycle.gd](../common/environment/day_night_cycle.gd) · extends `Node`

Drives a sun, a moon, the sky and the ambient light through a 24-hour day.

| Signal | Line | Description |
|---|---|---|
| `time_changed` | [16](../common/environment/day_night_cycle.gd#L16) | Emitted when the in-game minute changes. |

| Function | Line | Description |
|---|---|---|
| `get_sun_height()` | [63](../common/environment/day_night_cycle.gd#L63) | How far the sun is above the horizon, from -1 (midnight) to 1 (noon). |

**Engine callbacks:** [`_ready`](../common/environment/day_night_cycle.gd#L48), [`_process`](../common/environment/day_night_cycle.gd#L52)

**Internal:** [`_apply`](../common/environment/day_night_cycle.gd#L67), [`_point_light`](../common/environment/day_night_cycle.gd#L108), [`_sample`](../common/environment/day_night_cycle.gd#L113)

### `GrassField`

[common/environment/grass_field.gd](../common/environment/grass_field.gd) · extends `Node3D`

Scatters short grass blades over a square area made of chunks.

**Engine callbacks:** [`_ready`](../common/environment/grass_field.gd#L74), [`_process`](../common/environment/grass_field.gd#L78)

**Internal:** [`_queue_rebuild`](../common/environment/grass_field.gd#L90), [`_rebuild`](../common/environment/grass_field.gd#L97), [`_recenter`](../common/environment/grass_field.gd#L130), [`_make_layout`](../common/environment/grass_field.gd#L142), [`_make_blade_mesh`](../common/environment/grass_field.gd#L166)

## Import scripts

### `set_piece_import.gd`

[common/import/set_piece_import.gd](../common/import/set_piece_import.gd) · extends `EditorScenePostImport`

Post-import script for set pieces (rooms, props).

**Engine callbacks:** [`_post_import`](../common/import/set_piece_import.gd#L12)

**Internal:** [`_use_nearest_filtering`](../common/import/set_piece_import.gd#L18), [`_make_collision_two_sided`](../common/import/set_piece_import.gd#L29)

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
| `focus()` | [63](../stages/dressing_room/orbit_camera.gd#L63) | Glides to the focus preset named `id`. |
| `reset_focus()` | [76](../stages/dressing_room/orbit_camera.gd#L76) | Glides back to `default_focus`. |
| `get_focus()` | [81](../stages/dressing_room/orbit_camera.gd#L81) | Returns the current focus preset's id. |
| `get_camera()` | [86](../stages/dressing_room/orbit_camera.gd#L86) | Returns the orbiting camera. |

**Engine callbacks:** [`_ready`](../stages/dressing_room/orbit_camera.gd#L34), [`_process`](../stages/dressing_room/orbit_camera.gd#L40), [`_unhandled_input`](../stages/dressing_room/orbit_camera.gd#L51)

**Internal:** [`_get_focus_point`](../stages/dressing_room/orbit_camera.gd#L90), [`_get_target_distance`](../stages/dressing_room/orbit_camera.gd#L100), [`_set_pitch`](../stages/dressing_room/orbit_camera.gd#L104), [`_snap`](../stages/dressing_room/orbit_camera.gd#L108)

### `WalkableStage`

[stages/walkable_stage.gd](../stages/walkable_stage.gd) · extends `Node3D`

A stage the customized character can walk around in.

| Signal | Line | Description |
|---|---|---|
| `exit_requested` | [10](../stages/walkable_stage.gd#L10) | Emitted when the player asks to return to character creation. |

| Function | Line | Description |
|---|---|---|
| `setup()` | [39](../stages/walkable_stage.gd#L39) | Dresses the player's character. |

**Engine callbacks:** [`_ready`](../stages/walkable_stage.gd#L17)

**Internal:** [`_on_move_speed_changed`](../stages/walkable_stage.gd#L44), [`_on_jog_speed_changed`](../stages/walkable_stage.gd#L48), [`_on_time_of_day_changed`](../stages/walkable_stage.gd#L52), [`_on_time_paused_toggled`](../stages/walkable_stage.gd#L56), [`_on_walk_playback_multiplier_changed`](../stages/walkable_stage.gd#L60)

## Player

### `Player`

[player/player.gd](../player/player.gd) · extends `CharacterBody3D`

Walks a customized Mannequin around, relative to the camera.

| Function | Line | Description |
|---|---|---|
| `get_effective_move_speed()` | [50](../player/player.gd#L50) | Returns the speed the player walks at, in m/s, resolving `move_speed` = 0 to the walk's stride speed. |
| `get_effective_jog_speed()` | [60](../player/player.gd#L60) | Returns the speed the player jogs at, in m/s, resolving `jog_speed` = 0 to the jog's stride speed. |

**Engine callbacks:** [`_physics_process`](../player/player.gd#L25)

### `ThirdPersonCamera`

[player/third_person_camera.gd](../player/third_person_camera.gd) · extends `Node3D`

Orbits a SpringArm3D-mounted camera around its parent.

**Engine callbacks:** [`_ready`](../player/third_person_camera.gd#L22), [`_unhandled_input`](../player/third_person_camera.gd#L26)

**Internal:** [`_zoom`](../player/third_person_camera.gd#L38), [`_update_rotation`](../player/third_person_camera.gd#L43)

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

| Function | Line | Description |
|---|---|---|
| `set_body_values()` | [169](../ui/customization_menu/customization_menu.gd#L169) | Shows the current skin tone, undertone, hair and eye colors. |
| `set_follow_state()` | [177](../ui/customization_menu/customization_menu.gd#L177) | Shows whether the head and eyes follow the camera. |
| `set_arm_poses()` | [183](../ui/customization_menu/customization_menu.gd#L183) | Lists `poses` as arm pose buttons, after "Default". |
| `set_body_poses()` | [193](../ui/customization_menu/customization_menu.gd#L193) | Lists `poses` as body pose buttons, after "Idle". |
| `set_body_shape_values()` | [203](../ui/customization_menu/customization_menu.gd#L203) | Shows the current body shape sliders and auto blink state. |
| `set_body_shape_available()` | [210](../ui/customization_menu/customization_menu.gd#L210) | Disables a body shape slider whose clothing condition isn't met. |
| `set_slot_state()` | [222](../ui/customization_menu/customization_menu.gd#L222) | Shows which item is worn in `slot` and its tint. |

**Engine callbacks:** [`_ready`](../ui/customization_menu/customization_menu.gd#L138), [`_process`](../ui/customization_menu/customization_menu.gd#L164)

**Internal:** [`_update_hover`](../ui/customization_menu/customization_menu.gd#L236), [`_focus_card`](../ui/customization_menu/customization_menu.gd#L245), [`_is_hover_blocked`](../ui/customization_menu/customization_menu.gd#L257), [`_find_hovered_card`](../ui/customization_menu/customization_menu.gd#L268), [`_build_swatches`](../ui/customization_menu/customization_menu.gd#L280), [`_build_hair_styles`](../ui/customization_menu/customization_menu.gd#L302), [`_build_body_shape_sliders`](../ui/customization_menu/customization_menu.gd#L316), [`_build_expression_buttons`](../ui/customization_menu/customization_menu.gd#L331), [`_add_toggle_button`](../ui/customization_menu/customization_menu.gd#L342), [`_build_slot_list`](../ui/customization_menu/customization_menu.gd#L355), [`_clear`](../ui/customization_menu/customization_menu.gd#L394), [`_on_skin_slider_changed`](../ui/customization_menu/customization_menu.gd#L400), [`_on_body_shape_slider_changed`](../ui/customization_menu/customization_menu.gd#L404), [`_on_swatch_pressed`](../ui/customization_menu/customization_menu.gd#L408), [`_on_tint_picker_changed`](../ui/customization_menu/customization_menu.gd#L413)

### `StageHud`

[ui/stage_hud/stage_hud.gd](../ui/stage_hud/stage_hud.gd) · extends `Control`

Back button plus live tuning for walk and jog speed and stride matching, and time-of-day controls on stages with a DayNightCycle.

| Signal | Line | Description |
|---|---|---|
| `back_pressed` | [7](../ui/stage_hud/stage_hud.gd#L7) | Emitted when the back button is pressed. |
| `move_speed_changed` | [9](../ui/stage_hud/stage_hud.gd#L9) | Emitted when the move speed slider changes, in m/s. |
| `jog_speed_changed` | [11](../ui/stage_hud/stage_hud.gd#L11) | Emitted when the jog speed slider changes, in m/s. |
| `walk_playback_multiplier_changed` | [13](../ui/stage_hud/stage_hud.gd#L13) | Emitted when the walk playback slider changes. |
| `time_of_day_changed` | [15](../ui/stage_hud/stage_hud.gd#L15) | Emitted when the time of day slider is dragged, in hours. |
| `time_paused_toggled` | [17](../ui/stage_hud/stage_hud.gd#L17) | Emitted when the pause time toggle changes. |

| Function | Line | Description |
|---|---|---|
| `set_values()` | [45](../ui/stage_hud/stage_hud.gd#L45) | Shows the current tuning values without emitting change signals. |
| `show_time_controls()` | [67](../ui/stage_hud/stage_hud.gd#L67) | Shows the time-of-day controls with the cycle's current state. |
| `show_time()` | [74](../ui/stage_hud/stage_hud.gd#L74) | Shows the current time of day without emitting change signals. |

**Engine callbacks:** [`_ready`](../ui/stage_hud/stage_hud.gd#L34)

**Internal:** [`_format_time`](../ui/stage_hud/stage_hud.gd#L79), [`_on_time_slider_changed`](../ui/stage_hud/stage_hud.gd#L84), [`_on_move_speed_changed`](../ui/stage_hud/stage_hud.gd#L89), [`_on_jog_speed_changed`](../ui/stage_hud/stage_hud.gd#L94), [`_on_playback_changed`](../ui/stage_hud/stage_hud.gd#L99)

