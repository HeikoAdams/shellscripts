#!/bin/bash
notify_header="Wetterwarnungen für Coburg"
popup_icon=~/Bilder/Wetterwarnung.png
landkreis=COX
image_viewer=/usr/bin/display # must be able to handle URLs
warning_url='http://www.dwd.de/dyn/app/ws/html/reports/'${landkreis}'_warning_de.html'
timeline_url="http://www.dwd.de/dyn/app/ws/maps/${landkreis}_timeline.png"
automode=false

if [ -n "$1" ]; then
    if [ "$1" == "auto" ]; then
        automode=true
    else
        i="$1"
        size=${#i}
        if [ "$size" -eq 3 ]; then
            landkreis=$1
            /usr/bin/notify_header="Wetterwarnungen für "$landkreis
        else
            /usr/bin/notify-send --icon=$popup_icon """ungültiger Landkreis""" "ungültiger Landkreis: $1"
            exit
        fi
    fi
fi

textstring=$(/usr/bin/wget $warning_url -q -O -  | grep -i -e "warnung vor" -e "vorabinformation" | sed s/\<\\/p\>//g ) 

if [ "$textstring" = ""  ]; then 
    /usr/bin/notify-send --icon=$popup_icon """$notify_header""" "keine Warnungen vorhanden"
else 
    /usr/bin/notify-send --icon=$popup_icon """$notify_header""" """$textstring"""
    if [ "$automode" == false ]; then
        $image_viewer $timeline_url &
        # xdg-open $warning_url &
        sleep 4
        kill $!
    fi
fi
