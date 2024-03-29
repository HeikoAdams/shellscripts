#!/bin/bash

# Standardwerte für Optionen setzen
PRJDIR="$HOME/Projekte"
CLEAN=true
COMPRESS=false

# Parameter verarbeiten
while [ $# -gt 0 ]; do
    if [ "$1" == "--noclean" ]; then
        CLEAN=false
    elif [ "$1" == "--dir" ] && [ -n "$2" ] && [ -d "$2" ]; then
        PRJDIR="$2"
    elif [ "$1" == "--compress" ]; then
        COMPRESS=true
    else
        echo "unbekannter Parameter $1"
        exit 1
    fi
    shift
done

# Im Projektverzeichnis nach git Repositories suchen
# und diese aktualisieren
cd "$PRJDIR" || exit
echo "suche zu aktualisierende git Repositories"
for REPO in $(find . -name .git -type d | sort); do
    cd "$PRJDIR" || exit
    DIR=$(dirname "$REPO")
    REPOPATH=$(realpath "$DIR")
    REPONAME=$(basename "$REPOPATH")

    cd "$REPOPATH" || exit
    echo "Aktualisiere $REPONAME"
    UPSTREAM=$(git remote -v | grep ups)

    # Wenn es einen Upstream-Branch gibt, Änderungen mergen und pushen,
    # ansonten nur Änderungen herunterladen
    if [ -n "$UPSTREAM" ]; then
        echo "Synchronisiere mit Upstream"
        git fetch upstream

        if [ "$(git branch -r | grep -c master)" -gt 0 ]; then
            BRANCH="master"
        elif [ "$(git branch -r | grep -c main)" -gt 0 ]; then
            BRANCH="main"
        fi

        git checkout "$BRANCH"
        git merge "upstream/$BRANCH"
        git push
    else
        git pull
    fi

    if [ "$CLEAN" = true ]; then
        echo "Räume auf"
        git fetch -p -P
        git clean -fd
    fi

    if [ "$COMPRESS" = true ]; then
        echo "Komprimiere git Datenbank"
        git gc --aggressive
    fi

    echo
done
