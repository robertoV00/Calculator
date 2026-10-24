#!/bin/bash
# Installs HyperFrames, video-use and DeepFilterNet into /home/user/repos
# for Claude Code cloud sessions.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

REPOS=/home/user/repos
mkdir -p "$REPOS"

clone() {
  local url=$1 dir=$2
  if [ -d "$REPOS/$dir/.git" ]; then
    git -C "$REPOS/$dir" pull --ff-only --quiet || true
  else
    git clone --depth 1 --quiet "$url" "$REPOS/$dir"
  fi
}

# HyperFrames (HTML-to-video)
clone https://github.com/heygen-com/hyperframes.git hyperframes
(cd "$REPOS/hyperframes" && bun install && bun run build) >/dev/null

# video-use (conversational video editor, registered as a Claude Code skill)
clone https://github.com/browser-use/video-use.git video-use
(cd "$REPOS/video-use" && uv sync --quiet)
mkdir -p "$HOME/.claude/skills"
ln -sfn "$REPOS/video-use" "$HOME/.claude/skills/video-use"
if [ -n "${ELEVENLABS_API_KEY:-}" ]; then
  printf 'ELEVENLABS_API_KEY=%s\n' "$ELEVENLABS_API_KEY" > "$REPOS/video-use/.env"
  chmod 600 "$REPOS/video-use/.env"
fi

# DeepFilterNet (noise suppression). Python 3.11 + torch 2.4.1 because newer
# torchaudio drops the APIs deepfilternet imports.
clone https://github.com/Rikorose/DeepFilterNet.git DeepFilterNet
DF=$REPOS/DeepFilterNet
[ -x "$DF/.venv/bin/python" ] || uv venv --quiet -p 3.11 "$DF/.venv"
uv pip install --quiet -p "$DF/.venv" torch==2.4.1 torchaudio==2.4.1 deepfilternet
# The model download from GitHub is blocked by the proxy; use the copy in the repo.
mkdir -p "$HOME/.cache/DeepFilterNet"
[ -d "$HOME/.cache/DeepFilterNet/DeepFilterNet3" ] || unzip -oq "$DF/models/DeepFilterNet3.zip" -d "$HOME/.cache/DeepFilterNet"

echo "export PATH=\"$DF/.venv/bin:\$PATH\"" >> "${CLAUDE_ENV_FILE:-/dev/null}"
