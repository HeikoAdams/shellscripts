#!/bin/bash

if [ -z "$1" ]
then
	echo "Please provide the user- and groupname which permissions should be restored!";
	exit -1;
fi

HOMEDIR="/home/$1"
USER="$1"

if [ "$1" == "$2" ]
then
	GROUP=$USER
else
	GROUP="$2"
fi

CURRENT_USER=$(whoami)

if [ "$CURRENT_USER" != "root" ]
then
  echo "You have to be logged in as root!";
  exit -1;
fi

echo "resetting user and group"
chown -hR $USER:$GROUP "$HOMEDIR"

echo "restoring SELinux contexts"
restorecon -R "$HOMEDIR"

echo "post-restore actions completed!"
