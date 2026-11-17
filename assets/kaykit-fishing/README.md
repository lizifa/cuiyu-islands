# KayKit fishing animations

Author: Kay Lousberg. Pack: KayKit Character Animations Free 1.1.
Official source: https://kaylousberg.itch.io/kaykit-character-animations
Downloaded 2026-11-17 from the author's free download endpoint, upload 15799903.
Original archive path: Animations/gltf/Rig_Medium/Rig_Medium_Tools.glb.
License: CC0, commercial use allowed, attribution optional; original License.txt included.

`tools.glb` is the unmodified source. `fishing_actions.tres` contains only the seven fishing clips, baked onto the normalized Kenney rig with `tools/assets/prepare_kaykit_fishing.gd` (Godot headless). The character mesh is not replaced.

- Fishing_Cast -> casting, fitted to the existing cast duration.
- Fishing_Idle -> ready / charging / waiting / standing.
- Fishing_Bite -> bite.
- Fishing_Tug -> hooking.
- Fishing_Reeling -> reeling while pulling, normal line tension.
- Fishing_Struggling -> reeling under high tension or when releasing the reel.
- Fishing_Catch -> net_ready, as a bringing-fish-near gesture. Actual landing still uses the existing landing net.

Only upper-body rotations are used. Existing seated legs/feet, rod direction, left-hand reel IK, net and storage actions remain authoritative. The right-hand rod origin follows the retargeted arm with a constrained blend. Pause follows the fishing session clock; cancel clears animation state and restores the original pose. All twelve selectable Kenney appearances share this skeleton.

Rebuild:
`Godot --headless --path . --script tools/assets/prepare_kaykit_fishing.gd`

The pack does not supply sitting, net-scooping, unhooking, or fish-storage clips; those existing procedural actions have not been represented as KayKit animations. Visual acceptance on device is pending.
