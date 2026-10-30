# Downloads the official scrcpy release into the scrcpy folder and checks its SHA-256 hash.
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$version = 'v5.0.1'
$hash = 'b12a2c4ee8be317422451fc7dcf8ee20a71b5ea7ef9ad73ddd825a25316227a5'
$target = Join-Path $root 'scrcpy'
if (Test-Path (Join-Path $target 'scrcpy.exe')) { return }

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$zip = Join-Path $env:TEMP "scrcpy-win64-$version.zip"
$url = "https://github.com/Genymobile/scrcpy/releases/download/$version/scrcpy-win64-$version.zip"
Invoke-WebRequest -UseBasicParsing $url -OutFile $zip
if ((Get-FileHash $zip -Algorithm SHA256).Hash -ne $hash.ToUpperInvariant()) {
    Remove-Item $zip -Confirm:$false
    throw 'The scrcpy download does not match its expected hash.'
}

$temp = Join-Path $env:TEMP "scrcpy-win64-$version"
if (Test-Path $temp) { Remove-Item $temp -Recurse -Force -Confirm:$false }
Expand-Archive $zip $temp
Move-Item (Join-Path $temp "scrcpy-win64-$version") $target
Remove-Item $temp -Recurse -Force -Confirm:$false
Remove-Item $zip -Confirm:$false
