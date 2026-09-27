#!/usr/bin/env bash
# Mac（事務機）セットアップ — 1 本流すだけ。Windows と対になる最小構成。
# 使い方: bash <(curl -fsSL https://raw.githubusercontent.com/yamazakibutai-design/daisuke/claude/awesome-turing-hw3g4d/mac/setup.sh)
set -u
ok(){ printf '  OK   %s\n' "$*"; }; step(){ printf '\n[*] %s\n' "$*"; }; warn(){ printf '  WARN %s\n' "$*"; }

step "Homebrew"
if ! command -v brew >/dev/null 2>&1; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"; echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
fi
ok "$(brew --version | head -1)"

step "帳票に必要なもの（LibreOffice / Noto CJK / Python / uv / git）"
brew install --quiet git python uv >/dev/null 2>&1 && ok "git python uv"
brew install --cask --quiet libreoffice font-noto-sans-cjk-jp >/dev/null 2>&1 && ok "LibreOffice / Noto Sans CJK JP"
brew install --cask --quiet google-chrome google-drive claude obsidian >/dev/null 2>&1 && ok "Chrome / Google Drive / Claude Desktop / Obsidian"

step "Claude Code"
command -v claude >/dev/null 2>&1 || curl -fsSL https://claude.ai/install.sh | bash
grep -q '.local/bin' ~/.zprofile 2>/dev/null || echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zprofile
export PATH="$HOME/.local/bin:$PATH"; ok "$(claude --version 2>/dev/null || echo 'claude: ターミナルを開き直して確認')"

step "Python venv ~/.venvs/ybj"
mkdir -p ~/.venvs; [ -x ~/.venvs/ybj/bin/python ] || uv venv --python 3.13 ~/.venvs/ybj >/dev/null
uv pip install --python ~/.venvs/ybj/bin/python -q openpyxl matplotlib pillow numpy pandas pymupdf pypdf python-docx python-pptx reportlab lxml defusedxml requests && ok "packages"

step "環境変数（~/.zprofile）"
grep -q 'YBJ Mac (setup.sh)' ~/.zprofile 2>/dev/null || cat >> ~/.zprofile <<'EOF'
# --- YBJ Mac (setup.sh) ---
export YBJ_HOME="$HOME/Desktop/YBJ"
export YBJ_VENV="$HOME/.venvs/ybj/bin/python"
export PYTHONUTF8=1
# --- end YBJ ---
EOF
ok "YBJ_HOME=~/Desktop/YBJ / YBJ_VENV / PYTHONUTF8"

step "Windows と同じカスタマイズ（フォルダ / matplotlib / git / CLAUDE.md / 文字起こし）"
REPO="$HOME/daisuke"; [ -d "$REPO/.git" ] || git clone -q -b claude/awesome-turing-hw3g4d https://github.com/yamazakibutai-design/daisuke.git "$REPO"
git -C "$REPO" pull -q 2>/dev/null || true
for d in "3D/ブレンダ" 図面 パース 演出シート リハ映像 音源/文字起こし 音響 ClaudeOutput _中間ファイル_削除可 _to_windows; do mkdir -p "$HOME/Desktop/YBJ/$d"; done
mkdir -p ~/.matplotlib; cat > ~/.matplotlib/matplotlibrc <<'EOF2'
font.family        : sans-serif
font.sans-serif    : Noto Sans CJK JP, Hiragino Sans, Hiragino Kaku Gothic ProN, DejaVu Sans
axes.unicode_minus : False
pdf.fonttype       : 42
ps.fonttype        : 42
EOF2
git config --global core.quotepath false; git config --global core.autocrlf false
mkdir -p ~/.claude
if [ -f ~/.claude/CLAUDE.md ] && ! grep -q 'YBJ Mac 機ルール' ~/.claude/CLAUDE.md; then printf '\n\n' >> ~/.claude/CLAUDE.md; cat "$REPO/mac/CLAUDE.mac.md" >> ~/.claude/CLAUDE.md; else cp "$REPO/mac/CLAUDE.mac.md" ~/.claude/CLAUDE.md; fi
ok "~/.claude/CLAUDE.md（Mac 版ルール）"
uv pip install --python ~/.venvs/ybj/bin/python -q mlx-whisper && ok "mlx-whisper（文字起こし・Apple Silicon）" || warn "mlx-whisper は Apple Silicon 専用"
chmod +x "$REPO"/mac/*.sh; ok "$REPO/mac/{whisper,secrets,doctor}.sh"
cp "$REPO"/windows/SETUP_*.md "$HOME/Desktop/YBJ/README_Windows.md" 2>/dev/null && ok "~/Desktop/YBJ/README_Windows.md"

step "API キー"
[ -f ~/.bolero-senden.env ] && ok "~/.bolero-senden.env あり" || warn "~/.bolero-senden.env が無い（GEMINI_API_KEY=... を 1 行書く）"

step "検証"
soffice --version 2>/dev/null | head -1 || /Applications/LibreOffice.app/Contents/MacOS/soffice --version | head -1
~/.venvs/ybj/bin/python -c 'import openpyxl,reportlab;print("python ok")'
fc-list 2>/dev/null | grep -qi 'Noto Sans CJK' && ok "Noto CJK" || warn "Noto CJK は再ログイン後に有効"

cat <<'EOF'

完了。健康診断: bash ~/daisuke/mac/doctor.sh
あとは手作業 3 つ:
  1) Google Drive を起動 → サインイン → デスクトップを「ミラーリング」
  2) claude と打ってログイン（スキル 47 本と MCP は自動）
  3) Claude Desktop / Chrome の Claude 拡張にログイン
EOF
