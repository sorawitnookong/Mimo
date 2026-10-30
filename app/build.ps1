# Builds Mimo.exe in the project folder with the C# compiler included in Windows.
$ErrorActionPreference = 'Stop'
$app = $PSScriptRoot
$root = Split-Path $app -Parent
$csc = 'C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$vendor = Join-Path $app 'vendor'

& $csc /nologo /target:winexe /platform:x64 /optimize+ "/out:$root\Mimo.exe" "/win32icon:$root\assets\mimo.ico" `
    "/reference:$vendor\Microsoft.Web.WebView2.Core.dll" "/reference:$vendor\Microsoft.Web.WebView2.WinForms.dll" `
    /reference:System.Web.Extensions.dll /reference:System.Windows.Forms.dll /reference:System.Drawing.dll `
    "$app\Mimo.cs"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Copy-Item "$vendor\*.dll" $root -Force
