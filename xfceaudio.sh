#!/bin/bash

PAROLE=$(pgrep -c parole)
PRAGHA=$(pgrep -c pragha)

if [ "$PAROLE" -ge "1" ]
then
	if [ "$1" == "next" ]
	then
		parole -N
	elif [ "$1" == "prev" ]
	then
		parole -P
	elif [ "$1" == "play" ]
	then
		parole -p
	elif [ "$1" == "stop" ]
	then
		parole -s
	elif [ "$1" == "pause" ]
	then
		parole -s
	fi
elif [ "§PRAGHA" -ge "1" ]
then
	if [ "$1" == "next" ] 
	then
		pragha -n
	elif [ "$1" == "prev" ]
	then
		pragha -r
	elif [ "$1" == "play" ]
	then
		pragha -p
	elif [ "$1" == "stop" ]
	then
		pragha -s
	elif [ "$1" == "pause" ]
	then
		pragha -t
	fi
fi
