# Neighbours update — validation (2026-09-19)

**121 passing checks** across the corrected native town run (65), existing gameplay regression (50), and old-save/UI checks (6). Raw reports accompany this document in `neighbours-qa/`. Tests used Windows, Godot 4.7.2 Forward+, and the RTX 5070.

## Actual town observation

The corrected Windows executable ran for **483.5 seconds**. All **21 citizens completed at least 2 physical trips**. There were **136 arrivals**, no failed routes, no repaths and no fall recoveries. All starting capsules were tested clear of world geometry. Corin delivered fish, Elowen collected and delivered bread, Jory collected and delivered timber, and Bram collected and delivered remedies. Two meals consumed delivered supplies. A repeat bread errand was underway at the end; that second delivery was not observed completing.

The NPC walking regression sampled Elowen across multiple path cells: zero intermediate Idle frames and an animation clock beyond 0.65 seconds. Previously the cycle restarted roughly every third of a second. Garrick now starts at a clear aisle point instead of inside the counter.

The run recorded 11 nearby conversations and 17 utterances, with maximum queue depth 2 and no overlapping turns. Distant world interactions also occur without being globally audible. A dedicated speech-bus test measured **-25.2 dB nearby versus -200.0 dB outside the hearing range**. The remote subtitle disappeared. The original 237.277-second local Vesper recording loaded, and its independent volume control reached silence.

Mean frame interval was **13.36 ms**. Maximum was **143.0 ms**, including screenshot readbacks. Native recording and some verification ran concurrently; this is an observed development-machine measurement, not a hardware-independent performance guarantee.

## Jev and limits

The final bounded decision history retained 26 live Jev choices, with **489–712 ms** latency (mean **580 ms**), plus explicit rules fallbacks. Earlier live observation also verified crier notice selection and exposed eight people repeatedly choosing to remain at work. Staggered workplace rounds fixed that behaviour; the corrected run passed every citizen's physical-trip check.

Testing reached the then-configured **120-request daily limit**. The helper stopped online requests and the town continued moving, speaking from its authored library and fulfilling deliveries. The accumulated provider-reported estimate for the day's 120 requests was **$0.002698**; conservative reservations were higher. The delivered larger-cast configuration allows **360 requests/day with the same $0.01 spending ceiling**, and retains that day's ledger rather than resetting it. The first limit reached still stops calls. Helper protocol and accounting code are unchanged from the preceding tested milestone.

## Persistence and gameplay

The original normal living-town journey was copied to an isolated QA save and resumed. Inventory survived, the six-person save expanded to 21 citizens, Garrick was clear of furniture, and the original save remained byte-for-byte unchanged. A parcel reserves one existing plank, pays five gold once, and records a favour; repeated acceptance/delivery cannot duplicate it. The thank-you supper consumes one fish and one bread once. Reputation and remembered help survived restoration; a separate diagnostic also confirmed reputation written to and loaded from the journey file.

Existing gameplay checks passed with living citizens active: walking, museum delivery and reward, fishing, bank deposits/withdrawals and proximity, vendor purchases/sales, paperdoll, backpack, journal, map and view controls. Earlier v0.4 render/harbour/access reports remain historical evidence; they are not presented as freshly rerun for this update.

The notices and sound-settings screens were rendered and visually inspected. Long notices scroll inside their reading area. Music, city ambience, and town voices have separate controls.

## Recording

`Vesper-Neighbours-Showcase.mp4` is **115.1 seconds**, 1440×810 H.264, with 48 kHz stereo AAC. Six native camera shots measured **zero camera movement within each shot**. Editing selects actual speech and handoffs, preserves the game's audio, and uses short audio fades at cut edges. Capture uses explicitly labelled rules decisions for repeatability, authored state-selected dialogue, and locally generated Kokoro voices. It is not a live generative-dialogue demonstration.

The final mix measured **−22.2 dB mean / −1.4 dB peak**, with headroom. Local speech recognition recovered the exchanges; proper-name spellings in ASR are imperfect. Screenshots and subtitles were visually reviewed. Automated transcription and meter readings are not a claim of human headphone listening or universally natural pronunciation.

## Scope

Twenty-one citizens, seven reused synthetic voice identities and 178 authored voice clips; no unrestricted chatbot dialogue, microphone input, combat or multiplayer. Trade starter supplies are finite; fish and bread recur. Shopkeepers make nearby rounds rather than abandoning their businesses for long trips. The original public v0.3.2 release and prior local v0.4.0 build remain untouched.

## Packaged launcher

The final launcher passed 16 additional native checks, including actual voice playback, ocean ducking, subtitles, a paid player fish handoff, duplicate prevention and saved memory. It started and shut down its frozen helper cleanly. With the delivered 360-request configuration it made the next real Jev call without resetting the accumulated ledger: Jory selected the timber errand in 583 ms. No game or helper process remained afterward.

## Shutdown regression

A fresh-extraction smoke run exposed a shutdown-only warning when the game quit with HTTP coroutines still awaiting completion. Shutdown now cancels pending requests, resolves their waiting continuations, invalidates stale decisions and lets local voice polling observe shutdown before the scene is destroyed. A deterministic delayed-loopback test exited with **three requests in flight**, with no ObjectDB/resource leak warnings. No API key or provider call was used by that test.
