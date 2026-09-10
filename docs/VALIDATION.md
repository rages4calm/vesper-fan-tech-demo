# Release validation

The public v0.3.2 package is based on the previously tested 0.3.1 local demo. The public build changes audio packaging, local soundtrack import, save-folder isolation, and the fan-project notices.

On September 10, 2026, the exported Windows executable passed **226 automated checks** with exit code 0 and empty standard-error logs for every suite:

| Suite | Passed | Evidence |
| --- | ---: | --- |
| Gameplay, inventory, banking, quest, OGG/WAV import | 41 | [Report](validation/gameplay.json) |
| Physical walking routes | 9 | [Report](validation/routes.json) |
| Building access, doors, bridges, tree placement | 109 | [Report](validation/access.json) |
| Harbor vessels, crew, anglers, lookouts | 25 | [Report](validation/harbor.json) |
| Door behavior and rendering configuration | 42 | [Report](validation/render.json) |

The render suite also captured moving-camera frames and lighting views. These checks are not proof that every visual artifact is absent on every machine. References to original audio in inherited check labels mean this build's newly synthesized effects, not extracted UO recordings.

Native screenshots of the About panel and pause menu were inspected: credits and the local-music control fit correctly. A separate audio smoke test imported both OGG and WAV, then shut down without resource warnings. Gameplay and walking checks exercised actual player movement rather than only checking path existence.

SHA-256 of the tested binaries:

```text
99359dea689cfacb7477960c90411c5b5d0a54b26388138b08159cd13e4332a5  Vesper.exe
ab55e7305985f21137066b8770fd88c585ba1510a653035aca2595621e74b1e2  Vesper.pck
```

Both release ZIPs are checked for archive corruption and have external checksums in SHA256SUMS.txt. The source-assets manifest records individual asset hashes. Original UO audio and client files are excluded from these packages.

The development machine runs Windows with an NVIDIA RTX 5070. These checks do not establish compatibility or performance on every GPU. The executable is unsigned. Source assets and release downloads are supplied with SHA-256 checksums.
