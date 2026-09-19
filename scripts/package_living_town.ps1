param([string]$Output='',[string]$BuildDirectory='build/LivingVesper')
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
$build=Join-Path $projectRoot $BuildDirectory
if(!(Test-Path (Join-Path $build 'Vesper.pck'))){throw 'Export the Godot Windows build first.'}
Copy-Item (Join-Path $projectRoot 'Launch-LivingTown.ps1'),(Join-Path $projectRoot 'Play Living Vesper.cmd'),(Join-Path $projectRoot 'CREDITS.md'),(Join-Path $projectRoot 'LICENSE.md') $build -Force
Copy-Item (Join-Path $projectRoot 'docs') $build -Recurse -Force
Copy-Item (Join-Path $projectRoot 'docs/LIVING-TOWN.md') (Join-Path $build 'README.md') -Force
$source=Join-Path $build 'helper-source/helper'
New-Item -ItemType Directory -Force $source | Out-Null
foreach($name in @('service.py','speech_engine.py','test_service.py','config.json','requirements.txt','requirements-lock.txt','LICENSE','BUILDING.md','source-archives')){
    Copy-Item (Join-Path $projectRoot ('helper/'+$name)) $source -Recurse -Force
}
New-Item -ItemType Directory -Force (Join-Path $build 'helper-source/scripts') | Out-Null
Copy-Item (Join-Path $projectRoot 'scripts/build_helper.ps1') (Join-Path $build 'helper-source/scripts') -Force
if($Output){
    & python -c 'import pathlib,sys,zipfile; root=pathlib.Path(sys.argv[1]); z=zipfile.ZipFile(sys.argv[2],"w",zipfile.ZIP_DEFLATED,compresslevel=5); [z.write(p,pathlib.Path("LivingVesper")/p.relative_to(root)) for p in root.rglob("*") if p.is_file()]; z.close()' $build $Output
    if($LASTEXITCODE){throw 'Archive creation failed'}
    $hash=(Get-FileHash -LiteralPath $Output -Algorithm SHA256).Hash.ToLowerInvariant()
    Set-Content -LiteralPath ($Output+'.sha256') -Value ($hash+'  '+(Split-Path -Leaf $Output))
}
