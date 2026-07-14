# llama-amd-api

Docker container serving the llama.cpp HTTP API (OpenAI-compatible) on a Linux server with an AMD APU, Vulkan backend via Mesa RADV. No application code — the project is the container definition itself.

## Architecture

- `Dockerfile` — `debian:trixie-slim` + toolchain + Vulkan/RADV runtime; pinned llama.cpp sources (build-arg `LLAMA_CPP_VERSION`) are baked into `/opt/llama.cpp/src`. glibc is deliberate — do not switch to Alpine/musl (upstream llama.cpp is glibc-only tested).
- `entrypoint.sh` — idempotent startup: compiles `llama-server` only if `$BUILD_DIR/bin/llama-server` is missing (cached on the `llama-build` volume, `-march=native`), then `exec llama-server`. Model download is NOT scripted here — llama-server's built-in `-hf` handles it, cached in `LLAMA_CACHE=/models` (`llama-models` volume). Keep it POSIX sh with LF endings (enforced by `.gitattributes`).
- `compose.yml` — passes `/dev/dri` for the iGPU; runs as root so no `group_add` is needed.

## Conventions

- All server configuration goes through native `LLAMA_ARG_*` env vars (every llama-server CLI flag has one); do not add custom config parsing. Escape hatch: `LLAMA_EXTRA_ARGS`.
- Defaults live in three places, keep them in sync: `Dockerfile` (ENV), `compose.yml` (`${VAR:-default}`), `.env.example`.

## Verification

No GPU on the Windows dev machine — test the CPU-fallback path:

```sh
docker compose build
docker run --rm -p 8080:8080 -e LLAMA_ARG_HF_REPO=ggml-org/gemma-3-1b-it-GGUF \
  -v llama-build:/opt/llama.cpp/build -v llama-models:/models llama-amd-api:<tag>
curl http://localhost:8080/health
```

First start compiles (~minutes) and downloads; a restart with the same volumes must skip both (that's the idempotency contract). Vulkan/RADV itself can only be verified on the target AMD server (`ggml_vulkan: ... RADV ...` in the log).
