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
    WDIR=$(pwd)
    
    if [ "$WDIR" != "$HOME/rpmbuild" ]; then
        cd $HOME/rpmbuild 
    fi
}

function notificationSend {
    $NOTIFY "Fehler" """$1"""
    echo
    echo """$1"""
}

function initVars {
    # benötigte Variable befüllen
    RPMBUILD=$(whereis rpmbuild | awk '{print $2}')
    NOTIFY=$(whereis notify-send | awk '{print $2}')
    WGET=$(whereis wget | awk '{print $2}')
    MOCK=$(whereis mock | awk '{print $2}')
    CURL=$(whereis curl | awk '{print $2}')
    CLI=$(whereis copr-cli | awk '{print $2}')

    ARCH=$(cat SPECS/$PRJ.spec | grep BuildArch: | awk '{print $2}');
    SOURCE=$(cat SPECS/$PRJ.spec | grep Source: | awk '{print $2}');
    NAME=$(cat SPECS/$PRJ.spec | grep Name: | head -1 | awk '{print $2}');
    PRJNAME=$(cat SPECS/$PRJ.spec | grep prjname | head -1 | awk '{print $3}');
    PKGNAME=$(cat SPECS/$PRJ.spec | grep pkgname | head -1 | awk '{print $3}');
    BRANCH=$(cat SPECS/$PRJ.spec | grep branch | head -1 | awk '{print $3}');
    VERSION=$(cat SPECS/$PRJ.spec | grep Version: | head -1 | awk '{print $2}');
    COMMIT=$(cat SPECS/$PRJ.spec | grep commit | head -1 | awk '{print $3}');
    BZR_REV=$(cat SPECS/$PRJ.spec | grep bzr_rev | head -1 | awk '{print $3}');

    # Wenn im SPEC keine BuildArch angegeben ist, für die eigene Prozessor-
    # Architektur bauen
    if [ -z "$ARCH" ]; then
        BARCH=$(uname -m)
    fi

    # Falls keine Angabe zum Source-Tag gefunden wurde, im Source0-Tag
    # nachschauen
    if [ -z "$SOURCE" ]; then
        SOURCE=$(cat SPECS/$PRJ.spec | grep Source0: | awk '{print $2}');
    fi

    # Wenn die Quellen aus Git kommen, auch noch den Git-Hash berechnen
    if [ -n "$COMMIT" ]; then
        HASH=${COMMIT:0:7};
    fi
}

function buildProject {
    PRJ=$1
    AUTO=true
    BINARY=false

    if [ -n "$2" ]; then
        if [ "$2" == "noauto" ]; then
            AUTO=false
        fi
        if [ "$2" == "binary" ]; then
            BINARY=true
        fi
    fi

    initVars

    # FTP-Zugangsdaten auslesen sowie URL des SRPM auslesen
    if [ -e "$HOME/rpmbuild/ftp.conf" ]; then
        source $HOME/rpmbuild/ftp.conf
    else
        notificationSend "$HOME/rpmbuild/ftp.conf existiert nicht!"
        exit
    fi

    if [ $AUTO == true ]; then
        download="j"
    else
        echo
        read -p "Sourcen herunterladen? (j/n) " download
    fi

    if [ "$download" == "j" ]; then
        # URL für den Download der Sourcen zusammenbauen
        MATCH="%{name}"
        SOURCE=${SOURCE//$MATCH/$NAME}
        MATCH="%{version}"
        SOURCE=${SOURCE//$MATCH/$VERSION}

        if [ -n "$PRJNAME" ]; then
            MATCH="%{prjname}"
            SOURCE=${SOURCE//$MATCH/$PRJNAME}
        fi

        if [ -n "$PKGNAME" ]; then
            MATCH="%{pkgname}"
            SOURCE=${SOURCE//$MATCH/$PKGNAME}
        fi

        if [ -n "$BRANCH" ]; then
            MATCH="%{branch}"
            SOURCE=${SOURCE//$MATCH/$BRANCH}
        fi

        if [ -n "$COMMIT" ]; then
            MATCH="%{commit}"
            SOURCE=${SOURCE//$MATCH/$COMMIT}
        fi

        if [ -n "$HASH" ]; then
            MATCH="%{githash}"
            SOURCE=${SOURCE//$MATCH/$HASH}
        fi

        if [ -n "$BZR_REV" ]; then
            MATCH="%{bzr_rev}"
            SOURCE=${SOURCE//$MATCH/$BZR_REV}
        fi

        # Dateinamen des lokalen Sourcen-Archivs generieren
        DEST=$(echo $SOURCE | awk -F\/ '{print $NF}')

        # Wenn eine URL als Source angegeben ist, die Datei herunterladen
        if [ ${SOURCE:0:3} == "ftp" ] || [ ${SOURCE:0:4} == "http" ]; then
            echo "lösche alte Sourcen ..."
            rm -f SOURCES/*$PRJ*.gz
            rm -f SOURCES/*$PRJ*.xz
            rm -f SOURCES/*$PRJ*.bz2
            echo "Lade Source-Archiv $SOURCE herunter ..."

            if [ -n "$WGET" ]; then
                $WGET $SOURCE -q -O SOURCES/$DEST
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

    echo
    echo "Räume Build-Verzeichnisse auf ..."
    rm -rf BUILD/*
    rm -rf BUILDDIR/*
    rm -rf BUILDROOT/*

    echo "lösche vorhandene RPMs ..."
    rm -rf RPMS/i686/*$PRJ*.rpm
    rm -rf RPMS/noarch/*$PRJ*.rpm
    rm -rf RPMS/x86_64/*$PRJ*.rpm
    rm -rf SRPMS/*$PRJ*.rpm

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
    SRPM=$(find -samefile SRPMS/$PRJ* -type f)
    SRPM=$(readlink -f $SRPM)
    SRCRPM=$(basename $SRPM)

    if [ -z "$SRPM" ]; then
        notificationSend "konnte das SRPM nicht finden!"
        exit
    fi

    if [ $BINARY == true ]; then
        binary="j"
    elif [ $AUTO == true ]; then
        binary="n"
    else
        echo
        read -p "Binärpakete erstellen? (j/n/q) " binary
    fi

    # Das Binary bauen und paketieren
    if [ "$binary" == "j" ]; then
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

    if [ "$binary" == "q" ]; then
        exit
    fi

    if [ $AUTO == true ]; then
        upload="j"
    else
        echo
        read -p "Upload des Source-Paketes? (j/n/q) " upload
    fi

    # Das fertige SRPM auf den FTP-Server hochladen, damit COPR
    # es verwenden kann
    if [ "$upload" == "j" ]; then
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
    fi
    if [ "$upload" == "q" ]; then
        exit
    fi

    if [ $AUTO == true ]; then
        build="j"
    else
        echo
        read -p "Paket(e) im COPR bauen? (j/n/) " build
    fi

    if [ "$build" == "n" ]; then
        exit
    fi
    
    # COPR, übernehmen Sie
    if [ -n "$CLI" ]; then
        echo "Suche nach passendem COPR ..."
        for coprs in $($CLI list | grep Name | awk '{print $2}' | grep $PRJ); do
            if [ $AUTO == true ]; then
                use="j"
            else
                read -p "COPR $coprs verwenden? (j/n/q) " use
            fi

            if [ "$use" == "j" ]; then
                copr=$coprs
                break
            elif [ "$use" == "q" ]; then
                exit
            fi
        done

        # Kein passendes COPR gefunden -> in coprs.conf nachschauen
        if [ -z "$copr" ]; then
            if [ -e "$HOME/rpmbuild/coprs.conf" ]; then
                echo "Suche in coprs.conf nach passendem COPR ..."
                coprs=$(cat $HOME/rpmbuild/coprs.conf | grep $PRJ)
                coprs=${coprs#*=}

                if [ -n "$coprs" ]; then
                    if [ $AUTO == true ]; then
                        use="j"
                    else
                        read -p "COPR $coprs verwenden? (j/n/q) " use
                    fi

                    if [ "$use" == "j" ]; then
                        copr=$coprs
                    elif [ "$use" == "q" ]; then
                        exit
                    fi
                fi
            fi
        fi

        # Noch immer kein passendes COPR gefunden -> User fragen
        if [ -z "$copr" ]; then
            read -p "Name des zu verwendenden COPRs: " copr
        fi

        # COPR-Build veranlassen
        if [ -n "$copr" ]; then
            if [ -n "$HTTPHOST" ]; then
                # Nachschauen, ob ein Projekt nur für bestimmte
                # chroots gebaut werden soll
                if [ -e "$HOME/rpmbuild/chroots.conf" ]; then
                    CHROOTS=$(cat $HOME/rpmbuild/chroots.conf | grep $copr)
                    CHROOTS=${CHROOTS#*=}
                fi

                # Paket(e) bauen
                if [ -z "$CHROOTS" ]; then
                    echo
                    $CLI build "$copr" http://$HTTPHOST/$HTTPPATH/$SRCRPM
                else
                    echo
                    OLDIFS=$IFS
                    IFS=","

                    for CHROOT in $CHROOTS; do
                        CMDLINE="$CMDLINE -r $CHROOT"
                    done

                    IFS=$OLDIFS
                    $CLI build "$copr" $CMDLINE http://$HTTPHOST/$HTTPPATH/$SRCRPM
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

prepareBuild

if [ -z "$1" ]; then
    for spec in $(find -name *.spec -mmin -15); do
        SFILE=$(basename $spec .spec)
        
        echo "Baue $SFILE"
        echo
        buildProject "$SFILE" "$2"
    done
else
    buildProject "$1" "$2"
fi

cd ..
