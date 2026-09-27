#Requires -Version 5.1
<#
.SYNOPSIS
    ComfyUI（ローカル画像生成・GPU）を C:\YBJ\_tools\ComfyUI に入れ、Claude Code から叩ける形にする

.DESCRIPTION
    - ComfyUI 公式の Windows ポータブル版（NVIDIA・torch cu128 以降同梱）を GitHub 最新リリースから取得
    - 7-Zip で展開（00_bootstrap.ps1 で導入済み）
    - 既定モデル: SDXL base 1.0（6.9GB・ログイン不要）。FLUX 等は後から models\checkpoints に足す
    - comfy\comfy_generate.py: プロンプト → PNG を API 経由で生成する小さなクライアント
    - start-comfy.ps1: サーバー起動（http://127.0.0.1:8188）

    API 代ゼロ・ネット不要でパースの下書きを量産できる。Mac（GPU なし）ではできない領域。

.PARAMETER SkipModel   モデルの取得を飛ばす
.PARAMETER Test        導入後にサーバーを起動して 1 枚生成して止める
#>
[CmdletBinding()]
param([switch]$SkipModel, [switch]$Test)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
function Write-Step { param([string]$Message) Write-Host "`n[*] $Message" -ForegroundColor Cyan }
function Write-Ok   { param([string]$Message) Write-Host "  OK   $Message" -ForegroundColor Green }
function Write-Err2 { param([string]$Message) Write-Host "  NG   $Message" -ForegroundColor Red }

$tools = 'C:\YBJ\_tools'
$root  = Join-Path $tools 'ComfyUI_windows_portable'
$comfy = Join-Path $root 'ComfyUI'
New-Item -ItemType Directory -Force -Path $tools | Out-Null
$7z = "$env:ProgramFiles\7-Zip\7z.exe"
if (-not (Test-Path $7z)) { Write-Err2 '7-Zip が無い: winget install 7zip.7zip'; exit 1 }

# ---------------------------------------------------------------- 本体
Write-Step 'ComfyUI ポータブル版（最新リリース）'
if (Test-Path (Join-Path $root 'run_nvidia_gpu.bat')) {
    Write-Ok "導入済み: $root"
} else {
    $rel = Invoke-RestMethod 'https://api.github.com/repos/comfyanonymous/ComfyUI/releases/latest' -UseBasicParsing
    $asset = $rel.assets | Where-Object { $_.name -match 'windows_portable_nvidia.*\.7z$' } | Select-Object -First 1
    if (-not $asset) { Write-Err2 'リリースに nvidia ポータブルが見つからない。https://github.com/comfyanonymous/ComfyUI/releases から手動で'; exit 1 }
    $archive = Join-Path $tools $asset.name
    Write-Host "  GET  $($asset.browser_download_url)  ($([math]::Round($asset.size/1MB)) MB)" -ForegroundColor DarkGray
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $archive -UseBasicParsing
    Write-Step '展開（数分）'
    & $7z x $archive "-o$tools" -y | Select-String -Pattern 'Everything is Ok|Error' | ForEach-Object { Write-Host "       $_" }
    if (-not (Test-Path (Join-Path $root 'run_nvidia_gpu.bat'))) { Write-Err2 '展開後の構成が想定と違う。C:\YBJ\_tools を確認'; exit 1 }
    Remove-Item $archive -Force
    Write-Ok "展開完了: $root"
}

# 同梱 torch が Blackwell (sm_120) を扱えるか
$pyEmb = Join-Path $root 'python_embeded\python.exe'
$tv = (& $pyEmb -c 'import torch;print(torch.__version__, torch.version.cuda, torch.cuda.is_available())' 2>&1) -join ''
Write-Host "  torch: $tv"
if ($tv -notmatch 'True$') { Write-Err2 '同梱 torch で CUDA が使えない。update\update_comfyui_and_python_dependencies.bat を実行して再確認'; }

# ---------------------------------------------------------------- モデル
if (-not $SkipModel) {
    Write-Step 'モデル SDXL base 1.0（6.9GB・初回のみ・10〜20 分）'
    $ck = Join-Path $comfy 'models\checkpoints\sd_xl_base_1.0.safetensors'
    if (Test-Path $ck) { Write-Ok '取得済み' } else {
        Invoke-WebRequest -Uri 'https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors' -OutFile $ck -UseBasicParsing
        if ((Get-Item $ck).Length -lt 6GB) { Remove-Item $ck; Write-Err2 'ダウンロードが不完全'; exit 1 }
        Write-Ok $ck
    }
}

# ---------------------------------------------------------------- クライアントと起動スクリプト
Write-Step 'クライアント配置'
Copy-Item (Join-Path $here 'comfy\comfy_generate.py') (Join-Path $tools 'comfy_generate.py') -Force
Copy-Item (Join-Path $here 'comfy\workflow_sdxl_t2i.json') (Join-Path $tools 'workflow_sdxl_t2i.json') -Force
@"
# ComfyUI サーバー起動（07_comfyui.ps1 が生成）。閉じるまで http://127.0.0.1:8188 で待ち受け
Set-Location '$root'
& '.\python_embeded\python.exe' -s ComfyUI\main.py --windows-standalone-build --listen 127.0.0.1 --port 8188 --output-directory 'C:\YBJ\パース\_comfy出力'
"@ | Set-Content (Join-Path $tools 'start-comfy.ps1') -Encoding UTF8
New-Item -ItemType Directory -Force -Path 'C:\YBJ\パース\_comfy出力' | Out-Null
[Environment]::SetEnvironmentVariable('YBJ_COMFY', $tools, 'User')
Write-Ok "$tools\start-comfy.ps1 / comfy_generate.py"

# ---------------------------------------------------------------- テスト
if ($Test) {
    Write-Step 'テスト生成（サーバー起動 → 1 枚 → 停止）'
    $p = Start-Process pwsh -ArgumentList '-NoProfile', '-File', (Join-Path $tools 'start-comfy.ps1') -PassThru -WindowStyle Minimized
    $ok = $false
    for ($i = 0; $i -lt 60; $i++) { Start-Sleep 2; try { Invoke-RestMethod 'http://127.0.0.1:8188/system_stats' -TimeoutSec 2 | Out-Null; $ok = $true; break } catch {} }
    if ($ok) {
        & $env:YBJ_VENV (Join-Path $tools 'comfy_generate.py') --prompt 'empty concert hall stage, wide shot, photoreal' --steps 12 --size 1024x576 --out 'C:\YBJ\パース\_comfy出力\test.png'
    } else { Write-Err2 'サーバーが起動しない。start-comfy.ps1 を手で起動してログを見る' }
    Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
}

Write-Host @"

使い方:
  1) サーバー: pwsh -File $tools\start-comfy.ps1   （起動したまま）
  2) 生成:     `$env:YBJ_VENV $tools\comfy_generate.py --prompt "..." --out C:\YBJ\パース\x.png
  ブラウザ UI: http://127.0.0.1:8188
Claude Code には「ComfyUI でパース案を 4 枚」で通じる（CLAUDE.md に書いてある）。
"@
