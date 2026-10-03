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
| `outfits/` | One folder per garment, grouped by slot (`tops/`, `bottoms/`, `hats/`). Each holds the `.glb`, its textures, its `OutfitItem` `.tres` and its baked hide mask. `outfit_catalog.tres` lists what players can pick. |
| `common/` | Code and assets shared by several features: animation (`animation/`), import scripts (`import/`), the toon shader (`shaders/`) and its base material (`materials/`). |
| `stages/` | 3D places: the `dressing_room/` (character creation) and the walkable stages (`bedroom/`, `playground/`), which share `walkable_stage.gd`. |
| `player/` | The playable character body and its third-person camera. |
| `ui/` | The character creation menu, the stage HUD and the shared dreamy `theme/`. |
| `addons/` | Third-party editor plugins (currently empty). |

## Scenes

| Scene | Root script | Other scripts used |
|---|---|---|
| [main/main.tscn](../main/main.tscn) (main scene) | `main.gd` | Instances the dressing room and the customization menu. |
| [characters/mannequin/mannequin.tscn](../characters/mannequin/mannequin.tscn) | `Mannequin` | `Wardrobe`, `BodyCustomizer`, `ShapeKeyController`, `CharacterAnimator`, `LookAtController` (one child node each). |
| [stages/dressing_room/dressing_room.tscn](../stages/dressing_room/dressing_room.tscn) | `DressingRoom` | `OrbitCamera` with its `CameraFocus` presets; instances the mannequin. |
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
  removes character creation from the tree (keeping it in memory), adds the
  stage, and calls `WalkableStage.setup()` to dress the player's mannequin
  with it. "Back" reverses this.
- **Clothing:** `Wardrobe.equip()` moves the garment's own skeleton under
  the `ClothingRig` (a `RetargetModifier3D`) so it follows the body, converts
  its materials to the toon shader and sends its hide mask to the skin shader.
- **Hide masks:** `OutfitItem.bake_hide_mask()` (the "Bake Hide Mask" button
  in the Inspector) runs `HideMaskBaker.bake()` and saves
  `<id>_hide_mask.png` next to the item.
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
| [common/shaders/toon.gdshader](../common/shaders/toon.gdshader) | Character, hair, eyes and all clothing | Ambient-only flat shading, crisp pixel-art sampling, per-instance `tint`, and up to 8 clothing hide masks (`hide_masks`) on the skin. |
| [common/shaders/grid_floor.gdshader](../common/shaders/grid_floor.gdshader) | Playground floor | Procedural grid. |

# Script reference

Each script lists its **public API** (signals and functions other scripts
may use), followed by its engine callbacks and internal helpers (names
starting with `_`, private by convention).

## Entry point

### `main.gd`

[main/main.gd](../main/main.gd) · extends `Node`

Entry point. Wires the GUI to the 3D world (signals up, calls down) and swaps between character creation and a walkable stage.

**Engine callbacks:** [`_ready`](../main/main.gd#L14), [`_notification`](../main/main.gd#L59)

**Internal:** [`_update_shape_key_availability`](../main/main.gd#L66), [`_on_item_equipped`](../main/main.gd#L74), [`_on_item_unequipped`](../main/main.gd#L79), [`_on_play_requested`](../main/main.gd#L84), [`_on_stage_exit_requested`](../main/main.gd#L94)

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

Tints a character's skin and hair.

| Function | Line | Description |
|---|---|---|
| `set_skin_tone()` | [26](../customization/body_customizer.gd#L26) | Tints the skin with `palette`'s color for `tone` and `undertone`. |
| `set_hair_color()` | [33](../customization/body_customizer.gd#L33) | Tints the hair with `color`. |
| `apply_appearance()` | [39](../customization/body_customizer.gd#L39) | Applies the skin and hair colors of `appearance`. |
| `write_to_appearance()` | [45](../customization/body_customizer.gd#L45) | Stores the current skin and hair colors in `appearance`. |

**Internal:** [`_apply_tint`](../customization/body_customizer.gd#L51), [`_uses_material`](../customization/body_customizer.gd#L57)

### `CharacterAppearance`

[customization/character_appearance.gd](../customization/character_appearance.gd) · extends `Resource`

A saved look: body colors plus which OutfitItem is worn in each slot.

### `HideMaskBaker`

[customization/hide_mask_baker.gd](../customization/hide_mask_baker.gd) · extends `RefCounted`

Bakes the skin an OutfitItem hugs into a black/white mask over the body UVs.

| Function | Line | Description |
|---|---|---|
| `static bake()` | [23](../customization/hide_mask_baker.gd#L23) | Returns `item`'s hide mask as an L8 image, white where skin is hidden. |

**Internal:** [`_rasterize_triangle`](../customization/hide_mask_baker.gd#L57), [`_pad_islands`](../customization/hide_mask_baker.gd#L103), [`_collect_triangles`](../customization/hide_mask_baker.gd#L126), [`_append_surface`](../customization/hide_mask_baker.gd#L147), [`_triangle_bounds`](../customization/hide_mask_baker.gd#L186), [`_transform_to`](../customization/hide_mask_baker.gd#L191), [`_TriangleGrid._init`](../customization/hide_mask_baker.gd#L216), [`_TriangleGrid.segment_hits`](../customization/hide_mask_baker.gd#L234), [`_TriangleGrid._cell_of`](../customization/hide_mask_baker.gd#L247), [`_TriangleGrid._segment_hits_triangle`](../customization/hide_mask_baker.gd#L251)

### `HideMaskBody`

[customization/hide_mask_body.gd](../customization/hide_mask_body.gd) · extends `Resource`

The body that OutfitItem hide masks are baked against.

### `OutfitCatalog`

[customization/outfit_catalog.gd](../customization/outfit_catalog.gd) · extends `Resource`

The list of every OutfitItem a player can choose from.

| Function | Line | Description |
|---|---|---|
| `get_items_for_slot()` | [9](../customization/outfit_catalog.gd#L9) | Returns every item that is worn in `slot`. |

### `OutfitItem`

[customization/outfit_item.gd](../customization/outfit_item.gd) · extends `Resource`

A single wearable piece of clothing or accessory.

| Function | Line | Description |
|---|---|---|
| `bake_hide_mask()` | [63](../customization/outfit_item.gd#L63) | Bakes `hide_mask` from the garment's shape and saves it as `<id>_hide_mask.png` next to this resource. |

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
| `item_equipped` | [15](../customization/wardrobe.gd#L15) | Emitted after `item` is put on. |
| `item_unequipped` | [17](../customization/wardrobe.gd#L17) | Emitted after `item` is taken off. |

| Function | Line | Description |
|---|---|---|
| `equip()` | [48](../customization/wardrobe.gd#L48) | Puts `item` on, replacing whatever is worn in its slot. |
| `unequip()` | [70](../customization/wardrobe.gd#L70) | Takes off the item worn in `slot`, if any. |
| `get_equipped()` | [83](../customization/wardrobe.gd#L83) | Returns the item worn in `slot`, or null. |
| `get_equipped_items()` | [88](../customization/wardrobe.gd#L88) | Returns every worn item. |
| `get_equipped_meshes()` | [95](../customization/wardrobe.gd#L95) | Returns the meshes of every worn item. |
| `set_item_tint()` | [103](../customization/wardrobe.gd#L103) | Recolors the item worn in `slot`, if it is tintable. |
| `get_item_tint()` | [114](../customization/wardrobe.gd#L114) | Returns the tint of the item worn in `slot`. |
| `apply_appearance()` | [122](../customization/wardrobe.gd#L122) | Replaces everything worn with `appearance`'s items and tints. |
| `write_to_appearance()` | [131](../customization/wardrobe.gd#L131) | Stores the worn items and their tints in `appearance`. |

**Engine callbacks:** [`_ready`](../customization/wardrobe.gd#L40)

**Internal:** [`_update_hide_masks`](../customization/wardrobe.gd#L140), [`_attach_skinned`](../customization/wardrobe.gd#L156), [`_attach_rigid`](../customization/wardrobe.gd#L184), [`_convert_materials`](../customization/wardrobe.gd#L193), [`_create_toon_material`](../customization/wardrobe.gd#L205), [`_find_skeleton`](../customization/wardrobe.gd#L213), [`_shares_bones_with_rig`](../customization/wardrobe.gd#L220), [`_find_meshes`](../customization/wardrobe.gd#L228)

## Animation

### `ArmPose`

[common/animation/arm_pose.gd](../common/animation/arm_pose.gd) · extends `Resource`

An arm layer played on top of the full-body idle, e.g. "hand on hip".

### `BodyPose`

[common/animation/body_pose.gd](../common/animation/body_pose.gd) · extends `Resource`

A full-body pose or loop that replaces the idle as the character's base animation. Arm poses and walking still layer on top.

### `CharacterAnimator`

[common/animation/character_animator.gd](../common/animation/character_animator.gd) · extends `AnimationTree`

Plays the character's base animation (idle or a BodyPose), blends in a stride-matched walk, and layers independent left/right arm poses on top.

| Function | Line | Description |
|---|---|---|
| `set_move_speed()` | [113](../common/animation/character_animator.gd#L113) | Horizontal movement speed in m/s; drives the walk blend and playback rate. |
| `set_body_pose()` | [118](../common/animation/character_animator.gd#L118) | Cross-fades the base animation to `pose`. |
| `get_body_pose()` | [127](../common/animation/character_animator.gd#L127) | Returns the active body pose, or null while idling. |
| `set_arm_pose()` | [132](../common/animation/character_animator.gd#L132) | Cross-fades the arms to `pose`. |
| `get_arm_pose()` | [139](../common/animation/character_animator.gd#L139) | Returns the active arm pose, or null when the arms follow the body. |
| `measure_stride_speed()` | [146](../common/animation/character_animator.gd#L146) | Measures how fast `animation`'s feet travel backward while touching the ground, in m/s: net distance / time over each contact. |

**Engine callbacks:** [`_ready`](../common/animation/character_animator.gd#L70), [`_process`](../common/animation/character_animator.gd#L92)

**Internal:** [`_request_arm`](../common/animation/character_animator.gd#L186), [`_build_tree`](../common/animation/character_animator.gd#L196), [`_add_transition`](../common/animation/character_animator.gd#L244), [`_collect_arm_inputs`](../common/animation/character_animator.gd#L262), [`_get_looping_animations`](../common/animation/character_animator.gd#L275), [`_animation_node`](../common/animation/character_animator.gd#L291), [`_step_toward`](../common/animation/character_animator.gd#L297), [`_get_bone_chain`](../common/animation/character_animator.gd#L304), [`_index_bone_tracks`](../common/animation/character_animator.gd#L319), [`_sample_bone_transform`](../common/animation/character_animator.gd#L332), [`_bone_path`](../common/animation/character_animator.gd#L356), [`_merge_libraries`](../common/animation/character_animator.gd#L360), [`_retarget_library`](../common/animation/character_animator.gd#L374), [`_find_idle_animation`](../common/animation/character_animator.gd#L396)

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
| `exit_requested` | [9](../stages/walkable_stage.gd#L9) | Emitted when the player asks to return to character creation. |

| Function | Line | Description |
|---|---|---|
| `setup()` | [28](../stages/walkable_stage.gd#L28) | Dresses the player's character. |

**Engine callbacks:** [`_ready`](../stages/walkable_stage.gd#L15)

**Internal:** [`_on_move_speed_changed`](../stages/walkable_stage.gd#L32), [`_on_walk_playback_multiplier_changed`](../stages/walkable_stage.gd#L36)

## Player

### `Player`

[player/player.gd](../player/player.gd) · extends `CharacterBody3D`

Walks a customized Mannequin around, relative to the camera.

| Function | Line | Description |
|---|---|---|
| `get_effective_move_speed()` | [44](../player/player.gd#L44) | Returns the speed the player walks at, in m/s, resolving `move_speed` = 0 to the walk's stride speed. |

**Engine callbacks:** [`_physics_process`](../player/player.gd#L22)

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
| `item_selected` | [20](../ui/customization_menu/customization_menu.gd#L20) | Emitted when an item button is pressed. |
| `slot_cleared` | [22](../ui/customization_menu/customization_menu.gd#L22) | Emitted when a slot's "None" button is pressed. |
| `item_tint_changed` | [24](../ui/customization_menu/customization_menu.gd#L24) | Emitted when a slot's color picker changes. |
| `body_shape_changed` | [26](../ui/customization_menu/customization_menu.gd#L26) | Emitted when a body shape slider changes. |
| `expression_selected` | [28](../ui/customization_menu/customization_menu.gd#L28) | Emitted when an expression button is pressed. |
| `auto_blink_toggled` | [30](../ui/customization_menu/customization_menu.gd#L30) | Emitted when the auto blink checkbox is toggled. |
| `arm_pose_selected` | [32](../ui/customization_menu/customization_menu.gd#L32) | Emitted when an arm pose button is pressed. |
| `body_pose_selected` | [34](../ui/customization_menu/customization_menu.gd#L34) | Emitted when a body pose button is pressed. |
| `play_requested` | [36](../ui/customization_menu/customization_menu.gd#L36) | Emitted when the Play button is pressed. |
| `focus_requested` | [38](../ui/customization_menu/customization_menu.gd#L38) | Emitted with the camera framing of a newly hovered section. |
| `head_follow_toggled` | [40](../ui/customization_menu/customization_menu.gd#L40) | Emitted when the head follow chip is toggled. |
| `eyes_follow_toggled` | [42](../ui/customization_menu/customization_menu.gd#L42) | Emitted when the eyes follow chip is toggled. |

| Function | Line | Description |
|---|---|---|
| `set_body_values()` | [134](../ui/customization_menu/customization_menu.gd#L134) | Shows the current skin tone, undertone and hair color. |
| `set_follow_state()` | [141](../ui/customization_menu/customization_menu.gd#L141) | Shows whether the head and eyes follow the camera. |
| `set_arm_poses()` | [147](../ui/customization_menu/customization_menu.gd#L147) | Lists `poses` as arm pose buttons, after "Default". |
| `set_body_poses()` | [157](../ui/customization_menu/customization_menu.gd#L157) | Lists `poses` as body pose buttons, after "Idle". |
| `set_body_shape_values()` | [167](../ui/customization_menu/customization_menu.gd#L167) | Shows the current body shape sliders and auto blink state. |
| `set_body_shape_available()` | [174](../ui/customization_menu/customization_menu.gd#L174) | Disables a body shape slider whose clothing condition isn't met. |
| `set_slot_state()` | [186](../ui/customization_menu/customization_menu.gd#L186) | Shows which item is worn in `slot` and its tint. |

**Engine callbacks:** [`_ready`](../ui/customization_menu/customization_menu.gd#L106), [`_process`](../ui/customization_menu/customization_menu.gd#L129)

**Internal:** [`_update_hover`](../ui/customization_menu/customization_menu.gd#L199), [`_focus_card`](../ui/customization_menu/customization_menu.gd#L208), [`_is_hover_blocked`](../ui/customization_menu/customization_menu.gd#L220), [`_find_hovered_card`](../ui/customization_menu/customization_menu.gd#L231), [`_build_hair_swatches`](../ui/customization_menu/customization_menu.gd#L241), [`_build_body_shape_sliders`](../ui/customization_menu/customization_menu.gd#L260), [`_build_expression_buttons`](../ui/customization_menu/customization_menu.gd#L275), [`_add_toggle_button`](../ui/customization_menu/customization_menu.gd#L286), [`_build_slot_list`](../ui/customization_menu/customization_menu.gd#L299), [`_clear`](../ui/customization_menu/customization_menu.gd#L338), [`_on_skin_slider_changed`](../ui/customization_menu/customization_menu.gd#L344), [`_on_body_shape_slider_changed`](../ui/customization_menu/customization_menu.gd#L348), [`_on_hair_swatch_pressed`](../ui/customization_menu/customization_menu.gd#L352), [`_on_tint_picker_changed`](../ui/customization_menu/customization_menu.gd#L357)

### `StageHud`

[ui/stage_hud/stage_hud.gd](../ui/stage_hud/stage_hud.gd) · extends `Control`

Back button plus live tuning for walk speed and stride matching.

| Signal | Line | Description |
|---|---|---|
| `back_pressed` | [6](../ui/stage_hud/stage_hud.gd#L6) | Emitted when the back button is pressed. |
| `move_speed_changed` | [8](../ui/stage_hud/stage_hud.gd#L8) | Emitted when the move speed slider changes, in m/s. |
| `walk_playback_multiplier_changed` | [10](../ui/stage_hud/stage_hud.gd#L10) | Emitted when the walk playback slider changes. |

| Function | Line | Description |
|---|---|---|
| `set_values()` | [27](../ui/stage_hud/stage_hud.gd#L27) | Shows the current tuning values without emitting change signals. |

**Engine callbacks:** [`_ready`](../ui/stage_hud/stage_hud.gd#L20)

**Internal:** [`_on_move_speed_changed`](../ui/stage_hud/stage_hud.gd#L35), [`_on_playback_changed`](../ui/stage_hud/stage_hud.gd#L40)

