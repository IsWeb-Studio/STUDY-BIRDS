param([string]$FlutterSdk = 'C:\src\flutter')
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$flutter = Join-Path $FlutterSdk 'bin\flutter.bat'
if (!(Test-Path -LiteralPath $flutter)) { throw "Flutter SDK not found: $FlutterSdk" }
Push-Location $projectRoot
try {
    # Preserve generated caches on the roomier system drive. Junctions keep
    # Flutter/Gradle's expected project paths, without moving source or keys.
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $projectKey = ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($projectRoot.ToLowerInvariant())))).Replace('-', '').Substring(0, 12) }
    finally { $sha.Dispose() }
    $cacheRoot = Join-Path $env:LOCALAPPDATA "StudyBirds\build-cache\$projectKey"
    $cacheRoot = [IO.Path]::GetFullPath($cacheRoot)
    if (!$cacheRoot.StartsWith([IO.Path]::GetFullPath($env:LOCALAPPDATA) + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Invalid cache location' }
    New-Item -ItemType Directory -Path $cacheRoot -Force | Out-Null
    foreach ($relative in @('build', '.dart_tool\flutter_build')) {
        $source = [IO.Path]::GetFullPath((Join-Path $projectRoot $relative))
        $target = [IO.Path]::GetFullPath((Join-Path $cacheRoot $relative))
        if (!$source.StartsWith($projectRoot + '\', [StringComparison]::OrdinalIgnoreCase) -or !$target.StartsWith($cacheRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Cache path outside expected directory' }
        $entry = Get-Item -LiteralPath $source -Force -ErrorAction SilentlyContinue
        if ($entry -and ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint)) { continue }
        if ($entry) {
            if (Test-Path -LiteralPath $target) {
                # Keep earlier caches intact instead of merging or deleting.
                $target += '-' + [Guid]::NewGuid().ToString('N')
            }
            New-Item -ItemType Directory -Path (Split-Path $target) -Force | Out-Null
            Move-Item -LiteralPath $source -Destination $target
        } else {
            New-Item -ItemType Directory -Path $target -Force | Out-Null
        }
        New-Item -ItemType Directory -Path (Split-Path $source) -Force | Out-Null
        New-Item -ItemType Junction -Path $source -Target $target | Out-Null
    }
    & $flutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'Flutter dependency resolution failed' }
    & $flutter build apk --release --no-pub
    if ($LASTEXITCODE -ne 0) { throw 'Release build failed; check the first error above' }
    Write-Host "APK ready: $projectRoot\build\app\outputs\flutter-apk\app-release.apk"
} finally { Pop-Location }
