#!/bin/bash
#set -x
#echo $DISPLAY

function initURLS {
    header="Wetterwarnungen für Landkreis ${landkreis}"
    warning_url="http://www.wettergefahren.de/dyn/app/ws/html/reports/${landkreis}_warning_de.html"
    timeline_url="http://www.wettergefahren.de/dyn/app/ws/maps/${landkreis}_timeline.png"
}

function notificationSend {
    if [ "$automode" = true ]; then
        $notify """$2""" """$1"""
    else
        $zenity --notification --text="""$1"""
    fi
}

function invalidLK {
    notificationSend "ungültiger Landkreis: ${landkreis}" "$header"
    exit
}

function checkDependencies {
    img_viewer=$(whereis $image_viewer | awk '{print $2}')
    notify=$(whereis notify-send | awk '{print $2}')
    zenity=$(whereis zenity | awk '{print $2}')
    wget=$(whereis wget | awk '{print $2}')

    if [ -z "$img_viewer" ]; then
        notificationSend  "$image_viewer konnte nicht gefunden werden" "Wetterdienst"
        exit
    fi
    if [ -z "$zenity" ]; then
        notificationSend  "zenity konnte nicht gefunden werden" "Wetterdienst"
        exit
    fi
    if [ -z "$notify" ]; then
        notificationSend  "notify-send konnte nicht gefunden werden" "Wetterdienst"
        exit
    fi
    if [ -z "$wget" ]; then
        notificationSend  "wget konnte nicht gefunden werden" "Wetterdienst"
        exit
    fi
}

landkreis=COX
image_viewer=display # must be able to handle URLs
automode=false

checkDependencies

if [ -n "$1" ]; then
    if [ "$1" == "auto" ]; then
        automode=true

        if [ -z "$2" ] || [ "$1" == "$2" ]; then
            interval="30m"
        else
            interval=$2
        fi

        initURLS
    else
        i="$1"
        size=${#i}
        if [ "$size" -eq 3 ]; then
            landkreis=$1
            initURLS
            $wget $warning_url -q -O -
            if [ $? != 0 ]; then
                invalidLK
            fi
        else
            invalidLK
        fi
    fi
else
    initURLS
fi

textstring=$($wget $warning_url -q -O -  | grep -i -e "warnung vor" -e "vorabinformation" | sed s/\<\\/p\>//g ) 

if [ -z "$textstring" ]; then 
    if [ "$automode" != true ]; then
        notificationSend "keine Warnungen vorhanden" "$header"
    fi
else 
    notificationSend """$textstring""" "$header"
    if [ "$automode" != true ]; then
        $img_viewer $timeline_url &
        # xdg-open $warning_url &
        sleep 4
        kill $!
    fi
fi

if [ "$automode" = true ]; then
    sleep $interval
    exec $0 $@
fi
