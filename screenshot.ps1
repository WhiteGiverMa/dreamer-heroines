Add-Type -AssemblyName System.Windows.Forms
Start-Sleep -Milliseconds 500
$screen = [System.Windows.Forms.Screen]::PrimaryScreen
$bmp = New-Object System.Drawing.Bitmap($screen.Bounds.Width, $screen.Bounds.Height)
$graphics = [System.Drawing.Graphics]::FromImage($bmp)
$graphics.CopyFromScreen($screen.Bounds.Location, [System.Drawing.Point]::Empty, $screen.Bounds.Size)
$bmp.Save("G:\dev\DreamerHeroines\.sisyphus\evidence\final-qa\screenshot-2560x1080.png")
$graphics.Dispose()
$bmp.Dispose()
