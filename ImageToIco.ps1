param([switch]$LibraryOnly)

Add-Type -AssemblyName System.Drawing

function ConvertTo-Ico {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Destination,
        [int[]]$Sizes = @(16, 32, 48, 256),
        [ValidateSet('Fit', 'Crop', 'Stretch')][string]$Layout = 'Fit'
    )
    $Sizes = @($Sizes | Sort-Object -Unique)
    if (!$Sizes.Count -or @($Sizes | Where-Object { $_ -lt 16 -or $_ -gt 256 }).Count) {
        throw '图标尺寸必须在 16 到 256 之间。'
    }
    if ([IO.Path]::GetFullPath($Source) -eq [IO.Path]::GetFullPath($Destination)) {
        throw '输出路径不能与源图片相同。'
    }
    $original = $null
    $buffer = $null
    $writer = $null
    try {
        $original = [Drawing.Image]::FromFile($Source)
        $frames = @()
        foreach ($size in $Sizes) {
            $bitmap = New-Object Drawing.Bitmap($size, $size, ([Drawing.Imaging.PixelFormat]::Format32bppArgb))
            $graphics = [Drawing.Graphics]::FromImage($bitmap)
            $stream = New-Object IO.MemoryStream
            try {
                $graphics.Clear([Drawing.Color]::Transparent)
                $graphics.CompositingMode = [Drawing.Drawing2D.CompositingMode]::SourceCopy
                $graphics.CompositingQuality = [Drawing.Drawing2D.CompositingQuality]::HighQuality
                $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $graphics.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
                $target = New-Object Drawing.Rectangle(0, 0, $size, $size)
                $sourceRect = New-Object Drawing.Rectangle(0, 0, $original.Width, $original.Height)
                if ($Layout -eq 'Fit') {
                    $scale = [Math]::Min($size / $original.Width, $size / $original.Height)
                    $w = [Math]::Max(1, [int][Math]::Round($original.Width * $scale))
                    $h = [Math]::Max(1, [int][Math]::Round($original.Height * $scale))
                    $target = New-Object Drawing.Rectangle(([int](($size - $w) / 2)), ([int](($size - $h) / 2)), $w, $h)
                } elseif ($Layout -eq 'Crop') {
                    $edge = [Math]::Min($original.Width, $original.Height)
                    $sourceRect = New-Object Drawing.Rectangle(([int](($original.Width - $edge) / 2)), ([int](($original.Height - $edge) / 2)), $edge, $edge)
                }
                $attributes = New-Object Drawing.Imaging.ImageAttributes
                try {
                    $attributes.SetWrapMode([Drawing.Drawing2D.WrapMode]::TileFlipXY)
                    $graphics.DrawImage($original, $target, $sourceRect.X, $sourceRect.Y, $sourceRect.Width, $sourceRect.Height, [Drawing.GraphicsUnit]::Pixel, $attributes)
                } finally { $attributes.Dispose() }
                $bitmap.Save($stream, [Drawing.Imaging.ImageFormat]::Png)
                $frames += ,($stream.ToArray())
            } finally {
                $graphics.Dispose()
                $bitmap.Dispose()
                $stream.Dispose()
            }
        }
        $buffer = New-Object IO.MemoryStream
        $writer = New-Object IO.BinaryWriter($buffer)
        $writer.Write([uint16]0)
        $writer.Write([uint16]1)
        $writer.Write([uint16]$Sizes.Count)
        $offset = 6 + 16 * $Sizes.Count
        for ($i = 0; $i -lt $Sizes.Count; $i++) {
            $dimension = if ($Sizes[$i] -eq 256) { 0 } else { $Sizes[$i] }
            $writer.Write([byte]$dimension)
            $writer.Write([byte]$dimension)
            $writer.Write([byte]0)
            $writer.Write([byte]0)
            $writer.Write([uint16]1)
            $writer.Write([uint16]32)
            $writer.Write([uint32]$frames[$i].Length)
            $writer.Write([uint32]$offset)
            $offset += $frames[$i].Length
        }
        foreach ($frame in $frames) { $writer.Write([byte[]]$frame) }
        $writer.Flush()
        # CreateNew avoids overwriting an existing file, including a racing writer.
        $output = [IO.File]::Open($Destination, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write)
        try { $buffer.Position = 0; $buffer.CopyTo($output) } finally { $output.Dispose() }
    } finally {
        if ($writer) { $writer.Dispose() }
        if ($buffer) { $buffer.Dispose() }
        if ($original) { $original.Dispose() }
    }
}

function Get-FreeIconPath([string]$Folder, [string]$Name) {
    $candidate = Join-Path $Folder ($Name + '.ico')
    $number = 2
    while (Test-Path -LiteralPath $candidate) {
        $candidate = Join-Path $Folder ("$Name ($number).ico")
        $number++
    }
    return $candidate
}

function Read-SaveFolder([string]$SettingsPath) {
    try {
        if (Test-Path -LiteralPath $SettingsPath -PathType Leaf) {
            $settings = [IO.File]::ReadAllText($SettingsPath) | ConvertFrom-Json -ErrorAction Stop
            if ($settings.SaveFolder -is [string] -and
                (Test-Path -LiteralPath $settings.SaveFolder -PathType Container)) {
                return $settings.SaveFolder
            }
        }
    } catch { }
    return ''
}

function Write-SaveFolder([string]$SettingsPath, [string]$Folder) {
    if ([string]::IsNullOrWhiteSpace($Folder) -or !(Test-Path -LiteralPath $Folder -PathType Container)) {
        return
    }
    $resolvedFolder = (Resolve-Path -LiteralPath $Folder -ErrorAction Stop).ProviderPath
    $json = @{ SaveFolder = $resolvedFolder } | ConvertTo-Json
    [IO.File]::WriteAllText($SettingsPath, $json, (New-Object Text.UTF8Encoding($false)))
}

if ($LibraryOnly) { return }
$settingsDirectory = if ($PSScriptRoot) { $PSScriptRoot } else { [AppDomain]::CurrentDomain.BaseDirectory }
$settingsPath = Join-Path $settingsDirectory 'settings.json'
Add-Type -AssemblyName System.Windows.Forms
[Windows.Forms.Application]::EnableVisualStyles()
$form = New-Object Windows.Forms.Form
$form.Text = '轻图标 · 图片转 ICO'
$form.ClientSize = New-Object Drawing.Size(780, 610)
$form.MinimumSize = New-Object Drawing.Size(796, 649)
$form.MaximumSize = $form.MinimumSize
$form.StartPosition = 'CenterScreen'
$form.BackColor = [Drawing.Color]::FromArgb(247, 248, 251)
$form.Font = New-Object Drawing.Font('Microsoft YaHei UI', 10)
$form.AllowDrop = $true

function Add-Label($Text, $X, $Y, $Width, $Height = 28) {
    $control = New-Object Windows.Forms.Label
    $control.Text = $Text
    $control.SetBounds($X, $Y, $Width, $Height)
    $form.Controls.Add($control)
    return $control
}
function Add-Button($Text, $X, $Y, $Width, $Height = 36) {
    $control = New-Object Windows.Forms.Button
    $control.Text = $Text
    $control.SetBounds($X, $Y, $Width, $Height)
    $control.FlatStyle = 'Flat'
    $control.BackColor = [Drawing.Color]::White
    $form.Controls.Add($control)
    return $control
}
$title = Add-Label '轻图标' 26 20 240 40
$title.Font = New-Object Drawing.Font('Microsoft YaHei UI', 20, ([Drawing.FontStyle]::Bold))
$null = Add-Label '把图片变成图标。离线转换，保留透明背景。' 28 65 700
$add = Add-Button '＋ 添加图片' 28 108 135
$clear = Add-Button '清空列表' 174 108 110
$null = Add-Label '支持 JPG / PNG / BMP / GIF / TIFF，也可以拖入图片' 300 115 460
$list = New-Object Windows.Forms.ListBox
$list.SetBounds(28, 155, 465, 175)
$list.HorizontalScrollbar = $true
$list.IntegralHeight = $false
$form.Controls.Add($list)
$preview = New-Object Windows.Forms.PictureBox
$preview.SetBounds(516, 155, 236, 175)
$preview.BorderStyle = 'FixedSingle'
$preview.BackColor = [Drawing.Color]::FromArgb(229, 232, 239)
$preview.SizeMode = 'Zoom'
$form.Controls.Add($preview)
$null = Add-Label '图标尺寸（可多选）' 28 346 240
$checks = @()
$x = 28
foreach ($size in @(16, 24, 32, 48, 64, 128, 256)) {
    $check = New-Object Windows.Forms.CheckBox
    $check.Text = "$size"
    $check.Tag = $size
    $check.Checked = $size -in @(16, 32, 48, 256)
    $check.SetBounds($x, 378, 85, 26)
    $form.Controls.Add($check)
    $checks += $check
    $x += 99
}
$null = Add-Label '画面处理' 28 424 85
$layoutBox = New-Object Windows.Forms.ComboBox
$layoutBox.SetBounds(115, 420, 245, 32)
$layoutBox.DropDownStyle = 'DropDownList'
$layoutBox.Items.AddRange(@('完整显示 · 透明补边', '居中裁剪 · 铺满图标', '拉伸至正方形'))
$layoutBox.SelectedIndex = 0
$form.Controls.Add($layoutBox)
$separate = New-Object Windows.Forms.CheckBox
$separate.Text = '每个尺寸单独保存'
$separate.SetBounds(410, 423, 310, 28)
$form.Controls.Add($separate)
$null = Add-Label '保存到' 28 471 80
$folderBox = New-Object Windows.Forms.TextBox
$folderBox.SetBounds(115, 467, 524, 30)
$folderBox.Text = Read-SaveFolder $settingsPath
$form.Controls.Add($folderBox)
$browse = Add-Button '浏览…' 653 465 99 34
$convert = Add-Button '转换并保存' 28 517 220 46
$convert.BackColor = [Drawing.Color]::FromArgb(70, 92, 220)
$convert.ForeColor = [Drawing.Color]::White
$convert.Font = New-Object Drawing.Font('Microsoft YaHei UI', 11, ([Drawing.FontStyle]::Bold))
$status = Add-Label '默认合成一个多尺寸 ICO；同名文件自动编号。' 268 525 485 64

function Add-Images([string[]]$Paths) {
    foreach ($path in $Paths) {
        if ([IO.Path]::GetExtension($path).ToLowerInvariant() -in @('.jpg', '.jpeg', '.png', '.bmp', '.gif', '.tif', '.tiff')) {
            if (!$list.Items.Contains($path)) { $null = $list.Items.Add($path) }
        }
    }
    if ($list.Items.Count -and $list.SelectedIndex -lt 0) { $list.SelectedIndex = 0 }
    if ($list.Items.Count -and !$folderBox.Text) { $folderBox.Text = [IO.Path]::GetDirectoryName([string]$list.Items[0]) }
    $status.Text = "已添加 $($list.Items.Count) 张图片。GIF / TIFF 使用第一帧。"
}
$add.Add_Click({
    $dialog = New-Object Windows.Forms.OpenFileDialog
    try {
        $dialog.Title = '选择要转换的图片'
        $dialog.Filter = '图片文件|*.jpg;*.jpeg;*.png;*.bmp;*.gif;*.tif;*.tiff'
        $dialog.Multiselect = $true
        if ($dialog.ShowDialog() -eq 'OK') { Add-Images $dialog.FileNames }
    } finally { $dialog.Dispose() }
})
$form.Add_DragEnter({
    if ($_.Data.GetDataPresent([Windows.Forms.DataFormats]::FileDrop)) { $_.Effect = 'Copy' }
})
$form.Add_DragDrop({ Add-Images ($_.Data.GetData([Windows.Forms.DataFormats]::FileDrop)) })
$list.Add_SelectedIndexChanged({
    if ($preview.Image) { $preview.Image.Dispose(); $preview.Image = $null }
    if ($list.SelectedItem) {
        $sourceImage = $null
        try {
            $sourceImage = [Drawing.Image]::FromFile([string]$list.SelectedItem)
            $preview.Image = New-Object Drawing.Bitmap($sourceImage)
        } catch { $status.Text = '无法预览此图片，请确认文件完整。' }
        finally { if ($sourceImage) { $sourceImage.Dispose() } }
    }
})
$clear.Add_Click({
    $list.Items.Clear()
    if ($preview.Image) { $preview.Image.Dispose(); $preview.Image = $null }
    $status.Text = '列表已清空。'
})
$browse.Add_Click({
    $dialog = New-Object Windows.Forms.FolderBrowserDialog
    try {
        $dialog.Description = '选择 ICO 保存文件夹'
        if (Test-Path -LiteralPath $folderBox.Text -PathType Container) { $dialog.SelectedPath = $folderBox.Text }
        if ($dialog.ShowDialog() -eq 'OK') { $folderBox.Text = $dialog.SelectedPath }
    } finally { $dialog.Dispose() }
})
$convert.Add_Click({
    $selectedSizes = @($checks | Where-Object { $_.Checked } | ForEach-Object { [int]$_.Tag })
    if (!$list.Items.Count) { $status.Text = '请先添加图片。'; return }
    if (!$selectedSizes.Count) { $status.Text = '请至少选择一个尺寸。'; return }
    if (!(Test-Path -LiteralPath $folderBox.Text -PathType Container)) { $status.Text = '请选择已存在的保存文件夹。'; return }
    $convert.Enabled = $false
    $form.UseWaitCursor = $true
    $success = 0
    $errors = New-Object 'Collections.Generic.List[string]'
    try {
        $layout = @('Fit', 'Crop', 'Stretch')[$layoutBox.SelectedIndex]
        foreach ($path in $list.Items) {
            $name = [IO.Path]::GetFileNameWithoutExtension([string]$path)
            try {
                if ($separate.Checked) {
                    foreach ($size in $selectedSizes) {
                        $destination = Get-FreeIconPath $folderBox.Text ("${name}_${size}x${size}")
                        ConvertTo-Ico -Source $path -Destination $destination -Sizes @($size) -Layout $layout
                        $success++
                    }
                } else {
                    $destination = Get-FreeIconPath $folderBox.Text $name
                    ConvertTo-Ico -Source $path -Destination $destination -Sizes $selectedSizes -Layout $layout
                    $success++
                }
            } catch { $errors.Add("${name}: $($_.Exception.Message)") }
        }
        $status.Text = "已保存 $success 个 ICO。失败 $($errors.Count) 张图片。"
        if ($errors.Count) {
            $null = [Windows.Forms.MessageBox]::Show(($errors -join [Environment]::NewLine), '部分图片转换失败', 'OK', 'Warning')
        }
    } finally { $convert.Enabled = $true; $form.UseWaitCursor = $false }
})
$form.Add_FormClosing({
    try { Write-SaveFolder $settingsPath $folderBox.Text }
    catch {
        $null = [Windows.Forms.MessageBox]::Show('无法记住保存目录，请确认程序所在文件夹可写。', '设置保存失败', 'OK', 'Warning')
    }
})
$form.Add_FormClosed({ if ($preview.Image) { $preview.Image.Dispose() } })
$null = $form.ShowDialog()
$form.Dispose()
