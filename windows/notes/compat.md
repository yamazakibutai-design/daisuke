# スキル別 互換表 ｜ Mac 依存箇所と Windows での扱い

synced スキル 47 本を調べた結果。「どちらの機で回すか」と「Windows で回すときに読み替える所」。
方針: **クリエイティブ／テクニカルは Windows、庶務雑務は Mac**。同期はせず、Google Drive のミラーを読むだけ。

## 全スキル共通の読み替え

| Mac / Linux VM の書き方 | Windows | 対処 |
|---|---|---|
| `~/Desktop/YBJ/…` | `%YBJ_HOME%\…`（`C:\YBJ\…`） | `03_workspace.ps1` が環境変数と CLAUDE.md を用意 |
| `~/Desktop/山崎舞台事務所/…` | Mac 担当。読むだけなら `%YBJ_SHARED%\…` | 触らない |
| `~/Desktop/ClaudeOutput/` | `C:\YBJ\ClaudeOutput\` | |
| `/Volumes/PortableSSD/` | 外付け SSD のドライブレター（`D:\` 等） | 都度指定 |
| `python3` / `pip install … --break-system-packages` | venv の `python.exe`（`%YBJ_VENV%` / `%YBJ_VENV_BPY%`） | `01_python.ps1` |
| `/usr/share/fonts/opentype/noto/NotoSansCJK-*.ttc` | `%LOCALAPPDATA%\Microsoft\Windows\Fonts\NotoSansCJK-*.ttc`（`02_fonts.ps1` が置く） | フォント探索リストに足す |
| `/usr/share/fonts/truetype/droid/DroidSansFallbackFull.ttf` | 無い。Noto か `C:\Windows\Fonts\YuGothB.ttc` | 同上 |
| `font.family = "Yu Gothic"` 等の名前指定 | そのまま動く | `matplotlibrc` で既定も入れてある |
| 既定エンコーディング cp932 | `PYTHONUTF8=1` で UTF-8 固定 | `03_workspace.ps1` |
| bash 前提の手順（`&&`, `~`, `nohup`） | Claude Code の Bash ツールは Git Bash なので概ね動く。ユーザー側は PowerShell | CLAUDE.md に記載 |
| `open -a` / `osascript` | 無い | Mac 担当スキルにしか出てこない（boshu-anken の Keep 同期） |

## Windows で回すスキル（今回の主目的）

| スキル | 用途 | Windows での状態 | 読み替え・注意 |
|---|---|---|---|
| **zumen-3d-previz** | 図面→Blender ブロックアウト→FBX | ◎ Mac より速い（GPU レンダー） | `bpy==4.2.0` は 3.11 venv。`notes/previz-windows.md` |
| **riha-douga-telop** | リハ映像テロップ＋音源ミックス | ◎ Mac の VM より 3〜8 倍速い（NVENC） | 手順 8 を差し替え。`notes/telop-windows.md` |
| **butai-perspective** | 舞台イメージパース生成 | ○ | 画像生成 API（GPT-4o image / Nano Banana / Imagen4）のキーを環境変数で。Chrome 半自動は Windows Chrome で同じ。`Desktop/(YBJ/2026/…` は `C:\YBJ\パース\` |
| **enshutsu-sheet** | 演出シート（1曲1シート・A3横） | ○ | openpyxl のみ。PDF 化が要る場合だけ LibreOffice（下記 AF_UNIX 注意） |
| **tachiichi-hyou** | 立ち位置表（matplotlib 描画） | △ フォント探索が Linux パス | `render_tachiichi.py` 29〜34 行の候補に Windows の Noto パスを足す。無ければ matplotlibrc の既定（Yu Gothic）に落ちる |
| **intercom-zu** | インカムシステム図 PDF（matplotlib） | ○ | 保存先 `Desktop/山崎舞台事務所/インカム資料/` は Mac 担当領域。Windows で作るなら `C:\YBJ\図面\インカム\` に出して `_from_windows` で渡す |
| **foh-takuhaichi** | FOH 卓配置図（PIL） | ○ | `Desktop/YBJ/2026/HKTツアー/FOH客席/` → `C:\YBJ\図面\FOH客席\` |
| **kaigai-stage-rider** | 海外公演ライダー（docx・PIL 図） | △ | `gen_stage_images.py` が Droid/DejaVu の Linux パス直書き → Noto か YuGothB に。`build_doc_jp.js` は Node（入れてある） |
| **bolero-senden** | BOLERO 宣伝（画像・動画生成） | ○ 生成系のみ Windows 向き | 保存先が `Desktop/山崎舞台事務所/BOLERO在庫管理/_宣伝/`（Mac 領域）。成果物は `C:\YBJ\ClaudeOutput\` に出して渡す |
| pdf / xlsx / docx / pptx（Anthropic 共通） | 読み書き | ○ 読み書きは問題なし | **PDF 変換・再計算だけ AF_UNIX 問題**（下記） |

## Mac で回すスキル（庶務雑務。Windows では触らない）

estimate / invoice / ybj-mitsumori / ybj-juchusho / ybj-juchu / ybj-juchu-hub / purchase-order / mitsumori-irai / arari-shisan /
chouhyou-kenpin-loop / unpan-tsuika-order / dashin-kanri / dashin-hyou / boshu-anken / gachu-kanri-skill /
jizen-seisan-annai / getsumatsu-shiharai-annai / bolero-juchu / time-schedule / taisuke / hkt-namelist /
yamazaki-kadou-gantt / schedule-hansei-renkei / soukatsu-schedule-renkei / morning / kenko-kanri / boatrace-yosou / l8

理由: Gmail 下書き・Chrome ポップアップ・Google カレンダー・`~/Desktop/山崎舞台事務所` 配下の台帳が Mac に集まっている。
それぞれのスキルが台帳 xlsx を「正本」として更新するので、2 台から書くと壊れる。**Windows からは読むだけ**。

## どちらでも（OS 非依存）

codex-review / skill-creator / docs / google-workspace / import-memory / local-file-delivery

## 既知の Windows ブロッカー

### 1. `office/soffice.py` の `socket.AF_UNIX`（xlsx / docx / pptx スキル）

```python
def _needs_shim() -> bool:
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)   # Windows の CPython に AF_UNIX は無い
        ...
    except OSError:                                             # → AttributeError は捕まらない
        return True
```

`recalc.py`（数式再計算）と PDF 変換がここを通るので、Windows ネイティブでは **例外で止まる**。
synced スキルは同期で上書きされるのでローカルパッチは残らない。対処は 2 択:

- **WSL2 で回す**（推奨。`00_bootstrap.ps1 -IncludeWsl`）
  `wsl -e bash -lc 'cd /mnt/c/YBJ/... && python3 recalc.py 見積.xlsx'`
  WSL 側に `sudo apt install libreoffice-calc fonts-noto-cjk python3-openpyxl` が要る。
- 帳票はそもそも Mac 担当なので、**Windows で帳票を作らない**（今回の方針はこちら）。

### 2. `estimate` / `invoice` の `export_pdf.py` が Mac パス直書き

`/Applications/LibreOffice.app/Contents/MacOS/soffice` を探す。Windows なら `C:\Program Files\LibreOffice\program\soffice.exe`。
Mac 担当スキルなので放置でよい。

### 3. `--break-system-packages`

jizen-seisan-annai / dashin-hyou / zumen-3d-previz / boatrace-yosou / bolero-senden に出てくる。Linux の Debian 系 Python 専用オプション。
Windows の venv では付けない（付けるとエラーではなく無視されるが、system Python に入れようとしている合図なので venv を使う）。

### 4. 日本語ファイル名と cp932

`PYTHONUTF8=1` を入れた後も、**ターミナルを開き直すまで効かない**。`doctor.ps1` の `UTF-8 mode` 行が 1 になっているか確認。

## Google Drive の使い方（情報共有のルール）

- Mac: Desktop を Google Drive にミラー（既存）。
- Windows: Google Drive を**ストリーミング**で入れる（ミラーしない）。`G:\マイドライブ\` が Mac の Desktop の写し。
- Windows からは **読むだけ**。Obsidian の保管庫も G: 上のを開く（Obsidian 側は読み書きしてよい。MD は台帳ではない）。
- Mac に渡したい成果物は `G:\マイドライブ\_from_windows\` に置く。Mac 側で Finder に降りてくる。
- 数 GB の映像・.blend は G: に置かない（ストリーミングの容量とアップロードで詰まる）。SSD か `C:\YBJ`。
