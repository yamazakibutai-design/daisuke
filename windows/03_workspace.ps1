#Requires -Version 5.1
<#
.SYNOPSIS
    作業フォルダ・環境変数・Claude Code 用 CLAUDE.md・シェルの UTF-8 化

.DESCRIPTION
    Mac の ~/Desktop/YBJ に相当する場所を Windows では C:\YBJ に置く。
      - Desktop は OneDrive に取られていることが多く、数 GB の映像を置くと同期が暴れる
      - 日本語パスは動くが、ffmpeg / bpy / UE のログで化けやすいのでルートだけは ASCII に
    Mac がミラーしている Google Drive（G:）は「読む場所」。Windows からの成果物は C:\YBJ。
    Mac に渡したいものだけ G:\...\_from_windows に置く。

    やること:
      1. C:\YBJ 配下の作業フォルダを作る
      2. ユーザー環境変数を設定（YBJ_HOME / YBJ_SHARED / PYTHONUTF8 / PYTHONIOENCODING）
      3. git の日本語ファイル名対策
      4. PowerShell プロファイルを UTF-8 既定にする
      5. CLAUDE.windows.md を %USERPROFILE%\.claude\CLAUDE.md に配置（既存があれば末尾に追記）

.PARAMETER YbjHome
    作業ルート。既定 C:\YBJ。
.PARAMETER SharedRoot
    Google Drive 上の Mac ミラー（読む場所）。省略時は G: を探して推定する。
#>
[CmdletBinding()]
param(
    [string]$YbjHome = 'C:\YBJ',
    [string]$SharedRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

function Write-Step { param([string]$Message) Write-Host "`n[*] $Message" -ForegroundColor Cyan }
function Write-Ok   { param([string]$Message) Write-Host "  OK   $Message" -ForegroundColor Green }
function Write-Warn2 { param([string]$Message) Write-Host "  WARN $Message" -ForegroundColor Yellow }

# ---------------------------------------------------------------- 1. フォルダ

Write-Step "作業フォルダ: $YbjHome"
$dirs = @(
    '3D\ブレンダ', '3D\UE', '3D\図面入力',
    '図面', 'パース', 'パース\プロンプト保管', '演出シート',
    'リハ映像', '音源', '音響',
    'ClaudeOutput', '_中間ファイル_削除可'
)
foreach ($d in $dirs) {
    $p = Join-Path $YbjHome $d
    New-Item -ItemType Directory -Force -Path $p | Out-Null
    Write-Ok $p
}

# ---------------------------------------------------------------- 2. 共有元（Google Drive）

Write-Step 'Google Drive（Mac ミラー）の場所'
if (-not $SharedRoot) {
    foreach ($cand in @('G:\マイドライブ', 'G:\My Drive', 'G:\共有ドライブ', 'G:\Shared drives')) {
        if (Test-Path $cand) { $SharedRoot = $cand; break }
    }
}
if ($SharedRoot -and (Test-Path $SharedRoot)) {
    Write-Ok "共有元 = $SharedRoot"
    $fromWin = Join-Path $SharedRoot '_from_windows'
    New-Item -ItemType Directory -Force -Path $fromWin | Out-Null
    Write-Ok "Mac へ渡す箱 = $fromWin"
} else {
    Write-Warn2 'Google Drive が見つかりません。Google Drive をサインイン後、'
    Write-Host '       .\03_workspace.ps1 -SharedRoot "G:\マイドライブ" のように再実行してください。'
    $SharedRoot = ''
}

# ---------------------------------------------------------------- 3. 環境変数

Write-Step 'ユーザー環境変数'
$envs = [ordered]@{
    YBJ_HOME         = $YbjHome
    YBJ_SHARED       = $SharedRoot
    YBJ_VENV         = (Join-Path $env:USERPROFILE '.venvs\ybj\Scripts\python.exe')
    YBJ_VENV_BPY     = (Join-Path $env:USERPROFILE '.venvs\bpy311\Scripts\python.exe')
    # Windows Python は既定が cp932。これを UTF-8 に固定しないと open() で化ける・落ちる
    PYTHONUTF8       = '1'
    PYTHONIOENCODING = 'utf-8'
}
foreach ($k in $envs.Keys) {
    [Environment]::SetEnvironmentVariable($k, $envs[$k], 'User')
    Set-Item -Path "Env:$k" -Value $envs[$k]
    Write-Ok "$k = $($envs[$k])"
}

# ---------------------------------------------------------------- 4. git

Write-Step 'git の日本語対策'
if (Get-Command git -ErrorAction SilentlyContinue) {
    git config --global core.quotepath false      # 日本語ファイル名を \343\201... にしない
    git config --global core.autocrlf false        # スクリプトの改行を勝手に CRLF にしない
    git config --global i18n.commitEncoding utf-8
    git config --global i18n.logOutputEncoding utf-8
    Write-Ok 'core.quotepath=false / core.autocrlf=false / utf-8'
} else {
    Write-Warn2 'git 未検出（00_bootstrap.ps1 後にターミナルを開き直してください）'
}

# ---------------------------------------------------------------- 5. PowerShell プロファイル

Write-Step 'PowerShell プロファイル（UTF-8 既定）'
$marker = '# --- YBJ Windows (03_workspace.ps1) ---'
$block = @"
$marker
[Console]::InputEncoding  = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
`$PSDefaultParameterValues['*:Encoding'] = 'utf8'
`$env:PYTHONUTF8 = '1'
function ybj    { Set-Location `$env:YBJ_HOME }
function ybjpy  { & `$env:YBJ_VENV @args }
function bpypy  { & `$env:YBJ_VENV_BPY @args }
# --- end YBJ ---
"@
foreach ($prof in @($PROFILE.CurrentUserAllHosts)) {
    $dir = Split-Path -Parent $prof
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    if ((Test-Path $prof) -and ((Get-Content $prof -Raw) -match [regex]::Escape($marker))) {
        Write-Ok "$prof は設定済み"
    } else {
        Add-Content -Path $prof -Value $block -Encoding UTF8
        Write-Ok "$prof に追記"
    }
}

# ---------------------------------------------------------------- 6. CLAUDE.md

Write-Step 'Claude Code 用 CLAUDE.md'
$src  = Join-Path $here 'CLAUDE.windows.md'
$dst  = Join-Path $env:USERPROFILE '.claude\CLAUDE.md'
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dst) | Out-Null
$srcText = Get-Content $src -Raw -Encoding UTF8
# プレースホルダを実パスで埋める
$srcText = $srcText.Replace('{{YBJ_HOME}}', $YbjHome)
$srcText = $srcText.Replace('{{YBJ_SHARED}}', $(if ($SharedRoot) { $SharedRoot } else { 'G:\マイドライブ（未検出・要設定）' }))
if (Test-Path $dst) {
    if ((Get-Content $dst -Raw -Encoding UTF8) -match 'YBJ Windows 機ルール') {
        # 自分が置いたものなら最新版で上書き（ルール追記を反映させるため）
        Set-Content -Path $dst -Value $srcText -Encoding UTF8
        Write-Ok "$dst を最新版で更新"
    } else {
        Add-Content -Path $dst -Value "`n`n$srcText" -Encoding UTF8
        Write-Ok "$dst の末尾に追記"
    }
} else {
    Set-Content -Path $dst -Value $srcText -Encoding UTF8
    Write-Ok "$dst を作成"
}

Write-Host @'

次: ターミナルを開き直してから .\doctor.ps1 で検証。
'@
