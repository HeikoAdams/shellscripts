#!/bin/bash

HOMEDIR="/home/$1"
USER="$1"

if [ "$1" == "$2" ]
then
	GROUP=USER
else
	GROUP="$2"
fi

CURRENT_USER=$(whoami)

if [ "$CURRENT_USER" != "root" ]
then
  echo "You have to be logged in as root!";
  exit -1;
fi

echo "resetting user"
chown -hR "$USER" "$HOMEDIR"

echo "resetting group"
chgrp -hR "$GROUP" "$HOMEDIR"

echo "restoring SELinux contexts"
restorecon -R "$HOMEDIR"

echo "post-restore actions completed!"
