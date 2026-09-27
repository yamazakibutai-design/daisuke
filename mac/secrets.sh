#!/usr/bin/env bash
# API キーを ~/.bolero-senden.env に対話登録（値は画面に出ない）。Windows の 04_secrets.ps1 と対。
set -u
F=~/.bolero-senden.env; touch "$F"; chmod 600 "$F"
for k in GEMINI_API_KEY GOOGLE_API_KEY OPENAI_API_KEY; do
  if grep -q "^$k=" "$F" && [ "${1:-}" != "--force" ]; then echo "  --   $k : 設定済み（上書きは --force）"; continue; fi
  read -r -s -p "$k: " v; echo
  [ -z "$v" ] && { echo "  --   $k : 飛ばしました"; continue; }
  grep -v "^$k=" "$F" > "$F.tmp"; printf '%s=%s\n' "$k" "$v" >> "$F.tmp"; mv "$F.tmp" "$F"; chmod 600 "$F"
  echo "  OK   $k を登録（${#v} 文字）"
done
