> Historical notes for the local 0.6 preview. Its visual changes are now included in public 0.6.1; see the README and WATER-VALIDATION.md for current release details.

# Vesper Atmosphere preview — 0.6

Double-click **Play Living Vesper.cmd**. No engine or Blender installation is required to play. This is still a single-player fan tech demo, not an upcoming complete game.

## What changed

- The existing photographed plaster, stone, oak, roof, paving and grass maps now have subtle world-anchored variation. Plaster and masonry have uneven darkening near the ground; the pattern does not move with the camera.
- Daylight has stronger directional shade with less ambient fill. Windows are subdued by day and warm at night. Air remains clear: no fog, temporal blur or added screen filter.
- Six accessible buildings have visible hanging lanterns and localized warm interior lighting. The existing eight-nearby-light limit remains; at most three nearby lamps cast shadows on High quality.
- Nine shops have physical pictorial trade signs: fish, hammer, bread, tankard, anchor or medicine bottle.
- The fishing shop has a supported net/drying rack with fish, float line and coiled rope. The carpenter and shipwright have timber and tools. Shipyard casks sit on the existing bench. Tavern/inn shelving adds pottery, bottles and provisions; the Marsh Hall has a timber backbar.
- Citizen clothing uses subdued dye colours with a rougher cloth response. The working character rigs and animations are retained.

The new props are visual dressing, not new usable inventory items. NPC deliveries, finite stocks and meals continue to use the existing simulation. Jev and dialogue behavior have not been expanded in this visual pass.

## Controls and saves

Use **T** to compare Golden hour, Daylight and Lantern night. Scroll to zoom, hold right mouse to rotate. **Esc** opens audio and quality settings; **F3** shows town diagnostics. Existing fishing, banking, shops and errands retain their controls.

This preview has a separate save folder: `%APPDATA%\Vesper Atmosphere Preview\`. On a normal first launch, the launcher copies any existing Living Town journey, settings and voice preference file only if the matching preview file does not already exist. Your old files and the 0.5 launcher remain usable. QA runs do not import the personal journey.

## AI, audio and scope

The same optional TypeSafe helper, bounded requests and local Kokoro voices are included. No extra subscription or new credential is required. Rules keep the town running without a TypeSafe key; **F3** distinguishes live Jev from fallback. Default caps remain 360 requests and a conservative $0.01 reservation per day, whichever is reached first. This preview's regression runs use offline rules; they do not claim to retest live Jev.

The personal build retains the local Vesper recording and independent music, ambience and voice controls. Music credit and rights remain in CREDITS.md. No public GitHub release or upload was made as part of this update.

## Source and recovery

Worktree branch: `experiment/vesper-atmosphere`, based on Neighbours commit `898e53f`. The original source, 0.5 executable and player saves were checkpointed before work.

The Blender generator is `scripts/build_trade_dressing.py`. It exports original prop geometry using existing Brown Planks 03 maps into `godot/art/`; placements and navigation footprints live in `trade_dressing.json`. The rendering controller and shader are `town_atmosphere.gd` and `weathered_surface.gdshader`. Large generated GLBs and imported assets accompany the local working copy/build and are not committed as source text. Asset rights and origins are listed in ATMOSPHERE-ASSETS.json.

The architecture is still the existing stylized interpretation of Vesper. This pass improves its materials and atmosphere; it does not replace every building or character with a new high-detail asset.
