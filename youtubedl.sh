#! /bin/bash

youtube-dl --restrict-filenames -o "%(title)s.%(ext)s" "$1"
