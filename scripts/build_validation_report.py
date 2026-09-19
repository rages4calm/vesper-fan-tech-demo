"""Assemble measured native QA evidence into the distributable documentation."""
import json,shutil,statistics,sys
from pathlib import Path

root=Path(__file__).resolve().parents[1]
artifacts=Path(sys.argv[1])
out=root/'docs/living-town-qa';out.mkdir(exist_ok=True)
town=json.loads((artifacts/'final/town-report.json').read_text(encoding='utf8'))
speech=json.loads((artifacts/'helper-final-qa-isolated/report.json').read_text(encoding='utf8'))
suites={'Living town':town['checks'],'Packaged speech helper':speech['checks']}
suites['Final subtitle and launcher smoke']=json.loads((artifacts/'subtitle-smoke/town-smoke-report.json').read_text(encoding='utf8'))
shutil.copy2(artifacts/'subtitle-smoke/town-smoke-report.json',out/'subtitle-smoke-report.json')
for name,folder in [('Gameplay with living citizens','gameplay'),('Physical routes','routes'),('Harbor','harbor'),('Access','access'),('Render','render')]:
    path=next((artifacts/('regression-'+folder)).glob('*report.json'))
    suites[name]=json.loads(path.read_text(encoding='utf8'))
    shutil.copy2(path,out/(folder+'-report.json'))
for source,target in [('final/town-report.json','town-report.json'),('helper-final-qa-isolated/report.json','helper-report.json'),('credential-scan.json','credential-scan.json')]:shutil.copy2(artifacts/source,out/target)
for name,checks in suites.items():
    if any(not x['pass'] for x in checks):raise RuntimeError(name+' has failed checks')
m=town['metrics'];latencies=[x['latency_ms'] for x in town['decisions'] if x['mode']=='live Jev'];usage=town['helper']['usage']
rows='\n'.join(f'| {name} | {len(checks)}/{len(checks)} |' for name,checks in suites.items())
text=f'''# Living Vesper validation — 19 September 2026

Tested on this Windows x64 machine with an RTX 5070, Godot 4.7.2 Forward+, and the exported Windows executable. The old public checkout remains at c9fdca0; the original journey file matches its pre-work SHA256. The experiment uses a separate save directory.

## Native checks

| Suite | Passed |
|---|---:|
{rows}
| Helper budget/failure unit tests | 8/8 |

The living-town run observed **{town['duration_seconds']:.1f} seconds** after its initial interaction and persistence checks. Citizens completed {m['arrivals']} physical arrivals, two fish deliveries, the bread handoff and return report, and a meal consuming the delivered supplies. There were **{m['failed_routes']} failed routes, {m['recoveries']} falls requiring recovery, and no overlapping speech turns**. The maximum queued conversation count was {m['max_queue']}. There were {m['utterances']} played utterances. Crier delivery news was checked against the preceding report event.

After that run, visual review corrected subtitle anchoring and increased text legibility. The re-exported executable passed a targeted smoke run verifying on-screen speaker captions, audio ducking, the launcher, player commitments and saved memories. That UI-only correction did not change simulation rules. Its actual subtitle screenshot was inspected.

Mean measured frame interval: **{m['frame_ms_sum']/m['frame_samples']:.2f} ms** (approximately {1000*m['frame_samples']/m['frame_ms_sum']:.0f} frames/second). The largest interval was {m['frame_max_ms']:.1f} ms; this measurement includes screenshot readbacks and transitions, so it is not a claim of zero stutter. One stale asynchronous choice was safely discarded after state changed.

Player promises conserve inventory and award exactly three gold once. Town memories and completed promises survive atomic save/load. The separate gameplay suite ran with living citizens enabled and covered fishing, bank deposits/withdrawals, shops, the original museum delivery, paperdoll, zoom and saving. All original physical-route, harbor, access and render checks passed.

## AI and voice measurements

The corrected run recorded **{len(latencies)} live Jev decisions**, averaging **{statistics.mean(latencies):.0f} ms**, range {min(latencies):.0f}–{max(latencies):.0f} ms. Provider-reported model: jev-1.13.0. The helper's cumulative development ledger at capture contained {int(usage['requests'])} requests, {int(usage['input_tokens'])} input tokens and an estimated **${usage['estimated_usd']:.8f}** at the checked input price. This is a development total, not a per-session quote. The separate initial API probe used 411 input tokens. Provider billing remains authoritative.

Defaults are 120 requests/day and a conservative $0.01/day reservation. Failed requests keep their reservation; successful requests settle to reported usage. A second helper cannot own the same ledger simultaneously. Unit checks exercised no-key fallback, hard request and spending limits, timeouts/backoff, invalid choices, oversized state, persisted accounting and reservation settlement. A deliberately unavailable loopback endpoint did not stop the town clock.

The separately packaged helper, run with Python environment variables removed and only Windows System32 on PATH, produced **{speech['duration_seconds']:.2f} seconds of uncached speech in {speech['synthesis']['generation_seconds']:.2f} seconds**. Submission returned in {speech['job_response_ms']} ms; the slowest status request during synthesis was {speech['max_status_ms']} ms. PCM peaks stayed below clipping. The helper rejected unauthenticated and browser-origin requests, then exited cleanly and removed its connection file.

There are 72 included speech clips. NPC conversations and crier lines use authored, state-selected text, not live generated prose. Stock reports are built from actual kitchen counts and synthesized asynchronously on the local CPU. No other runtime language-model credential or speech subscription is required.

## Mix, visual review and limits

Following the user's report that the ocean masked voices, ambient water was reduced by 6 dB overall, with an additional approximately 18 dB reduction during nearby speech, smooth recovery, and a 2 dB voice gain increase. The native test verified the ducking state. Voice volume/mute controls and spatial range remain independent.

Actual screenshots were inspected, speech was played through the machine's audio output, and local transcription checked generated sentences. The user supplied listening feedback. The agent's tools did not provide perceptual audio input, so subjective naturalness and the final mix are not presented as independently certified by ear.

This is a bounded first version: six connected citizens, a finite bread errand, recurring fish work and meals, authored conversation topics, and retained memories. It is not unrestricted AI chat, an MMO, or a simulation tested over multiple days. The recording uses the same town with rules-driven action selection for reproducibility; live Jev operation is evidenced by the separate native test above. No assets or code from the reference video's private implementation were copied.

The distributable was scanned for the actual saved TypeSafe credential: none was found. The original release and saves remain separate. Asset sources, creators, licenses and model hashes are in LIVING-ASSET-MANIFEST.json; helper source and required source archives accompany the build.
'''
(root/'docs/LIVING-TOWN-VALIDATION.md').write_text(text,encoding='utf8')
print(json.dumps({name:len(checks) for name,checks in suites.items()},indent=2))
