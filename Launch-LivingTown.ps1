param([switch]$Offline,[string]$GameArgs='')
$ErrorActionPreference='Stop'
$demoRoot=$PSScriptRoot
$gamePath=Join-Path $demoRoot 'Vesper.exe'
$helperPath=Join-Path $demoRoot 'helper/VesperTownHelper.exe'
$runtimeDir=Join-Path $env:LOCALAPPDATA ('VesperLivingTown/session-'+[Guid]::NewGuid().ToString('N'))
$connectionPath=Join-Path $runtimeDir 'connection.json'
$helperProcess=$null
$connection=$null
try {
    # Continue a previous journey in a separate folder; never overwrite either save.
    if ($GameArgs -notmatch '--qa|--town-film') {
        $oldJourneyDirectory=Join-Path $env:APPDATA 'Vesper Living Town'
        $previewJourneyDirectory=Join-Path $env:APPDATA 'Vesper Atmosphere Preview'
        New-Item -ItemType Directory -Force -Path $previewJourneyDirectory | Out-Null
        foreach($saveName in @('journey.json','settings.cfg','town_voice.cfg')) {
            $oldSave=Join-Path $oldJourneyDirectory $saveName
            $previewSave=Join-Path $previewJourneyDirectory $saveName
            if((Test-Path -LiteralPath $oldSave) -and !(Test-Path -LiteralPath $previewSave)) {
                Copy-Item -LiteralPath $oldSave -Destination $previewSave
            }
        }
    }
    if (!(Test-Path -LiteralPath $gamePath)){throw 'Vesper.exe is missing. Extract the entire Living Town ZIP before launching.'}
    New-Item -ItemType Directory -Force -Path $runtimeDir | Out-Null
    if (!$Offline -and (Test-Path -LiteralPath $helperPath)) {
        $helperProcess=Start-Process -FilePath $helperPath -ArgumentList ('--connection "'+$connectionPath+'"') -WorkingDirectory (Split-Path $helperPath) -WindowStyle Hidden -PassThru -RedirectStandardError (Join-Path $runtimeDir 'helper-error.log') -RedirectStandardOutput (Join-Path $runtimeDir 'helper.log')
        $deadline=(Get-Date).AddSeconds(20)
        while(!(Test-Path -LiteralPath $connectionPath) -and (Get-Date) -lt $deadline -and !$helperProcess.HasExited){Start-Sleep -Milliseconds 150}
        if(Test-Path -LiteralPath $connectionPath){$connection=Get-Content -LiteralPath $connectionPath -Raw | ConvertFrom-Json}
        else{Write-Host 'The town helper could not start. The game will use local rules and its included voice library. See the F3 developer view.'}
    }
    $info=New-Object System.Diagnostics.ProcessStartInfo
    $info.FileName=$gamePath;$info.WorkingDirectory=$demoRoot;$info.UseShellExecute=$false;$info.Arguments=$GameArgs
    $info.EnvironmentVariables.Remove('TYPESAFE_API_KEY')
    if($connection){$info.EnvironmentVariables['VESPER_HELPER_URL']=$connection.url;$info.EnvironmentVariables['VESPER_HELPER_TOKEN']=$connection.token}
    else{$info.EnvironmentVariables.Remove('VESPER_HELPER_URL');$info.EnvironmentVariables.Remove('VESPER_HELPER_TOKEN')}
    $gameProcess=[System.Diagnostics.Process]::Start($info)
    $gameProcess.WaitForExit()
} catch {
    Write-Host ('Living Vesper could not launch: '+$_.Exception.Message)
    Read-Host 'Press Enter to close'
} finally {
    if($helperProcess -and !$helperProcess.HasExited){
        if($connection){try{Invoke-RestMethod -Method Post -Uri ($connection.url+'/shutdown') -Headers @{'X-Vesper-Token'=$connection.token} -ContentType 'application/json' -Body '{"quit":true}' -TimeoutSec 2 | Out-Null}catch{}}
        if(!$helperProcess.WaitForExit(4000)){$helperProcess.Kill()}
    }
    if(Test-Path -LiteralPath $connectionPath){Remove-Item -LiteralPath $connectionPath}
}
