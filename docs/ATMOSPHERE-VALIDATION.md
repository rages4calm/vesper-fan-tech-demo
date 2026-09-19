# Atmosphere 0.6 validation — 19 September 2026

Test machine: Windows, NVIDIA RTX 5070, Godot 4.7.2 Forward+. Tests use offline town rules; no new Jev API requests were needed. These results describe the local preview, not the public GitHub release.

## Native executable checks

- Gameplay: 50 checks passed, including banking, inventory, fishing, deliveries and vendor transactions.
- Render/doors: 42 checks passed, including door hysteresis, audio trigger state and all three lighting modes. This run used the Dummy audio driver; it is not a listening test.
- Access: 109 checks passed. Actual player walks reached public approaches, the north mainland, and both directions through harbor buildings to their docks.
- Town observation: eight minutes with all 21 citizens. Every citizen completed a physical trip; fish, bread, timber and remedies were delivered. No repeated route failures or water recoveries occurred during the observation. Conversation turns did not overlap and the maximum queued conversation count was two. Parcel duplication/payment and saved reputation/memory checks passed.
- The long-run suite passed 64 of 65 checks. Its one failure was an instantaneous audio peak sample (-82.2 dB nearby), which can land in a spoken pause. A dedicated follow-up measured the same real welcome recording over three-second windows: approximately -6.7 dB at 2 m, -11.0 dB at 12 m and -200 dB at 60 m. All three follow-up assertions passed. The long-run test now samples a window; the entire eight-minute run was not repeated solely for that test change.
- Final exported executable passed a fresh gameplay smoke run. Launcher PowerShell parsing succeeded. First-launch migration copied the old journey and settings byte-for-byte into the separate preview folder; original files remained unchanged.

## Visual inspection and recording

Reviewed native screenshots at six locations in daylight, golden hour and lantern night. Corrected initially green-looking prop timber, a barrel overlap and a lantern self-shadow artifact before export. New Blender geometry uses brown oak maps, existing furniture support and navigation exclusions.

Twenty-four aligned camera-pan comparisons on building surfaces had a maximum mean difference of 1.33/255 and maximum 99th-percentile difference of 9/255. At most 0.079% of sampled pixels differed by over 25/255. This is a targeted regression check, not a guarantee against every possible rendering artifact.

The short showcase is actual Godot Movie Maker footage with stationary cameras and cuts. It uses the included recorded synthetic speech and personal local music, not live Jev-generated dialogue. The welcome is deliberately queued for the shot. Audio was measured and checked with speech transcription; subjective voice quality was not assessed by a human listening session in this pass.

Concurrent QA/capture workloads make the collected frame rates unsuitable as a clean performance benchmark. No claim of locked frame rate is made.

## Evidence and limits

Raw reports, logs, before/after images and the capture source are retained in the outer workspace under `artifacts/atmosphere/`. The local delivery folder includes the preview film and selected screenshots.

This is an incremental art and lighting pass. It retains the stylized architecture, existing character meshes and existing behavior. New trade props are decorative. Live TypeSafe connectivity, network outages and fresh voice generation were not revalidated because their implementation is unchanged. Existing limits and fallback modes remain in effect.
