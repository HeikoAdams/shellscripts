#! /bin/bash
if [ -e /usr/bin/evince ]
then
	sandbox -X -t sandbox_x_t evince "$1"
elif [ -e /usr/bin/epdfview ]
then
	sandbox -X -t sandbox_x_t epdfview "$1"
fi
