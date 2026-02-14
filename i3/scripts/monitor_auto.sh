#!/bin/bash

set -u

LOCK_FILE="${XDG_RUNTIME_DIR:-/tmp}/i3-monitor-auto.lock"

restore_wallpaper() {
    if command -v nitrogen >/dev/null 2>&1; then
        nitrogen --restore
    fi
}

get_connected_outputs() {
    xrandr --query | awk '/ connected/ {print $1}'
}

get_internal_output() {
    get_connected_outputs | grep -E '^(eDP|LVDS|DSI)' | head -n1
}

get_external_output() {
    get_connected_outputs | grep -Ev '^(eDP|LVDS|DSI)' | head -n1
}

get_best_mode_and_rate() {
    local target_output="$1"

    xrandr --query | awk -v out="$target_output" '
        $1 == out && $2 == "connected" { in_output=1; next }
        in_output && $0 !~ /^ / { in_output=0 }

        in_output && /^[[:space:]]+[0-9]+x[0-9]+/ {
            mode=$1
            split(mode, dims, "x")
            area=dims[1] * dims[2]

            for (i=2; i<=NF; i++) {
                rate=$i
                gsub(/[^0-9.]/, "", rate)
                if (rate == "") {
                    continue
                }

                rate_num=rate+0

                if (area > best_area || (area == best_area && rate_num > best_rate_num)) {
                    best_area=area
                    best_mode=mode
                    best_rate=rate
                    best_rate_num=rate_num
                }
            }
        }

        END {
            if (best_mode != "" && best_rate != "") {
                print best_mode, best_rate
            }
        }
    '
}

set_output_best_mode() {
    local output="$1"
    local mode=""
    local rate=""

    read -r mode rate < <(get_best_mode_and_rate "$output")

    if [ -n "$mode" ] && [ -n "$rate" ]; then
        xrandr --output "$output" --mode "$mode" --rate "$rate" --primary
    else
        xrandr --output "$output" --auto --primary
    fi
}

apply_layout() {
    mapfile -t connected_outputs < <(get_connected_outputs)

    internal_output="$(get_internal_output)"
    external_output="$(get_external_output)"

    if [ -n "$external_output" ]; then
        set_output_best_mode "$external_output"

        for output in "${connected_outputs[@]}"; do
            if [ "$output" != "$external_output" ]; then
                xrandr --output "$output" --off
            fi
        done
        return
    fi

    if [ -n "$internal_output" ]; then
        set_output_best_mode "$internal_output"

        for output in "${connected_outputs[@]}"; do
            if [ "$output" != "$internal_output" ]; then
                xrandr --output "$output" --off
            fi
        done
    fi
}

watch_mode() {
    exec 9>"$LOCK_FILE"
    flock -n 9 || exit 0

    last_signature=""
    while true; do
        current_signature="$(xrandr --query | awk '/ connected/ {print $1":"$2}' | tr '\n' ' ')"
        if [ "$current_signature" != "$last_signature" ]; then
            apply_layout
            restore_wallpaper
            last_signature="$current_signature"
        fi
        sleep 2
    done
}

if [ "${1:-}" = "--watch" ]; then
    watch_mode
else
    apply_layout
    restore_wallpaper
fi