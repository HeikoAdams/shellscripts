#!/bin/bash
notify_header="Wetterwarnungen für Coburg"
popup_icon=~/Bilder/Wetterwarnung.png
landkreis=COX
image_viewer=display # must be able to handle URLs
warning_url='http://www.wettergefahren.de/dyn/app/ws/html/reports/'${landkreis}'_warning_de.html'
timeline_url="http://www.wettergefahren.de/dyn/app/ws/maps/${landkreis}_timeline.png"
automode=false

img_viewer=$(whereis $image_viewer | awk '{print $2}')
notify=$(whereis notify-send | awk '{print $2}')
wget=$(whereis wget | awk '{print $2}')

if [ -z "$img_viewer" ]; then
    echo "$image_viewer konnte nicht gefunden werden"
    exit
elif [ -z "$notify" ]; then
    echo "notify-send konnte nicht gefunden werden"
    exit
elif [ -z "$wget" ]; then
    echo "wget konnte nicht gefunden werden"
    exit
fi

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
            $notify --icon=$popup_icon """ungültiger Landkreis""" "ungültiger Landkreis: $1"
            exit
        fi
    fi
fi

textstring=$($wget $warning_url -q -O -  | grep -i -e "warnung vor" -e "vorabinformation" | sed s/\<\\/p\>//g ) 

if [ "$textstring" = ""  ]; then 
    $notify --icon=$popup_icon """$notify_header""" "keine Warnungen vorhanden"
else 
    $notify --icon=$popup_icon """$notify_header""" """$textstring"""
    if [ "$automode" == false ]; then
        $img_viewer $timeline_url &
        # xdg-open $warning_url &
        sleep 4
        kill $!
    fi
fi
