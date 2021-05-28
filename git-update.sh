#! /bin/bash

PRJDIR="$HOME/Projekte"

if [ "$1" == "noclean" ]; then
    CLEAN=false
else
    CLEAN=true
fi

cd $PRJDIR
echo "suche zu aktualisierende git Repositories"
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
        if [ "$CLEAN" = true ];
        then
	        echo "Räume auf"
	        git clean -fd
        fi
    else
        git pull
        if [ "$CLEAN" = true ];
        then
	        echo "Räume auf"
	        git clean -fd
        fi
    fi
    echo
done
