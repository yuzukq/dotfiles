#!/bin/bash

SOUND_DIR="$HOME/.claude/sounds"

case "$1" in
  notification)
    SOUND_FILE="$SOUND_DIR/notice.wav"
    ;;
  stop|*)
    SOUND_FILE="$SOUND_DIR/fin.wav"
    ;;
esac

if ! command -v afplay >/dev/null 2>&1; then
    echo "Error: afplay command not found." >&2
    exit 1
fi

if [ ! -f "$SOUND_FILE" ]; then
    echo "Error: sound file not found: $SOUND_FILE" >&2
    exit 1
fi

afplay "$SOUND_FILE"
