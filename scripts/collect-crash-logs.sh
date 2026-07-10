#!/usr/bin/env bash
set -euo pipefail

log_root="${XDG_DATA_HOME:-$HOME/.local/share}/mc-launcher-qt-cpp/logs"
out_dir="${1:-$PWD}"
stamp="$(date +%Y%m%d-%H%M%S)"
archive="$out_dir/mc-launcher-crash-$stamp.tar.gz"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$out_dir" "$tmp/logs"

for name in latest.log crash-last.log last-run-state.json; do
    [[ -f "$log_root/$name" ]] && cp -a "$log_root/$name" "$tmp/logs/"
done

newest_session="$(find "$log_root" -maxdepth 1 -type f -name 'session-*.log' -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -n 1 | cut -d' ' -f2- || true)"
[[ -n "$newest_session" && -f "$newest_session" ]] && cp -a "$newest_session" "$tmp/logs/"

newest_terminal="$(find "$log_root" -maxdepth 1 -type f -name 'terminal-*.log' -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -n 1 | cut -d' ' -f2- || true)"
[[ -n "$newest_terminal" && -f "$newest_terminal" ]] && cp -a "$newest_terminal" "$tmp/logs/"

{
    echo "collectedAt=$(date --iso-8601=seconds 2>/dev/null || date)"
    echo "uname=$(uname -a)"
    command -v lsb_release >/dev/null 2>&1 && lsb_release -a 2>&1 || true
    echo
    echo "environment:"
    env | grep -E '^(XDG_|QT_|QML_|WAYLAND_|DISPLAY=|XDG_SESSION_TYPE=)' | sort || true
    echo
    echo "recent coredump metadata:"
    command -v coredumpctl >/dev/null 2>&1 && coredumpctl --no-pager --reverse 2>/dev/null | head -n 30 || true
} > "$tmp/system-info.txt"

tar -czf "$archive" -C "$tmp" .
echo "$archive"
