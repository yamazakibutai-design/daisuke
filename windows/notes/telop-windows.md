# リハ映像テロップ ｜ Windows 最適化メモ

`riha-douga-telop` スキルは Mac の Cowork（Linux VM・4 コア・120 秒制限・rm 不可）向けに書かれている。
この Windows 機にはその制約が無いので、**手順 8「書き出し」だけ差し替える**。
手順 1〜7（譜割の読み方・クロマ照合・テロップ仕様・音のミックス）と手順 9〜10（検証・チャプター）はそのまま。

## VM との違い（ここだけ覚えればいい）

| 項目 | Mac の Linux VM | この Windows 機 |
|---|---|---|
| 1 回の実行時間 | 120〜178 秒で切られる | 制限なし |
| バックグラウンド | 殺される | 普通に動く |
| 削除 | `rm` 不可 | 可（確認してから） |
| HEVC Main10 デコード | ソフト。実時間の 1.2 倍 | GPU（`-hwaccel cuda` など） |
| H.264 エンコード | `libx264 veryfast` | `h264_nvenc`（無ければ libx264） |
| 62 分素材の書き出し | 40〜50 分 | **約 5 分**（実測: RTX 5070 Ti Laptop、cuda デコード→h264_nvenc で実時間の 13 倍速。2026-09-27） |
| 書き出し方 | 30 秒セグメント＋レジューム | **曲ごとに 1 本** → concat |
| 素材の場所 | `/Volumes/PortableSSD/...` | `D:\HKTRH\前\...`（外付け SSD のレター） |
| フォント | `/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc` | `%YBJ_TELOP_FONT%`（Noto か YuGothB） |

## エンコーダの選び方

`doctor.ps1` の `ffmpeg encoder` 行を見る。上から順に使えるものを選ぶ。

| GPU | デコード | エンコード | 品質指定 |
|---|---|---|---|
| NVIDIA | `-hwaccel cuda` | `-c:v h264_nvenc -preset p5 -tune hq -rc vbr -cq 23` | `-b:v 4200k -maxrate 7000k -bufsize 10000k` |
| Intel 内蔵 | `-hwaccel qsv` | `-c:v h264_qsv -preset medium -global_quality 23` | 同上 |
| AMD | `-hwaccel d3d11va` | `-c:v h264_amf -quality quality -rc vbr_peak` | 同上 |
| 無し | （指定しない） | `-c:v libx264 -preset veryfast -crf 21` | 同上 |

`-hwaccel cuda` は「デコードだけ GPU、フレームはメインメモリへ戻す」指定。
drawtext は CPU フィルタなので、`-hwaccel_output_format cuda` は付けない（付けると drawtext に渡せず落ちる）。
ビットレート・`-g 60 -keyint_min 60 -sc_threshold 0 -pix_fmt yuv420p -video_track_timescale 30000` は VM 時代の値をそのまま踏襲する（2.06GB／62 分に着地した実測）。

## NVENC が「Driver does not support the required nvenc API version」で落ちるとき

ffmpeg 9.x の NVENC は NVIDIA ドライバ **610 以上**（API 13.1）が要る。実機は 591.97 で落ちた。
NVIDIA App → ドライバー → エクスプレスインストール で更新すれば直る。`doctor.ps1` の `NVIDIA driver >= 610` 行で確認できる。
更新できないときは `libx264 -preset veryfast -crf 21` に落とす（VM と同じ速度感だが、制限が無いぶん実時間はそれより短い）。

## drawtext のフォント指定（Windows で一番ハマる所）

`fontfile=` に Windows パスを渡すときは **コロンをエスケープ・区切りはスラッシュ**。

```
fontfile='C\:/Users/daisuke/AppData/Local/Microsoft/Windows/Fonts/NotoSansCJK-Bold.ttc'
```

Python から組むならこれで固定:

```python
import os
font = os.environ["YBJ_TELOP_FONT"].replace("\\", "/").replace(":", r"\:")
```

テキスト側は `:` `'` `\` `%` を `\:` `\'` `\\` `\%` にエスケープ。曲名に `?` や `!` が入っていても問題ない。
テロップの中身（全角スペース 2 つ・fontsize 上限 84・boxborderw 18・x=34/1158・y=31）はスキル記載どおり。

## 1 曲ぶんの書き出し（映像＋音声を 1 本で）

VM では「映像と音声を一緒にセグメント化するとつなぎ目でクリックが乗る」ためバラしていたが、
**曲ごとに 1 本で書けばセグメントのつなぎ目自体が無い**ので、映像・音声を同時に出してよい。
ただし曲間の concat は `-c copy` なので、全曲で同じエンコード設定・同じ fps・同じ音声設定にする。

```
ffmpeg -y -hide_banner
  -hwaccel cuda
  -ss {video_in} -t {L} -i "D:/HKTRH/前/M9.MOV"
  -ss {src_in}   -t {L} -i "C:/YBJ/音源/愛知/M9_count.mp3"
  -filter_complex "
    [0:v]scale=1920:1080:flags=bilinear,fps=30,
         drawtext=fontfile='{font}':text='M9　　リターンマッチ':fontsize={fs}:fontcolor=black:box=1:boxcolor=yellow@0.82:boxborderw=18:x=34:y=31,
         drawtext=fontfile='{font}':textfile='C:/YBJ/_中間ファイル_削除可/M9_sections.txt':...[v];
    [1:a]adelay=3000|3000,volume=0.70[a1];
    [0:a]volume=0.30[a2];
    [a1][a2]amix=inputs=2:duration=first:dropout_transition=0:normalize=0[a]"
  -map "[v]" -map "[a]"
  -c:v h264_nvenc -preset p5 -tune hq -rc vbr -cq 23 -b:v 4200k -maxrate 7000k -bufsize 10000k
  -pix_fmt yuv420p -g 60 -keyint_min 60 -sc_threshold 0 -video_track_timescale 30000
  -c:a aac -b:a 160k -ar 48000 -ac 2
  "C:/YBJ/_中間ファイル_削除可/out_M09.mp4"
```

- `L` は `round(L*30)/30` で 30fps の整数フレームに丸める（スキル記載どおり）。
- 頭が録れていない曲は `adelay` を外して余白 0 で始める。
- セクション名は時刻付きの `enable='between(t,{s},{e})'` を並べる。曲によっては 20 個以上になるので `textfile=` かフィルタスクリプト（`-filter_complex_script`）に逃がすと引数長で困らない。
- 4〜5 曲を並列で回すと GPU が飽和する。NVENC は同時セッション数に上限があるので **2 並列まで**にする。順に回しても VM より速い。

## 全曲を繋ぐ・チャプター・検証

```
# list.txt: file 'C:/YBJ/_中間ファイル_削除可/out_M01.mp4' ... をセトリ順に
ffmpeg -y -f concat -safe 0 -i list.txt -i chapters.ffmeta -map_metadata 1 -c copy -movflags +faststart "D:/HKTRH/愛知_リハ_テロップ付き.mp4"
```

検証はスキルの手順 9 そのまま（40 秒クロマ再照合 → 全曲 0.25 秒以内、コンタクトシートで目視）。
コンタクトシートは ffmpeg で作れる:

```
ffmpeg -y -i out.mp4 -vf "select='eq(n\,180)',crop=1920:150:0:0" -frames:v 1 head_M09.png
ffmpeg -y -i "concat:..." -vf tile=1x13 sheet_1.png
```

（Python + PIL で縦積みしたほうが楽。`ybj` venv に Pillow が入っている。）

## 抜粋の渡し方

SendUserFile の 30MB 制限は Claude Code でも同じ。55 秒・2500kbps に再エンコードして渡す。
本編は SSD 上のパスを伝える。

## 所要時間の見積もり（着手前に伝える）

`doctor.ps1` で NVENC が OK なら「62 分素材で 5 分前後」（RTX 5070 Ti 実測 13 倍速）、無ければ「libx264 で 30〜40 分（VM よりは速い）」と伝える。
初回は 1 曲だけ書いて実測し、`(実測秒 / 曲の長さ) × 合計` で言い直す。
