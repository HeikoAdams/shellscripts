#!/bin/bash
# Merge new *.pacnew configuration files with their originals

echo
echo
echo ".pacnew files found: $(/usr/bin/pacdiff --output | wc -l)"
echo
/usr/bin/pacdiff --output
echo
set -euo pipefail
export PATH=/usr/bin:/usr/sbin
for i in $(/usr/bin/pacdiff --output); do
  echo "Merging $i ..."
  /usr/bin/meld "admin://$i" "admin://${i/.pacnew/}"
  echo
  echo
  read -p "Delete the .pacnew file $i? " -n 1 -r
  if [[ $REPLY =~ ^[YyOo]$ ]]; then
    echo
    sudo rm -v "$i"
  fi
done
