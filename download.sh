#!/bin/bash

if [ -n $1 ]
then
  curl -C0 -O $1;
else
  echo "Please submit a download url";
  exit -1;
fi
