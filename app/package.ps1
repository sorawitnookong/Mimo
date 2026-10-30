# Collects Mimo and everything the receiver needs into dist\Mimo, then builds dist\Mimo-Setup.exe.
# Needs a finished build-fit\uxplay.exe, and Inno Setup 6 for the last step.
$ErrorActionPreference = 'Stop'
$app = $PSScriptRoot
$root = Split-Path $app -Parent
$msys = 'C:\msys64\ucrt64'
$dist = Join-Path $root 'dist\Mimo'
$receiver = Join-Path $dist 'receiver'
$bin = Join-Path $receiver 'bin'
$plugins = Join-Path $receiver 'lib\gstreamer-1.0'
$scanner = Join-Path $receiver 'libexec\gstreamer-1.0'

# GStreamer plugins used by the uxplay video, audio and HLS pipelines
$pluginNames = 'coreelements', 'app', 'typefindfunctions', 'playback', 'autodetect', 'videoconvertscale',
    'videoparsersbad', 'videofilter', 'libav', 'd3d11', 'd3d12', 'audioconvert', 'audioresample', 'volume',
    'audioparsers', 'wasapi', 'wasapi2', 'directsound', 'jpeg', 'imagefreeze', 'pango', 'isomp4',
    'adaptivedemux2', 'hls', 'soup', 'opus', 'level', 'debug', 'rtp', 'udp'

if (Test-Path $dist) { Remove-Item $dist -Recurse -Force -Confirm:$false }
New-Item -ItemType Directory -Force $bin, $plugins, $scanner, (Join-Path $receiver 'assets') | Out-Null

& (Join-Path $app 'build.ps1')
Copy-Item (Join-Path $root 'Mimo.exe'), (Join-Path $root 'LICENSE') $dist
Copy-Item (Join-Path $app 'vendor\*.dll') $dist
New-Item -ItemType Directory -Force (Join-Path $dist 'app') | Out-Null
Copy-Item (Join-Path $app 'ui') (Join-Path $dist 'app\ui') -Recurse
& (Join-Path $app 'get-scrcpy.ps1')
Copy-Item (Join-Path $root 'scrcpy') (Join-Path $dist 'scrcpy') -Recurse
Copy-Item (Join-Path $root 'assets\mimo.ico') (Join-Path $receiver 'assets')
Copy-Item (Join-Path $root 'build-fit\uxplay.exe') $bin
Copy-Item (Join-Path $msys 'libexec\gstreamer-1.0\gst-plugin-scanner.exe') $scanner

$queue = New-Object System.Collections.Generic.Queue[string]
$queue.Enqueue((Join-Path $bin 'uxplay.exe'))
$queue.Enqueue((Join-Path $scanner 'gst-plugin-scanner.exe'))
foreach ($name in $pluginNames) {
    $plugin = Join-Path $msys "lib\gstreamer-1.0\libgst$name.dll"
    if (Test-Path $plugin) {
        Copy-Item $plugin $plugins
        $queue.Enqueue((Join-Path $plugins "libgst$name.dll"))
    } else {
        Write-Warning "plugin not found: $name"
    }
}

# copy the DLLs these files depend on, and the DLLs those depend on
$seen = @{}
while ($queue.Count -gt 0) {
    $file = $queue.Dequeue()
    $names = & (Join-Path $msys 'bin\objdump.exe') -p $file | Select-String 'DLL Name: (.+)$' |
        ForEach-Object { $_.Matches[0].Groups[1].Value.Trim() }
    foreach ($name in $names) {
        $key = $name.ToLowerInvariant()
        if ($seen.ContainsKey($key)) { continue }
        $seen[$key] = $true
        $source = Join-Path $msys "bin\$name"
        if (Test-Path $source) {
            Copy-Item $source $bin
            $queue.Enqueue((Join-Path $bin $name))
        }
    }
}

$size = (Get-ChildItem $dist -Recurse -File | Measure-Object Length -Sum).Sum / 1MB
Write-Host ("Collected {0:N0} MB in dist\Mimo" -f $size)

$iscc = @("$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe", "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "$env:ProgramFiles\Inno Setup 6\ISCC.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $iscc) { throw 'Inno Setup 6 was not found.' }
& $iscc /Q (Join-Path $app 'mimo.iss')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Get-Item (Join-Path $root 'dist\Mimo-Setup.exe') | Select-Object Name, Length
