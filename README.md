# llama-amd-api

Docker-контейнер с [llama.cpp](https://github.com/ggml-org/llama.cpp) HTTP API (OpenAI-совместимый) для Linux-сервера с AMD APU (встроенная графика Radeon, Vulkan/RADV).

При **первом** старте контейнер собирает `llama-server` из запечённых в образ исходников (`-DGGML_VULKAN=ON` + `-march=native` под CPU сервера) и скачивает GGUF-модель с Hugging Face. Повторные старты идемпотентны: бинарник и модель кэшируются на volume'ах, рестарт мгновенный.

## Запуск

```sh
cp .env.example .env    # настроить модель, порт и т.д.
docker compose up -d
docker compose logs -f  # первый старт: сборка ~5–15 мин + скачивание модели
curl http://localhost:8080/health
```

## Конфигурация (переменные окружения)

Любой CLI-флаг llama-server имеет env-эквивалент `LLAMA_ARG_*`. Основные:

| Переменная | По умолчанию | Описание |
|---|---|---|
| `LLAMA_ARG_HF_REPO` | `ggml-org/gemma-3-4b-it-GGUF:Q4_K_M` | Модель с Hugging Face `<user>/<repo>[:<quant>]` |
| `LLAMA_ARG_PORT` | `8080` | Порт API |
| `LLAMA_ARG_CTX_SIZE` | `8192` | Размер контекста |
| `LLAMA_ARG_N_GPU_LAYERS` | `999` | Слои на GPU (`0` — только CPU) |
| `HF_TOKEN` | – | Токен HF для приватных репо |
| `LLAMA_EXTRA_ARGS` | – | Доп. CLI-аргументы llama-server |
| `LLAMA_CPP_VERSION` | `b9993` | Релиз llama.cpp (build-arg, требует `docker compose build`) |

## Заметки

- **GPU**: в контейнер пробрасывается `/dev/dri`; контейнер работает от root, поэтому доп. группы не нужны. Без GPU llama.cpp автоматически откатывается на CPU.
- **Пересборка llama.cpp**: удалить volume — `docker compose down && docker volume rm llama-amd-api_llama-build && docker compose up -d`.
- **Debian, а не Alpine**: upstream llama.cpp тестируется только на glibc (на musl были баги [#8762](https://github.com/ggml-org/llama.cpp/issues/8762), [#11308](https://github.com/ggml-org/llama.cpp/issues/11308)); с toolchain в образе экономия Alpine ~10%. В trixie свежая Mesa 25.x (RADV для RDNA3).
