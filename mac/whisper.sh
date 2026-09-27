#!/usr/bin/env bash
# 文字起こし（Apple Silicon: mlx-whisper）。使い方: whisper.sh <音声/動画> [ja]
set -eu
f="$1"; lang="${2:-ja}"; name="$(basename "${f%.*}")"
out="$HOME/Desktop/YBJ/音源/文字起こし/$name"; mkdir -p "$out"
~/.venvs/ybj/bin/mlx_whisper "$f" --model mlx-community/whisper-large-v3-turbo --language "$lang" \
  --output-dir "$out" --output-format all --verbose False
echo "完了 → $out"; ls -la "$out"
