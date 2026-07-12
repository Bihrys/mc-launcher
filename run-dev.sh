#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$ROOT_DIR/build-cpp"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
LOG_DIR="$DATA_HOME/mc-launcher-qt-cpp/logs/build"
STAMP="$(date +%Y%m%d-%H%M%S)"
BUILD_LOG="$LOG_DIR/build-$STAMP.log"
LATEST_LOG="$LOG_DIR/latest-build.log"

mkdir -p "$LOG_DIR"

if [[ "${1:-}" == "--clean" ]]; then
    rm -rf "$BUILD_DIR"
fi

printf '配置并编译 MC Launcher…\n'
if ! {
    cmake -S "$ROOT_DIR" -B "$BUILD_DIR" -G Ninja \
        -DCMAKE_BUILD_TYPE=Debug \
        -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
        -DCMAKE_PREFIX_PATH=/usr/lib/cmake \
        -DQt6_DIR=/usr/lib/cmake/Qt6
    cmake --build "$BUILD_DIR" -j"$(nproc)"
} >"$BUILD_LOG" 2>&1; then
    cp -f "$BUILD_LOG" "$LATEST_LOG"
    printf '编译失败。日志：%s\n\n' "$BUILD_LOG" >&2
    tail -n 80 "$BUILD_LOG" >&2
    exit 1
fi

cp -f "$BUILD_LOG" "$LATEST_LOG"
printf '编译完成。构建日志：%s\n' "$BUILD_LOG"
printf '启动器日志目录：%s\n' "$DATA_HOME/mc-launcher-qt-cpp/logs"
exec "$BUILD_DIR/mc-launcher-qt-cpp"
