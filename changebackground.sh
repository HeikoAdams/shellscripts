#! /bin/bash

PID=$(pgrep xfdesktop)

if [ -n "$PID" ]
then
	#DISPLAY=:0 xfdesktop --reload
	xfdesktop --reload
fi
