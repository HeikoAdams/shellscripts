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

function initConfig {
    if [ ! -d "$HOME/.config/minibuild/" ]; then
        mkdir -p "$HOME"/.config/minibuild/
        notificationSend "Config directory created! Please check the minibuild-configuration!"
        exit -1
    else
        if [ ! -e "$HOME/.config/minibuild/chroots.conf" ]; then
            touch "$HOME"/.config/minibuild/chroots.conf
            notificationSend "chroots.conf created!"
            exit -1
        fi

        if [ ! -e "$HOME/.config/minibuild/coprs.conf" ]; then
            touch "$HOME"/.config/minibuild/coprs.conf
            notificationSend "coprs.conf created!"
            exit -1
        fi

        if [ ! -e "$HOME/.config/minibuild/ftp.conf" ]; then
            touch "$HOME"/.config/minibuild/ftp.conf
            notificationSend "ftp.conf created!"
            exit -1
        fi
    fi
}

function prepareBuild {
    local WDIR
    WDIR=$(pwd)

    if [ "$WDIR" != "$HOME/rpmbuild" ]; then
        cd "$HOME/rpmbuild"
        readonly WORKDIR=$(pwd)
    fi
}

function debugMsg {
    echo
    echo """$1"""
}

function notificationSend {
    local MSG=$1
    local TITLE=$2

    if [ -z "$TITLE" ]; then
        TITLE="MiniBuild"
    fi

    $NOTIFY """$TITLE""" """$MSG"""

    debugMsg $MSG
}

function initVars {
    # benötigte Variable befüllen

    # benötigte Programme suchen
    readonly RPMBUILD=$(command -v rpmbuild)
    readonly RPMLINT=$(command -v rpmlint)
    readonly RPMDEPLINT=$(command -v rpmdeplint)
    readonly NOTIFY=$(command -v notify-send)
    readonly WGET=$(command -v wget)
    readonly MOCK=$(command -v mock)
    readonly CURL=$(command -v curl)
    readonly CLI=$(command -v copr-cli)
    readonly LFTP=$(command -v lftp)
    readonly SYSTEMD=$(command -v systemd-nspawn)

    # Paketspezifische Variablen füllen
    readonly ARCH=$(grep BuildArch: SPECS/"$PRJ".spec | awk '{print $2}');
    readonly SRC=$(grep Source: SPECS/"$PRJ".spec | awk '{print $2}');
    readonly PRJURL=$(grep URL: SPECS/"$PRJ".spec | awk '{print $2}');
    readonly NAME=$(grep Name: SPECS/"$PRJ".spec | head -1 | awk '{print $2}');
    readonly PRJNAME=$(grep prjname SPECS/"$PRJ".spec | head -1 | awk '{print $3}');
    readonly PKGNAME=$(grep pkgname SPECS/"$PRJ".spec | head -1 | awk '{print $3}');
    readonly BRANCH=$(grep branch SPECS/"$PRJ".spec | head -1 | awk '{print $3}');
    readonly VERSION=$(grep Version: SPECS/"$PRJ".spec | head -1 | awk '{print $2}');
    readonly COMMIT=$(grep commit SPECS/"$PRJ".spec | head -1 | awk '{print $3}');
    readonly BZR_REV=$(grep bzr_rev SPECS/"$PRJ".spec | head -1 | awk '{print $3}');
    
    # sonstige Variable befüllen
    readonly CPU=$(uname -m)
    readonly MOCKVER=$(mock --version)

    # Wenn im SPEC keine BuildArch angegeben ist, für die eigene Prozessor-
    # Architektur bauen
    if [ -z "$ARCH" ]; then
        readonly BARCH=$CPU
    else
        readonly BARCH=$ARCH
    fi

    # Falls keine Angabe zum Source-Tag gefunden wurde, im Source0-Tag
    # nachschauen
    if [ -z "$SRC" ]; then
        readonly SOURCE=$(grep Source0: SPECS/"$PRJ".spec | awk '{print $2}');
    else
        readonly SOURCE=$SRC
    fi

    # Wenn die Quellen aus Git kommen, auch noch den Git-Hash berechnen
    if [ -n "$COMMIT" ]; then
        readonly HASH=${COMMIT:0:7};
    fi

    # Wenn mock > 1.2.19 ist, systemd-nspawn verwenden, sofern installiert
    if [ -n "$SYSTEMD" ] && [ "$MOCKVER" \> "1.2.19" ] ; then
        readonly NSPAWN="--new-chroot"
    else
        debugMsg "Mock version $MOCKVER is too old for systemd-nspawn, using chroot!"
        readonly NSPAWN="--old-chroot"
    fi
}

function moveLocal {
    local ARCHDIR
    local FILES
    local RPMFILE
    local DIRS
    local COUNTER
    local SPEC

    # Das src.rpm wird nicht benötigt und deshalb gelöscht
    find "$HOME/rpmbuild/RPMS/" -maxdepth 1 -name "*$PRJ*src.rpm" -type f -exec rm -f '{}' \;

    DIRS=$(ls "$HOME/rpmbuild/RPMS/")

    for ARCHDIR in $DIRS; do
        FILES=$(find "$HOME/rpmbuild/RPMS/" -maxdepth 1 -name "$CPU" -type f 2> /dev/null | wc -l)

        if [ "$FILES" != "0" ]; then
            echo
            echo "removing existing RPMs from $HOME/rpmbuild/RPMS/$ARCHDIR/"
            find "$HOME/rpmbuild/RPMS/$ARCHDIR/" -name "*$PRJ*" -type f -exec rm -f '{}' \;

            echo "copying RPMs to $HOME/rpmbuild/RPMS/$ARCHDIR/"
            mv -f "$HOME/rpmbuild/RPMS/*$ARCHDIR*.rpm $HOME/rpmbuild/RPMS/$ARCHDIR/"

            if [ -n "$RPMLINT" ]; then
                RPMFILE=$(find . -path "./RPMS/$ARCHDIR/$NAME-$VERSION*.rpm" -type f)
                COUNTER=$(find . -path "./RPMS/$ARCHDIR/$NAME-$VERSION*.rpm" -type f | wc -l)
                SPEC=$(readlink -f "./SPECS/$PRJ.spec")

                echo "Valid $PRJ Pakete mit rpmlint"
                if [ "$COUNTER" == 1 ]; then
                    $RPMLINT "$SRPM" "$RPMFILE" "$SPEC"
                fi
            else
                echo "rpmlint is missing"
            fi
        fi
    done
}

function downloadSources {
    local MATCH
    local URL
    local DEST

    # URL für den Download der Sourcen zusammenbauen
    MATCH="%{url}"
    URL=${URL//$MATCH/$PRJURL}
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
    DEST=$(echo "$URL" | awk -F\/ '{print $NF}')

    # Wenn eine URL als Source angegeben ist, die Datei herunterladen
    if [ "${URL:0:3}" == "ftp" ] || [ "${URL:0:4}" == "http" ]; then
        echo "removing old sources ..."
        find "$HOME/rpmbuild/SOURCES/" -name "*.tar.*" -type f -exec rm -f '{}' \;
        find "$HOME/rpmbuild/SOURCES/" -name "*.zip" -type f -exec rm -f '{}' \;

        if [ -n "$WGET" ]; then
            echo "downloading sources from $URL ..."
            $WGET "$URL" --quiet --show-progress -O "SOURCES/$DEST"
            RC=$?
            if [ $RC != 0 ]; then
                notificationSend "download failed! (code $RC)"
                exit
            fi
        else
            notificationSend "wget is missing!"
            exit
        fi
    fi
}

function get_mock_root {
    if [ -n "$MOCK" ]; then
        RELEASE=$(grep VERSION_ID /etc/os-release)
        RELEASE=${RELEASE#*=}
        readonly ROOT="fedora-$RELEASE-$CPU"
    fi
}

function buildRPMs {
    local DIR
    local DIRS
    local BUILD
    local SOURCEFILE
    local RC

    echo
    echo "removing existing SRPMs ..."
    find "$HOME/rpmbuild/SRPMS/" -name "*src.rpm" -type f -exec rm -f '{}' \;

    echo "removing old logs ..."
    find . -name "*log" -type f -exec rm -f '{}' \;

    echo "cleaning build directory ..."
    DIRS=$(find "$HOME/rpmbuild" -name "BUILD*" -type d)

    get_mock_root

    for DIR in $DIRS ; do
        rm -rf ${DIR:?}/*
    done

    echo
    echo -e "generating $PRJ source package"

    # SRPM erstellen
    if $USERPMBUILD ; then
        if [ -n "$RPMBUILD" ]; then
            $RPMBUILD -bs "$HOME/rpmbuild/SPECS/$PRJ.spec"
            RC=$?
        else
            notificationSend "rpmbuild is missing!"
            exit
        fi
    else
        if [ -n "$MOCK" ]; then
            $MOCK -r "$ROOT" \
              --dnf \
              --buildsrpm \
              --bootstrap-chroot \
              --spec="$HOME/rpmbuild/SPECS/$PRJ.spec" \
              --sources="$HOME/rpmbuild/SOURCES" \
              --resultdir="$HOME/rpmbuild/SRPMS" \
              $NSPAWN
            RC=$?
        else
            notificationSend "mock is missing!"
            exit
        fi
    fi

    if [ "$RC" != 0 ]; then
        notificationSend "generating srpm failed! (code $RC)"
        exit
    fi

    # Pfad zum SRPM generieren
    SOURCEFILE=$(find . -path "./SRPMS/$PRJ*" -type f)
    readonly SRPM=$(readlink -f "$SOURCEFILE")
    readonly SRCRPM=$(basename "$SRPM")

    if [ -z "$SRPM" ]; then
        notificationSend "can't find the srpm!"
        exit
    fi

    if [ -n "$RPMLINT" ]; then
        echo
        echo "validating $PRJ source package with rpmlint"
        SPEC=$(readlink -f "./SPECS/$PRJ.spec")
        $RPMLINT "$SRPM" "$SPEC"
    fi

    if [ -n "$RPMDEPLINT" ]; then
        echo
        echo "validating $PRJ source package with rpmdeplint"
        $RPMDEPLINT check --arch $CPU "$SRPM"
    fi

    # Das Binary bauen und paketieren
    if $BUILDRPM ; then
        echo
        echo "generating binary package ..."
        if [ -n "$MOCK" ]; then
            $MOCK -r "$ROOT" \
                --rebuild "$SRPM" \
                --target="$BARCH" \
                --dnf \
                --resultdir="$HOME/rpmbuild/RPMS/$BARCH" \
                --bootstrap-chroot \
                $NSPAWN
            RC=$?

            if [ "$RC" != 0 ]; then
                notificationSend "build failed! (code $RC)"
                exit
            fi
        else
            notificationSend "mock is missing"
            exit
        fi
    fi

    if [ "${BUILD,,}" == "q" ]; then
        exit
    fi
}

function uploadSources {
    cd $WORKDIR/SRPMS
    # FTP-Zugangsdaten auslesen sowie URL des SRPM auslesen
    if [ -s "$HOME/.config/minibuild/ftp.conf" ]; then
        source "$HOME/.config/minibuild/ftp.conf"
    else
        notificationSend "ftp-credentials not configured!"
        exit
    fi

    # Das fertige SRPM auf den FTP-Server hochladen, damit COPR
    # es verwenden kann
    if [ -n "$FTPHOST" ]; then
        echo
        echo "uploading $SRPM to ftp ..."
        if [ -n "$LFTP" ]; then
            local FTPURL="ftp://$FTPUSER:$FTPPWD@$FTPHOST"
            local LCD="$WORKDIR/SRPMS"
            local DELETE="--delete"
            local NOVERFIY="set ssl:verify-certificate no;"
            $LFTP -c "set ftp:list-options -a; $NOVERFIY
            open '$FTPURL';
            lcd $LCD;
            cd $FTPPATH;
            mirror --reverse \
                   $DELETE \
                   --verbose \
                   --exclude-glob *.log"
        elif [ -n "$CURL" ]; then
            $CURL --ftp-ssl -# -k -T "$SRPM" -u "$FTPUSER:$FTPPWD" "ftp://$FTPHOST/$FTPPATH"
            RC=$?
            if [ "$RC" != 0 ]; then
                notificationSend "upload failed! (code $RC)"
                exit
            fi
        else
            notificationSend "curl and lftp missing!"
            exit
        fi
    else
        notificationSend "ftp-credentials not configured!"
        exit
    fi
}

function buildCOPR {
    local COPRS
    local USE
    local CHROOT
    local CHROOTS
    local COUNTER=0

    # FTP-Zugangsdaten auslesen sowie URL des SRPM auslesen
    if [ -s "$HOME/.config/minibuild/ftp.conf" ]; then
        source "$HOME/.config/minibuild/ftp.conf"
    else
        notificationSend "ftp-credentials not configured!"
        exit
    fi

    # COPR, übernehmen Sie
    if [ -n "$CLI" ]; then
        if [ -z "$COPRNAME" ]; then
            if [ -s "$HOME/.config/minibuild/coprs.conf" ]; then
                echo
                echo "searching coprs.conf for a matching copr ..."
                COPRS=$(grep "$PRJ" "$HOME/.config/minibuild/coprs.conf")
                COUNTER=$(grep -c "$PRJ" "$HOME/.config/minibuild/coprs.conf")
                COPRS=${COPRS#*=}

                if [[ -n "$COPRS" && "$COUNTER" == 1 ]]; then
                    read -p "using copr $COPRS? (y/n) " USE

                    if [ "${USE,,}" == "y" ]; then
                        COPR=$COPRS
                        echo "using copr $COPRS for creating packages..."
                    fi
                fi
            fi

            # Kein passendes COPR gefunden -> das COPR CLI befragen
            if [[ -z "$COPR" || $COUNTER != 1 ]]; then
                echo "looking for a matching copr ..."
                for COPRS in $($CLI list | grep Name | awk '{print $2}' | grep "$PRJ"); do
                    read -p "using copr $COPRS? (y/n) " USE

                    if [ "${USE,,}" == "y" ]; then
                        COPR=$COPRS
                        break
                    fi
                done
            fi

            # Noch immer kein passendes COPR gefunden -> User fragen
            if [ -z "$COPR" ]; then
                read -p "using copr: " COPR
            fi
        else
            COPR=$COPRNAME
        fi

        # COPR-Build veranlassen
        if [ -n "$COPR" ]; then
            # Nachschauen, ob ein Projekt/COPR nur für bestimmte
            # chroots gebaut werden soll
            if [ -s "$HOME/.config/minibuild/chroots.conf" ]; then
                CHROOT=$(grep "$PRJ" "$HOME/.config/minibuild/chroots.conf")
                if [ -z "$CHROOT" ]; then
                    CHROOT=$(grep "$COPR" "$HOME/.config/minibuild/chroots.conf")
                fi
                CHROOTS=${CHROOT#*=}
            fi

            # Paket(e) bauen
            if [ -z "$CHROOTS" ]; then
                echo
                if ! $UPLOADFTP ; then
                    $CLI build "$COPR" "$SRPM"
                else
                    $CLI build "$COPR" "http://$HTTPHOST/$HTTPPATH/$SRCRPM"
                fi
            else
                echo
                OLDIFS=$IFS
                IFS=","

                for CHROOT in $CHROOTS; do
                    CMDLINE="$CMDLINE -r $CHROOT"
                done

                IFS=$OLDIFS
                if ! $UPLOADFTP ; then
                    $CLI build "$COPR" $CMDLINE "$SRPM"
                else
                    $CLI build "$COPR" $CMDLINE "http://$HTTPHOST/$HTTPPATH/$SRCRPM"
                fi
            fi
        fi
    else
        notificationSend "copr-cli is missing!"
        exit
    fi
}

function buildProject {
    if [ -e !"SPECS/$PRJ.spec" ]; then
        notificationSend "the submitted spec file does not exist!"
        exit
    fi

    initVars
    initConfig
    downloadSources
    buildRPMs
    if $BUILDRPM ; then
        moveLocal
    fi
    if $UPLOADFTP ; then
        uploadSources
    fi
    if $COPRBUILD ; then
        buildCOPR
    fi
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
            --spec)     PARAM="${PARAM}-s "
                ;;
            --build)    PARAM="${PARAM}-b " # Build binary rpm for testing local
                ;;
            --upload)   PARAM="${PARAM}-u " # upload srpm to ftp space
                ;;
            --copr)     PARAM="${PARAM}-c " # use copr for building binary rpms
                ;;
            --name)     PARAM="${PARAM}-n " # name of the copr to use for building binary rpms
                ;;
            --rpmbuild) PARAM="${PARAM}-r " # use rpmbuild for building srpms
                ;;
            #pass through anything else
            *) [[ "${ARG:0:1}" == "-" ]] || DELIM="\""
                PARAM="${PARAM}${DELIM}${ARG}${DELIM} "
                ;;
        esac
    done

    #Reset the positional parameters to the short options
    eval set -- "$PARAM"

    local BUILD=false
    local UPLOAD=true
    local COPR=true
    local SRPMRPMBUILD=true
    local NAME

    while getopts ":s:b:u:c:n:r:x:" opt; do
        case $opt in
            s)
                readonly PRJ=$OPTARG
                ;;
            b)
                if [ "$OPTARG" == "no" ]; then
                    BUILD=false
                elif [ "$OPTARG" == "yes" ]; then
                    BUILD=true
                fi
                ;;
            u)
                if [ "$OPTARG" == "no" ]; then
                    UPLOAD=false
                elif [ "$OPTARG" == "yes" ]; then
                    UPLOAD=true
                fi
                ;;
            c)
                if [ "$OPTARG" == "no" ]; then
                    COPR=false
                elif [ "$OPTARG" == "yes" ]; then
                    COPR=true
                fi
                ;;
            r)
                if [ "$OPTARG" == "no" ]; then
                    SRPMRPMBUILD=false
                elif [ "$OPTARG" == "yes" ]; then
                    SRPMRPMBUILD=true
                fi
                ;;
            n)
                if [ -n "$OPTARG" ]; then
                    NAME=$OPTARG
                fi
                ;;
            \?)
                echo "invalid argument: -$OPTARG" >&2
                exit 1
                ;;
            :)
                echo "argument -$OPTARG requires a value." >&2
                exit 1
                ;;
        esac
    done

    readonly BUILDRPM=$BUILD
    readonly UPLOADFTP=$UPLOAD
    readonly COPRBUILD=$COPR
    readonly COPRNAME=$NAME
    readonly USERPMBUILD=$SRPMRPMBUILD

    [[ -z $PRJ ]] \
        && echo "You must provide --spec file" && exit

    return 0
}

function main {
    cmdline $ARGS
    prepareBuild
    buildProject
}

CURRDIR=$(dirname "$0")
readonly PROGNAME=$(basename "$0")
readonly PROGDIR=$(readlink -m "$CURRDIR")
readonly ARGS="$@"

main
cd ..

exit 0
