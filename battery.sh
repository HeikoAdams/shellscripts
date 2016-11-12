#! /bin/bash

LOAD=$(upower -i /org/freedesktop/UPower/devices/battery_BAT0 | grep percentage | awk '{print $2}');
STATE=$(upower -i /org/freedesktop/UPower/devices/battery_BAT0 | grep state | awk '{print $2}')
LOAD=${LOAD::-1}

if [ "$STATE" != "charging" ]; then
    if [ "$LOAD" -ge "80" ]; then
        notify-send "Akku" "Akku ist vollständig gelade! Allmählich Netzstecker ziehen oder sterben!"
    elif [ "$LOAD" -le "25" ]; then
        notify-send "Akku" "Akku ist fast leer! Aufladen!"
    fi
fi
