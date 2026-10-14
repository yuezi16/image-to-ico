$ErrorActionPreference = 'Stop'
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$automation = [System.Management.Automation.PowerShell].Assembly.Location
$output = Join-Path $PSScriptRoot '轻图标.exe'
& $compiler /nologo /target:winexe /platform:anycpu /optimize+ "/out:$output" /reference:System.Windows.Forms.dll "/reference:$automation" "/resource:$PSScriptRoot\ImageToIco.ps1,ImageToIco.ps1" "$PSScriptRoot\Program.cs"
if ($LASTEXITCODE -ne 0 -or !(Test-Path -LiteralPath $output)) { throw 'EXE build failed' }
Write-Output "PASS EXE build: $output"
