#! /bin/bash

# build.sh - a script to build Fedora packages localy using mock and upload them to COPR
#
#  Copyright (C) 2015 Heiko Adams heiko.adams@gmail.com
#
#  This source is free software; you can redistribute it and/or modify it under
#  the terms of the GNU General Public License as published by the Free
#  Software Foundation; either version 2 of the License, or (at your option)
#  any later version.
#
#  This code is distributed in the hope that it will be useful, but WITHOUT ANY
#  WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
#  FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
#  details.
#
#  A copy of the GNU General Public License is available on the World Wide Web
#  at <http://www.gnu.org/copyleft/gpl.html>. You can also obtain it by writing
#  to the Free Software Foundation, Inc., 59 Temple Place - Suite 330, Boston,
#  MA 02111-1307, USA.
#

function prepareBuild {
    local WDIR=$(pwd)

    if [ "$WDIR" != "$HOME/rpmbuild" ]; then
        cd $HOME/rpmbuild
    fi
}

function notificationSend {
    local MSG=$1
    local TITLE=$2

    if [ -z "$TITLE" ]; then
        $NOTIFY "Builder" """$MSG"""
    else
        $NOTIFY """$TITLE""" """$MSG"""
    fi
    echo
    echo """$MSG"""
}

function initVars {
    # benötigte Variable befüllen
    readonly RPMBUILD=$(whereis rpmbuild | awk '{print $2}')
    readonly NOTIFY=$(whereis notify-send | awk '{print $2}')
    readonly WGET=$(whereis wget | awk '{print $2}')
    readonly MOCK=$(whereis mock | awk '{print $2}')
    readonly CURL=$(whereis curl | awk '{print $2}')
    readonly CLI=$(whereis copr-cli | awk '{print $2}')

    readonly ARCH=$(grep BuildArch: SPECS/$PRJ.spec | awk '{print $2}');
    readonly SRC=$(grep Source: SPECS/$PRJ.spec | awk '{print $2}');
    readonly NAME=$(grep Name: SPECS/$PRJ.spec | head -1 | awk '{print $2}');
    readonly PRJNAME=$(grep prjname SPECS/$PRJ.spec | head -1 | awk '{print $3}');
    readonly PKGNAME=$(grep pkgname SPECS/$PRJ.spec | head -1 | awk '{print $3}');
    readonly BRANCH=$(grep branch SPECS/$PRJ.spec | head -1 | awk '{print $3}');
    readonly VERSION=$(grep Version: SPECS/$PRJ.spec | head -1 | awk '{print $2}');
    readonly COMMIT=$(grep commit SPECS/$PRJ.spec | head -1 | awk '{print $3}');
    readonly BZR_REV=$(grep bzr_rev SPECS/$PRJ.spec | head -1 | awk '{print $3}');

    # Wenn im SPEC keine BuildArch angegeben ist, für die eigene Prozessor-
    # Architektur bauen
    if [ -z "$ARCH" ]; then
        readonly BARCH=$(uname -m)
    fi

    # Falls keine Angabe zum Source-Tag gefunden wurde, im Source0-Tag
    # nachschauen
    if [ -z "$SRC" ]; then
        readonly SOURCE=$(grep Source0: SPECS/$PRJ.spec | awk '{print $2}');
    else
        readonly SOURCE=$SRC
    fi

    # Wenn die Quellen aus Git kommen, auch noch den Git-Hash berechnen
    if [ -n "$COMMIT" ]; then
        readonly HASH=${COMMIT:0:7};
    fi
}

function moveLocal {
    local DIR
    local RESDIR
    local ARCHDIR
    local FILES

    for DIR in $(ls /var/lib/mock/); do
        RESDIR="/var/lib/mock/$DIR/result"

        for ARCHDIR in $(ls $HOME/rpmbuild/RPMS/); do
            FILES=$(ls $RESDIR/*$ARCHDIR*.rpm 2> /dev/null | wc -l)

            if [ "$FILES" != "0" ]; then
                echo
                echo "lösche vorhandene RPMs aus $HOME/rpmbuild/RPMS/$ARCHDIR/"
                rm -rf $HOME/rpmbuild/RPMS/$ARCHDIR/*$PRJ*.rpm

                echo
                echo "kopiere RPMs nach $HOME/rpmbuild/RPMS/$ARCHDIR/"
                mv -f $RESDIR/*$ARCHDIR*.rpm $HOME/rpmbuild/RPMS/$ARCHDIR/
            fi
        done
    done
}

function downloadSources {
    local PRJ="$1"
    local AUTO="$2"
    local DOWNLOAD
    local MATCH
    local URL

    if [ $AUTO == true ]; then
        DOWNLOAD="j"
    else
        echo
        read -p "Sourcen herunterladen? (j/n) " DOWNLOAD
    fi

    if [ "${DOWNLOAD,,}" == "j" ]; then
        # URL für den Download der Sourcen zusammenbauen
        MATCH="%{name}"
        URL=${SOURCE//$MATCH/$NAME}
        MATCH="%{version}"
        URL=${URL//$MATCH/$VERSION}

        if [ -n "$PRJNAME" ]; then
            MATCH="%{prjname}"
            URL=${URL//$MATCH/$PRJNAME}
        fi

        if [ -n "$PKGNAME" ]; then
            MATCH="%{pkgname}"
            URL=${URL//$MATCH/$PKGNAME}
        fi

        if [ -n "$BRANCH" ]; then
            MATCH="%{branch}"
            URL=${URL//$MATCH/$BRANCH}
        fi

        if [ -n "$COMMIT" ]; then
            MATCH="%{commit}"
            URL=${URL//$MATCH/$COMMIT}
        fi

        if [ -n "$HASH" ]; then
            MATCH="%{githash}"
            URL=${URL//$MATCH/$HASH}
        fi

        if [ -n "$BZR_REV" ]; then
            MATCH="%{bzr_rev}"
            URL=${URL//$MATCH/$BZR_REV}
        fi

        # Dateinamen des lokalen Sourcen-Archivs generieren
        local DEST=$(echo $URL | awk -F\/ '{print $NF}')

        # Wenn eine URL als Source angegeben ist, die Datei herunterladen
        if [ ${URL:0:3} == "ftp" ] || [ ${URL:0:4} == "http" ]; then
            echo "lösche alte Sourcen ..."
            rm -f SOURCES/*$PRJ*.gz
            rm -f SOURCES/*$PRJ*.xz
            rm -f SOURCES/*$PRJ*.bz2
            echo "Lade Source-Archiv $URL herunter ..."

            if [ -n "$WGET" ]; then
                $WGET $URL -q -O SOURCES/$DEST
                RC=$?
                if [ $RC != 0 ]; then
                    notificationSend "Download fehlgeschlagen! (Fehlercode $RC)"
                    exit
                fi
            else
                notificationSend "wget ist nicht installiert!"
                exit
            fi
        fi
    fi
}

function buildRPM {
    local PRJ="$1"
    local BINARY="$2"
    local BUILD
    local DIR
    local RESDIR

    echo
    echo "lösche vorhandene SRPMs ..."
    rm -rf $HOME/rpmbuild/SRPMS/*$PRJ*.rpm

    echo
    echo "Räume Build-Verzeichnisse auf ..."
    for DIR in $(ls $HOME/rpmbuild/ | grep BUILD); do
        rm -rf $DIR/*
    done

    # Mock aufräumen
    for DIR in $(ls /var/lib/mock/); do
        RESDIR="/var/lib/mock/$DIR/result"
        rm -rf $RESDIR/*$PRJ*.rpm
    done

    echo
    echo -e "Erstelle ${1} Source-Paket"

    # SRPM erstellen
    if [ -n "$RPMBUILD" ]; then
        $RPMBUILD -bs SPECS/$PRJ.spec
        RC=$?
        if [ $RC != 0 ]; then
            notificationSend "SRPM-Build fehlgeschlagen! (Fehlercode $RC)"
            exit
        fi
    else
        notificationSend "rpmbuild ist nicht installiert!"
        exit
    fi

    # Pfad zum SRPM generieren
    local SOURCEFILE=$(find . -path "./SRPMS/$PRJ*" -type f)
    readonly SRPM=$(readlink -f $SOURCEFILE)
    readonly SRCRPM=$(basename $SRPM)

    if [ -z "$SRPM" ]; then
        notificationSend "konnte das SRPM nicht finden!"
        exit
    fi

    if [ $BINARY == true ]; then
        BUILD="j"
    elif [ $AUTO == true ]; then
        BUILD="n"
    else
        echo
        read -p "Binärpakete erstellen? (j/n/q) " BUILD
    fi

    # Das Binary bauen und paketieren
    if [ "${BUILD,,}" == "j" ]; then
        echo "Erstelle Binärpaket ..."
        if [ -n "$MOCK" ]; then
            $MOCK rebuild $SRPM --target=$BARCH --dnf
            RC=$?
            if [ $RC != 0 ]; then
                notificationSend "Build fehlgeschlagen! (Fehlercode $RC)"
                exit
            fi
        else
            notificationSend "mock ist nicht installiert"
            exit
        fi
    fi

    if [ "${BUILD,,}" == "q" ]; then
        exit
    fi
}

function uploadSources {
    local AUTO="$1"
    local UPLOAD

    # FTP-Zugangsdaten auslesen sowie URL des SRPM auslesen
    if [ -e "$HOME/rpmbuild/ftp.conf" ]; then
        source $HOME/rpmbuild/ftp.conf
    else
        notificationSend "$HOME/rpmbuild/ftp.conf existiert nicht!"
        exit
    fi

    if [ $AUTO == true ]; then
        UPLOAD="j"
    else
        echo
        read -p "Upload des Source-Paketes? (j/n/q) " UPLOAD
    fi

    # Das fertige SRPM auf den FTP-Server hochladen, damit COPR
    # es verwenden kann
    if [ "${UPLOAD,,}" == "j" ]; then
        if [ -n "$FTPHOST" ]; then
            echo "lade $SRPM auf FTP-Server hoch ..."
            if [ -n "$CURL" ]; then
                $CURL -T $SRPM -u "$FTPUSER:$FTPPWD" ftp://$FTPHOST/$FTPPATH
                RC=$?
                if [ $RC != 0 ]; then
                    notificationSend "Upload fehlgeschlagen! (Fehlercode $RC)"
                    exit
                fi
            else
                notificationSend "curl ist nicht installiert!"
                exit
            fi
        else
            notificationSend "FTP-Zugangsdaten sind nicht konfiguriert"
            exit
        fi
    elif [ "${UPLOAD,,}" == "q" ]; then
        exit
    fi
}

function buildCOPR {
    local PRJ="$1"
    local AUTO="$2"
    local BUILDCOPR
    local COPRS
    local USE
    local CHROOT
    local CHROOTS

    if [ $AUTO == true ]; then
        BUILDCOPR="j"
    else
        echo
        read -p "Paket(e) im COPR bauen? (j/n/) " BUILDCOPR
    fi

    if [ "${BUILDCOPR,,}" == "n" ]; then
        exit
    fi

    # COPR, übernehmen Sie
    if [ -n "$CLI" ]; then
        echo "Suche nach passendem COPR ..."
        for COPRS in $($CLI list | grep Name | awk '{print $2}' | grep $PRJ); do
            if [ $AUTO == true ]; then
                USE="j"
            else
                read -p "COPR $COPRS verwenden? (j/n/q) " USE
            fi

            if [ "${USE,,}" == "j" ]; then
                COPR=$COPRS
                break
            elif [ "${USE,,}" == "q" ]; then
                exit
            fi
        done

        # Kein passendes COPR gefunden -> in coprs.conf nachschauen
        if [ -z "$COPR" ]; then
            if [ -e "$HOME/rpmbuild/coprs.conf" ]; then
                echo "Suche in coprs.conf nach passendem COPR ..."
                COPRS=$(grep $PRJ $HOME/rpmbuild/coprs.conf)
                COPRS=${COPRS#*=}

                if [ -n "$COPRS" ]; then
                    if [ $AUTO == true ]; then
                        USE="j"
                    else
                        read -p "COPR $COPRS verwenden? (j/n/q) " use
                    fi

                    if [ "${USE,,}" == "j" ]; then
                        COPR=$COPRS
                        echo "Verwende COPR $COPRS zum Erstellen der Pakete..."
                    elif [ "${USE,,}" == "q" ]; then
                        exit
                    fi
                fi
            fi
        fi

        # Noch immer kein passendes COPR gefunden -> User fragen
        if [ -z "$COPR" ]; then
            read -p "Name des zu verwendenden COPRs: " COPR
        fi

        # COPR-Build veranlassen
        if [ -n "$COPR" ]; then
            if [ -n "$HTTPHOST" ]; then
                # Nachschauen, ob ein Projekt/COPR nur für bestimmte
                # chroots gebaut werden soll
                if [ -e "$HOME/rpmbuild/chroots.conf" ]; then
                    CHROOT=$(grep $PRJ $HOME/rpmbuild/chroots.conf)
                    if [ -z "$CHROOT" ]; then
                        CHROOT=$(grep $COPR $HOME/rpmbuild/chroots.conf)
                    fi
                    CHROOTS=${CHROOT#*=}
                fi

                # Paket(e) bauen
                if [ -z "$CHROOTS" ]; then
                    echo
                    $CLI build "$COPR" http://$HTTPHOST/$HTTPPATH/$SRCRPM
                else
                    echo
                    OLDIFS=$IFS
                    IFS=","

                    for CHROOT in $CHROOTS; do
                        CMDLINE="$CMDLINE -r $CHROOT"
                    done

                    IFS=$OLDIFS
                    $CLI build "$COPR" $CMDLINE http://$HTTPHOST/$HTTPPATH/$SRCRPM
                fi
            else
                notificationSend "$HOME/rpmbuild/ftp.conf ist fehlerhaft!"
                exit
            fi
        fi
    else
        notificationSend "copr-cli ist nicht installiert!"
        exit
    fi
}

function buildProject {
    local AUTO=true
    local BINARY=false
    local PRJ="$1"
    local OPT="$2"
    local DIR

    if [ -e !SPECS/$PRJ.spec ]; then
        notificationSend "Die angegebene Spec-Datei existiert nicht!"
        exit
    fi

    if [ -n "$OPT" ]; then
        if [ "$OPT" == "noauto" ]; then
            AUTO=false
        fi
        if [ "$OPT" == "binary" ]; then
            BINARY=true
        fi
    fi

    initVars
    downloadSources $PRJ $AUTO
    buildRPM $PRJ $BINARY
    moveLocal
    uploadSources $AUTO
    buildCOPR $PRJ $AUTO
}

function cmdline {
    # got this idea from here:
    # http://kirk.webfinish.com/2009/10/bash-shell-script-to-use-getopts-with-gnu-style-long-positional-parameters/
    local ARG
    local PARAM
    local OPTION

    for ARG; do
        local DELIM=""
        case "$ARG" in
            #translate --gnu-long-options to -g (short options)
            --spec)         PARAM="${PARAM}-s "
                ;;
            --option)       PARAM="${PARAM}-o "
                ;;
            #pass through anything else
            *) [[ "${ARG:0:1}" == "-" ]] || DELIM="\""
                PARAM="${PARAM}${DELIM}${ARG}${DELIM} "
                ;;
        esac
    done

    #Reset the positional parameters to the short options
    eval set -- "$PARAM"

    while getopts "s:o:" opt; do
         case $opt in
         s)
             readonly PARAMFILE=$OPTARG
             ;;
         o)
             readonly PARAMOPT=$OPTARG
             ;;
        esac
    done

    [[ -z $PARAMFILE ]] \
        && echo "You must provide --spec file" && exit

    if [ -z $PARAMOPT ]; then
        readonly PARAMOPT="binary"
    fi

    return 0
}

function main {
    cmdline $ARGS
    prepareBuild
    buildProject "$PARAMFILE" "$PARAMOPT"
}

readonly ARGS="$@"

main

cd ..
