# Release 0.6.1 — water and living town

Tested on 19 September 2026 on Windows with an NVIDIA RTX 5070, Godot 4.7.2 Forward+.

## Water integration

Replaced the legacy single Three.js water normal with two unchanged MIT-licensed UnionBytes wave textures (512 and 1024 pixels) and its foam texture. The Vesper shader combines independently moving scales, modest long-wave displacement, distance-filtered fine detail, restrained depth-contact foam and the existing planar reflection technique. Reflection resolution increases from 720 x 405 to 1280 x 720 on High. Low disables the additional reflection viewport. License, original authors, exact upstream commit and file hashes are included in the manifests.

Reviewed twelve views across two camera projections, three lighting modes and two quality levels. Before/after runs on this machine stayed at the 75 FPS display cap: median frames around 13.33 ms. This is a capped comparison, not an uncapped benchmark or a minimum hardware guarantee. Final foam was reduced after visual review to avoid a continuous bright border.

The 18-second water preview is actual Godot Movie Maker output, using fixed cameras, scene cuts and the demo's original ambience. It does not contain original UO music or depict live Jev dialogue. Water, boats and reflections animate in-engine. Developer recording utilities were added after the executable export; gameplay sources are the tested export's implementation.

## Exported Windows checks

| Suite | Passed |
| --- | ---: |
| Gameplay with living citizens | 50 |
| Harbor boats, fishing poses and lookout interactions | 25 |
| Door and rendering regression | 42 |
| Public building, mainland and dock access | 109 |
| Eight-minute town observation and interaction checks | 65 |
| Helper request limits, failures and action validation (mocked network) | 8 |

All **291 native assertions** and **8 helper unit tests** passed. Standard-error logs were empty. The observation covered all 21 citizens completing trips, all four connected delivery types, bounded speech queues, turn-taking, parcel duplication prevention and saved reputation/memory. It found no repeated route failures during the observation. The offline public build also passed without an optional soundtrack. Near/far spoken audio measured approximately -5 dB / -200 dB using a windowed sample.

Twenty-four aligned building-wall pan comparisons found at most 0.051% of pixels differing by over 25/255, maximum mean difference 1.33/255 and maximum 99th-percentile difference 10/255. The water shader's animation does not add a moving overlay to buildings. These targeted image measurements are not a guarantee against every rendering artifact.

The packaged helper generated a new 4.907-second spoken sentence locally: 0.930 seconds of synthesis, 1.93 seconds total request-to-ready time, peak 0.574. It made zero model API requests and shut down cleanly. This is a functional measurement, not a new subjective voice-quality assessment. Live TypeSafe connectivity was not re-tested; this release does not change that integration.

Raw release checks are under `docs/validation/water-0.6.1/`. Earlier validation documents describe their named historical releases. Current source and Windows packages include corresponding licenses and helper source archives. No developer API key, runtime connection token, personal saves or original UO soundtrack are intentionally included.

## Scope

This release also brings the previously local living-town and atmosphere experiments to GitHub. It remains a small single-player fan tech demo, not a promised complete game. Water has no fluid simulation, swimming, refraction through a modeled seabed or new sailing controls. Normal/detail textures are not advertised as 4K. Existing personal music can still be imported with independent volume control.
