#Requires -Version 5.1
<#
.SYNOPSIS
    Windows 機が「Mac と同じかそれ以上」で動く状態になっているか一括検証する

.DESCRIPTION
    OK / NG を表で出す。NG には直し方を添える。終了コードは NG の数。
    GPU と ffmpeg のハードウェアエンコーダ（NVENC / QSV / AMF）も見る。
    ここが通れば Mac の Linux VM より速いテロップ書き出しができる。
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

$rows = [System.Collections.Generic.List[object]]::new()
function Add-Row {
    param([string]$Area, [string]$Item, [bool]$Ok, [string]$Detail = '', [string]$Fix = '')
    $rows.Add([pscustomobject]@{ Area = $Area; Item = $Item; Status = $(if ($Ok) { 'OK' } else { 'NG' }); Detail = $Detail; Fix = $Fix })
}
function Test-Cmd {
    param([string]$Area, [string]$Name, [string]$Cmd, [string[]]$VersionArgs = @('--version'), [string]$Fix)
    $c = Get-Command $Cmd -ErrorAction SilentlyContinue
    if (-not $c) { Add-Row $Area $Name $false 'PATH に無い' $Fix; return $null }
    $v = (& $c.Source @VersionArgs 2>&1 | Select-Object -First 1) -join ''
    Add-Row $Area $Name $true "$v" ''
    return $c.Source
}

# ---------------------------------------------------------------- core
$null = Test-Cmd 'core' 'git'    'git'    -Fix '.\00_bootstrap.ps1'
$null = Test-Cmd 'core' 'node'   'node'   -Fix '.\00_bootstrap.ps1'
$null = Test-Cmd 'core' 'npm'    'npm'    -Fix 'ターミナルを開き直す'
$null = Test-Cmd 'core' 'claude' 'claude' -Fix 'irm https://claude.ai/install.ps1 | iex'
$null = Test-Cmd 'core' 'uv'     'uv'     -Fix '.\00_bootstrap.ps1'
$null = Test-Cmd 'core' 'pwsh (PowerShell 7)' 'pwsh' -Fix 'winget install Microsoft.PowerShell'

# ---------------------------------------------------------------- python venvs
foreach ($v in @(
    @{ Name = 'ybj';    Want = '3.13'; Modules = 'openpyxl,matplotlib,PIL,fitz,numpy' },
    @{ Name = 'bpy311'; Want = '3.11'; Modules = 'bpy,numpy,fitz' }
)) {
    $py = Join-Path $env:USERPROFILE ".venvs\$($v.Name)\Scripts\python.exe"
    if (-not (Test-Path $py)) { Add-Row 'python' "venv $($v.Name)" $false '無い' '.\01_python.ps1'; continue }
    $ver = & $py -c 'import sys;print(f"{sys.version_info.major}.{sys.version_info.minor}")' 2>&1
    Add-Row 'python' "venv $($v.Name) = Python $ver" ($ver -eq $v.Want) '' $(if ($ver -ne $v.Want) { '.\01_python.ps1 -Recreate' })
    $code = "import importlib.util,sys`nbad=[m for m in '$($v.Modules)'.split(',') if importlib.util.find_spec(m) is None]`nprint(','.join(bad))"
    $bad = (& $py -c $code 2>&1) -join ''
    Add-Row 'python' "venv $($v.Name) modules" ([string]::IsNullOrWhiteSpace($bad)) $(if ($bad) { "missing: $bad" } else { $v.Modules }) $(if ($bad) { '.\01_python.ps1' })
    $utf = & $py -c 'import sys;print(sys.flags.utf8_mode)' 2>&1
    Add-Row 'python' "venv $($v.Name) UTF-8 mode" ("$utf" -eq '1') "utf8_mode=$utf" $(if ("$utf" -ne '1') { '.\03_workspace.ps1 の後、ターミナルを開き直す' })
}

# ---------------------------------------------------------------- creative
$ff = Test-Cmd 'creative' 'ffmpeg' 'ffmpeg' -VersionArgs @('-version') -Fix 'winget install Gyan.FFmpeg'
if ($ff) {
    $enc = (& ffmpeg -hide_banner -encoders 2>&1) -join "`n"
    foreach ($e in @('h264_nvenc', 'hevc_nvenc', 'h264_qsv', 'h264_amf')) {
        Add-Row 'creative' "ffmpeg encoder $e" ($enc -match $e) $(if ($enc -match $e) { '使える' } else { 'このビルドには無い' }) ''
    }
    $hw = (& ffmpeg -hide_banner -hwaccels 2>&1) -join ' '
    Add-Row 'creative' 'ffmpeg hwaccel' ($hw -match 'cuda|d3d11va|qsv|dxva2') ($hw -replace 'Hardware acceleration methods:', '').Trim() ''
}
$blender = Get-ChildItem "$env:ProgramFiles\Blender Foundation" -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
Add-Row 'creative' 'Blender (GUI)' ($null -ne $blender) $(if ($blender) { $blender.FullName } else { '無い' }) 'winget install BlenderFoundation.Blender'
Add-Row 'creative' 'Google Chrome' (Test-Path "$env:ProgramFiles\Google\Chrome\Application\chrome.exe") '' 'winget install Google.Chrome'
Add-Row 'creative' 'Obsidian' ((Test-Path "$env:LOCALAPPDATA\Programs\Obsidian\Obsidian.exe") -or (Test-Path "$env:LOCALAPPDATA\Obsidian\Obsidian.exe")) '' 'winget install Obsidian.Obsidian'
$gd = @('G:\マイドライブ', 'G:\My Drive') | Where-Object { Test-Path $_ } | Select-Object -First 1
Add-Row 'creative' 'Google Drive (G:)' ($null -ne $gd) $(if ($gd) { $gd } else { 'G: にマイドライブが無い' }) 'Google Drive にサインイン → ストリーミング'
Add-Row 'creative' 'Epic Games Launcher' (Test-Path "${env:ProgramFiles(x86)}\Epic Games\Launcher\Portal\Binaries\Win64\EpicGamesLauncher.exe") '' 'winget install EpicGames.EpicGamesLauncher'
$ue = Get-ChildItem "$env:ProgramFiles\Epic Games" -Directory -Filter 'UE_*' -ErrorAction SilentlyContinue | Select-Object -First 1
Add-Row 'creative' 'Unreal Engine' ($null -ne $ue) $(if ($ue) { $ue.Name } else { '未導入（任意）' }) 'Epic Games Launcher から UE 5.x を導入'
Add-Row 'creative' 'DaVinci Resolve' (Test-Path "$env:ProgramFiles\Blackmagic Design\DaVinci Resolve\Resolve.exe") '' '任意: blackmagicdesign.com から'

# ---------------------------------------------------------------- fonts
$userFonts = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
Add-Row 'fonts' 'Yu Gothic Bold'  (Test-Path "$env:WINDIR\Fonts\YuGothB.ttc") '' '設定 > 言語 > 日本語 補助フォント'
Add-Row 'fonts' 'Noto Sans CJK Bold' (Test-Path "$userFonts\NotoSansCJK-Bold.ttc") "$userFonts" '.\02_fonts.ps1'
Add-Row 'fonts' 'matplotlibrc' (Test-Path "$env:USERPROFILE\.matplotlib\matplotlibrc") '' '.\02_fonts.ps1'

# ---------------------------------------------------------------- env / workspace
foreach ($k in @('YBJ_HOME', 'YBJ_VENV', 'YBJ_VENV_BPY', 'PYTHONUTF8', 'YBJ_TELOP_FONT')) {
    $val = [Environment]::GetEnvironmentVariable($k, 'User')
    Add-Row 'env' $k (-not [string]::IsNullOrWhiteSpace($val)) "$val" '.\03_workspace.ps1 / .\02_fonts.ps1'
}
$home_ = [Environment]::GetEnvironmentVariable('YBJ_HOME', 'User')
if ($home_) { Add-Row 'env' 'YBJ_HOME exists' (Test-Path $home_) $home_ '.\03_workspace.ps1' }
Add-Row 'env' 'CLAUDE.md' ((Test-Path "$env:USERPROFILE\.claude\CLAUDE.md") -and ((Get-Content "$env:USERPROFILE\.claude\CLAUDE.md" -Raw -ErrorAction SilentlyContinue) -match 'YBJ Windows')) '' '.\03_workspace.ps1'

# ---------------------------------------------------------------- GPU
$gpus = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue
foreach ($g in $gpus) {
    $vramGB = [math]::Round(($g.AdapterRAM / 1GB), 1)
    Add-Row 'gpu' $g.Name $true "VRAM ${vramGB}GB (WMI 値は 4GB 上限で頭打ちのことあり) / driver $($g.DriverVersion)" ''
}
if (Get-Command nvidia-smi -ErrorAction SilentlyContinue) {
    $smi = (& nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader 2>&1) -join ''
    Add-Row 'gpu' 'nvidia-smi' $true $smi ''
}

# ---------------------------------------------------------------- WSL
# wsl.exe は UTF-16 で出力するので、取り込むと NUL が混ざる。落としてから見る
$wslOut = ((& wsl -l -v 2>&1) -join ' ') -replace "`0", ''
$wslOk = $wslOut -match 'Ubuntu'
Add-Row 'wsl' 'WSL2 Ubuntu (保険)' $wslOk $(if ($wslOk) { '入っている' } else { '未導入（任意）' }) '管理者で wsl --install -d Ubuntu'

# ---------------------------------------------------------------- 出力
$rows | Format-Table -AutoSize -Wrap Area, Status, Item, Detail, Fix | Out-String -Width 200 | Write-Host
$ng = @($rows | Where-Object Status -eq 'NG')
$must = @($ng | Where-Object { $_.Area -in @('core', 'python', 'fonts', 'env') -or $_.Item -match '^ffmpeg$|Blender|Google Drive' })
Write-Host ("OK {0} / NG {1}  （必須の NG: {2}）" -f (@($rows | Where-Object Status -eq 'OK')).Count, $ng.Count, $must.Count) -ForegroundColor $(if ($must.Count) { 'Red' } else { 'Green' })
if ($must.Count -eq 0) {
    Write-Host '必須項目はそろっています。Claude Code を起動して zumen-3d-previz / riha-douga-telop を試せます。' -ForegroundColor Green
}
exit $must.Count
