#!/usr/bin/env bash
# Mac 側の健康診断（Windows の doctor.ps1 と対）
set -u
row(){ printf '%-8s %-3s %-32s %s\n' "$1" "$2" "$3" "$4"; }
chk(){ if eval "$3" >/dev/null 2>&1; then row "$1" OK "$2" "$(eval "$4" 2>/dev/null | head -1)"; else row "$1" NG "$2" "$5"; fi; }
export PATH="$HOME/.local/bin:/opt/homebrew/bin:$PATH"
chk core   "brew"        "command -v brew"      "brew --version"            "setup.sh"
chk core   "git"         "command -v git"       "git --version"             "setup.sh"
chk core   "claude"      "command -v claude"    "claude --version"          "curl -fsSL https://claude.ai/install.sh | bash"
chk core   "uv"          "command -v uv"        "uv --version"              "brew install uv"
chk python "venv ybj"    "test -x ~/.venvs/ybj/bin/python" "~/.venvs/ybj/bin/python -c 'import openpyxl,reportlab,matplotlib;print(\"openpyxl reportlab matplotlib\")'" "setup.sh"
chk office "LibreOffice" "test -x /Applications/LibreOffice.app/Contents/MacOS/soffice" "/Applications/LibreOffice.app/Contents/MacOS/soffice --version" "brew install --cask libreoffice"
chk fonts  "Noto Sans CJK JP" "fc-list 2>/dev/null | grep -qi 'Noto Sans CJK' || ls ~/Library/Fonts /Library/Fonts 2>/dev/null | grep -qi NotoSansCJK" "echo ok" "brew install --cask font-noto-sans-cjk-jp"
chk apps   "Google Drive" "test -d '/Applications/Google Drive.app'" "echo ok" "brew install --cask google-drive"
chk apps   "Drive ミラー ~/Desktop/YBJ" "test -d ~/Desktop/YBJ" "echo ok" "Drive でデスクトップをミラーリング"
chk apps   "Claude Desktop" "test -d /Applications/Claude.app" "echo ok" "brew install --cask claude"
chk apps   "Chrome"       "test -d '/Applications/Google Chrome.app'" "echo ok" "brew install --cask google-chrome"
chk secret "GEMINI_API_KEY" "grep -q '^GEMINI_API_KEY=.\\+' ~/.bolero-senden.env" "echo '登録済み'" "bash ~/daisuke/mac/secrets.sh"
if grep -q '^GEMINI_API_KEY=' ~/.bolero-senden.env 2>/dev/null; then
  k=$(sed -n 's/^GEMINI_API_KEY=//p' ~/.bolero-senden.env | head -1)
  curl -fsS "https://generativelanguage.googleapis.com/v1beta/models?key=$k&pageSize=1" >/dev/null 2>&1 && row secret OK "Gemini API 接続" "接続 OK" || row secret NG "Gemini API 接続" "キー無効。AI Studio で再発行"
fi
chk plus   "whisper (mlx)" "test -x ~/.venvs/ybj/bin/mlx_whisper" "echo 'mlx-whisper'" "setup.sh"
chk env    "CLAUDE.md"    "grep -q 'YBJ Mac 機ルール' ~/.claude/CLAUDE.md" "echo ok" "setup.sh"
