param([Parameter(Mandatory=$true)][string]$Python)
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
& $Python -m PyInstaller --noconfirm --onedir --name VesperTownHelper --collect-all espeakng_loader --collect-all kokoro_onnx --collect-all phonemizer --collect-all onnxruntime --exclude-module soundfile --collect-all language_tags --collect-all segments --collect-all csvw --distpath (Join-Path $projectRoot 'helper/dist') --workpath (Join-Path $projectRoot 'helper/build') (Join-Path $projectRoot 'helper/service.py')
if($LASTEXITCODE){throw 'Helper build failed'}
$destination=Join-Path $projectRoot 'helper/dist/VesperTownHelper'
Copy-Item (Join-Path $projectRoot 'helper/config.json') $destination
Copy-Item (Join-Path $projectRoot 'helper/models') $destination -Recurse -Force
