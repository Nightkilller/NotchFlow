#!/bin/bash
# Download ggml-base.en.bin Whisper model
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

mkdir -p "$ROOT_DIR/Models"

MODEL_FILE="$ROOT_DIR/Models/ggml-base.en.bin"

if [ ! -f "$MODEL_FILE" ]; then
    echo "==> Downloading Whisper base.en model (~141MB)..."
    curl -L "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin" -o "$MODEL_FILE"
    echo "==> Model downloaded successfully to $MODEL_FILE"
else
    echo "==> Whisper model already exists at $MODEL_FILE"
fi
