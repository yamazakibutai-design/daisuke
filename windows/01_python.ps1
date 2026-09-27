#Requires -Version 5.1
<#
.SYNOPSIS
    Python venv を 2 系統作る（汎用 3.13 / bpy 用 3.11）

.DESCRIPTION
    - %USERPROFILE%\.venvs\ybj     : Python 3.13  汎用（requirements-general.txt）
    - %USERPROFILE%\.venvs\bpy311  : Python 3.11  bpy==4.2.0 専用（requirements-bpy311.txt）

    uv があれば uv で作る（Python 本体の取得まで面倒を見てくれる）。
    無ければ py ランチャーで作る。

    bpy を 3.11 に隔離する理由:
      Blender 4.2 LTS は CPython 3.11。bpy==4.2.0 の wheel は 3.11 向けしか無いので、
      汎用 venv（3.13）に入れようとすると「No matching distribution」で止まる。

.PARAMETER Recreate
    既存の venv を消して作り直す。

.EXAMPLE
    .\01_python.ps1
    .\01_python.ps1 -Recreate
#>
[CmdletBinding()]
param([switch]$Recreate)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$here     = Split-Path -Parent $MyInvocation.MyCommand.Path
$venvRoot = Join-Path $env:USERPROFILE '.venvs'
New-Item -ItemType Directory -Force -Path $venvRoot | Out-Null

function Write-Step { param([string]$Message) Write-Host "`n[*] $Message" -ForegroundColor Cyan }
function Write-Ok   { param([string]$Message) Write-Host "  OK   $Message" -ForegroundColor Green }
function Write-Warn2 { param([string]$Message) Write-Host "  WARN $Message" -ForegroundColor Yellow }
function Write-Err2 { param([string]$Message) Write-Host "  NG   $Message" -ForegroundColor Red }

$uv = Get-Command uv -ErrorAction SilentlyContinue
$py = Get-Command py -ErrorAction SilentlyContinue

function New-Venv {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$PythonVersion,   # '3.13' / '3.11'
        [Parameter(Mandatory)][string]$Requirements
    )
    $path = Join-Path $venvRoot $Name
    Write-Step "venv '$Name' (Python $PythonVersion) -> $path"

    if ((Test-Path $path) -and $Recreate) {
        Write-Warn2 '既存を削除して作り直します'
        Remove-Item -Recurse -Force $path
    }

    if (-not (Test-Path (Join-Path $path 'Scripts\python.exe'))) {
        if ($uv) {
            # uv は必要な Python を自動で取ってくる（winget 版 Python が無くても動く）
            & uv venv --python $PythonVersion $path
        } elseif ($py) {
            & py "-$PythonVersion" -m venv $path
        } else {
            Write-Err2 'uv も py ランチャーも見つかりません。00_bootstrap.ps1 を先に実行してください。'
            return $false
        }
        if ($LASTEXITCODE -ne 0) {
            Write-Err2 "venv 作成失敗（Python $PythonVersion が入っていない可能性）"
            return $false
        }
    } else {
        Write-Ok '既存の venv を再利用'
    }

    $python = Join-Path $path 'Scripts\python.exe'
    $ver = & $python -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")'
    if ($ver -ne $PythonVersion) {
        Write-Err2 "この venv の Python は $ver です。$PythonVersion が必要。-Recreate で作り直してください。"
        return $false
    }

    Write-Step "pip install -r $(Split-Path -Leaf $Requirements)"
    if ($uv) {
        & uv pip install --python $python -r $Requirements
    } else {
        & $python -m pip install --upgrade pip
        & $python -m pip install -r $Requirements
    }
    if ($LASTEXITCODE -ne 0) {
        Write-Err2 'pip install で失敗したパッケージがあります（上のログ参照）'
        return $false
    }
    Write-Ok "'$Name' 準備完了"
    return $true
}

$results = @{}
$results['ybj']    = New-Venv -Name 'ybj'    -PythonVersion '3.13' -Requirements (Join-Path $here 'requirements-general.txt')
$results['bpy311'] = New-Venv -Name 'bpy311' -PythonVersion '3.11' -Requirements (Join-Path $here 'requirements-bpy311.txt')

# bpy が本当に import できるか（wheel が入っただけでは安心できない）
if ($results['bpy311']) {
    Write-Step 'bpy import テスト'
    $bpyPython = Join-Path $venvRoot 'bpy311\Scripts\python.exe'
    $out = & $bpyPython -c 'import bpy; print(bpy.app.version_string)' 2>&1
    if ($LASTEXITCODE -eq 0) { Write-Ok "bpy $out" } else { Write-Err2 "bpy import 失敗: $out"; $results['bpy311'] = $false }
}

# ---------------------------------------------------------------- 使い方の案内

Write-Host @"

================================================================
 使い方
================================================================
汎用:      & "$venvRoot\ybj\Scripts\Activate.ps1"
3D(bpy):   & "$venvRoot\bpy311\Scripts\Activate.ps1"

Claude Code からスクリプトを叩くときはアクティベート不要で、
  "$venvRoot\ybj\Scripts\python.exe" script.py
  "$venvRoot\bpy311\Scripts\python.exe" build_template.py
のようにフルパスで呼べば済む（CLAUDE.md にも同じ規約を書いてある）。
"@

if ($results.Values -contains $false) { exit 1 }
