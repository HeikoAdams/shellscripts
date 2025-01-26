#!/bin/bash

OLDIFS=$IFS;
IFS=$'\n';
MP3DIR=("$HOME/Musik/" "$HOME/Downloads/MP3's");
GAIN=$(which replaygain);
LOGFILE="gain.log";

# check if mp3gain is installed
if [ -z "$GAIN" ]; then
	echo "replaygain not installed";
	exit 1;
fi

# delete existing logfile
if [ -e "$LOGFILE" ]; then
	rm -f $LOGFILE;
fi

# create an empty logfile
touch $LOGFILE;

# process directories array
for DIR in "${MP3DIR[@]}"; do
    # make sure the directory exists
    if [ ! -d "$DIR" ]; then
        continue
    fi

	echo "$DIR";
	
	# create filelist for current directory
	if [ -z "$1" ]; then
		FILES=$(find "$DIR" -name '*mp3'|sort);
	else
		FILES=$(find "$DIR/$1" -name '*mp3'|sort);
	fi

	# gain files in current directory
	for MP3 in $FILES; do
		"$GAIN" "$MP3"
	done;
done;

# show log only if --show-log is passed as parameter
if [ "$1" == "--show-log" ]; then
	cat gain.log;
fi

IFS=$OLDIFS
