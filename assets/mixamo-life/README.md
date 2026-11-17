# Mixamo life actions

Downloaded from the user's signed-in Adobe Mixamo account on 2026-11-17, applied to BOY_CHARACTER_MIXAMO_V2:

- Waving.fbx: Waving (description: Waving), 17 frames at 30 fps.
- Drinking.fbx: Drinking (description: Male Drinking), 267 frames at 30 fps; left hand holds the drink.

Source: https://www.mixamo.com/
Adobe FAQ / usage terms: https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html
These are Adobe Mixamo assets, not CC0 assets. No source model is instantiated by the game.

Rebuild the rest-relative motion library (background only):

```
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python tools/assets/extract_mixamo_life.py
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/assets/prepare_mixamo_life.gd
```

The extractor writes intermediate rotations to /tmp/cuiyu_mixamo_life.json. The baker maps Mixamo Spine1/Spine2/ToeBase onto Kenney Chest/UpperChest/Toes. Runtime uses upper-body rotations, preserving the grounded stance and existing hand IK for mouth/bottle alignment. All twelve Kenney appearances share this rig.

Eating and washing hands were not downloaded: no suitable animations were confirmed in the catalogue. Existing eating remains procedural.
