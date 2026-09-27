# Windows 機セットアップ ｜ YBJ クリエイティブ／テクニカル機

Mac（庶務雑務）と役割分担する **Windows 機（3D・図面・パース・演出シート・リハ映像テロップ・音響）** を、
「Mac と同じかそれ以上」で動く状態にするための一式。Mac の synced スキル 47 本を調べて作ってある。

```
windows/
├─ 00_bootstrap.ps1     winget で一括導入（Git / Node / Python 3.13+3.11 / uv / Blender / ffmpeg / Chrome / Drive / Obsidian / REAPER …）
├─ 01_python.ps1        venv 2 系統（汎用 3.13 / bpy 用 3.11）
├─ 02_fonts.ps1         Noto Sans CJK（ユーザー単位）＋ matplotlibrc ＋ ffmpeg 用フォントパス
├─ 03_workspace.ps1     C:\YBJ 作業フォルダ・環境変数・git/PowerShell の UTF-8 化・CLAUDE.md 配置
├─ doctor.ps1           全部入ったか検証（GPU / NVENC の有無も出す）
├─ CLAUDE.windows.md    Windows 機の Claude Code ルール（03 が ~/.claude/CLAUDE.md に配置）
├─ requirements-general.txt / requirements-bpy311.txt
└─ notes/
   ├─ compat.md          スキル別 Mac 依存 → Windows 読み替え表・既知ブロッカー
   ├─ telop-windows.md   リハ映像テロップの Windows 最適化（GPU、drawtext のフォント指定、1 本書き）
   └─ previz-windows.md  Blender / bpy / GPU レンダー / UE 受け渡し
```

## 手順（30 分〜1 時間。ダウンロード待ちが大半）

### 0. 前提

- Windows 10 1809 以降 / Windows 11。winget（アプリ インストーラー）が入っていること。
- 管理者権限は **WSL2 を入れるときだけ**必要。それ以外はユーザー権限で通る。
- 外付け SSD（リハ映像用）と Google アカウント（Drive 用）。

### 1. このリポジトリを取る

PowerShell を開いて:

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned   # 初回のみ。.ps1 を実行できるようにする
winget install --id Git.Git -e                                          # git が無ければ
git clone https://github.com/yamazakibutai-design/daisuke.git "$env:USERPROFILE\daisuke"
cd "$env:USERPROFILE\daisuke\windows"
```

### 2. 順番に流す

```powershell
.\00_bootstrap.ps1 -DryRun        # 何が入るか確認
.\00_bootstrap.ps1                # 本番（core + creative + audio）
#   帳票も Windows で回すなら:  .\00_bootstrap.ps1 -Groups all
#   WSL2 も入れるなら（管理者 PowerShell で）: .\00_bootstrap.ps1 -IncludeWsl
```

**ここで一度ターミナルを閉じて開き直す**（PATH に Node / Python / uv が載る）。

```powershell
cd "$env:USERPROFILE\daisuke\windows"
.\01_python.ps1                   # venv: ybj(3.13) / bpy311(3.11)。bpy の import テストまでやる
.\02_fonts.ps1                    # Noto Sans CJK をユーザー単位で。オフラインなら -SkipNoto
.\03_workspace.ps1                # C:\YBJ、環境変数、CLAUDE.md。Drive が G: に無ければ -SharedRoot で指定
```

もう一度ターミナルを開き直して:

```powershell
.\doctor.ps1                      # OK/NG 一覧。必須 NG が 0 なら完了
```

### 3. アプリ側の初期設定（手作業）

| アプリ | やること |
|---|---|
| **Claude Code** | `claude` を実行してログイン。Mac と同じアカウントなら synced スキル（zumen-3d-previz 等）が自動で降りてくる。降りてこなければ Mac の `~/.claude/skills/` を Drive 経由でコピー |
| **Google Drive** | サインイン → **「ファイルをストリーミング」** を選ぶ（ミラーしない）。G: に「マイドライブ」が出れば OK |
| **Obsidian** | 「保管庫を開く」で `G:\マイドライブ\…\<Mac の保管庫>` を指定 |
| **Blender** | 一度起動して 4.2 LTS であることを確認（bpy と版を揃える） |
| **Epic Games Launcher** | サインイン → Unreal Engine 5.x を導入（40GB 級。必要になってから） |
| **DaVinci Resolve**（任意） | blackmagicdesign.com から。Studio 版なら MCP 連携がある（riha-douga-telop 参照） |
| **画像生成 API**（任意） | butai-perspective / bolero-senden 用。`OPENAI_API_KEY` / `GOOGLE_API_KEY` をユーザー環境変数に |

## Mac との役割分担（決めごと）

| | Windows（この機） | Mac |
|---|---|---|
| 担当 | 3D プレビズ / 図面 / パース / 演出シート / 立ち位置表 / リハ映像テロップ / 音響 / 画像・動画生成 | 見積 / 請求 / 受注 / 精算 / 打診 / 募集 / Gmail 下書き / Chrome 自動化 / カレンダー |
| 作業場所 | `C:\YBJ\`（`%YBJ_HOME%`） | `~/Desktop/YBJ/` `~/Desktop/山崎舞台事務所/` |
| 共有 | Drive を**読む**（`G:\マイドライブ` = Mac の Desktop の写し）。渡すときは `_from_windows\` に置く | Desktop を Drive に**ミラー**（既存） |
| 同期 | しない | しない |

台帳系 xlsx（受注管理・打診台帳・在庫）は Mac のスキルが正本として更新する。Windows から書くと壊れるので読むだけ。

## 「Mac と同じかそれ以上」の中身

| | Mac（Cowork の Linux VM） | Windows |
|---|---|---|
| リハ映像 62 分の書き出し | 40〜50 分（ソフトデコード、120 秒制限でセグメント分割） | GPU なら 10 分前後。制限なし、1 本書き |
| Blender レンダー | CPU | GPU（Cycles OptiX / Eevee） |
| Unreal Engine | 無し | ネイティブ |
| DaVinci Resolve | 無し（MCP 経由のみ） | ネイティブ |
| Python | VM 内。`--break-system-packages` | venv 2 系統。UTF-8 固定 |
| 日本語フォント | Noto CJK | Noto CJK ＋ Yu Gothic |
| 帳票 PDF 化 | ○ | △ AF_UNIX 問題 → Mac 担当のまま、または WSL2（`notes/compat.md`） |

## 困ったとき

| 症状 | 対処 |
|---|---|
| `.ps1 を読み込めません。スクリプトの実行が無効` | `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` |
| 日本語が化ける（PowerShell） | PowerShell 7（`pwsh`）を使う。5.1 は `03_workspace.ps1` のプロファイルで UTF-8 化してある |
| `python` が Microsoft Store を開く | 設定 > アプリ > アプリ実行エイリアス で python.exe / python3.exe を OFF。venv のフルパスで呼べば無関係 |
| `bpy` が入らない | `01_python.ps1 -Recreate`。それでもだめなら `blender.exe -b --python` で回す（`notes/previz-windows.md`） |
| ffmpeg に `h264_nvenc` が無い | `winget install Gyan.FFmpeg`（Essentials 版には無い）。NVIDIA ドライバも更新 |
| winget の ID が見つからない | `winget search <名前>` で現在の ID を調べ、`00_bootstrap.ps1` の候補リストに足す |
| Drive が G: に出ない | Drive の設定 > マイドライブの同期オプション > ストリーミング。レターは設定で変えられる |
| `Operation not permitted` で消せない | それは Mac の VM の話。Windows では普通に消せる（`_中間ファイル_削除可` を確認してから） |
