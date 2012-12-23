#! /bin/bash

if [ -n "$1" ]
then
	echo "# xfce backdrop list" > "$1/$2"
	find "$3" -name "$4"|sort >> "$1/$2"
else
	echo -e "\nUsage:\nlistcreate.sh SavePath FileName SearchPath Pattern\n"
	echo -e "Parameters:"
	echo -e "SavePath: Path where the filelist is saved"	
	echo -e "FileName: Filename of imagelist"
	echo -e "SearchPath: Path where to look for files"
	echo -e "Pattern: The search-pattern\n"
fi
