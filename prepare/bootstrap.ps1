param(
    [string]$Example = '',
    [string]$Manifest = (Join-Path $PSScriptRoot 'prepare-manifest.json'),
    [string]$Release = '',
    [string]$InstallRoot = '',
    [string]$Cache = '',
    [switch]$All
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Add-Type -AssemblyName System.Net.Http
Add-Type -AssemblyName System.IO.Compression.FileSystem

$utf8 = [Text.UTF8Encoding]::new($false)
$handler = [Net.Http.HttpClientHandler]::new()
$handler.AllowAutoRedirect = $false
$http = [Net.Http.HttpClient]::new($handler)
$http.Timeout = [TimeSpan]::FromSeconds(90)
$releaseCache = @{}
$verifiedPackages = @{}
$token = $env:GH_TOKEN
if (-not $token) { $token = $env:GITHUB_TOKEN }
$askedForToken = $false

function Get-PrepareHash([string]$Path) {
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Write-PrepareJson([string]$Path, $Value) {
    [IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth 20) + [Environment]::NewLine, $utf8)
}

function Get-PreparePath([string]$Root, [string]$Member) {
    $parts = $Member -split '[/\\]'
    if (-not $Member -or ($parts | Where-Object { -not $_ -or $_ -in '.', '..' -or $_ -match '[:*?"<>|\x00-\x1f]' })) {
        throw "Invalid relative path: $Member"
    }
    $base = [IO.Path]::GetFullPath($Root).TrimEnd('\') + '\'
    $resolved = [IO.Path]::GetFullPath((Join-Path $base ($parts -join '\')))
    if (-not $resolved.StartsWith($base, [StringComparison]::OrdinalIgnoreCase)) {
        throw "A path would leave the preparation folder: $Member"
    }
    $resolved
}

function Get-GitHubToken {
    $gh = Get-Command gh -CommandType Application -ErrorAction SilentlyContinue
    if ($gh) {
        $value = & $gh.Source auth token --hostname github.com 2>$null
        if ($LASTEXITCODE -eq 0 -and $value) { return $value.Trim() }
    }
    if (-not ('CrossPascal.PrepareCredential' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;

namespace CrossPascal {
    public static class PrepareCredential {
        private const string Target = "CrossPascal/GitHub/pisarev";

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        private struct Credential {
            public uint Flags, Type;
            public string TargetName, Comment;
            public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
            public uint BlobSize;
            public IntPtr Blob;
            public uint Persist, AttributeCount;
            public IntPtr Attributes;
            public string TargetAlias, UserName;
        }

        [DllImport("advapi32.dll", EntryPoint = "CredReadW", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern bool ReadCredential(string name, uint type, uint flags, out IntPtr address);

        [DllImport("advapi32.dll", EntryPoint = "CredWriteW", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern bool WriteCredential(ref Credential credential, uint flags);

        [DllImport("advapi32.dll", EntryPoint = "CredFree")]
        private static extern void FreeCredential(IntPtr address);

        public static string Read() {
            IntPtr address;
            if (!ReadCredential(Target, 1, 0, out address)) {
                int error = Marshal.GetLastWin32Error();
                if (error == 1168) return null;
                throw new Win32Exception(error);
            }
            try {
                Credential c = (Credential)Marshal.PtrToStructure(address, typeof(Credential));
                return Marshal.PtrToStringUni(c.Blob, checked((int)c.BlobSize / 2));
            } finally { FreeCredential(address); }
        }

        public static void Save(string token) {
            IntPtr blob = Marshal.StringToHGlobalUni(token);
            try {
                Credential c = new Credential {
                    Type = 1, TargetName = Target, Blob = blob, BlobSize = checked((uint)token.Length * 2),
                    Persist = 2, UserName = "github.com"
                };
                if (!WriteCredential(ref c, 0)) throw new Win32Exception(Marshal.GetLastWin32Error());
            } finally { Marshal.ZeroFreeGlobalAllocUnicode(blob); }
        }
    }
}
'@
    }
    $saved = [CrossPascal.PrepareCredential]::Read()
    if ($saved) { return $saved }
    Write-Host 'GitHub refused the anonymous request. Public downloads normally need no sign-in.'
    $secret = Read-Host 'Optional GitHub token for this run' -AsSecureString
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret)
    try { $value = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer).Trim() }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer) }
    if ($value -and (Read-Host 'Save it in Windows Credential Manager for other examples? [y/N]') -ieq 'y') {
        $script:saveToken = $true
    }
    $value
}

function Open-PrepareResponse([uri]$Uri, [string]$Accept = '', [long]$Start = 0) {
    $original = $Uri
    for ($hop = 0; $hop -le 8; $hop++) {
        if ($Uri.Scheme -cne 'https' -or $Uri.UserInfo) { throw 'Expected a secure HTTPS download URL.' }
        $request = [Net.Http.HttpRequestMessage]::new([Net.Http.HttpMethod]::Get, $Uri)
        try {
            $request.Headers.UserAgent.ParseAdd('CrossPascal-Prepare/1.0')
            $request.Headers.AcceptEncoding.ParseAdd('identity')
            if ($Accept) { $request.Headers.Accept.ParseAdd($Accept) }
            if ($Start) { $request.Headers.Range = [Net.Http.Headers.RangeHeaderValue]::new($Start, $null) }
            if ($Uri.Host -ceq 'api.github.com' -and $script:token) {
                $request.Headers.Authorization = [Net.Http.Headers.AuthenticationHeaderValue]::new('Bearer', $script:token)
            }
            $response = $http.SendAsync($request, [Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
        } finally {
            $request.Dispose()
        }
        $code = [int]$response.StatusCode
        if ($code -in 301, 302, 303, 307, 308) {
            try {
                if (-not $response.Headers.Location) { throw 'A download redirect omitted its destination.' }
                $Uri = [uri]::new($Uri, $response.Headers.Location)
            } finally { $response.Dispose() }
            continue
        }
        if ($code -in 401, 403, 404 -and $Uri.Host -ceq 'api.github.com') {
            $response.Dispose()
            if ($script:token -or $script:askedForToken) {
                throw 'GitHub denied access. Check the release URL or wait for the public request limit to reset.'
            }
            $script:askedForToken = $true
            $script:token = Get-GitHubToken
            if (-not $script:token) { throw 'Authenticated retry cancelled.' }
            $Uri = $original
            continue
        }
        if (-not $response.IsSuccessStatusCode) {
            $response.Dispose()
            throw [Net.Http.HttpRequestException]::new("The download returned HTTP $code.")
        }
        if ($script:saveToken -and $Uri.Host -ceq 'api.github.com') {
            [CrossPascal.PrepareCredential]::Save($script:token)
            $script:saveToken = $false
        }
        return $response
    }
    throw 'The download exceeded the redirect limit.'
}

function Read-PrepareResponse([uri]$Uri, [string]$Accept, [int]$Limit = 2097152) {
    $response = Open-PrepareResponse $Uri $Accept
    try {
        if ($response.Content.Headers.ContentLength -gt $Limit) { throw 'The release metadata is too large.' }
        $stream = $response.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
        $buffer = [byte[]]::new(8192)
        $body = [IO.MemoryStream]::new()
        try {
            while (($count = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
                if ($body.Length + $count -gt $Limit) { throw 'The release metadata is too large.' }
                $body.Write($buffer, 0, $count)
            }
            $utf8.GetString($body.ToArray()).TrimStart([char]0xfeff) | ConvertFrom-Json
        } finally { $body.Dispose(); $stream.Dispose() }
    } finally { $response.Dispose() }
}

function Get-GitHubRelease([string]$Repository, [string]$Tag) {
    if ($Repository -notmatch '^[\w.-]+/[\w.-]+$' -or $Tag -notmatch '^[\w.-]+$') { throw 'Invalid release address.' }
    $uri = "https://api.github.com/repos/$Repository/releases/tags/$Tag"
    if (-not $releaseCache.ContainsKey($uri)) {
        $releaseCache[$uri] = Read-PrepareResponse $uri 'application/vnd.github+json'
    }
    $releaseCache[$uri]
}

function Find-ReleaseAsset([string]$Repository, [string]$Tag, [string]$Name) {
    $assets = @((Get-GitHubRelease $Repository $Tag).assets | Where-Object name -CEQ $Name)
    if ($assets.Count -ne 1) { throw "The release does not contain the expected asset: $Name" }
    $assets[0]
}

function Get-AssetAddress($Asset) {
    if ($Asset.url) {
        $uri = [uri]$Asset.url
        if ($uri.Host -ceq 'api.github.com') { return @($uri, 'application/octet-stream') }
        return @($uri, '')
    }
    $releaseAsset = Find-ReleaseAsset $Asset.repository $Asset.release $Asset.name
    if ($releaseAsset.size -ne $Asset.bytes) { throw "The release asset size differs: $($Asset.name)" }
    if (-not $script:token -and $releaseAsset.browser_download_url) {
        return @([uri]$releaseAsset.browser_download_url, '')
    }
    @([uri]$releaseAsset.url, 'application/octet-stream')
}

function Test-AssetFile([string]$Path, $Asset) {
    (Test-Path -LiteralPath $Path -PathType Leaf) -and
        ((Get-Item -LiteralPath $Path).Length -eq [long]$Asset.bytes) -and
        ((Get-PrepareHash $Path) -ceq $Asset.sha256)
}

function Get-PrepareAsset($Asset) {
    if ($Asset.name -notmatch '^[\w.-]+$' -or $Asset.sha256 -notmatch '^[0-9a-f]{64}$' -or [long]$Asset.bytes -le 0) {
        throw 'Invalid preparation asset metadata.'
    }
    if ($Asset.path) {
        $local = Get-PreparePath (Split-Path -Parent $Manifest) $Asset.path
        if (-not (Test-AssetFile $local $Asset)) { throw "Local package failed verification: $local" }
        return $local
    }
    $file = Get-PreparePath $Cache $Asset.name
    if (Test-AssetFile $file $Asset) {
        Write-Host "Verified cached file: $($Asset.name)"
        return $file
    }
    $partial = "$file.partial"
    $address, $accept = Get-AssetAddress $Asset
    for ($attempt = 0; $attempt -lt 3; $attempt++) {
        $start = 0L
        if (Test-Path -LiteralPath $partial -PathType Leaf) { $start = (Get-Item -LiteralPath $partial).Length }
        if ($start -gt [long]$Asset.bytes) { Remove-Item -LiteralPath $partial; $start = 0L }
        if ($start -lt [long]$Asset.bytes) {
            if ($start) { Write-Host "Resuming $($Asset.name) from $start bytes" }
            else { Write-Host "Downloading $($Asset.name) ($($Asset.bytes) bytes)" }
            try {
                $response = Open-PrepareResponse $address $accept $start
                try {
                    $status = [int]$response.StatusCode
                    $mode = [IO.FileMode]::Create
                    $completed = 0L
                    if ($status -eq 206) {
                        if ($response.Content.Headers.ContentRange.From -ne $start) { throw 'Unexpected download range.' }
                        $mode = [IO.FileMode]::Append
                        $completed = $start
                    }
                    $inputStream = $response.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
                    $outputStream = [IO.File]::Open($partial, $mode, [IO.FileAccess]::Write, [IO.FileShare]::Read)
                    try {
                        $buffer = [byte[]]::new(1048576)
                        $timer = [Diagnostics.Stopwatch]::StartNew()
                        while (($count = $inputStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
                            $completed += $count
                            if ($completed -gt [long]$Asset.bytes) { throw 'A download exceeds its declared size.' }
                            $outputStream.Write($buffer, 0, $count)
                            if ($timer.Elapsed.TotalSeconds -ge 3) {
                                Write-Host ('  {0:0}%' -f (100.0 * $completed / [long]$Asset.bytes))
                                $timer.Restart()
                            }
                        }
                    } finally { $outputStream.Dispose(); $inputStream.Dispose() }
                    if ($completed -ne [long]$Asset.bytes) { throw [IO.IOException]::new('The download ended early.') }
                } finally { $response.Dispose() }
            } catch {
                if ($attempt -eq 2) { throw }
                if ($_.Exception -isnot [IO.IOException] -and $_.Exception.InnerException -isnot [IO.IOException] -and
                    $_.Exception -isnot [Net.Http.HttpRequestException] -and $_.Exception.InnerException -isnot [Net.Http.HttpRequestException]) { throw }
                Write-Host 'Connection interrupted. Retrying.'
                Start-Sleep -Seconds 2
                continue
            }
        }
        if (-not (Test-AssetFile $partial $Asset)) {
            Remove-Item -LiteralPath $partial
            throw "SHA-256 verification failed: $($Asset.name)"
        }
        Move-Item -LiteralPath $partial -Destination $file -Force
        return $file
    }
    throw "Download interrupted. Run Prepare.cmd again to resume $($Asset.name)."
}

function Expand-PrepareZip([string]$Archive, [string]$Destination) {
    $zip = [IO.Compression.ZipFile]::OpenRead($Archive)
    try {
        foreach ($entry in $zip.Entries) {
            $name = $entry.FullName.Replace('\', '/')
            $folder = $name.EndsWith('/')
            $target = Get-PreparePath $Destination $name.TrimEnd('/')
            $attributes = [IO.Compression.ZipArchiveEntry].GetProperty('ExternalAttributes')
            if ($attributes -and ((($attributes.GetValue($entry) -shr 16) -band 0xf000) -eq 0xa000)) {
                throw 'Archive links are not supported.'
            }
            if ($folder) { [void][IO.Directory]::CreateDirectory($target); continue }
            [void][IO.Directory]::CreateDirectory((Split-Path -Parent $target))
            [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $target, $false)
        }
    } finally { $zip.Dispose() }
}

function Invoke-PrepareArchiveTool([string]$Tool, [string[]]$Arguments) {
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = $Tool
    $info.Arguments = ($Arguments | ForEach-Object { '"' + $_ + '"' }) -join ' '
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $info.EnvironmentVariables.Remove('GH_TOKEN')
    $info.EnvironmentVariables.Remove('GITHUB_TOKEN')
    $child = [Diagnostics.Process]::Start($info)
    try {
        $read = $child.StandardOutput.ReadToEndAsync()
        $errors = $child.StandardError.ReadToEndAsync()
        $child.WaitForExit()
        $outputText = $read.GetAwaiter().GetResult()
        $errorText = $errors.GetAwaiter().GetResult()
        if ($child.ExitCode) { throw "Could not read or extract the model archive. $errorText" }
        $outputText
    } finally { $child.Dispose() }
}

function Expand-PrepareSevenZip([string]$Tool, [string]$Archive, [string]$Destination) {
    $listing = Invoke-PrepareArchiveTool $Tool @('l', '-slt', $Archive)
    $sections = $listing -split '(?m)^----------\r?$', 2
    if ($sections.Count -ne 2) { throw 'Could not verify model archive paths.' }
    foreach ($line in ($sections[1] -split '\r?\n')) {
        if ($line.StartsWith('Path = ')) { [void](Get-PreparePath $Destination $line.Substring(7)) }
        if ($line.StartsWith('Symbolic Link = ') -or $line.StartsWith('Hard Link = ')) {
            throw 'Archive links are not supported.'
        }
    }
    [void](Invoke-PrepareArchiveTool $Tool @('x', '-y', "-o$Destination", $Archive))
}

function Test-PackageIdentity($Recorded, $Expected) {
    if (-not $Recorded -or @($Recorded.PSObject.Properties).Count -ne $Expected.Count) { return $false }
    foreach ($name in $Expected.Keys) {
        if ($Recorded.PSObject.Properties[$name].Value -cne $Expected[$name]) { return $false }
    }
    $true
}

function Get-Package($Package, $Assets, [string]$SevenZip) {
    $destination = Get-PreparePath $InstallRoot $Package.directory
    if ($verifiedPackages.ContainsKey($destination)) { return $destination }
    if ($Package.id -notmatch '^[\w.-]+$') { throw 'Invalid preparation package identifier.' }
    $receiptFile = Get-PreparePath $InstallRoot ".receipts/$($Package.id).json"
    $identity = [ordered]@{}
    foreach ($name in $Package.assets) {
        $identity[$name] = $Assets.PSObject.Properties[$name].Value.sha256
    }
    if (Test-Path -LiteralPath $receiptFile -PathType Leaf) {
        $receipt = Get-Content -LiteralPath $receiptFile -Raw -Encoding UTF8 | ConvertFrom-Json
        if (Test-PackageIdentity $receipt.assets $identity) {
            Write-Host "Checking installed package: $($Package.title)"
            foreach ($pin in $receipt.files.PSObject.Properties) {
                $file = Get-PreparePath $destination $pin.Name
                if (Test-AssetFile $file $pin.Value) { continue }
                if (($Package.editable -ccontains $pin.Name) -and (Test-Path -LiteralPath $file -PathType Leaf)) {
                    Write-Host "Preserved local changes: $($pin.Name)"
                    continue
                }
                throw "Prepared files have changed. Preserve your work and choose a new installation folder: $destination"
            }
            $verifiedPackages[$destination] = $true
            return $destination
        }
    }
    if (Test-Path -LiteralPath $destination) { throw "Destination exists without a matching receipt: $destination" }
    $paths = @($Package.assets | ForEach-Object { Get-PrepareAsset $Assets.PSObject.Properties[$_].Value })
    if (-not $paths) { throw "The package has no assets: $($Package.id)" }
    $workspace = Get-PreparePath $InstallRoot ".extract-$($Package.id)"
    $marker = "$workspace.owner.json"
    if (Test-Path -LiteralPath $workspace) {
        $item = Get-Item -LiteralPath $workspace -Force
        if (-not $item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -or
            $item.FullName -ne $workspace -or
            $item.Parent.FullName -ne ([IO.Path]::GetFullPath($InstallRoot).TrimEnd('\')) -or
            -not (Test-Path -LiteralPath $marker -PathType Leaf) -or
            -not (Test-PackageIdentity (Get-Content -LiteralPath $marker -Raw -Encoding UTF8 | ConvertFrom-Json) $identity)) {
            throw "Unrecognized extraction folder already exists: $workspace"
        }
        Write-Host "Restarting extraction: $($Package.title)"
        Remove-Item -LiteralPath $workspace -Recurse -Force
    }
    Write-PrepareJson $marker $identity
    [void][IO.Directory]::CreateDirectory($workspace)
    Write-Host "Extracting $($Package.title)..."
    if ($Package.format -eq 'file') {
        Copy-Item -LiteralPath $paths[0] -Destination (Get-PreparePath $workspace (Split-Path -Leaf $paths[0]))
    } elseif ([IO.Path]::GetExtension($paths[0]) -ieq '.zip') {
        Expand-PrepareZip $paths[0] $workspace
    } else {
        Expand-PrepareSevenZip $SevenZip $paths[0] $workspace
    }
    $source = $workspace
    if ($Package.archive_root) { $source = Get-PreparePath $workspace $Package.archive_root }
    if (-not (Test-Path -LiteralPath $source -PathType Container)) { throw 'The expected package directory is missing.' }
    $pins = [ordered]@{}
    foreach ($file in Get-ChildItem -LiteralPath $source -File -Force -Recurse) {
        if ($file.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Archive links are not supported.' }
        $relative = $file.FullName.Substring($source.Length + 1).Replace('\', '/')
        $pins[$relative] = @{bytes = $file.Length; sha256 = Get-PrepareHash $file.FullName}
    }
    foreach ($name in $Package.required) {
        if (-not $pins.Contains($name)) { throw "A required package file is missing: $name" }
    }
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $destination))
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $receiptFile))
    $temporaryReceipt = "$receiptFile.partial"
    Write-PrepareJson $temporaryReceipt @{assets = $identity; files = $pins}
    [IO.Directory]::Move($source, $destination)
    try {
        Move-Item -LiteralPath $temporaryReceipt -Destination $receiptFile -Force
    } catch {
        [IO.Directory]::Move($destination, $source)
        throw
    }
    if ($source -ne $workspace -and (Test-Path -LiteralPath $workspace)) {
        [IO.Directory]::Delete($workspace)
    }
    Remove-Item -LiteralPath $marker
    $verifiedPackages[$destination] = $true
    $destination
}

function Copy-PreparedFile([string]$Source, [string]$Destination) {
    if (Test-Path -LiteralPath $Destination -PathType Leaf) {
        if ((Get-PrepareHash $Source) -cne (Get-PrepareHash $Destination)) {
            throw "A different dependency would be overwritten: $Destination"
        }
        return
    }
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $Destination))
    [IO.File]::Copy($Source, $Destination, $false)
}

function Install-Example($Row, $Document) {
    $needed = 0L
    $extract = 0L
    $split = $false
    foreach ($key in $Row.packages) {
        $pkg = $Document.packages.PSObject.Properties[$key].Value
        if (-not (Test-Path -LiteralPath (Get-PreparePath $InstallRoot $pkg.directory))) {
            $extract += [long]$pkg.extracted_bytes
        }
        foreach ($name in $pkg.assets) {
            $asset = $Document.assets.PSObject.Properties[$name].Value
            if (-not $asset.path -and -not (Test-Path -LiteralPath (Get-PreparePath $Cache $asset.name))) {
                $needed += [long]$asset.bytes
            }
        }
        if ($pkg.assets[0].EndsWith('.001')) { $split = $true }
    }
    $drive = [IO.DriveInfo]::new([IO.Path]::GetPathRoot($InstallRoot))
    if ($drive.AvailableFreeSpace -lt $needed + $extract + 1GB) {
        throw ('Not enough disk space. Allow about {0:0.0} GiB for this example.' -f (($needed + $extract + 1GB) / 1GB))
    }
    Write-Host ''
    Write-Host "Preparing $($Row.title)"
    Write-Host ('Download size for missing files: {0:0.00} GiB' -f ($needed / 1GB))
    if ($Row.requirements) { Write-Host $Row.requirements }
    $sevenZip = ''
    if ($split) { $sevenZip = Get-PrepareAsset $Document.sevenzip }
    $paths = [ordered]@{}
    foreach ($key in $Row.packages) {
        $paths[$key] = Get-Package $Document.packages.PSObject.Properties[$key].Value $Document.assets $sevenZip
    }
    $sdk = $paths['sdk']
    foreach ($key in $Row.packages) {
        foreach ($relative in $Document.packages.PSObject.Properties[$key].Value.overlay) {
            Copy-PreparedFile (Get-PreparePath $paths[$key] $relative) (Get-PreparePath $sdk $relative)
        }
    }
    $project = Get-PreparePath $sdk $Row.project
    $delphiFile = "$project.dproj"
    $lazarusFile = "$project.lpi"
    if (-not (Test-Path -LiteralPath $delphiFile -PathType Leaf) -or
        -not (Test-Path -LiteralPath $lazarusFile -PathType Leaf)) { throw 'The project files are missing.' }
    $projectFolder = Split-Path -Parent $project
    $folders = @($projectFolder)
    $delphi = [xml](Get-Content -LiteralPath $delphiFile -Raw -Encoding UTF8)
    $target = $delphi.SelectSingleNode('//*[local-name()="DCC_ExeOutput"]')
    if ($target -and $target.InnerText) {
        $output = $target.InnerText.Replace('$(Platform)', 'Win64').Replace('$(Config)', 'Release')
        $folders += [IO.Path]::GetFullPath((Join-Path $projectFolder $output))
    }
    $lazarus = [xml](Get-Content -LiteralPath $lazarusFile -Raw -Encoding UTF8)
    $target = $lazarus.SelectSingleNode('/CONFIG/CompilerOptions/Target/Filename')
    if ($target -and $target.GetAttribute('Value')) {
        $folders += Split-Path -Parent ([IO.Path]::GetFullPath((Join-Path $projectFolder $target.GetAttribute('Value'))))
    }
    $lines = @('[example]', "sdk = $sdk")
    foreach ($entry in $Row.defaults.PSObject.Properties) {
        $value = [string]$entry.Value
        foreach ($key in $paths.Keys) { $value = $value.Replace("{$key}", $paths[$key]) }
        $lines += "$($entry.Name) = $value"
    }
    $files = @()
    foreach ($folder in ($folders | Select-Object -Unique)) {
        if (-not ($folder.TrimEnd('\') + '\').StartsWith($sdk.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) {
            throw "Project output would leave the SDK: $folder"
        }
        [void][IO.Directory]::CreateDirectory($folder)
        $ini = Join-Path $folder ((Split-Path -Leaf $project) + '.prepared.ini')
        if (-not (Test-Path -LiteralPath $ini)) { [IO.File]::WriteAllLines($ini, [string[]]$lines, $utf8) }
        $files += $ini
        foreach ($relative in $Row.app_local) {
            $from = Get-PreparePath $sdk $relative
            Copy-PreparedFile $from (Get-PreparePath $folder (Split-Path -Leaf $from))
        }
    }
    [void][IO.Directory]::CreateDirectory((Join-Path $sdk 'results'))
    Write-Host ''
    Write-Host "READY: $($Row.title)"
    Write-Host "Delphi: open $delphiFile"
    Write-Host "Lazarus: open $lazarusFile"
    Write-Host "Build for Windows 64-bit, then Run. $($Row.next)"
    @{example = $Row.id; project = $project; defaults = $files; status = 'READY'}
}

try {
    $bootstrap = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'prepare-bootstrap.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if (-not $Release) { $Release = $bootstrap.release }
    if ($bootstrap.local_preview -and -not $PSBoundParameters.ContainsKey('Manifest') -and
        -not (Test-Path -LiteralPath $Manifest -PathType Leaf)) {
        $locationFile = Join-Path $PSScriptRoot 'prepare-location.json'
        if (-not (Test-Path -LiteralPath $locationFile -PathType Leaf)) {
            throw 'Start Prepare.cmd from the extracted native preview kit.'
        }
        $location = Get-Content -LiteralPath $locationFile -Raw -Encoding UTF8 | ConvertFrom-Json
        $Manifest = [string]$location.manifest
        if (-not (Test-Path -LiteralPath $Manifest -PathType Leaf)) {
            throw 'The native preview kit has moved. Run Prepare.cmd from its current folder.'
        }
        if (-not $InstallRoot) { $InstallRoot = $env:CROSSPASCAL_PREPARE_HOME }
        if (-not $InstallRoot) { $InstallRoot = $location.install_root }
        if (-not $Cache) { $Cache = $location.cache }
    }
    $Manifest = [IO.Path]::GetFullPath($Manifest)
    if (Test-Path -LiteralPath $Manifest -PathType Leaf) {
        $document = Get-Content -LiteralPath $Manifest -Raw -Encoding UTF8 | ConvertFrom-Json
    } else {
        $asset = Find-ReleaseAsset 'pisarev/crosspascal' $Release 'PREPARE-MANIFEST.json'
        if ($asset.size -gt 2097152) { throw 'The release preparation manifest is too large.' }
        $address = $asset.url
        $accept = 'application/octet-stream'
        if (-not $script:token -and $asset.browser_download_url) {
            $address = $asset.browser_download_url
            $accept = ''
        }
        $document = Read-PrepareResponse $address $accept
    }
    if ($document.schema -cne 'crosspascal.prepare.v1' -or $document.release -cne $Release) {
        throw 'The preparation manifest belongs to a different release.'
    }
    if (-not $InstallRoot) { $InstallRoot = $env:CROSSPASCAL_PREPARE_HOME }
    if (-not $InstallRoot) {
        $installName = $Release
        if ($bootstrap.install_directory) { $installName = $bootstrap.install_directory }
        if ($installName -notmatch '^[\w.-]+$' -or $installName -in '.', '..') { throw 'Invalid installation directory name.' }
        $InstallRoot = Join-Path $env:LOCALAPPDATA "CrossPascal/$installName"
    }
    $InstallRoot = [IO.Path]::GetFullPath($InstallRoot)
    if (-not $Cache) { $Cache = Join-Path (Split-Path -Parent $InstallRoot) 'downloads' }
    $Cache = [IO.Path]::GetFullPath($Cache)
    [void][IO.Directory]::CreateDirectory($InstallRoot)
    [void][IO.Directory]::CreateDirectory($Cache)
    if ($All) { $selected = @($document.examples) }
    else {
        if (-not $Example) {
            for ($i = 0; $i -lt $document.examples.Count; $i++) {
                Write-Host "$($i + 1). $($document.examples[$i].title)"
            }
            $Example = (Read-Host 'Choose an example').Trim()
            $number = 0
            if ([int]::TryParse($Example, [ref]$number) -and $number -ge 1 -and $number -le $document.examples.Count) {
                $Example = $document.examples[$number - 1].id
            }
        }
        $selected = @($document.examples | Where-Object id -CEQ $Example)
        if ($selected.Count -ne 1) { throw 'Choose a listed example.' }
    }
    foreach ($row in $selected) {
        foreach ($key in $row.packages) {
            $package = $document.packages.PSObject.Properties[$key].Value
            if ($package.license_notice) {
                Write-Host "$($package.title): $($package.license_notice)"
                Write-Host "Terms: $($package.license_url)"
            }
        }
    }
    $lock = [IO.File]::Open((Join-Path $Cache '.prepare.lock'), [IO.FileMode]::OpenOrCreate,
        [IO.FileAccess]::ReadWrite, [IO.FileShare]::ReadWrite)
    try {
        if ($lock.Length -eq 0) { $lock.WriteByte(0); $lock.Flush() }
        try { $lock.Lock(0, 1) }
        catch { throw 'Another preparation is using this cache. Wait for it to finish and try again.' }
        $results = @($selected | ForEach-Object { Install-Example $_ $document })
        if ($bootstrap.local_preview) {
            $sdk = Get-PreparePath $InstallRoot $document.packages.sdk.directory
            $locationFile = Get-PreparePath $sdk 'crosspascal/prepare/prepare-location.json'
            Write-PrepareJson "$locationFile.partial" @{manifest = $Manifest; install_root = $InstallRoot; cache = $Cache}
            Move-Item -LiteralPath "$locationFile.partial" -Destination $locationFile -Force
        }
        Write-PrepareJson (Join-Path $InstallRoot 'prepare-result.json') @{release = $Release; examples = $results}
    } finally { $lock.Dispose() }
    if ($results.Count -eq 1 -and $env:CROSSPASCAL_PREPARE_NO_OPEN -ne '1') {
        try { Invoke-Item -LiteralPath (Split-Path -Parent $results[0].project) }
        catch { Write-Warning 'The project is ready. Open its folder using the path printed above.' }
    }
    exit 0
} catch {
    Write-Host ''
    Write-Host ('Preparation failed: ' + $_.Exception.Message) -ForegroundColor Red
    exit 1
} finally {
    $http.Dispose()
}
