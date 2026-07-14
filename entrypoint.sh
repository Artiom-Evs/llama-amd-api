#!/bin/sh
# Idempotent startup: build llama.cpp once (cached on the /opt/llama.cpp/build
# volume), then exec llama-server. Model download is handled by llama-server
# itself via LLAMA_ARG_HF_REPO and cached in LLAMA_CACHE (/models volume).
set -eu

SRC_DIR="${SRC_DIR:-/opt/llama.cpp/src}"
BUILD_DIR="${BUILD_DIR:-/opt/llama.cpp/build}"
SERVER_BIN="$BUILD_DIR/bin/llama-server"

log() {
    echo "[entrypoint] $*"
}

# BUILD_DIR is a volume mountpoint, so it cannot be removed itself -
# clear its contents instead.
clean_build_dir() {
    mkdir -p "$BUILD_DIR"
    find "$BUILD_DIR" -mindepth 1 -delete
}

# --- 1. Build llama.cpp only if the server binary is missing -----------------
if [ -x "$SERVER_BIN" ]; then
    log "Found existing llama-server binary at $SERVER_BIN, skipping build."
else
    log "llama-server binary not found, building llama.cpp (this happens once)..."
    # Wipe any partial build from a previously interrupted start so a broken
    # cache never blocks the container.
    clean_build_dir

    if ! cmake -S "$SRC_DIR" -B "$BUILD_DIR" -G Ninja \
            -DCMAKE_BUILD_TYPE=Release \
            -DGGML_VULKAN=ON \
            -DLLAMA_CURL=ON \
            -DLLAMA_BUILD_TESTS=OFF \
            -DLLAMA_BUILD_EXAMPLES=OFF \
            -DLLAMA_BUILD_SERVER=ON \
        || ! cmake --build "$BUILD_DIR" --target llama-server -j "$(nproc)"; then
        clean_build_dir
        log "ERROR: llama.cpp build failed."
        exit 1
    fi
    log "Build finished: $SERVER_BIN"
fi

# --- 2. GPU diagnostics (informational only) ---------------------------------
if [ -d /dev/dri ]; then
    log "/dev/dri present: $(ls /dev/dri | tr '\n' ' ')"
else
    log "WARNING: /dev/dri not found - no GPU passed to the container, llama.cpp will fall back to CPU."
fi
if command -v vulkaninfo >/dev/null 2>&1; then
    vulkaninfo --summary 2>/dev/null | grep -E 'deviceName|driverName' || log "vulkaninfo: no Vulkan devices detected."
fi

# --- 3. Start the server ------------------------------------------------------
# Model source is configured via env: LLAMA_ARG_HF_REPO (download from
# Hugging Face into LLAMA_CACHE, skipped when already cached) or
# LLAMA_ARG_MODEL (path to a local GGUF file).
if [ -z "${LLAMA_ARG_HF_REPO:-}" ] && [ -z "${LLAMA_ARG_MODEL:-}" ]; then
    log "ERROR: no model configured. Set LLAMA_ARG_HF_REPO (e.g. ggml-org/gemma-3-4b-it-GGUF:Q4_K_M) or LLAMA_ARG_MODEL."
    exit 1
fi

log "Starting llama-server on ${LLAMA_ARG_HOST:-0.0.0.0}:${LLAMA_ARG_PORT:-8080}..."
# shellcheck disable=SC2086 # LLAMA_EXTRA_ARGS is intentionally word-split
exec "$SERVER_BIN" ${LLAMA_EXTRA_ARGS:-}
