#!/bin/bash

OLDIFS=$IFS;
IFS=$'\n';
MP3DIR=("$HOME/Musik/Charts" "$HOME/Musik/Weihnachten" "$HOME/Musik/Comedy" "$HOME/Musik/Nena" "$HOME/Downloads/MP3's");
GAIN=$(which mp3gain);
LOGFILE="gain.log";

# check if mp3gain is installed
if [ -z "$GAIN" ] 
then
  echo "mp3gain not installed";
  exit -1;
fi

# delete existing logfile
if [ -e "$LOGFILE" ]
then
	rm -f $LOGFILE;
fi

# create an empty logfile
touch $LOGFILE;

# process directories array
for DIR in ${MP3DIR[*]}
do
	echo $DIR;
	
	# create filelist for current directory
	if [ -z "$1" ]
	then
	   FILES=$(find "$DIR" -name *mp3|sort);
	else
	   FILES=$(find "$DIR/$1" -name *mp3|sort);
	fi

	# gain files in current directory
	for MP3 in $FILES;
	  do "$GAIN" -c -r -k -d 2 "$MP3"|grep Applying >> $LOGFILE;
	done;
done;

# show log only if --show-log is passed as parameter
if [ "$1" == "--show-log" ]
then
  cat gain.log;
fi

IFS=$OLDIFS
