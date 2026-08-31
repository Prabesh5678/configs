#!/bin/bash
ON_TEMP=2000
OFF_TEMP=6000
SOCK="/run/user/$(id -u)/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.hyprsunset.sock"

if ! pgrep -x hyprsunset >/dev/null || [ ! -S "$SOCK" ]; then
    pkill -x hyprsunset 2>/dev/null
    setsid uwsm-app -- hyprsunset >/dev/null 2>&1 &
    sleep 1
fi

CURRENT_TEMP=$(hyprctl hyprsunset temperature 2>/dev/null | grep -oE '[0-9]+')

if [[ "$CURRENT_TEMP" == "$OFF_TEMP" ]]; then
    hyprctl hyprsunset temperature "$ON_TEMP"
    notify-send -u low "Nightlight: ${ON_TEMP}K"
else
    hyprctl hyprsunset temperature "$OFF_TEMP"
    notify-send -u low "Daylight: ${OFF_TEMP}K"
fi
