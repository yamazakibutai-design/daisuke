#Requires -Version 5.1
<#
.SYNOPSIS
    Windows クリエイティブ／テクニカル機の初期セットアップ（winget 一括導入）

.DESCRIPTION
    山崎大介（株式会社YBJ／山崎舞台事務所）の Windows 機を
    「3D・図面・パース・演出シート・リハ映像テロップ・音響」を回せる状態にする。
    庶務雑務（帳票・メール）は Mac 側に残す前提なので、LibreOffice 等の帳票系は
    -Groups に office を明示したときだけ入る。

    winget のパッケージ ID は改名されることがあるため、各パッケージに候補 ID を
    複数持たせ、順に試す。全滅したものは最後にまとめて報告する（黙って落とさない）。

.PARAMETER Groups
    導入グループ。既定は core, creative, audio。
      core     : Git / Node.js LTS / Python / PowerShell 7 / Windows Terminal / VS Code / 7-Zip / uv
      creative : Blender / ffmpeg / Chrome / Google Drive / Obsidian / Epic Games Launcher
      audio    : REAPER
      office   : LibreOffice（帳票系を Windows でも回す場合のみ）
      optional : GIMP / Inkscape / Krita
      all      : 全部

.PARAMETER DryRun
    実際には入れず、何を入れるかだけ表示する。

.PARAMETER IncludeWsl
    WSL2（Ubuntu）も導入する。POSIX 専用スクリプトの逃げ道。再起動が必要。

.EXAMPLE
    .\00_bootstrap.ps1 -DryRun
    .\00_bootstrap.ps1
    .\00_bootstrap.ps1 -Groups all -IncludeWsl
#>
[CmdletBinding()]
param(
    [ValidateSet('core', 'creative', 'audio', 'office', 'optional', 'all')]
    [string[]]$Groups = @('core', 'creative', 'audio'),

    [switch]$DryRun,
    [switch]$IncludeWsl
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:Installed = [System.Collections.Generic.List[string]]::new()
$script:Skipped   = [System.Collections.Generic.List[string]]::new()
$script:Failed    = [System.Collections.Generic.List[string]]::new()

function Write-Step { param([string]$Message) Write-Host "`n[*] $Message" -ForegroundColor Cyan }
function Write-Ok   { param([string]$Message) Write-Host "  OK   $Message" -ForegroundColor Green }
function Write-Warn2 { param([string]$Message) Write-Host "  WARN $Message" -ForegroundColor Yellow }
function Write-Err2 { param([string]$Message) Write-Host "  NG   $Message" -ForegroundColor Red }

function Test-Winget {
    $wg = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $wg) {
        Write-Err2 'winget が見つかりません。'
        Write-Host @'
  対処: Microsoft Store で「アプリ インストーラー」(App Installer) を更新してください。
        ストアが使えない場合は https://aka.ms/getwinget から入れます。
        winget は Windows 10 1809 以降で利用できます。
'@
        return $false
    }
    Write-Ok "winget: $((& winget --version) 2>&1 | Select-Object -First 1)"
    return $true
}

function Test-PkgInstalled {
    param([Parameter(Mandatory)][string]$Id)
    # winget list は未導入時に非 0 を返すが、バージョンによって挙動が揺れるので
    # 終了コードと出力の両方を見る。
    $out = & winget list --id $Id --exact --source winget 2>&1 | Out-String
    if ($LASTEXITCODE -eq 0 -and $out -match [regex]::Escape($Id)) { return $true }
    # --source winget 付きだと取りこぼす（ストア版・MSI 版など）ので素で再確認
    $out2 = & winget list --id $Id --exact 2>&1 | Out-String
    return ($LASTEXITCODE -eq 0 -and $out2 -match [regex]::Escape($Id))
}

function Install-Pkg {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string[]]$Id,
        [string]$Note
    )

    foreach ($candidate in $Id) {
        if (Test-PkgInstalled -Id $candidate) {
            Write-Ok "$Name : 既に導入済み ($candidate)"
            $script:Skipped.Add($Name)
            return
        }
    }

    if ($DryRun) {
        Write-Host "  DRY  $Name -> $($Id[0])" -ForegroundColor DarkGray
        return
    }

    foreach ($candidate in $Id) {
        Write-Step "$Name : winget install $candidate"
        $wgArgs = @(
            'install', '--id', $candidate, '--exact',
            '--accept-package-agreements', '--accept-source-agreements'
        )
        & winget @wgArgs 2>&1 | ForEach-Object { Write-Host "       $_" -ForegroundColor DarkGray }

        if ($LASTEXITCODE -eq 0 -or (Test-PkgInstalled -Id $candidate)) {
            Write-Ok "$Name 導入完了 ($candidate)"
            if ($Note) { Write-Host "       $Note" -ForegroundColor DarkGray }
            $script:Installed.Add($Name)
            return
        }
        Write-Warn2 "$candidate は失敗（終了コード $LASTEXITCODE）。次の候補を試します。"
    }

    Write-Err2 "$Name : 候補 ID すべて失敗 ($($Id -join ', '))"
    $script:Failed.Add("$Name  (候補: $($Id -join ', '))")
}

# ---------------------------------------------------------------- パッケージ定義

$catalog = [ordered]@{
    core = @(
        @{ Name = 'Git';                Id = @('Git.Git') }
        @{ Name = 'Node.js LTS';        Id = @('OpenJS.NodeJS.LTS', 'OpenJS.NodeJS')
           Note = 'Claude Code CLI をこの上に入れる' }
        @{ Name = 'Python 3.13';        Id = @('Python.Python.3.13')
           Note = '汎用（openpyxl / matplotlib / PIL / PyMuPDF）' }
        @{ Name = 'Python 3.11';        Id = @('Python.Python.3.11')
           Note = 'bpy==4.2.0 専用（Blender 4.2 が CPython 3.11 系のため）' }
        @{ Name = 'uv';                 Id = @('astral-sh.uv')
           Note = 'venv と Python バージョンの取り回しを楽にする' }
        @{ Name = 'PowerShell 7';       Id = @('Microsoft.PowerShell')
           Note = 'UTF-8 が既定。日本語を扱うならこちらを使う' }
        @{ Name = 'Windows Terminal';   Id = @('Microsoft.WindowsTerminal') }
        @{ Name = 'VS Code';            Id = @('Microsoft.VisualStudioCode') }
        @{ Name = '7-Zip';              Id = @('7zip.7zip') }
    )
    creative = @(
        @{ Name = 'Blender';            Id = @('BlenderFoundation.Blender')
           Note = 'zumen-3d-previz の .blend を目視確認する用' }
        @{ Name = 'ffmpeg';             Id = @('Gyan.FFmpeg.Full', 'Gyan.FFmpeg', 'BtbN.FFmpeg.GPL')
           Note = 'リハ映像テロップの本体。NVENC/QSV 入りビルドが必要' }
        @{ Name = 'Google Chrome';      Id = @('Google.Chrome')
           Note = '画像生成の半自動操作・Gmail 下書き確認' }
        @{ Name = 'Google Drive';       Id = @('Google.GoogleDrive', 'Google.Drive')
           Note = 'Mac がミラーしている資料を G: から読む（ストリーミング推奨）' }
        @{ Name = 'Obsidian';           Id = @('Obsidian.Obsidian')
           Note = 'Google Drive 上の MD 保管庫を開く' }
        @{ Name = 'Epic Games Launcher'; Id = @('EpicGames.EpicGamesLauncher')
           Note = 'Unreal Engine を入れる窓口（FBX の受け先）' }
    )
    audio = @(
        @{ Name = 'REAPER';             Id = @('Cockos.REAPER')
           Note = '音源の切り出し・確認用' }
    )
    office = @(
        @{ Name = 'LibreOffice';        Id = @('TheDocumentFoundation.LibreOffice')
           Note = 'xlsx/docx -> PDF。notes/compat.md の AF_UNIX 制約を必ず読む' }
    )
    optional = @(
        @{ Name = 'GIMP';               Id = @('GIMP.GIMP') }
        @{ Name = 'Inkscape';           Id = @('Inkscape.Inkscape') }
        @{ Name = 'Krita';              Id = @('KDE.Krita') }
    )
}

# ---------------------------------------------------------------- 実行

Write-Host '================================================================'
Write-Host ' YBJ Windows セットアップ  00_bootstrap' -ForegroundColor White
Write-Host '================================================================'

if ($env:OS -ne 'Windows_NT') {
    Write-Err2 'このスクリプトは Windows 専用です。'
    exit 1
}
if (-not (Test-Winget)) { exit 1 }

$targets = if ($Groups -contains 'all') { $catalog.Keys } else { $Groups }

foreach ($group in $targets) {
    Write-Host "`n---- グループ: $group ----" -ForegroundColor Magenta
    foreach ($pkg in $catalog[$group]) {
        Install-Pkg -Name $pkg.Name -Id $pkg.Id -Note ($pkg['Note'])
    }
}

# ---------------------------------------------------------------- Claude Code

if (($targets -contains 'core') -and -not $DryRun) {
    Write-Step 'Claude Code CLI'
    # winget で入れた Node は、このセッションの PATH にまだ載っていないことがある
    $npm = Get-Command npm -ErrorAction SilentlyContinue
    if (-not $npm) {
        $guess = Join-Path $env:ProgramFiles 'nodejs\npm.cmd'
        if (Test-Path $guess) { $npm = $guess } 
    }
    if ($npm) {
        & $(if ($npm -is [string]) { $npm } else { $npm.Source }) install -g '@anthropic-ai/claude-code' 2>&1 |
            ForEach-Object { Write-Host "       $_" -ForegroundColor DarkGray }
        if ($LASTEXITCODE -eq 0) {
            Write-Ok 'claude コマンド導入完了'
            $script:Installed.Add('Claude Code CLI')
        } else {
            Write-Warn2 'npm での導入に失敗。ターミナルを開き直して再実行してください:'
            Write-Host '       npm install -g @anthropic-ai/claude-code'
            $script:Failed.Add('Claude Code CLI')
        }
    } else {
        Write-Warn2 'npm が PATH に載っていません。ターミナルを開き直してから次を実行:'
        Write-Host '       npm install -g @anthropic-ai/claude-code'
        $script:Failed.Add('Claude Code CLI (npm 未検出)')
    }
}

# ---------------------------------------------------------------- WSL2

if ($IncludeWsl -and -not $DryRun) {
    Write-Step 'WSL2 (Ubuntu)'
    $isAdmin = ([Security.Principal.WindowsPrincipal] `
        [Security.Principal.WindowsIdentity]::GetCurrent()
        ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Warn2 'WSL2 の導入には管理者権限が必要です。管理者 PowerShell で次を実行:'
        Write-Host '       wsl --install -d Ubuntu'
        $script:Failed.Add('WSL2 (要管理者権限)')
    } else {
        & wsl --install -d Ubuntu 2>&1 | ForEach-Object { Write-Host "       $_" -ForegroundColor DarkGray }
        Write-Ok 'WSL2 導入手続き完了（再起動後に Ubuntu の初回設定が走ります）'
        $script:Installed.Add('WSL2 (Ubuntu)')
    }
}

# ---------------------------------------------------------------- まとめ

Write-Host "`n================================================================"
Write-Host ' 結果' -ForegroundColor White
Write-Host '================================================================'
Write-Host "導入      : $($script:Installed.Count) 件" -ForegroundColor Green
$script:Installed | ForEach-Object { Write-Host "  + $_" }
Write-Host "既に導入済: $($script:Skipped.Count) 件" -ForegroundColor DarkGray
Write-Host "失敗      : $($script:Failed.Count) 件" -ForegroundColor $(if ($script:Failed.Count) { 'Red' } else { 'DarkGray' })
$script:Failed | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }

Write-Host @'

次の手順:
  1. ターミナルを開き直す（PATH を反映させる）
  2. .\01_python.ps1      ... venv を 2 系統作る（汎用 3.13 / bpy 用 3.11）
  3. .\02_fonts.ps1       ... 日本語フォントと matplotlib の既定を入れる
  4. .\03_workspace.ps1   ... 作業フォルダと CLAUDE.md を配置
  5. .\doctor.ps1         ... 全部入ったか検証
'@

if ($script:Failed.Count -gt 0) { exit 1 }
