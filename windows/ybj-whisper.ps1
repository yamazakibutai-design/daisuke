#Requires -Version 5.1
<#
.SYNOPSIS  音声/動画をローカル GPU で文字起こし → txt / srt / json
.EXAMPLE   .\ybj-whisper.ps1 "D:\HKTRH\前\M9.MOV"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)][string]$File,
    [string]$Lang = 'ja',
    [string]$Model = $(if ($env:YBJ_WHISPER_MODEL) { $env:YBJ_WHISPER_MODEL } else { 'large-v3-turbo' }),
    [string]$OutDir
)
$py = if ($env:YBJ_VENV_WHISPER) { $env:YBJ_VENV_WHISPER } else { Join-Path $env:USERPROFILE '.venvs\whisper\Scripts\python.exe' }
if (-not (Test-Path $py)) { Write-Error '06_whisper.ps1 を先に実行してください'; exit 1 }
if (-not (Test-Path $File)) { Write-Error "ファイルが無い: $File"; exit 1 }
$name = [IO.Path]::GetFileNameWithoutExtension($File)
if (-not $OutDir) { $OutDir = Join-Path 'C:\YBJ\音源\文字起こし' $name }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$sw = [Diagnostics.Stopwatch]::StartNew()
& $py -m whisper $File --model $Model --language $Lang --device cuda --fp16 True `
    --output_format all --output_dir $OutDir --verbose False
$sw.Stop()
if ($LASTEXITCODE) { Write-Error "whisper 失敗 (exit $LASTEXITCODE)"; exit $LASTEXITCODE }
Write-Host "完了 $([int]$sw.Elapsed.TotalSeconds) 秒 → $OutDir" -ForegroundColor Green
Get-ChildItem $OutDir | Select-Object Name, Length | Format-Table -AutoSize
