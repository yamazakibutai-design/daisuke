#Requires -Version 5.1
<#
.SYNOPSIS
    ローカル文字起こし（OpenAI Whisper + CUDA）を入れる。Mac にはできない「GPU で数分」の文字起こし。

.DESCRIPTION
    - venv: %USERPROFILE%\.venvs\whisper（Python 3.12）
    - torch は CUDA 12.8 ビルド（RTX 50 系 = Blackwell は cu128 以降が必須。cu126 だと GPU が使えない）
    - モデル large-v3-turbo（約 1.6GB）を初回に落とす
    - 使い方: .\ybj-whisper.ps1 <音声/動画ファイル>  → C:\YBJ\音源\文字起こし\<名前>\ に txt / srt / json

.PARAMETER Model
    既定 large-v3-turbo。精度重視なら large-v3（遅い）、軽いなら medium。
#>
[CmdletBinding()]
param([string]$Model = 'large-v3-turbo', [switch]$Recreate)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Write-Step { param([string]$Message) Write-Host "`n[*] $Message" -ForegroundColor Cyan }
function Write-Ok   { param([string]$Message) Write-Host "  OK   $Message" -ForegroundColor Green }
function Write-Err2 { param([string]$Message) Write-Host "  NG   $Message" -ForegroundColor Red }

$venv = Join-Path $env:USERPROFILE '.venvs\whisper'
$py   = Join-Path $venv 'Scripts\python.exe'
if ($Recreate -and (Test-Path $venv)) { Remove-Item -Recurse -Force $venv }

Write-Step "venv whisper (Python 3.12) -> $venv"
if (-not (Test-Path $py)) { & uv venv --python 3.12 $venv; if ($LASTEXITCODE) { Write-Err2 'venv 作成失敗'; exit 1 } }

Write-Step 'torch (CUDA 12.8) + openai-whisper  … 約 3GB、5〜10 分'
& uv pip install --python $py torch torchaudio --index-url https://download.pytorch.org/whl/cu128
if ($LASTEXITCODE) { Write-Err2 'torch 導入失敗'; exit 1 }
& uv pip install --python $py openai-whisper
if ($LASTEXITCODE) { Write-Err2 'whisper 導入失敗'; exit 1 }

Write-Step 'GPU 認識テスト'
$gpu = (& $py -c 'import torch;print(torch.cuda.is_available(), torch.cuda.get_device_name(0) if torch.cuda.is_available() else chr(45), torch.version.cuda)' 2>&1) -join ''
Write-Host "  $gpu"
if ($gpu -notmatch '^True') { Write-Err2 'CUDA が使えません。NVIDIA ドライバ 610 以上か、torch が cu128 かを確認'; exit 1 }
Write-Ok 'GPU で動きます'

Write-Step "モデル $Model を取得（初回のみ・約 1.6GB）"
& $py -c "import whisper; whisper.load_model('$Model'); print('model ok')"
if ($LASTEXITCODE) { Write-Err2 'モデル取得失敗'; exit 1 }

New-Item -ItemType Directory -Force -Path 'C:\YBJ\音源\文字起こし' | Out-Null
[Environment]::SetEnvironmentVariable('YBJ_VENV_WHISPER', $py, 'User')
[Environment]::SetEnvironmentVariable('YBJ_WHISPER_MODEL', $Model, 'User')
Write-Ok "環境変数 YBJ_VENV_WHISPER / YBJ_WHISPER_MODEL=$Model"
Write-Host @"

使い方:
  .\ybj-whisper.ps1 "D:\HKTRH\前\M9.MOV"
  .\ybj-whisper.ps1 "C:\YBJ\音源\会議.m4a" -Lang ja
  → C:\YBJ\音源\文字起こし\<ファイル名>\ に .txt / .srt / .json
Claude Code には「文字起こしして」で通じる（CLAUDE.md に書いてある）。
"@
