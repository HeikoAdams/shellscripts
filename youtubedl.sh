#! /bin/bash

youtube-dl -o "%(stitle)s.%(ext)s" "$1"
