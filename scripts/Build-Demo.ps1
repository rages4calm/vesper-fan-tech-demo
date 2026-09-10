param([Parameter(Mandatory=$true)][string]$Godot)
$ErrorActionPreference = 'Stop'
$demoRoot = Split-Path -Parent $PSScriptRoot
if (!(Test-Path -LiteralPath (Join-Path $demoRoot 'godot/assets/vesper_city.glb'))) {
    throw 'Extract the matching Source-Assets ZIP into this repository first. See docs/BUILDING.md.'
}
$enginePath = (Get-Command $Godot -ErrorAction Stop).Source
New-Item -ItemType Directory -Force -Path (Join-Path $demoRoot 'build/Vesper') | Out-Null
& $enginePath --headless --path (Join-Path $demoRoot 'godot') --editor --import
if ($LASTEXITCODE -ne 0) { throw 'Godot import failed.' }
& $enginePath --headless --path (Join-Path $demoRoot 'godot') --export-release 'Windows Desktop' (Join-Path $demoRoot 'build/Vesper/Vesper.exe')
if ($LASTEXITCODE -ne 0) { throw 'Godot export failed. Install matching Windows export templates in Godot.' }
Copy-Item -LiteralPath (Join-Path $demoRoot 'README.md'),(Join-Path $demoRoot 'CREDITS.md'),(Join-Path $demoRoot 'LICENSE.md') -Destination (Join-Path $demoRoot 'build/Vesper')
Write-Output 'Built build/Vesper/Vesper.exe. Keep its PCK beside it.'
