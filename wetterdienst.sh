#!/bin/bash
notify_header="Wetterwarnungen für Coburg"
popup_icon=~/Bilder/Wetterwarnung.png
landkreis=COX
image_viewer=display # must be able to handle URLs
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
            notify_header="Wetterwarnungen für "$landkreis
        else
            notify-send --icon=$popup_icon """ungültiger Landkreis""" "ungültiger Landkreis: $1"
            exit
        fi
    fi
fi

textstring=$(wget $warning_url -O -  | grep -i -e "warnung vor" -e "vorabinformation" | sed s/\<\\/p\>//g ) 

if [ "$textstring" = ""  ]; then 
    notify-send --icon=$popup_icon """$notify_header""" "keine Warnungen vorhanden"
else 
    notify-send --icon=$popup_icon """$notify_header""" """$textstring"""
    if [ "$automode" == false ]; then
        $image_viewer $timeline_url &
        # xdg-open $warning_url &
        sleep 4
        kill $!
    fi
fi
