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

# Show brightness notification (Placeholder if no tool found yet)
show_brightness_notif() {
    # Check for brightnessctl or xbacklight
    if command -v brightnessctl &> /dev/null; then
        bright=$(brightnessctl g)
        max=$(brightnessctl m)
        percent=$((bright * 100 / max))
        dunstify -t 1500 -r 2593 -u normal -h int:value:"$percent" -h string:hlcolor:"$bar_color" "$icon_bright  $percent%"
    elif command -v xbacklight &> /dev/null; then
        percent=$(xbacklight -get | awk '{print int($1)}')
        dunstify -t 1500 -r 2593 -u normal -h int:value:"$percent" -h string:hlcolor:"$bar_color" "$icon_bright  $percent%"
    else
        dunstify -t 1500 -r 2593 -u normal "Brightness tool missing"
    fi
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
        if command -v brightnessctl &> /dev/null; then
            brightnessctl s +5%
        elif command -v xbacklight &> /dev/null; then
            xbacklight -inc 5
        fi
        show_brightness_notif
        ;;
    brightness_down)
         if command -v brightnessctl &> /dev/null; then
            brightnessctl s 5%-
        elif command -v xbacklight &> /dev/null; then
            xbacklight -dec 5
        fi
        show_brightness_notif
        ;;
esac
