> Historical v0.4.0 validation. See [Neighbours validation](NEIGHBOURS-VALIDATION.md) for the current update.

# Living Vesper validation â€” 19 September 2026

Tested on this Windows x64 machine with an RTX 5070, Godot 4.7.2 Forward+, and the exported Windows executable. The old public checkout remains at c9fdca0; the original journey file matches its pre-work SHA256. The experiment uses a separate save directory.

## Native checks

| Suite | Passed |
|---|---:|
| Living town | 28/28 |
| Packaged speech helper | 7/7 |
| Final subtitle and launcher smoke | 16/16 |
| Gameplay with living citizens | 41/41 |
| Physical routes | 9/9 |
| Harbor | 25/25 |
| Access | 109/109 |
| Render | 42/42 |
| Helper budget/failure unit tests | 8/8 |

The living-town run observed **444.8 seconds** after its initial interaction and persistence checks. Citizens completed 12 physical arrivals, two fish deliveries, the bread handoff and return report, and a meal consuming the delivered supplies. There were **0 failed routes, 0 falls requiring recovery, and no overlapping speech turns**. The maximum queued conversation count was 1. There were 14 played utterances. Crier delivery news was checked against the preceding report event.

After that run, visual review corrected subtitle anchoring and increased text legibility. The re-exported executable passed a targeted smoke run verifying on-screen speaker captions, audio ducking, the launcher, player commitments and saved memories. That UI-only correction did not change simulation rules. Its actual subtitle screenshot was inspected.

Mean measured frame interval: **13.36 ms** (approximately 75 frames/second). The largest interval was 143.3 ms; this measurement includes screenshot readbacks and transitions, so it is not a claim of zero stutter. One stale asynchronous choice was safely discarded after state changed.

Player promises conserve inventory and award exactly three gold once. Town memories and completed promises survive atomic save/load. The separate gameplay suite ran with living citizens enabled and covered fishing, bank deposits/withdrawals, shops, the original museum delivery, paperdoll, zoom and saving. All original physical-route, harbor, access and render checks passed.

## AI and voice measurements

The corrected run recorded **9 live Jev decisions**, averaging **594 ms**, range 525â€“641 ms. Provider-reported model: jev-1.13.0. The helper's cumulative development ledger at capture contained 32 requests, 16085 input tokens and an estimated **$0.00067557** at the checked input price. This is a development total, not a per-session quote. The separate initial API probe used 411 input tokens. Provider billing remains authoritative.

Defaults are 120 requests/day and a conservative $0.01/day reservation. Failed requests keep their reservation; successful requests settle to reported usage. A second helper cannot own the same ledger simultaneously. Unit checks exercised no-key fallback, hard request and spending limits, timeouts/backoff, invalid choices, oversized state, persisted accounting and reservation settlement. A deliberately unavailable loopback endpoint did not stop the town clock.

The separately packaged helper, run with Python environment variables removed and only Windows System32 on PATH, produced **4.71 seconds of uncached speech in 0.95 seconds**. Submission returned in 169 ms; the slowest status request during synthesis was 632 ms. PCM peaks stayed below clipping. The helper rejected unauthenticated and browser-origin requests, then exited cleanly and removed its connection file.

There are 72 included speech clips. NPC conversations and crier lines use authored, state-selected text, not live generated prose. Stock reports are built from actual kitchen counts and synthesized asynchronously on the local CPU. No other runtime language-model credential or speech subscription is required.

## Mix, visual review and limits

Following the user's report that the ocean masked voices, ambient water was reduced by 6 dB overall, with an additional approximately 18 dB reduction during nearby speech, smooth recovery, and a 2 dB voice gain increase. The native test verified the ducking state. Voice volume/mute controls and spatial range remain independent.

Actual screenshots were inspected, speech was played through the machine's audio output, and local transcription checked generated sentences. The user supplied listening feedback. The agent's tools did not provide perceptual audio input, so subjective naturalness and the final mix are not presented as independently certified by ear.

This is a bounded first version: six connected citizens, a finite bread errand, recurring fish work and meals, authored conversation topics, and retained memories. It is not unrestricted AI chat, an MMO, or a simulation tested over multiple days. The recording uses the same town with rules-driven action selection for reproducibility; live Jev operation is evidenced by the separate native test above. No assets or code from the reference video's private implementation were copied.

The distributable was scanned for the actual saved TypeSafe credential: none was found. The original release and saves remain separate. Asset sources, creators, licenses and model hashes are in LIVING-ASSET-MANIFEST.json; helper source and required source archives accompany the build.
