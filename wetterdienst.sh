#!/bin/bash
function initURLS {
    warning_url="http://www.wettergefahren.de/dyn/app/ws/html/reports/${landkreis}_warning_de.html"
    timeline_url="http://www.wettergefahren.de/dyn/app/ws/maps/${landkreis}_timeline.png"
}

function invalidLK {
    $notify --notification --text="ungültiger Landkreis: ${landkreis}"
    exit
}

function checkDependencies {
    img_viewer=$(whereis $image_viewer | awk '{print $2}')
    notify=$(whereis zenity | awk '{print $2}')
    wget=$(whereis wget | awk '{print $2}')

    if [ -z "$img_viewer" ]; then
        echo "$image_viewer konnte nicht gefunden werden"
        exit
    elif [ -z "$notify" ]; then
        echo "zenity konnte nicht gefunden werden"
        exit
    elif [ -z "$wget" ]; then
        echo "wget konnte nicht gefunden werden"
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

if [ "$textstring" = ""  ]; then 
    $notify --notification --text="keine Warnungen vorhanden"
else 
    $notify --notification --text="""$textstring"""
    if [ "$automode" == false ]; then
        $img_viewer $timeline_url &
        # xdg-open $warning_url &
        sleep 4
        kill $!
    fi
fi
