# 轻图标 · Image to ICO

一个简约的 Windows 桌面图片转 ICO 工具。支持批量转换、多尺寸图标、透明背景和保存目录记忆，图片全程在本机处理，无需上传到网站。

## 使用方法

下载并解压 [Windows 版下载包](https://github.com/yuezi16/image-to-ico/raw/refs/heads/main/downloads/image-to-ico-v1.0.0.zip)，双击 `轻图标.exe` 即可使用，无需安装第三方依赖。请把程序放在可写的文件夹，以便保存目录设置。

双击 `轻图标.exe`，添加 JPG、PNG、BMP、GIF 或 TIFF 图片，勾选尺寸，选择保存文件夹，然后点击「转换并保存」。也可以把图片拖入窗口。原来的 `启动.cmd` 仍可使用。

## 功能

- 支持 JPG / JPEG、PNG、BMP、GIF 和 TIFF 图片，支持多选与拖入窗口。
- 提供图片预览，可选择 16、24、32、48、64、128、256 像素尺寸。
- 默认生成含 16、32、48、256 像素图像的一个 ICO 文件。
- 勾选「每个尺寸单独保存」可分别输出各尺寸。
- 「完整显示」保持比例并补透明边；「居中裁剪」取中间正方形；「拉伸」直接缩放。
- PNG 的透明背景会保留；JPG 不会自动抠图。GIF / TIFF 使用第一帧。
- 同名输出自动加编号，原图片和已有 ICO 不会被覆盖。
- 关闭窗口时记住有效的保存目录，下次启动自动恢复。设置位于程序旁的 `settings.json`；目录不存在或设置损坏时使用默认行为，输入无效路径不会覆盖上次有效设置。请把程序放在可写的文件夹。
- 使用 Windows PowerShell 5.1、.NET System.Drawing 和 Windows Forms；ICO 内图像采用 PNG 编码，适用于现代 Windows。

## 运行环境与限制

EXE 已内嵌转换脚本，可单独复制使用，不需要同目录的 PS1 文件。运行环境为 Windows 的 .NET Framework 4.x 和 Windows PowerShell 5.1。不支持 SVG、WebP、HEIC。JPG 等没有透明通道的图片不会自动去除背景。

## 从源码构建

重新打包：在 Windows PowerShell 中运行 `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\build.ps1`。无需下载第三方工具。

转换逻辑也可单独调用：

```powershell
. .\ImageToIco.ps1 -LibraryOnly
ConvertTo-Ico -Source 'D:\图片\样例.png' -Destination 'D:\图片\样例.ico' -Sizes 16,32,48,256
```
