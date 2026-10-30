# Draws assets/mimo.png and assets/mimo.ico (run from anywhere with Windows PowerShell)
Add-Type -AssemblyName System.Drawing

function New-RoundedPath([single]$x, [single]$y, [single]$w, [single]$h, [single]$r) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $r * 2
    $path.AddArc($x, $y, $d, $d, 180, 90)
    $path.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
    $path.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
    $path.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
    $path.CloseFigure()
    return $path
}

$size = 1024
$bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'AntiAlias'
$g.TextRenderingHint = 'AntiAliasGridFit'
$g.Clear([System.Drawing.Color]::Transparent)

$blue = [System.Drawing.ColorTranslator]::FromHtml('#A9CCFF')
$pink = [System.Drawing.ColorTranslator]::FromHtml('#FFC6DA')
$midnight = [System.Drawing.ColorTranslator]::FromHtml('#29344B')

# background tile
$tile = New-RoundedPath 32 32 960 960 216
$tileBrush = New-Object System.Drawing.SolidBrush($blue)
$g.FillPath($tileBrush, $tile)

# mirrored phone behind
$ghost = New-RoundedPath 472 216 340 592 72
$ghostBrush = New-Object System.Drawing.SolidBrush($pink)
$g.FillPath($ghostBrush, $ghost)

# phone in front
$phone = New-RoundedPath 212 160 400 704 84
$white = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
$g.FillPath($white, $phone)

# M on the phone
$font = New-Object System.Drawing.Font('Segoe UI', 300, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$format = New-Object System.Drawing.StringFormat
$format.Alignment = 'Center'
$format.LineAlignment = 'Center'
$textRect = New-Object System.Drawing.RectangleF(212, 160, 400, 704)
$textBrush = New-Object System.Drawing.SolidBrush($midnight)
$g.DrawString('M', $font, $textBrush, $textRect, $format)
$g.Dispose()

$dir = $PSScriptRoot
$bmp.Save((Join-Path $dir 'mimo.png'), [System.Drawing.Imaging.ImageFormat]::Png)

# .ico with PNG images
$sizes = 16, 24, 32, 48, 64, 128, 256
$images = foreach ($s in $sizes) {
    $small = New-Object System.Drawing.Bitmap($s, $s, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $sg = [System.Drawing.Graphics]::FromImage($small)
    $sg.InterpolationMode = 'HighQualityBicubic'
    $sg.PixelOffsetMode = 'HighQuality'
    $sg.DrawImage($bmp, 0, 0, $s, $s)
    $sg.Dispose()
    $ms = New-Object System.IO.MemoryStream
    $small.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    $small.Dispose()
    , $ms.ToArray()
}
$out = New-Object System.IO.MemoryStream
$w = New-Object System.IO.BinaryWriter($out)
$w.Write([uint16]0); $w.Write([uint16]1); $w.Write([uint16]$sizes.Count)
$offset = 6 + 16 * $sizes.Count
for ($i = 0; $i -lt $sizes.Count; $i++) {
    $s = $sizes[$i]
    $b = if ($s -ge 256) { 0 } else { $s }
    $w.Write([byte]$b); $w.Write([byte]$b); $w.Write([byte]0); $w.Write([byte]0)
    $w.Write([uint16]1); $w.Write([uint16]32)
    $w.Write([uint32]$images[$i].Length); $w.Write([uint32]$offset)
    $offset += $images[$i].Length
}
foreach ($image in $images) { $w.Write([byte[]]$image) }
$w.Flush()
[System.IO.File]::WriteAllBytes((Join-Path $dir 'mimo.ico'), $out.ToArray())
$bmp.Dispose()
