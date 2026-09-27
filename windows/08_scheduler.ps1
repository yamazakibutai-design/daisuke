#Requires -Version 5.1
<#
.SYNOPSIS
    夜間バッチ: Task Scheduler から Claude Code を無人で回す仕組みを作る

.DESCRIPTION
    - C:\YBJ\_jobs\<名前>.md にやってほしいことを日本語で書く（例を配置する）
    - 08_scheduler.ps1 -Register <名前> -At 03:00  でタスク登録
    - 時刻になると run-job.ps1 が  claude -p "<md の中身>" --permission-mode auto  を C:\YBJ で実行し、
      C:\YBJ\_logs\<名前>_<日時>.log に結果を残す
    - -List で一覧、-Unregister <名前> で削除、-RunNow <名前> で今すぐ試す

    PC がスリープしていると動かないので、電源設定で「スリープしない」か「スリープ解除タイマー許可」にしておく。

.EXAMPLE
    .\08_scheduler.ps1                          # ジョブ置き場と例を作るだけ
    .\08_scheduler.ps1 -Register drive_cleanup -At 03:00
    .\08_scheduler.ps1 -RunNow drive_cleanup
#>
[CmdletBinding()]
param(
    [string]$Register,
    [string]$At = '03:00',
    [string]$Unregister,
    [string]$RunNow,
    [switch]$List
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Write-Ok   { param([string]$Message) Write-Host "  OK   $Message" -ForegroundColor Green }
function Write-Err2 { param([string]$Message) Write-Host "  NG   $Message" -ForegroundColor Red }

$jobs = 'C:\YBJ\_jobs'; $logs = 'C:\YBJ\_logs'
New-Item -ItemType Directory -Force -Path $jobs, $logs | Out-Null
$runner = Join-Path $jobs 'run-job.ps1'
$prefix = 'YBJ-'

# ---------------------------------------------------------------- runner と例
@'
# run-job.ps1 — Task Scheduler から呼ばれる。引数: ジョブ名
param([Parameter(Mandatory)][string]$Name)
$job = "C:\YBJ\_jobs\$Name.md"
$log = "C:\YBJ\_logs\{0}_{1}.log" -f $Name, (Get-Date -Format 'yyyyMMdd_HHmm')
if (-not (Test-Path $job)) { "ジョブ無し: $job" | Set-Content $log; exit 1 }
$claude = Join-Path $env:USERPROFILE '.local\bin\claude.exe'
$prompt = Get-Content $job -Raw -Encoding UTF8
Set-Location 'C:\YBJ'
"=== $(Get-Date) $Name ===" | Set-Content $log -Encoding UTF8
& $claude -p $prompt --permission-mode auto --output-format text 2>&1 | Out-File $log -Append -Encoding UTF8
"=== exit $LASTEXITCODE $(Get-Date) ===" | Out-File $log -Append -Encoding UTF8
'@ | Set-Content $runner -Encoding UTF8

$example = Join-Path $jobs 'drive_cleanup.md'
if (-not (Test-Path $example)) {
@'
C:\YBJ\_中間ファイル_削除可 の中で 7 日以上前のファイルを一覧にして、合計サイズを報告して。
削除はしない（一覧だけ）。結果を C:\YBJ\_logs\cleanup_report.md に書く。
'@ | Set-Content $example -Encoding UTF8
}
$example2 = Join-Path $jobs 'render_queue.md'
if (-not (Test-Path $example2)) {
@'
C:\YBJ\3D\_render_queue フォルダにある .blend を順番に、bpy311 の venv で 4 視点レンダー（Eevee）して
同じフォルダの renders\ に PNG を出す。終わったファイルは done\ に移す。所要時間を C:\YBJ\_logs\render_report.md に追記。
'@ | Set-Content $example2 -Encoding UTF8
}
Write-Ok "ジョブ置き場 $jobs（例: drive_cleanup.md / render_queue.md）"

$pwsh = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
if (-not $pwsh) { $pwsh = 'powershell.exe' }

# ---------------------------------------------------------------- 操作
if ($List) {
    Get-ScheduledTask | Where-Object TaskName -like "$prefix*" | ForEach-Object {
        $i = $_ | Get-ScheduledTaskInfo
        [pscustomobject]@{ Task = $_.TaskName; State = $_.State; Next = $i.NextRunTime; Last = $i.LastRunTime; LastResult = $i.LastTaskResult }
    } | Format-Table -AutoSize
}
if ($Register) {
    if (-not (Test-Path (Join-Path $jobs "$Register.md"))) { Write-Err2 "$jobs\$Register.md が無い。先に書いてください"; exit 1 }
    $t = [datetime]::ParseExact($At, 'HH:mm', $null)
    $action  = New-ScheduledTaskAction -Execute $pwsh -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$runner`" -Name $Register"
    $trigger = New-ScheduledTaskTrigger -Daily -At $t
    $settings = New-ScheduledTaskSettingsSet -WakeToRun -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 6)
    Register-ScheduledTask -TaskName "$prefix$Register" -Action $action -Trigger $trigger -Settings $settings -Force | Out-Null
    Write-Ok "登録: $prefix$Register 毎日 $At  → ログ $logs"
}
if ($Unregister) {
    Unregister-ScheduledTask -TaskName "$prefix$Unregister" -Confirm:$false
    Write-Ok "削除: $prefix$Unregister"
}
if ($RunNow) {
    & $pwsh -NoProfile -ExecutionPolicy Bypass -File $runner -Name $RunNow
    $latest = Get-ChildItem $logs -Filter "$RunNow*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($latest) { Write-Ok "ログ: $($latest.FullName)"; Get-Content $latest.FullName -Tail 30 }
}
if (-not ($List -or $Register -or $Unregister -or $RunNow)) {
    Write-Host @"

次:
  .\08_scheduler.ps1 -RunNow drive_cleanup           # まず手動で 1 回試す
  .\08_scheduler.ps1 -Register drive_cleanup -At 03:00
  .\08_scheduler.ps1 -List
"@
}
