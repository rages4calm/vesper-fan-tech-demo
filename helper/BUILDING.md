# Local helper source

The helper's project code is GPL-3.0-or-later; see LICENSE. It is a separate process communicating with Godot over authenticated loopback HTTP. No credentials belong in this directory.

On Windows x64, install Python 3.14, create a virtual environment, and run:

```powershell
python -m venv .venv
.venv/Scripts/python.exe -m pip install -r requirements.txt
.venv/Scripts/python.exe -m unittest discover -s . -p test_service.py
```

The playable distribution includes the model files under `helper/models`. For a source build, obtain `kokoro-v1.0.onnx` and `voices-v1.0.bin` from https://github.com/thewh1teagle/kokoro-onnx/releases/tag/model-files-v1.1 and save them as `models/kokoro.onnx` and `models/voices.bin`. Their checksums and licenses are in the asset manifest. They can also be copied from the playable package. Do not download models from unrelated mirrors.

Run `service.py --connection <private-local-path>` for development. Treat the resulting connection file as a transient local credential; do not publish it. The packaged launcher's normal shutdown removes it.

The repository's `scripts/build_helper.ps1 -Python <venv-python>` builds an executable with PyInstaller and copies the models. The corresponding script accompanies this source package. PyInstaller has its documented bundling exception; its license does not relicense the bundled dependencies.

The installed eSpeak library reports **1.52.0**. Its source release is provided in `source-archives/espeak-ng-1.52.0.tar.gz`; the additional eSpeak snapshot and espeakng-loader archive preserve the loader's source/build references. The phonemizer-fork 3.3.1 source archive is also provided. Refer to those archives' build instructions and licenses to rebuild the phonemization components. Other dependency license notices and versions are under `docs/licenses/living-town` in the distribution. Exact installed dependency versions are recorded in `requirements-lock.txt`.

Only one helper may own a user's usage ledger at once. A second game can use included voices and rules until the first helper exits. The OS releases the lock after a crash. The daily request count and conservative cost reservations persist outside the game directory.
