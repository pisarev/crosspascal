$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$compiler=if($env:BDS_BIN){Join-Path $env:BDS_BIN 'dcc64.exe'}else{
  Join-Path ${env:ProgramFiles(x86)} 'Embarcadero/Studio/37.0/bin/dcc64.exe'
}
if(-not(Test-Path -LiteralPath $compiler -PathType Leaf)){throw 'Delphi37 Win64 compiler missing'}
$scratch=if($env:CROSSPASCAL_PREVIEW_BUILD_ROOT){$env:CROSSPASCAL_PREVIEW_BUILD_ROOT}else{
  Join-Path ([IO.Path]::GetTempPath()) ('crosspascal-preview-'+[guid]::NewGuid().ToString('N'))
}
if(Test-Path -LiteralPath $scratch){throw 'Preview build output path must be new/empty'}
New-Item -ItemType Directory -Path $scratch -ErrorAction Stop|Out-Null
$source=Join-Path $root 'rtl-algorithms'
$units=Join-Path $source 'src'
$previousTemp=$env:TEMP;$previousTmp=$env:TMP
try {
  $env:TEMP=$scratch;$env:TMP=$scratch
  foreach($name in @('TestGeometry','TestDisjointSet')){
    $program=Join-Path $source ('tests/'+$name+'.dpr')
    & $compiler '-B' '-Q' '-NSSystem;System.Win;Winapi' ('-U'+$units) ('-NU'+$scratch) ('-E'+$scratch) $program
    if($LASTEXITCODE -ne 0){throw ($name+' compile failed '+$LASTEXITCODE)}
    $exe=Join-Path $scratch ($name+'.exe')
    if(-not(Test-Path -LiteralPath $exe -PathType Leaf)){throw ($name+' output missing')}
    $out=@(& $exe)
    if($LASTEXITCODE -ne 0){throw ($name+' native exit '+$LASTEXITCODE)}
    $match=@($out|Where-Object{$_ -match '^\s*PASSED\b'})
    if($match.Count -ne 1 -or $out[-1] -notmatch '^PASSED [1-9][0-9]*, FAILED 0$'){
      throw ($name+' incorrect smoke summary')
    }
    Write-Output ($name+' '+$out[-1])
  }
} finally {$env:TEMP=$previousTemp;$env:TMP=$previousTmp}
