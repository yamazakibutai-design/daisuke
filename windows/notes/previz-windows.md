# 図面→3D プレビズ ｜ Windows メモ

`zumen-3d-previz` スキルの手順 0〜3（図面の読み方・縮尺・1800mm グリッド校正・寸法根拠表）は OS 無関係。
Windows で変わるのは **手順 4 のビルド環境と保存先**、そして UE への受け渡し。

## Python と bpy

| 用途 | 使うもの | 理由 |
|---|---|---|
| ビルドスクリプト実行 | `%YBJ_VENV_BPY%`（Python 3.11 ＋ `bpy==4.2.0`） | Blender 4.2 LTS は CPython 3.11 系。3.13 の venv には wheel が無い |
| 図面 PDF の画像化 | 同じ venv の PyMuPDF（`import fitz`） | 200dpi 化 → Read で目視、はスキルどおり |
| .blend を開いて目視 | Blender 4.2 LTS（GUI） | `00_bootstrap.ps1` で導入済み |

```powershell
& $env:YBJ_VENV_BPY build_template.py
```

`pip install bpy==4.2.0 --break-system-packages` はスキルに書いてあるが Linux 用。Windows では venv に入れてあるので不要。

### bpy の wheel が入らない・落ちるとき

Blender 本体の Python で同じスクリプトを走らせる。API は同一なので `build_template.py` は無改造で動く。

```powershell
& "C:\Program Files\Blender Foundation\Blender 4.2\blender.exe" -b --python build_template.py
```

`bpy.ops.wm.save_as_mainfile()` の保存先を引数で渡すか、スクリプト内の出力パスを `C:\YBJ\3D\ブレンダ\...` にしておく。

## GPU レンダー（Mac の VM より「以上」の部分）

4 視点レンダーを Cycles の GPU で回すと目視検証が速い。ビルドスクリプトのレンダー設定の直前に:

```python
import bpy
prefs = bpy.context.preferences.addons["cycles"].preferences
prefs.compute_device_type = "OPTIX"      # NVIDIA。無ければ "CUDA"、AMD は "HIP"
prefs.get_devices()
for d in prefs.devices:
    d.use = True
bpy.context.scene.cycles.device = "GPU"
```

`compute_device_type` の設定が通らない（例外）ときは GPU が無いかドライバが古い。`doctor.ps1` の gpu 行を見る。
ブロックアウトの目視用なら Eevee（`scene.render.engine = "BLENDER_EEVEE_NEXT"`）で十分速い。

## 保存先と版管理

| Mac | Windows |
|---|---|
| `~/Desktop/YBJ/３D/ブレンダ/{会場}/{YYYYMMDD}/` | `C:\YBJ\3D\ブレンダ\{会場}\{YYYYMMDD}\` |
| 図面入力 PDF | `C:\YBJ\3D\図面入力\{会場}\` |
| FBX | `C:\YBJ\3D\UE\{会場}\{YYYYMMDD}\` |

過去の類似 .blend は Mac 側にある。`%YBJ_SHARED%`（Google Drive のミラー）の `YBJ/３D/ブレンダ/` を読みに行く。
コピーして使い、共有元には書き戻さない。

## FBX → Unreal Engine

- Blender は m、UE は cm。`export_fbx.py` で `apply_unit_scale=True, global_scale=1.0` にしておくと FBX 側に単位が乗り、UE 側は「Convert Scene Unit」を ON で cm に揃う。
- 座標系（X+=上手／Y+奥／Z+上）は Blender の Z-up。UE も Z-up だが Y の向きが逆になるので、UE 取り込み後に「上手が右」になっているか 1 度だけ確認する。
- コレクション（VENUE / STAGE_SET / LED / …）はそのまま FBX の階層になるので、UE ではフォルダ単位で表示切替できる。
- UE は Epic Games Launcher から 5.x を入れる（`00_bootstrap.ps1` は Launcher までしか入れない。UE 本体は 40GB 級なので手動で）。

## 学習済みルールの追記先

スキル本文の「造作の学習済みルール」は Mac の synced スキルにある。Windows で新しく得た知見も同じ SKILL.md に追記する
（アカウント同期なので、どちらの機から書いても両方に降りる）。
