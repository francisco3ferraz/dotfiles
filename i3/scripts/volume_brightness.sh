#!/bin/bash
# Adapted from dotfiles-main for Pipewire and Dunst

# Configuration
bar_color="#a6da95"
volume_step=5
max_volume=100

# Icons
icon_vol_high=""
icon_vol_med="󰖀"
icon_vol_low="󰕿"
icon_vol_mute="󰸈"
icon_bright=""

# Get volume
get_volume() {
    wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print int($2 * 100)}'
}

# Get mute status
get_mute() {
    if wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep -q "[MUTED]"; then
        echo "yes"
    else
        echo "no"
    fi
}

# Get volume icon
get_volume_icon() {
    vol=$(get_volume)
    mute=$(get_mute)
    if [ "$mute" == "yes" ] || [ "$vol" -eq 0 ]; then
        echo "$icon_vol_mute"
    elif [ "$vol" -lt 30 ]; then
        echo "$icon_vol_low"
    elif [ "$vol" -lt 70 ]; then
        echo "$icon_vol_med"
    else
        echo "$icon_vol_high"
    fi
}

# Show volume notification
show_volume_notif() {
    vol=$(get_volume)
    icon=$(get_volume_icon)
    # ID 2593 ensures we replace the existing notification
    dunstify -t 1500 -r 2593 -u normal -h int:value:"$vol" -h string:hlcolor:"$bar_color" "$icon  $vol%"
    
    # Refresh i3blocks volume block
    pkill -RTMIN+1 i3blocks
}

# DDC brightness cache file — avoids reading from monitor on every keypress
DDC_CACHE="${XDG_RUNTIME_DIR:-/tmp}/ddc_brightness"

# Returns cached brightness or seeds cache from monitor on first use
# Returns empty string if no external monitor connected
get_ddc_brightness() {
    if [ -f "$DDC_CACHE" ]; then
        cat "$DDC_CACHE"
    else
        val=$(ddcutil getvcp 10 --display 1 --sleep-multiplier 0.1 2>/dev/null | grep -oP 'current value =\s*\K[0-9]+')
        [ -n "$val" ] && echo "$val" > "$DDC_CACHE"
        echo "$val"
    fi
}

# Show brightness notification using already-computed value
show_brightness_notif() {
    local percent="$1"
    dunstify -t 1500 -r 2593 -u normal -h int:value:"$percent" -h string:hlcolor:"$bar_color" "$icon_bright  $percent%"
}

case $1 in
    volume_up)
        wpctl set-mute @DEFAULT_AUDIO_SINK@ 0
        wpctl set-volume @DEFAULT_AUDIO_SINK@ $volume_step%+ --limit 1.0
        show_volume_notif
        ;;
    volume_down)
        wpctl set-volume @DEFAULT_AUDIO_SINK@ $volume_step%-
        show_volume_notif
        ;;
    volume_mute)
        wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
        show_volume_notif
        ;;
    brightness_up)
        current=$(get_ddc_brightness)
        if [ -n "$current" ]; then
            new=$((current + 5 > 100 ? 100 : current + 5))
            echo "$new" > "$DDC_CACHE"
            ddcutil setvcp 10 $new --display 1 --sleep-multiplier 0.1 &
            show_brightness_notif "$new"
        elif command -v brightnessctl &>/dev/null; then
            brightnessctl s +5%
            show_brightness_notif "$(($(brightnessctl g) * 100 / $(brightnessctl m)))"
        elif command -v xbacklight &>/dev/null; then
            xbacklight -inc 5
            show_brightness_notif "$(xbacklight -get | awk '{print int($1)}')"
        fi
        ;;
    brightness_down)
        current=$(get_ddc_brightness)
        if [ -n "$current" ]; then
            new=$((current - 5 < 0 ? 0 : current - 5))
            echo "$new" > "$DDC_CACHE"
            ddcutil setvcp 10 $new --display 1 --sleep-multiplier 0.1 &
            show_brightness_notif "$new"
        elif command -v brightnessctl &>/dev/null; then
            brightnessctl s 5%-
            show_brightness_notif "$(($(brightnessctl g) * 100 / $(brightnessctl m)))"
        elif command -v xbacklight &>/dev/null; then
            xbacklight -dec 5
            show_brightness_notif "$(xbacklight -get | awk '{print int($1)}')"
        fi
        ;;
esac
