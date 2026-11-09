param([string]$Example='')
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
try {
 $manifest=Get-Content -LiteralPath "$PSScriptRoot/prepare-bootstrap.json" -Raw -Encoding UTF8 | ConvertFrom-Json
 $cache=Join-Path $env:LOCALAPPDATA 'CrossPascal/bootstrap'
 if($env:CROSSPASCAL_PREPARE_BOOTSTRAP){$cache=$env:CROSSPASCAL_PREPARE_BOOTSTRAP}
 New-Item -ItemType Directory -Path $cache -Force | Out-Null
 $archive=Join-Path $cache $manifest.python.name
 if(-not (Test-Path -LiteralPath $archive) -or (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant() -ne $manifest.python.sha256){
  Write-Host 'Downloading the portable preparation runtime...'
  Invoke-WebRequest -UseBasicParsing -Uri $manifest.python.url -OutFile "$archive.partial"
  if((Get-FileHash -LiteralPath "$archive.partial" -Algorithm SHA256).Hash.ToLowerInvariant() -ne $manifest.python.sha256){throw 'The preparation runtime failed SHA-256 verification.'}
  Move-Item -LiteralPath "$archive.partial" -Destination $archive -Force
 }
 $pythonFolder=Join-Path $cache 'python-3.12.10'
 $python=Join-Path $pythonFolder 'python.exe'
 $pinsFile=Join-Path $cache 'python-3.12.10-files.json'
 $valid=$false
 if((Test-Path -LiteralPath $python) -and (Test-Path -LiteralPath $pinsFile)){
  $valid=$true
  $pins=Get-Content -LiteralPath $pinsFile -Raw | ConvertFrom-Json
  foreach($pin in $pins.PSObject.Properties){
   $file=Join-Path $pythonFolder $pin.Name
   if(-not (Test-Path -LiteralPath $file) -or (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant() -ne $pin.Value){$valid=$false;break}
  }
 }
 if(-not $valid){
  Expand-Archive -LiteralPath $archive -DestinationPath $pythonFolder -Force
  $pins=[ordered]@{}
  Get-ChildItem -LiteralPath $pythonFolder -File | ForEach-Object {$pins[$_.Name]=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()}
  $pins | ConvertTo-Json | Set-Content -LiteralPath $pinsFile -Encoding UTF8
 }
 $arguments=@('-I',"$PSScriptRoot/prepare.py",'--release',$manifest.release)
 if($Example){$arguments+=@('--example',$Example)}
 & $python @arguments
 $result=$LASTEXITCODE
 if($result -ne 0){throw "Preparation returned exit code $result."}
 exit 0
} catch {
 Write-Host ''
 Write-Host ('Preparation failed: '+$_.Exception.Message) -ForegroundColor Red
 exit 1
}
