#Requires -Version 5.1
<#
.SYNOPSIS
    WSL2 (Ubuntu) を導入し、帳票系スキル（LibreOffice 依存）を Windows でも回せるようにする

.DESCRIPTION
    2 段階。
      段階 A（管理者 PowerShell）: wsl --install -d Ubuntu → 再起動
      段階 B（通常 PowerShell）  : Ubuntu 初回起動でユーザー作成 → wsl-setup.sh を流す
                                  （LibreOffice / Noto CJK / Python venv / /mnt/c/YBJ リンク）

    これで xlsx/docx/pptx スキルの office/soffice.py（AF_UNIX 依存）が WSL 側で動き、
    estimate / invoice などの帳票が Windows 機だけで完結する。

.PARAMETER Stage
    'A' = WSL 本体の導入（要管理者・再起動）、'B' = Ubuntu 内のセットアップ、'auto' = 状態を見て判断（既定）
#>
[CmdletBinding()]
param([ValidateSet('auto', 'A', 'B')][string]$Stage = 'auto')

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

function Write-Step { param([string]$Message) Write-Host "`n[*] $Message" -ForegroundColor Cyan }
function Write-Ok   { param([string]$Message) Write-Host "  OK   $Message" -ForegroundColor Green }
function Write-Warn2 { param([string]$Message) Write-Host "  WARN $Message" -ForegroundColor Yellow }
function Write-Err2 { param([string]$Message) Write-Host "  NG   $Message" -ForegroundColor Red }

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$wslList = ((& wsl -l -q 2>&1) -join ' ') -replace "`0", ''
$hasUbuntu = $wslList -match 'Ubuntu'

if ($Stage -eq 'auto') { $Stage = if ($hasUbuntu) { 'B' } else { 'A' } }

if ($Stage -eq 'A') {
    Write-Step '段階 A: WSL2 + Ubuntu の導入'
    if ($hasUbuntu) { Write-Ok 'Ubuntu は導入済み。-Stage B に進んでください'; exit 0 }
    if (-not $isAdmin) {
        Write-Err2 '管理者権限が必要です。'
        Write-Host @'
  スタート → "PowerShell" を右クリック → 「管理者として実行」 → そこで:
    cd "$env:USERPROFILE\daisuke\windows"
    .\05_wsl.ps1 -Stage A
'@
        exit 1
    }
    & wsl --install -d Ubuntu 2>&1 | ForEach-Object { Write-Host "       $_" -ForegroundColor DarkGray }
    Write-Ok '導入手続き完了。'
    Write-Host @'

  次: パソコンを再起動 → 自動で Ubuntu の黒い画面が開き「Enter new UNIX username:」と聞かれる
      → 好きなユーザー名（例 daisu）と、パスワード（2 回）を入力
      → その画面を閉じて、通常の PowerShell で  .\05_wsl.ps1 -Stage B
'@
    exit 0
}

# ---------------------------------------------------------------- 段階 B
Write-Step '段階 B: Ubuntu 内のセットアップ（LibreOffice / フォント / Python）'
if (-not $hasUbuntu) { Write-Err2 'Ubuntu が見つかりません。先に -Stage A（管理者）を実行してください'; exit 1 }

$sh = Join-Path $here 'wsl\wsl-setup.sh'
# Windows パス → WSL パス（C:\Users\... → /mnt/c/Users/...）
$shWsl = (& wsl wslpath -a ($sh -replace '\\', '/')) -join ''
$homeWsl = (& wsl wslpath -a ($env:USERPROFILE -replace '\\', '/')) -join ''
if (-not $shWsl) { Write-Err2 'wslpath が動きません。Ubuntu の初回起動（ユーザー作成）が済んでいるか確認してください'; exit 1 }

Write-Host "  スクリプト: $shWsl" -ForegroundColor DarkGray
Write-Host '  sudo のパスワードを聞かれたら、Ubuntu で決めたパスワードを入力' -ForegroundColor DarkGray
& wsl -e bash -lc "bash '$shWsl' '$homeWsl'"
if ($LASTEXITCODE -ne 0) { Write-Err2 "wsl-setup.sh が失敗（終了コード $LASTEXITCODE）"; exit 1 }

Write-Step '検証'
# 引用符を PowerShell → bash に渡すと PS 5.1 で崩れるので、検証もファイルで渡す
$chk = (& wsl wslpath -a ((Join-Path $here 'wsl\wsl-check.sh') -replace '\\', '/')) -join ''
$v = (& wsl -e bash -lc "bash '$chk'" 2>&1) -join "`n"
Write-Host $v
if ($v -match 'WSL_CHECK_OK') {
    Write-Ok 'WSL 側で帳票スキルが動く状態です'
    Write-Host @'

  使い方（Claude Code に伝わっている。手で叩くなら）:
    wsl -e bash -lc 'source ~/.venvs/ybj/bin/activate && cd /mnt/c/YBJ && python3 <スクリプト>'
  Windows の C:\YBJ は WSL から /mnt/c/YBJ（~/YBJ でも可）、G: は /mnt/g
'@
} else { Write-Err2 '検証に失敗。上のログを確認' ; exit 1 }
