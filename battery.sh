#! /bin/bash
export DISPLAY=:0

LOAD=$(upower -i /org/freedesktop/UPower/devices/battery_BAT0 | grep percentage | awk '{print $2}');
STATE=$(upower -i /org/freedesktop/UPower/devices/battery_BAT0 | grep state | awk '{print $2}')
LOAD=${LOAD::-1}

if [[ "$LOAD" -ge "90" ]] && [[ "$STATE" == "charging" ]]; then
    notify-send "Akku" "Akku ist vollständig gelade! Allmählich Netzstecker ziehen oder sterben!"
    play /usr/share/sounds/freedesktop/stereo/bell.oga
elif [[ "$LOAD" -le "25" ]] && [[ "$STATE" == "discharging" ]]; then
#if [[ "$LOAD" -le "20" ]] && [[ "$STATE" == "discharging" ]]; then
    notify-send "Akku" "Akku ist fast leer! Aufladen!"
    play /usr/share/sounds/freedesktop/stereo/bell.oga
fi
