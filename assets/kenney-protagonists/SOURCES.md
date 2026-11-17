# Kenney Animated Characters — Protagonists

- Author: Kenney. License: CC0 1.0; original `License.txt` retained.
- Official pack: https://kenney.nl/assets/animated-characters-protagonists
- Author's original publication / archive: https://opengameart.org/content/animated-characters-2
- Download: https://opengameart.org/sites/default/files/kenney_animated-characters-2.zip
- Retrieved 2026-11-17. This 2020 pack has one shared rigged body and four skins, not eight distinct bodies.
- All four skins are selectable: skaterMaleA, skaterFemaleA, cyborgFemaleA, criminalMaleA. Asset filenames are preserved; the game offers appearances without gender categories.
- FBX and skins are original sources. `character.glb`, `idle.glb`, `run.glb` are converted via Blender; `protagonist.scn` is baked via Godot.
- Reproduce from project root:
  1. `blender --background --factory-startup --python tools/assets/convert_protagonists.py`
  2. `godot --headless --path . --editor --import --quit`
  3. `godot --headless --path . --script res://tools/assets/prepare_protagonists.gd`
- Derived model: height 2.2 game units before the existing playable-character scale, Y-up, normalized bone rest axes and inverse skin binds. Original appearance textures retained. Idle and Run imported; Walk is a slowed Run, not a new authored walk cycle.
- Old Polyfork-only cloak/shoe meshes are not present. Their removal sequence does not strip the new character's integrated clothing; old geometric eyelids are not placed on the new face.
e92059003852b8e3f78cf50c2846480f8a93016f25f48a34c283d29d80d3e7e7  /tmp/kenney-protagonists.zip
