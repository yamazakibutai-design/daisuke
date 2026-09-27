#Requires -Version 5.1
<#
.SYNOPSIS
    日本語フォントの導入と matplotlib / ffmpeg 向けの既定設定

.DESCRIPTION
    1. Yu Gothic（Windows 標準）の存在確認 … これだけで全スキルは一応動く
    2. Noto Sans CJK JP を「ユーザー単位」で導入（管理者権限不要）
       - Mac / Linux VM のテロップ出力と同じ見た目にするため
       - riha-douga-telop が参照する NotoSansCJK-Bold.ttc をそのまま使えるようにする
    3. ~/.matplotlib/matplotlibrc に日本語フォント優先順位を書く
       - スキル側が font.family を指定していなくても豆腐（□）にならない
    4. ffmpeg drawtext 用のフォントパス（Windows の書き方）を表示する

.PARAMETER SkipNoto
    Noto のダウンロードを飛ばす（オフライン時など）。
#>
[CmdletBinding()]
param([switch]$SkipNoto)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Write-Step { param([string]$Message) Write-Host "`n[*] $Message" -ForegroundColor Cyan }
function Write-Ok   { param([string]$Message) Write-Host "  OK   $Message" -ForegroundColor Green }
function Write-Warn2 { param([string]$Message) Write-Host "  WARN $Message" -ForegroundColor Yellow }

$sysFonts  = Join-Path $env:WINDIR 'Fonts'
$userFonts = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
$fontReg   = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
New-Item -ItemType Directory -Force -Path $userFonts | Out-Null

# ---------------------------------------------------------------- 1. Yu Gothic

Write-Step 'Yu Gothic（Windows 標準）'
$yuBold = Join-Path $sysFonts 'YuGothB.ttc'
if (Test-Path $yuBold) { Write-Ok "$yuBold" } else { Write-Warn2 'YuGothB.ttc が無い。設定 > 時刻と言語 > 言語 で日本語の補助フォントを入れてください' }

# ---------------------------------------------------------------- 2. Noto Sans CJK

# ユーザー単位のフォント導入 = フォントファイルを %LOCALAPPDATA%\Microsoft\Windows\Fonts に置き、
# HKCU の Fonts キーにフルパスで登録する（Windows 10 1809 以降）。
function Install-UserFont {
    param(
        [Parameter(Mandatory)][string]$Url,
        [Parameter(Mandatory)][string]$FileName,
        [Parameter(Mandatory)][string]$RegName
    )
    $dest = Join-Path $userFonts $FileName
    if (Test-Path $dest) { Write-Ok "$FileName は導入済み"; return $true }

    Write-Host "  GET  $Url" -ForegroundColor DarkGray
    try {
        Invoke-WebRequest -Uri $Url -OutFile $dest -UseBasicParsing
    } catch {
        Write-Warn2 "ダウンロード失敗: $($_.Exception.Message)"
        Write-Host "       手動: https://github.com/notofonts/noto-cjk/tree/main/Sans/OTC から $FileName を取り、右クリック > インストール"
        return $false
    }
    if ((Get-Item $dest).Length -lt 1MB) {
        Remove-Item $dest -Force
        Write-Warn2 "$FileName のダウンロード内容が小さすぎる（URL 変更の可能性）。手動導入に切り替えてください。"
        return $false
    }
    New-Item -Path $fontReg -Force | Out-Null
    New-ItemProperty -Path $fontReg -Name $RegName -Value $dest -PropertyType String -Force | Out-Null
    Write-Ok "$FileName をユーザー単位で登録"
    return $true
}

Write-Step 'Noto Sans CJK（ユーザー単位・管理者権限不要）'
if ($SkipNoto) {
    Write-Warn2 '-SkipNoto 指定のため飛ばします（Yu Gothic で代替）'
} else {
    $base = 'https://github.com/notofonts/noto-cjk/raw/main/Sans/OTC'
    Install-UserFont -Url "$base/NotoSansCJK-Bold.ttc"    -FileName 'NotoSansCJK-Bold.ttc'    -RegName 'Noto Sans CJK Bold (TrueType)'    | Out-Null
    Install-UserFont -Url "$base/NotoSansCJK-Regular.ttc" -FileName 'NotoSansCJK-Regular.ttc' -RegName 'Noto Sans CJK Regular (TrueType)' | Out-Null
}

# ---------------------------------------------------------------- 3. matplotlibrc

Write-Step 'matplotlibrc（日本語フォントの既定）'
$mplDir = Join-Path $env:USERPROFILE '.matplotlib'
New-Item -ItemType Directory -Force -Path $mplDir | Out-Null
$rc = Join-Path $mplDir 'matplotlibrc'
@'
# YBJ Windows: 日本語フォントの既定（02_fonts.ps1 が生成）
# スキルが font.family を明示していない場合でも豆腐にしない。
font.family        : sans-serif
font.sans-serif    : Noto Sans CJK JP, Yu Gothic, Meiryo, MS Gothic, DejaVu Sans
axes.unicode_minus : False
pdf.fonttype       : 42
ps.fonttype        : 42
'@ | Set-Content -Path $rc -Encoding UTF8
Write-Ok $rc

# フォントキャッシュを消して次回起動で作り直させる（新しいフォントを拾わせる）
Get-ChildItem $mplDir -Filter 'fontlist-*.json' -ErrorAction SilentlyContinue | Remove-Item -Force
Write-Ok 'matplotlib フォントキャッシュを破棄（次回起動時に再構築）'

# ---------------------------------------------------------------- 4. ffmpeg 用の案内

$notoBold = Join-Path $userFonts 'NotoSansCJK-Bold.ttc'
$telopFont = if (Test-Path $notoBold) { $notoBold } else { $yuBold }

Write-Host @"

================================================================
 ffmpeg drawtext で使うフォント（Windows の書き方）
================================================================
テロップ用フォント: $telopFont

drawtext の fontfile= は「コロンをエスケープしてスラッシュ区切り」で渡す:
  fontfile='$(($telopFont -replace '\\','/') -replace ':','\:')'

例:
  -vf "drawtext=fontfile='$(($telopFont -replace '\\','/') -replace ':','\:')':text='M9　　リターンマッチ':fontsize=84:fontcolor=black:box=1:boxcolor=yellow@0.82:boxborderw=18:x=34:y=31"

（notes/telop-windows.md に完全版がある）
"@

# 後続スクリプトが拾えるようユーザー環境変数に残す
[Environment]::SetEnvironmentVariable('YBJ_TELOP_FONT', $telopFont, 'User')
Write-Ok "環境変数 YBJ_TELOP_FONT = $telopFont"
