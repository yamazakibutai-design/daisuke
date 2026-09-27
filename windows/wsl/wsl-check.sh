#!/usr/bin/env bash
# WSL 側の検証 — 05_wsl.ps1 -Stage B から呼ばれる（PowerShell から引用符を渡さないためにファイル化）
set -u
ok=1
if soffice --version >/dev/null 2>&1; then echo "LibreOffice: $(soffice --version | head -1)"; else echo "LibreOffice: NG"; ok=0; fi
if [ -x ~/.venvs/ybj/bin/python ]; then
  if ~/.venvs/ybj/bin/python - <<'PY'
import socket, openpyxl, reportlab, matplotlib
socket.socket(socket.AF_UNIX).close()
print("python: AF_UNIX ok / openpyxl", openpyxl.__version__)
PY
  then :; else echo "python: NG"; ok=0; fi
else echo "python venv: NG"; ok=0; fi
fc-list | grep -qi 'Noto Sans CJK' && echo "fonts: Noto Sans CJK ok" || { echo "fonts: NG"; ok=0; }
[ -e ~/YBJ ] && echo "link: ~/YBJ -> $(readlink -f ~/YBJ)" || echo "link: NG"
[ "$ok" = 1 ] && echo "WSL_CHECK_OK" || exit 1
