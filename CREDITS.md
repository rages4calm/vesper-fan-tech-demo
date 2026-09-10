# Credits, sources, and acknowledgments

## Project and intent

**Carl Prewitt Jr. / [rages4calm](https://github.com/rages4calm)** initiated the project, supplied the Ultima Online references and creative direction, played successive builds, and guided the revisions.

**OpenAI Codex** assisted with research, programming, procedural Blender modeling, asset preparation, interface implementation, testing, and video capture. The journal background was created with **OpenAI image generation**. This was an AI-assisted collaboration, not a claim that every asset was hand-made or created from scratch.

This is a personal fan tech demo made for nostalgia and fun. It will never become a complete game. There is no commercial release, MMO, or official remake being developed here.

## Ultima Online and Vesper

Credit for **Ultima Online**, **Britannia**, and **Vesper** belongs to **Origin Systems and the original Ultima Online creators**, including Richard Garriott's foundational work on Ultima. Original place and shop names identify the inspiration. No ownership of the original game's intellectual property is claimed.

**This project is not endorsed by or affiliated with EA or its licensors.** It is also unaffiliated with Broadsword and the official Ultima Online service. The names, trademarks, music, and original game content retain their respective rights. Acknowledgment is not a claim of redistribution permission.

Primary geographical reference: **Ultima Online: The Second Age** manual, Vesper map and key, printed pages 16.26–16.27, PDF page 105. [Museum of Computer Adventure Game History scan](https://mocagh.org/origin/uosecondage-alt-manual.pdf). The scan is a reference, not a bundled game asset.

Supporting references:

- [Stratics Grand Atlas — Vesper](https://uo.stratics.com/content/atlas/vesper.shtml)
- [UOGuide — Vesper](https://www.uoguide.com/Vesper)
- [Codex of Ultima Wisdom — Vesper](https://wiki.ultimacodex.com/wiki/Vesper#Ultima_Online)
- [YMT Vesper Diary — annotated city map](https://sun-ymt.hatenablog.com/entry/2021/12/11/181654)
- [Blade Spirit's Vesper video](https://www.youtube.com/watch?v=iy_lFmivB7I), used to understand the Mint and streets; stream overlays and the presenter's camera were not interpreted as game scenery
- Official UO [Ships Guide](https://uo.com/wiki/ultima-online-wiki/gameplay/ships-guide/) and [Fishing guide](https://uo.com/wiki/ultima-online-wiki/skills/fishing/)

## Music and sound

The **public release does not distribute the original UO soundtrack, extracted UO effects, or UO client files**. It includes new synthesized canal ambience, footsteps, gull calls, bell, wooden-door sounds, splash, and inventory effects. Their generators are `scripts/make_ambience.py` and `scripts/make_public_effects.py`; these produce waveforms from oscillators and noise, without sampling UO recordings.

The original Vesper theme heard in some development videos is the original UO composition rendered on a **Roland Sound Canvas SC-55** and archived by **Rabbit's Lair**. The reference recording's metadata credits **Joe Basquez and Kirk Winterowd** for soundtrack composition/arrangement. [Archive and recording notes](http://ultima.rabbitslair.de/ultima_online.htm). The composition and recording retain their original rights; they are not described as CC0 or public domain here.

The demo can load an OGG or WAV selected by the player, locally. It neither downloads music nor grants rights to a player's chosen recording.

## Quaternius — characters and base animations

The following **free Standard packs by [Quaternius](https://quaternius.com/)** are licensed **CC0 1.0**:

- [Modular Character Outfits — Fantasy](https://quaternius.com/packs/modularcharacteroutfitsfantasy.html): the Male Ranger and male/female Peasant outfits.
- [Universal Base Characters](https://quaternius.com/packs/universalbasecharacters.html): heads, eyes, eyebrows, and hair.
- [Universal Animation Library](https://quaternius.com/packs/universalanimationlibrary.html): idle, talking, walking, jogging, sprinting, jumping, and interaction clips.

Characters were assembled and rebound in Blender. The harbor fishing performance was baked onto the adapted peasant rig. See the original pack notices in [docs/licenses](docs/licenses/).

## Poly Haven — models and materials

These models and photographed PBR materials come from **[Poly Haven](https://polyhaven.com/)** and its contributing artists under **[CC0](https://polyhaven.com/license)**. Each asset page identifies its contributors.

**Trees:** [Tree Small 02](https://polyhaven.com/a/tree_small_02), [Island Tree 02](https://polyhaven.com/a/island_tree_02). Geometry was optimized in Blender while retaining its UVs and material maps; the scanned ground patches were seated below the grass.

**Furnishings:** [Treasure Chest](https://polyhaven.com/a/treasure_chest), [Wooden Bookshelf Worn](https://polyhaven.com/a/wooden_bookshelf_worn), [Wooden Table 01](https://polyhaven.com/a/WoodenTable_01), [Wooden Chair 01](https://polyhaven.com/a/WoodenChair_01), [Brass Candleholders](https://polyhaven.com/a/brass_candleholders).

**Materials:**

- [Medieval Blocks 03](https://polyhaven.com/a/medieval_blocks_03)
- [Clay Roof Tiles 03](https://polyhaven.com/a/clay_roof_tiles_03)
- [Brown Planks 03](https://polyhaven.com/a/brown_planks_03)
- [Cobblestone Floor 08](https://polyhaven.com/a/cobblestone_floor_08)
- [Plastered Wall 02](https://polyhaven.com/a/plastered_wall_02)
- [Grey Roof Tiles](https://polyhaven.com/a/grey_roof_tiles)
- [Cobblestone Floor 02](https://polyhaven.com/a/cobblestone_floor_02)
- [Medieval Wall 02](https://polyhaven.com/a/medieval_wall_02)
- [Leafy Grass](https://polyhaven.com/a/leafy_grass)
- [Wooden Rough Planks](https://polyhaven.com/a/wooden_rough_planks)
- [Fabric Pattern 07](https://polyhaven.com/a/fabric_pattern_07), variant 03 adapted as the sail canvas weave

Prepared GLBs and textures are supplied in the separately downloadable source asset pack. That pack does not include raw marketplace/source downloads or the original development Blender working files.

## Original project work

The simplified city geometry and architecture, three boat hulls and rigs, tackle and fish, route choreography, gameplay, NPC dialogue, delivery quest, small economy, map, shaders, crest, compass, and remaining props were developed for this demo with Codex assistance. The boats are not models extracted from another game. Third-party character, tree, furnishing, and material contributions are identified above.

The journal background is a generated project asset; the pack, journal cover, and compass use vector/code artwork. There are no extracted UO character or building sprites in the rendered scene.

## Tools, font, and runtime notices

- **[Godot Engine](https://godotengine.org/)**, 4.7.2 stable, Forward+ renderer. Credit to Juan Linietsky, Ariel Manzur, and Godot Engine contributors. Its MIT license and bundled third-party notices are in [docs/licenses](docs/licenses/).
- **[Blender](https://www.blender.org/)**, 5.2.1 LTS, used through its Python API to build and prepare models. Credit to the Blender Foundation and Blender contributors. Blender itself is not bundled in the playable release.
- **[Cormorant Garamond](https://fonts.google.com/specimen/Cormorant+Garamond)**, SIL Open Font License; see `docs/licenses/OFL.txt`. Interface text uses the operating system's Segoe UI when available; no Microsoft font file is redistributed.
- **[Three.js](https://github.com/mrdoob/three.js)** example `waternormals.jpg`, used as the water normal texture, with its MIT license in `docs/licenses/THREE.txt`.
- **NumPy** was used during development for synthesized audio and validation. It is not required to run the executable.
- **FFmpeg** was used for development film editing and verification. It is not bundled with or required by the game.

All licenses apply to their respective components. See [LICENSE.md](LICENSE.md) for the scope of the public project and personal-play permission.
