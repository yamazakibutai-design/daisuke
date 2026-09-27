#Requires -Version 5.1
<#
.SYNOPSIS
    画像生成などで使う API キーを「ユーザー環境変数」に登録する（対話式・画面に値を残さない）

.DESCRIPTION
    Mac の ~/.zshrc 等にある API キーを Windows に移すためのもの。
    値はファイルにもリポジトリにも残さず、その場で入力してユーザー環境変数にだけ書く。
    空 Enter で飛ばせる。既に入っているキーは「設定済み」と表示して上書きしない（-Force で上書き）。

    対象（スキルが参照するもの）:
      OPENAI_API_KEY      butai-perspective（GPT-4o image）/ bolero-senden
      GOOGLE_API_KEY      Nano Banana / Imagen 4（Gemini API）
      GEMINI_API_KEY      同上（ライブラリによってこちらを見る）
      ANTHROPIC_API_KEY   Claude API を直接叩くスクリプトがある場合のみ（Claude Code 自体には不要）
      DAVINCI_RESOLVE_*   DaVinci の外部スクリプト用（通常は不要）

.PARAMETER Force
    設定済みのキーも聞き直して上書きする。
.PARAMETER Keys
    登録するキー名を自分で指定する。省略時は上の既定リスト。
#>
[CmdletBinding()]
param(
    [switch]$Force,
    [string[]]$Keys = @('GEMINI_API_KEY', 'GOOGLE_API_KEY', 'OPENAI_API_KEY', 'ANTHROPIC_API_KEY')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Ok   { param([string]$Message) Write-Host "  OK   $Message" -ForegroundColor Green }
function Write-Skip { param([string]$Message) Write-Host "  --   $Message" -ForegroundColor DarkGray }

Write-Host '================================================================'
Write-Host ' API キー登録（値は画面に出ません。空 Enter で飛ばす）' -ForegroundColor White
Write-Host '================================================================'

$set = 0
foreach ($k in $Keys) {
    $current = [Environment]::GetEnvironmentVariable($k, 'User')
    if ($current -and -not $Force) {
        Write-Skip "$k : 設定済み（末尾 …$($current.Substring([Math]::Max(0, $current.Length - 4)))）。上書きは -Force"
        continue
    }
    $secure = Read-Host -Prompt "$k" -AsSecureString
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try { $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }

    if ([string]::IsNullOrWhiteSpace($plain)) { Write-Skip "$k : 飛ばしました"; continue }
    $plain = $plain.Trim()
    [Environment]::SetEnvironmentVariable($k, $plain, 'User')
    Set-Item -Path "Env:$k" -Value $plain
    Write-Ok "$k を登録（$($plain.Length) 文字）"
    $set++
}

Write-Host ''
Write-Host "登録 $set 件。新しいターミナルから有効になります。" -ForegroundColor Green
Write-Host '確認: [Environment]::GetEnvironmentVariable("OPENAI_API_KEY","User").Length'
