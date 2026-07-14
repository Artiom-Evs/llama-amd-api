# llama-amd-api

Docker container exposing the [llama.cpp](https://github.com/ggml-org/llama.cpp) HTTP API (OpenAI-compatible) for a Linux server with an AMD APU (integrated Radeon graphics, Vulkan/RADV).

On the **first** start the container builds `llama-server` from sources baked into the image (`-DGGML_VULKAN=ON` + `-march=native` for the host CPU) and downloads a GGUF model from Hugging Face. Subsequent starts are idempotent: the binary and the model are cached on volumes, so restarts are instant.

## Run

```sh
cp .env.example .env    # set model, port, etc.
docker compose up -d
docker compose logs -f  # first start: ~5-15 min build + model download
curl http://localhost:8080/health
```

The built-in llama.cpp web UI is available at http://localhost:8080.

## Configuration (environment variables)

Every llama-server CLI flag has an `LLAMA_ARG_*` env equivalent. The common ones:

| Variable | Default | Description |
|---|---|---|
| `LLAMA_ARG_HF_REPO` | `ggml-org/gemma-3-4b-it-GGUF:Q4_K_M` | Hugging Face model `<user>/<repo>[:<quant>]` |
| `LLAMA_ARG_PORT` | `8080` | API port |
| `LLAMA_ARG_CTX_SIZE` | `8192` | Context size |
| `LLAMA_ARG_N_GPU_LAYERS` | `999` | Layers offloaded to GPU (`0` = CPU only) |
| `HF_TOKEN` | – | HF token for private repos |
| `LLAMA_EXTRA_ARGS` | – | Extra llama-server CLI arguments |
| `LLAMA_CPP_VERSION` | `b9993` | llama.cpp release (build arg, requires `docker compose build`) |

## GPU on the target server

The base `compose.yml` runs without a GPU (CPU fallback), which is convenient for local development, because `/dev/dri` only exists on a real Linux host with a graphics device (it is absent under Docker Desktop on Windows/macOS). To use the AMD iGPU through Vulkan/RADV, add the overlay on the server:

```sh
docker compose -f compose.yml -f compose.gpu.yml up -d
```

The overlay passes through `/dev/dri`; the container runs as root, so no extra groups are needed. To confirm the GPU was picked up, check the llama-server log for `ggml_vulkan: ... AMD Radeon ... (RADV ...)` instead of `llvmpipe`.

## Notes

- **Rebuild llama.cpp**: remove the volume — `docker compose down && docker volume rm llama-amd-api_llama-build && docker compose up -d`.
- **Debian, not Alpine**: upstream llama.cpp is tested only against glibc (musl had bugs [#8762](https://github.com/ggml-org/llama.cpp/issues/8762), [#11308](https://github.com/ggml-org/llama.cpp/issues/11308)); with the toolchain in the image Alpine would only save ~10%. trixie also ships a recent Mesa 25.x (RADV for RDNA3).
