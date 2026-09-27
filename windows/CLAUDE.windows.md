# YBJ Windows 機ルール（Claude Code 用）

このファイルは `daisuke/windows/03_workspace.ps1` が `%USERPROFILE%\.claude\CLAUDE.md` に配置したもの。
Windows 機で Claude Code を使うときの前提を書いてある。Mac 側の CLAUDE.md とは別物。

## 役割分担（最重要）

| 機 | 担当 | 代表スキル |
|---|---|---|
| **この Windows 機** | クリエイティブ／テクニカル | zumen-3d-previz / riha-douga-telop / butai-perspective / intercom-zu / foh-takuhaichi / enshutsu-sheet / kaigai-stage-rider / bolero-senden（画像・動画生成） |
| **Mac** | 庶務雑務 | estimate / invoice / ybj-juchusho / arari-shisan / dashin-kanri / boshu-anken / jizen-seisan-annai / getsumatsu-shiharai-annai / bolero-juchu / Gmail 下書き・Chrome 自動化 全般 |

- 帳票・メール系は原則 Mac 担当。ただし **WSL2 が入っていればここでも回せる**（`wsl -l -q` に Ubuntu があれば可）:
  `wsl -e bash -lc 'source ~/.venvs/ybj/bin/activate && cd /mnt/c/YBJ && python3 <script>'`
  - Windows の Python で直接回さない（xlsx/docx/pptx の `office/soffice.py` が `socket.AF_UNIX` で落ちる）
  - 台帳（`estimates_2026.xlsx` 等）は Mac の Drive ミラー上にある。Windows から書くのは **Mac 側で同じファイルを開いていないとき**だけ。書く前にユーザーに一言確認する
  - Gmail 下書きは MCP（claude.ai コネクタ）経由で作れる。Chrome ポップアップの手順は Windows の Chrome で同じ
- 逆に 3D・図面・パース・映像・音響は Mac の Linux VM より **この機のほうが速い**（GPU がある）。遠慮なく使う。

## パス規約

| 用途 | 場所 | 備考 |
|---|---|---|
| 作業ルート | `{{YBJ_HOME}}` | Mac の `~/Desktop/YBJ` に相当。**成果物は必ずここ** |
| 共有元（読むだけ） | `{{YBJ_SHARED}}` | Mac が Google Drive にミラーしている Desktop。Obsidian の MD もここ |
| Mac へ渡す箱 | `{{YBJ_SHARED}}\_from_windows\` | 共有元に書くのはここだけ |
| 中間ファイル | `{{YBJ_HOME}}\_中間ファイル_削除可\` | 消してよいか確認してから消す |
| 外付け SSD | ドライブレター（例 `D:\`） | スキル内の `/Volumes/PortableSSD` はこれに読み替える |

- スキル内の `~/Desktop/YBJ/…` は `{{YBJ_HOME}}\…` に読み替える。`~/Desktop/山崎舞台事務所/…` は Mac 担当なので原則触らない。
- パスは `pathlib.Path` で組む。文字列連結で `/` `\` を混ぜない。
- ルートは ASCII（`C:\YBJ`）だが配下の日本語フォルダ名は使ってよい。`PYTHONUTF8=1` が入っている。
- `open()` には `encoding='utf-8'` を明示する（既定 cp932 の事故防止）。

## Python

- 汎用: `%YBJ_VENV%`（Python 3.13）。openpyxl / matplotlib / PIL / PyMuPDF / numpy が入っている。
- 3D（bpy）: `%YBJ_VENV_BPY%`（Python 3.11）。`bpy==4.2.0` はここにしか入らない。
- 追加パッケージは venv に入れる。`--break-system-packages` は Linux の話なので使わない。
- Bash ツールから呼ぶときはアクティベート不要。フルパスで
  `"$YBJ_VENV" script.py` / `"$YBJ_VENV_BPY" build_template.py`。

## シェル

- **Claude Code の Bash ツールは Git Bash** で動く。`&&` `~` `$HOME` は使える。
  Windows パスは `/c/YBJ/...` か、`"C:\\YBJ\\..."` のように引用符で渡す。
- ユーザーが自分で叩くのは PowerShell 7。手順を提示するときは PowerShell 構文で書く。
- PowerShell コマンドレットが要るときは `pwsh -NoProfile -c "..."`。
- POSIX 専用（`LD_PRELOAD` / `nohup` / `/usr/share/fonts` …）は WSL2 へ: `wsl -e bash -lc '...'`。
  WSL からは Windows のファイルが `/mnt/c/YBJ/...` で見える。

## ffmpeg / リハ映像テロップ

- Linux VM 向けの「30 秒セグメント＋レジューム」「120 秒制限」は **この機には無い**。1 本で書き出す。
- GPU があれば `-hwaccel cuda` でデコード、`-c:v h264_nvenc` でエンコード。無ければ `libx264`。
- テロップフォントは `%YBJ_TELOP_FONT%`。drawtext は `fontfile='C\:/Users/.../NotoSansCJK-Bold.ttc'` の書き方。
- 仕様（黄色 0.82 ＋黒文字・x=34/1158・y=31・amix normalize=0 …）は skill の記述をそのまま守る。
- 詳細: `daisuke/windows/notes/telop-windows.md`

## 3D プレビズ

- `bpy==4.2.0` は `bpy311` venv。Blender GUI は 4.2 LTS を入れてある。
- wheel が入らないときは `blender.exe -b --python build.py` で同じスクリプトが動く（API 同一）。
- FBX → Unreal Engine。単位は m（Blender）→ cm（UE）の変換に注意。
- 詳細: `daisuke/windows/notes/previz-windows.md`

## Mac にできないこと（この機の強み。積極的に使う）

| 機能 | 呼び方 | 出力先 |
|---|---|---|
| **文字起こし**（Whisper・GPU） | `pwsh -File %USERPROFILE%\daisuke\windows\ybj-whisper.ps1 "<音声/動画>"` | `C:\YBJ\音源\文字起こし\<名前>\`（txt / srt / json） |
| **ローカル画像生成**（ComfyUI・GPU） | サーバー `pwsh -File %YBJ_COMFY%\start-comfy.ps1` を起動しておき、`"$YBJ_VENV" %YBJ_COMFY%\comfy_generate.py --prompt "..." --n 4 --out C:\YBJ\パース\x.png` | `C:\YBJ\パース\` |
| **API 画像生成**（Gemini / Imagen） | `GEMINI_API_KEY` 登録済み。butai-perspective / bolero-senden のスクリプトがそのまま使う | スキルの規定どおり |
| **夜間バッチ** | `C:\YBJ\_jobs\<名前>.md` に日本語で書き、`08_scheduler.ps1 -Register <名前> -At 03:00` | `C:\YBJ\_logs\` |

- パースは「まず ComfyUI で構図案を量産 → 良いものを Gemini/Imagen で仕上げ」の 2 段が速くて安い。
- 文字起こしはリハ音声の譜割時刻取り・MC 把握・会議録に使う。1 時間の音声で数分。
- 長いレンダー・書き出しは夜間バッチに回す提案をする（PC はスリープさせない）。

## 報告のしかた

- 所要時間は着手前に伝える（GPU の有無で 5〜10 倍変わる）。
- 「消せない」制約は無い。中間ファイルは `_中間ファイル_削除可` へ移し、確認を取ってから消す。
- Mac にしか無い情報（受注表・打診台帳など）が要るときは、`{{YBJ_SHARED}}` から読む。無ければユーザーに Mac 側で出してもらう。
