#!/usr/bin/env bash
# Ubuntu (WSL2) 側セットアップ — 05_wsl.ps1 -Stage B から呼ばれる
# 引数1: Windows のユーザーフォルダの WSL パス（例 /mnt/c/Users/daisu）
set -euo pipefail
WINHOME="${1:-/mnt/c/Users/$USER}"

echo "== apt: LibreOffice / Noto CJK / Python =="
sudo apt-get update -qq
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
  libreoffice-calc libreoffice-writer libreoffice-impress \
  fonts-noto-cjk fonts-noto-cjk-extra fonts-ipafont-gothic \
  python3 python3-venv python3-pip build-essential fontconfig >/dev/null
fc-cache -f >/dev/null || true

echo "== Python venv ~/.venvs/ybj =="
mkdir -p ~/.venvs
[ -x ~/.venvs/ybj/bin/python ] || python3 -m venv ~/.venvs/ybj
~/.venvs/ybj/bin/pip install -q --upgrade pip
REQ="$WINHOME/daisuke/windows/requirements-general.txt"
if [ -f "$REQ" ]; then
  # Windows 用ファイルは CRLF の可能性があるので落としてから渡す
  tr -d '\r' < "$REQ" > /tmp/req.txt
  ~/.venvs/ybj/bin/pip install -q -r /tmp/req.txt
else
  ~/.venvs/ybj/bin/pip install -q openpyxl matplotlib pillow numpy pymupdf pypdf python-docx python-pptx reportlab lxml defusedxml requests
fi

echo "== リンクと環境変数 =="
[ -e ~/YBJ ] || ln -s /mnt/c/YBJ ~/YBJ
if ! grep -q 'YBJ Windows (wsl-setup.sh)' ~/.bashrc; then
cat >> ~/.bashrc <<'EOF'

# --- YBJ Windows (wsl-setup.sh) ---
export YBJ_HOME=/mnt/c/YBJ
export YBJ_SHARED="/mnt/g/マイドライブ"
export PYTHONUTF8=1
export LANG=C.UTF-8
alias ybjpy='~/.venvs/ybj/bin/python'
# Windows 側の synced スキル（Claude Code が同期）をそのまま参照できる
export YBJ_SKILLS="__WINHOME__/.claude/skills/synced"
# --- end YBJ ---
EOF
sed -i "s|__WINHOME__|$WINHOME|" ~/.bashrc
fi

echo "== 完了 =="
soffice --version | head -1
~/.venvs/ybj/bin/python -c 'import openpyxl, reportlab; print("python ok")'
