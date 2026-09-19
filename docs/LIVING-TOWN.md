# Play Living Vesper

This single-player experiment is included in the public 0.6.1 release. It is not an MMO or a promised full game. Current save folder: `%APPDATA%\Vesper Atmosphere Preview\`; older release saves remain separate.

Extract the entire folder and double-click **Play Living Vesper.cmd**. The launcher starts the local helper, launches Vesper, and shuts its helper down when the game exits. No Godot, Blender, Python installation, voice subscription, or new account is required for the packaged version.

## What to look for

Enter the town and listen for **Osric**, the blue-liveried crier beside the Mint square. He has a handbell and noticeboard. Shortly afterward, he asks **Elowen** to carry bread from **Lysa** to **Garrick**. Follow her over the bridges: the basket appears when she collects the loaves and disappears only after she hands them over. She returns to report the completed errand.

**Corin** works the waterfront with an animated fishing rod, lands fish, and can choose to carry them to the Marsh Hall. **Nessa**, a net mender, visits the square and seeks a meal. Garrick can serve her only when the kitchen actually has both fish and bread. Deliveries and meals change finite inventories. Merchants make short local rounds and return to their workplaces. Nine former background walkers now have names, occupations, destinations and voices.

Conversations happen when the participants meet; distance affects what you hear. The crier's notices are spaced apart. Completed-delivery news requires a report reaching him. The town does not broadcast knowledge to every person automatically.

## Talk and interact

- **WASD** to walk; **Shift** to run; mouse wheel to zoom; right-drag to turn the camera; **V** for closer traveller view.
- **E** near an NPC opens the existing interaction. Greetings are voiced. Existing banking, shopping, fishing, paperdoll and museum deliveries remain available.
- **Enter**, type, **Enter** to speak to the nearest citizen. Ask Osric **news**, **services**, or **work**.
- Near Garrick, say **work**, then **accept** to promise one fish. Return with a fish and say **deliver fish**. The handoff pays exactly three gold. **Remember** asks about that promise.
- Say **supplies** near Garrick for a newly synthesized spoken stock report. This needs the local helper, but no API payment; synthesis runs on your CPU.
- **Esc → Town voices** controls volume and mute. **F4** toggles voice mute; subtitles remain. Ocean ambience and music lower during nearby speech.
- **F3** opens the developer view: goals, last decision modes, memories, supplies, conversations, news, connection status, latency, usage and failures. This information stays out of the normal HUD.

## AI, speech and costs

**Jev chooses actions; it does not generate dialogue.** It receives compact character state, remembered observations and the current valid action set. Movement, rewards, supplies, permission checks and saves remain game code. An answer that becomes stale is rejected.

This version uses **authored, state-selected dialogue**, with 178 included synthetic speech recordings. It does not claim these are live generated sentences or unlimited chatbot conversations. Kokoro's distinct voices were generated locally. Dynamic stock reports use asynchronous local generation and a disk cache.

The helper reads `TYPESAFE_API_KEY` from the process environment or saved Windows USER environment. The key is never printed, committed, copied into the game folder or sent to the Godot process by the launcher. The helper binds only `127.0.0.1` on an available port, requires a random per-launch token, rejects browser-origin requests, and exposes only decision, voice, status and shutdown operations.

No TypeSafe key is required to explore or hear voices. Without a key, after a network failure, or after hitting the limits, ordinary rules keep citizens working. F3 labels that fallback explicitly. To avoid all online decisions, run `Launch-LivingTown.ps1 -Offline`, or set `ai_enabled` to `false` in `helper/config.json`.

Default limits in that file: **360 requests per day**, **$0.01 conservative daily spending reservation**, at least **8 seconds between requests**, and a **6-second network timeout** with increasing backoff. Limits can be lowered or raised. Raising them authorizes additional usage on your own account. Usage persists across launches, so restarting is not a way around the daily cap. Actual cost estimates use provider-reported input tokens at the checked price of $0.042 per million; output was listed as free. Check your provider dashboard for authoritative billing and current pricing. The request cap remains the hard count limit.

Kokoro speech and authored dialogue have **no service fee**. They consume local CPU, disk space and electricity. The demo uses no Astra runtime API and assumes nothing about a Codex subscription providing API access. A separate local generative model would add memory, latency and grounding work; it is not bundled or required for this deliberately bounded first version.

## Saves and troubleshooting

This version stores journeys under `%APPDATA%\Vesper Atmosphere Preview\`, separate from v0.3.2. Player items, bank contents, town supplies, commitments, relevant memories, positions, news and announcement history share the journey save. The old release and its saves are untouched.

Helper usage, latency records and cached speech are under `%LOCALAPPDATA%\VesperLivingTown\`. The credential is not stored there. An initial helper failure falls back to the included voice library; F3 shows the state. Missing game files usually mean only the EXE was copied instead of the entire archive.

This is a small simulation: 21 active citizens, bounded activities, authored conversational topics, no microphone, no combat and no multiplayer. Time advances during active play; pausing stops town activity. It does not simulate the town for days while closed. Background ambience is intentionally quieter than the original release to make nearby speech clear.

Bread deliveries can repeat when the tavern runs low, Lysa has baked more, and Elowen has finished her previous commitment. This is not a complete economic simulation. Corin can continue catching and delivering fish; Lysa's batches and Nessa's meals change tracked supplies. These limited occupations are the first playable slice, not a claim that every original NPC has autonomous reasoning or that dialogue is freely generated.

## Rebuilding and verification

Use the matching 0.6.1 source asset pack described in `BUILDING.md`; it includes the voice library. The helper's model downloads and build instructions are in `helper/BUILDING.md`. Build with Godot 4.7.2 and export the Windows Desktop preset; `scripts/package_living_town.ps1` assembles notices and corresponding helper source around the exported game.

For the new end-to-end check, launch with `-- --qa-town --qa-neighbours --qa-output=C:/your-writable-test-folder`. It observes more than seven minutes of activity and writes a JSON report. Existing `--qa --qa-living` checks gameplay with the new citizens active; the original route, harbor, access and render suites remain available. `--town-film` is camera choreography over an actual rules-driven simulation for reproducible recording, not a live-Jev showcase.

See [asset manifest](LIVING-ASSET-MANIFEST.json), [design and research](LIVING-TOWN-DIRECTION.md), [credits](../CREDITS.md), and the validation report supplied with the build.


## Neighbours update — 0.5.0

Garrick works in the tavern's clear aisle, away from the counter collision. Citizens consume path waypoints without restarting their walking animation at every grid cell. All 21 citizens use the same physical movement system. Shopkeepers take short local rounds; visitors cross town to the square, waterfront, tavern and museum. People greet each other only when nearby with a clear line of sight, keep memories and allow time between encounters.

Jory collects three planks from Tomas and carries them to Maren. Bram collects two jars of remedies from Anwen and takes them to Sella. Parcels appear in their hands, stocks transfer at the physical handoff, and they can return to report to Osric. These two trades use a finite starting supply; fish and bread have recurring production. Jev chooses eligible activities and, when nearby listeners are present, which verified notice the crier should read. Ready fish deliveries get scheduling priority. Rules keep the same world running offline.

Press **N** for the town notices, current supplies, your reputation and instructions for small jobs. Near Tomas, say **accept parcel**. Carry it to Maren and say **deliver parcel** to receive five gold. Garrick's fish job remains available. Fulfilling a job earns a remembered favour; after two, ask Garrick for **supper** when he has fish and bread. This one-time thank-you meal consumes real supplies. After three favours the notices call you a **Friend of Vesper**. Say **share news** near Osric to report your completed fish delivery. These new systems extend your existing experimental save; old releases remain separate.

### Your local soundtrack

The public package does not bundle the original UO recording. Use **Esc → Choose local music** for an OGG/WAV you are entitled to use; the README links the familiar Vesper archive. **Esc → Vesper music** adjusts it independently from voices and ocean ambience; zero mutes it. Speech lowers music and strongly lowers the ocean. An existing personal `music/Vesper.ogg` beside the EXE or `VESPER_MUSIC_PATH` is also supported. Music imported into your local save folder takes precedence.

The new recording uses fixed wide views and direct scene cuts. It records actual simulation and local speech, with explicit rules mode for repeatability. Camera movement within a shot is measured in the capture log. NPCs are not being dragged through a cinematic route.

The Neighbours update raises the request allowance from 120 to 360 for the larger cast while retaining the same $0.01 daily spending ceiling. The first limit reached still stops online calls; accumulated usage is preserved. Scheduled workplace rounds continue even when a model repeatedly chooses to keep working.
