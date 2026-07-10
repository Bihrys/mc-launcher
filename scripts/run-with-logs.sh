#!/usr/bin/env bash
set -euo pipefail

verbose_qt=0
if [[ "${1:-}" == "--verbose-qt" ]]; then
    verbose_qt=1
    shift
fi

executable="${1:-}"
if [[ -n "$executable" ]]; then
    shift
else
    for candidate in \
        ./build-cpp/mc-launcher-qt-cpp \
        ./build-cpp/mc \
        ./build/mc-launcher-qt-cpp \
        ./build/mc; do
        if [[ -x "$candidate" ]]; then
            executable="$candidate"
            break
        fi
    done
fi

if [[ -z "$executable" || ! -x "$executable" ]]; then
    echo "找不到可执行文件。用法：$0 [--verbose-qt] ./build-cpp/mc-launcher-qt-cpp [程序参数...]" >&2
    exit 2
fi

log_root="${XDG_DATA_HOME:-$HOME/.local/share}/mc-launcher-qt-cpp/logs"
mkdir -p "$log_root"
stamp="$(date +%Y%m%d-%H%M%S)"
terminal_log="$log_root/terminal-$stamp.log"

# 允许系统生成 core dump；是否真正保留仍取决于发行版的 coredump 配置。
ulimit -c unlimited 2>/dev/null || true

if (( verbose_qt )); then
    export QSG_INFO=1
    export QT_DEBUG_PLUGINS=1
    export QML_IMPORT_TRACE=1
fi

{
    echo "===== launcher terminal capture ====="
    echo "time=$(date --iso-8601=seconds 2>/dev/null || date)"
    echo "cwd=$(pwd)"
    echo "executable=$executable"
    echo "verboseQt=$verbose_qt"
    echo "====================================="
} | tee "$terminal_log"

set +e
"$executable" "$@" 2>&1 | tee -a "$terminal_log"
status=${PIPESTATUS[0]}
set -e

echo "exitCode=$status" | tee -a "$terminal_log"
echo "terminalLog=$terminal_log"
echo "applicationLog=$log_root/latest.log"
echo "crashLog=$log_root/crash-last.log"
exit "$status"
