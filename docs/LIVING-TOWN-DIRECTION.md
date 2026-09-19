# Living Vesper experiment

The user explicitly authorized this expansion on September 19, 2026. The v0.3.2 release remains a historical fan tech demo. Its earlier no-expansion statements do not prohibit this separately saved single-player experiment. No MMO or commercial release is promised.

The goal is a playable town whose people work, keep commitments, notice nearby events, speak naturally, and generate truthful town news. Begin with six connected citizens rather than a crowd of disconnected chatbots. Keep fishing, banking, buying, selling, and the museum delivery intact.

## Architecture

- Godot owns navigation, collision, inventory, money, commitments, saves, observations, news provenance, audio ranges and turn-taking.
- Jev receives compact state plus valid actions at sensible intervals. It selects among them. Code revalidates a returned choice against the current actor revision. No API call per frame.
- Dialogue in this version is explicitly authored and selected from world state. This is not a generative conversation model. Live Jev decisions and rules fallback are distinguished in F3.
- Kokoro renders distinct synthetic voices locally. The included speech library makes first playback immediate; the helper also implements asynchronous cached synthesis for new utterances.
- A loopback helper reads the existing Windows USER credential, enforces daily request/spending reservations and network backoff, and logs latency and provider-reported usage. No key enters source or distributable files.
- The launcher manages its own helper and removes the TypeSafe key from the game process environment.

## References investigated

- Matt Shumer's [village clip](https://x.com/mattshumer_/status/2095596175705399482): inspected sampled frames and a locally transcribed 350–415 second excerpt. Visible: residents, work areas, resources, agent state overlay, and task-linked speech. The excerpt includes a failed crafting attempt and a promise to tell another resident. It does not establish the private implementation, model calls, cost, or memory design. Avoid reproducing its visibly repeated replies.
- [Official UO town-crier guide](https://uo.com/wiki/ultima-online-wiki/gameplay/the-town-crier/): news keyword, locations near banks/starting inns, service introductions, events, and quests. Vesper's crier stands by the Mint and distinguishes service notices from witnessed/reported simulation events.
- [TypeSafe HTTP API](https://docs.typesafe.ai/api.md), [Choice](https://docs.typesafe.ai/primitives/choice.md), [State](https://docs.typesafe.ai/concepts/state.md), and [function-calling cookbook](https://docs.typesafe.ai/cookbooks/function_calling.md) were read live before integration. Choice is action selection, not a text generator.
- [Kokoro official model card](https://huggingface.co/hexgrad/Kokoro-82M): Apache 2.0 weights, multiple synthetic voices. [kokoro-onnx](https://github.com/thewh1teagle/kokoro-onnx): MIT implementation. A typed-input adapter fixes the installed wrapper's integer speed input for the model's float input.

## Checkpoint

Branch `experiment/living-town` forks public commit `c9fdca077d9eecdb216dae5bfd3bc5aed52d485f`. The old executable, PCK, repository main, and original saves are preserved. Save snapshots are outside the repository under `artifacts/living-town/checkpoint-saves`. The experiment saves under `%APPDATA%/Vesper Living Town`.
