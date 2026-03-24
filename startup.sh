#!/usr/bin/env bash
set -euo pipefail

# ─── Open Canvas Startup Script ───
# Ensures dependencies are installed, launches the app, and sets up tmux tiles.

APP_NAME="Open Canvas"

# 1. Install Homebrew if missing
if ! command -v brew >/dev/null 2>&1; then
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# 2. Install tmux if missing
if ! command -v tmux >/dev/null 2>&1; then
  echo "Installing tmux..."
  brew install tmux
fi

# 3. Install Open Canvas if not in /Applications
if [[ ! -d "/Applications/${APP_NAME}.app" ]]; then
  echo "Open Canvas not found in /Applications. Running installer..."
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  if [[ -f "$SCRIPT_DIR/install.sh" ]]; then
    bash "$SCRIPT_DIR/install.sh"
  else
    echo "install.sh not found. Please install Open Canvas first."
    exit 1
  fi
fi

# 4. Restart Open Canvas
echo "Restarting ${APP_NAME}..."
osascript -e "quit app \"${APP_NAME}\"" 2>/dev/null || true
sleep 2
open -a "${APP_NAME}"
echo "${APP_NAME} is running."

# 5. Set up tmux session with tiles
SESSION="open-canvas"

if tmux has-session -t "$SESSION" 2>/dev/null; then
  echo "tmux session '$SESSION' already exists. Attaching..."
  tmux attach-session -t "$SESSION"
  exit 0
fi

echo "Creating tmux session '$SESSION' with tiled panes..."
tmux new-session -d -s "$SESSION" -n main

# Split into a 2x2 grid
tmux split-window -h -t "$SESSION:main"
tmux split-window -v -t "$SESSION:main.0"
tmux split-window -v -t "$SESSION:main.1"

# Apply tiled layout
tmux select-layout -t "$SESSION:main" tiled

echo "Attaching to tmux session..."
tmux attach-session -t "$SESSION"
