#! /bin/bash

PRJDIR="$HOME/Projekte"

cd $PRJDIR
for REPO in $(find -name .git -type d | sort); do
    cd $PRJDIR
    DIR=$(dirname $REPO)
    REPOPATH=$(realpath $DIR)
    REPONAME=$(basename $REPOPATH)

    cd "$REPOPATH"
    echo "Aktualisiere $REPONAME"
    UPSTREAM=$(git remote -v | grep ups)
    if [ -n "$UPSTREAM" ]; then
        echo "Synchronisiere mit Upstream"
        git fetch upstream
        git checkout master
        git merge upstream/master
        git push
    else
        git pull
    fi
    echo
done
