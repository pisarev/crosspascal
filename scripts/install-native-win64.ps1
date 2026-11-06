# Copyright (C) 2026 Yuriy Pisarev. MIT license; see LICENSE.
[CmdletBinding()]
param(
    [string]$OpenCVSource,
    [string]$LeptonicaSource,
    [string]$SdkRoot,
    [string]$Python,
    [string]$WslDistribution,
    [ValidateRange(1, 8)][int]$Jobs = 2
)

$ErrorActionPreference = 'Stop'
if (!$OpenCVSource -and !$LeptonicaSource) {
    throw 'Provide an extracted OpenCV or Leptonica native source asset.'
}
if (!$SdkRoot) {
    $SdkRoot = Join-Path $PSScriptRoot '../..'
}
$sdk = (Resolve-Path -LiteralPath $SdkRoot).Path
if (!$Python) {
    $Python = Join-Path $sdk 'runtime/python/python.exe'
}
if ($WslDistribution) {
    $wsl = Get-Command wsl.exe -CommandType Application | Select-Object -First 1 -ExpandProperty Source
}
else {
    $docker = Get-Command docker -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty Source
    if (!$docker) {
        throw 'Put the Windows Docker CLI on PATH, or specify -WslDistribution for a Linux Docker engine in WSL.'
    }
}

function Invoke-Checked([string]$Program, [string[]]$Arguments) {
    & $Program @Arguments
    if ($LASTEXITCODE) {
        throw "$Program failed with exit code $LASTEXITCODE."
    }
}

function Invoke-Docker([string[]]$Arguments) {
    if ($WslDistribution) {
        $ErrorActionPreference = 'Continue'
        & $wsl -d $WslDistribution --exec docker @Arguments
    }
    else {
        & $docker @Arguments
    }
}

function Invoke-DockerChecked([string[]]$Arguments) {
    Invoke-Docker $Arguments
    if ($LASTEXITCODE) {
        throw "Docker failed with exit code $LASTEXITCODE."
    }
}

function Convert-DockerPath([string]$WindowsPath) {
    if (!$WslDistribution) {
        return $WindowsPath
    }
    $ErrorActionPreference = 'Continue'
    $linuxPath = & $wsl -d $WslDistribution --exec wslpath -a $WindowsPath
    if ($LASTEXITCODE -or $linuxPath -notmatch '^/') {
        throw "The selected WSL distribution cannot access $WindowsPath."
    }
    return $linuxPath
}

$platform = Invoke-Docker @('info', '--format', '{{.OSType}}')
if ($LASTEXITCODE -or $platform -ne 'linux') {
    throw 'Start a Docker engine configured for Linux containers.'
}
$base = 'docker.io/library/ubuntu:22.04@sha256:e0f80c829509ef4df9e76bd8944eb7b8ec25cbb379b112a7f9448b2c77a77c9b'
$runId = [Guid]::NewGuid().ToString('N')
$work = Join-Path ([IO.Path]::GetTempPath()) "crosspascal-native-$runId"
New-Item -Path $work -ItemType Directory | Out-Null
Write-Host "Build files and output remain at $work"

$specs = @(
    @{ Name = 'opencv'; Source = $OpenCVSource; Library = 'crosscv.dll'; ExpectedJobs = 3; ContainerPath = '/opt/crosscv-win/bin/crosscv.dll' },
    @{ Name = 'leptonica'; Source = $LeptonicaSource; Library = 'leptonica-1.87.0.dll'; ExpectedJobs = 2; ContainerPath = '/output/leptonica-1.87.0.dll' }
)
foreach ($spec in $specs) {
    if (!$spec.Source) {
        continue
    }
    $source = (Resolve-Path -LiteralPath $spec.Source).Path
    $context = Join-Path $work $spec.Name
    Copy-Item -LiteralPath $source -Destination $context -Recurse
    $fetch = Join-Path $context 'tools/fetch-build-packages.py'
    $verify = Join-Path $context 'tools/verify-source.py'
    $packages = Join-Path $context 'build-packages'
    Invoke-Checked $Python @('-B', $verify, '--allow-build-packages')
    Invoke-Checked $Python @('-B', $fetch, '--output', $packages)
    Invoke-Checked $Python @('-B', $fetch, '--output', $packages, '--verify-only')
    Invoke-Checked $Python @('-B', $verify, '--allow-build-packages')

    $recipe = Join-Path $context 'Dockerfile.windows'
    $text = [IO.File]::ReadAllText($recipe)
    $workerToken = '$(nproc)'
    if ([regex]::Matches($text, [regex]::Escape($workerToken)).Count -ne $spec.ExpectedJobs) {
        throw "The pinned $($spec.Name) recipe changed."
    }
    [IO.File]::WriteAllText($recipe, $text.Replace($workerToken, [string]$Jobs))
    Invoke-Docker @('image', 'inspect', $base) *> $null
    if ($LASTEXITCODE) {
        Invoke-DockerChecked @('pull', '--platform', 'linux/amd64', $base)
    }
    $tag = "crosspascal-$($spec.Name):$runId"
    $build = @('build', '--platform', 'linux/amd64', '--pull=false', '--network=none',
        '-f', (Convert-DockerPath $recipe), '-t', $tag)
    if ($spec.Name -eq 'opencv') {
        $digest = & $Python -B (Join-Path $context 'tools/context-digest.py')
        if ($LASTEXITCODE -or $digest -cnotmatch '^[0-9a-f]{64}$') {
            throw 'Cannot verify the OpenCV build context.'
        }
        $build += @('--target', 'builder', '--build-arg', "CROSSCV_SOURCE_CONTEXT=$digest")
    }
    Invoke-DockerChecked ($build + (Convert-DockerPath $context))
    $container = Invoke-Docker @('create', $tag)
    if ($LASTEXITCODE -or $container -cnotmatch '^[0-9a-f]{64}$') {
        throw 'Cannot create an export container.'
    }
    $output = Join-Path $work $spec.Library
    try {
        Invoke-DockerChecked @('cp', "${container}:$($spec.ContainerPath)", (Convert-DockerPath $output))
    }
    finally {
        Invoke-DockerChecked @('rm', $container)
    }
    $directory = Join-Path $sdk "crosspascal-$($spec.Name)/bin"
    New-Item -Path $directory -ItemType Directory -Force | Out-Null
    $destination = Join-Path $directory $spec.Library
    $hash = (Get-FileHash -LiteralPath $output).Hash
    if (Test-Path -LiteralPath $destination) {
        if ((Get-FileHash -LiteralPath $destination).Hash -ne $hash) {
            throw "Use a clean SDK directory. A different library already exists at $destination."
        }
    }
    else {
        Copy-Item -LiteralPath $output -Destination $destination
    }
    Write-Host "$destination SHA-256 $hash"
}
