# llama.cpp server with Vulkan backend for AMD iGPU (RADV).
# llama.cpp is compiled on first container start (idempotent, cached on a volume)
# so the binary gets native optimizations for the host CPU (-march=native).
FROM debian:trixie-slim

ARG LLAMA_CPP_VERSION=b9993

RUN apt-get update && apt-get install -y --no-install-recommends \
        # toolchain
        build-essential \
        cmake \
        ninja-build \
        pkg-config \
        ca-certificates \
        curl \
        # build deps
        libcurl4-openssl-dev \
        libvulkan-dev \
        glslc \
        spirv-headers \
        # runtime
        libvulkan1 \
        mesa-vulkan-drivers \
        libgomp1 \
        vulkan-tools \
    && rm -rf /var/lib/apt/lists/*

# Bake pinned llama.cpp sources into the image so container start
# does not depend on GitHub availability.
ADD https://github.com/ggml-org/llama.cpp/archive/refs/tags/${LLAMA_CPP_VERSION}.tar.gz /opt/llama.cpp/src.tar.gz
RUN mkdir -p /opt/llama.cpp/src \
    && tar -xzf /opt/llama.cpp/src.tar.gz -C /opt/llama.cpp/src --strip-components=1 \
    && rm /opt/llama.cpp/src.tar.gz

ENV SRC_DIR=/opt/llama.cpp/src \
    BUILD_DIR=/opt/llama.cpp/build \
    LLAMA_CACHE=/models \
    HF_HOME=/models/hf \
    LLAMA_ARG_HOST=0.0.0.0 \
    LLAMA_ARG_PORT=8080 \
    LLAMA_ARG_N_GPU_LAYERS=999 \
    LLAMA_ARG_API_PREFIX=

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

VOLUME ["/models", "/opt/llama.cpp/build"]
EXPOSE 8080

# Long start period: first start compiles llama.cpp and downloads the model.
HEALTHCHECK --interval=30s --timeout=5s --start-period=30m --retries=3 \
    CMD curl -fsS "http://127.0.0.1:${LLAMA_ARG_PORT}/health" || exit 1

ENTRYPOINT ["/entrypoint.sh"]
