# YBJ Mac 機ルール（Claude Code 用）

`daisuke/mac/setup.sh` が `~/.claude/CLAUDE.md` に配置したもの。Windows 機の CLAUDE.md と対になる。

## 役割分担（最重要）

| 機 | 担当 |
|---|---|
| **この Mac** | 事務: 見積 / 請求 / 受注 / 精算 / 打診 / 募集 / Gmail 下書き / Chrome 自動化 / カレンダー / 台帳の更新（**台帳の正本はここ**） |
| **Windows** | 3D プレビズ / 図面 / パース / 演出シート / リハ映像テロップ（NVENC）/ 文字起こし（GPU）/ ComfyUI 画像生成 / 夜間バッチ |

- 映像テロップ・3D レンダー・大量画像生成を頼まれたら「Windows 機のほうが速い（GPU）」と一言添え、それでもここでやるなら CPU で回す。
- Windows から来た成果物は `~/Desktop/_from_windows/`（Drive 経由）に落ちてくる。

## パス規約

| 用途 | 場所 |
|---|---|
| 作業ルート | `~/Desktop/YBJ`（`$YBJ_HOME`）。Google Drive がミラーしているので Windows からも見える |
| 事務所側 | `~/Desktop/山崎舞台事務所` |
| 中間ファイル | `~/Desktop/YBJ/_中間ファイル_削除可` |
| Python | `$YBJ_VENV`（`~/.venvs/ybj/bin/python`）。`--break-system-packages` は使わない |
| LibreOffice | `soffice` が PATH に無ければ `/Applications/LibreOffice.app/Contents/MacOS/soffice` |
| API キー | `~/.bolero-senden.env`（GEMINI_API_KEY）。Windows と同じキー |

## 自動判断ルール（聞かずにやる）

1. 帳票は必ず `chouhyou-kenpin-loop` を通してから渡す。PDF 化は LibreOffice。
2. 音声・映像の内容を聞かれたら `~/daisuke/mac/whisper.sh <file>` で文字起こし（Apple Silicon の MLX。1 時間で 10 分前後）してから答える。
3. 台帳 xlsx を更新するときは、Windows 側で同じファイルを開いていないか一言確認。
4. 20 分を超える処理は見積もり時間を言い、「Windows の夜間バッチに回す」を提案する。
5. 成果物は `~/Desktop/YBJ` 配下に保存しパスを報告する。Windows に渡す物は `~/Desktop/YBJ/_to_windows/`。

## 報告のしかた

所要時間は着手前に伝える。消せない制約は無い。中間ファイルは `_中間ファイル_削除可` に寄せ、確認してから消す。
