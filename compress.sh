#!/bin/bash

OLDIFS=$IFS
IFS=$'\n'

# Variablen für die Profil-Verzeichnisse
FFDIR="${HOME}/.mozilla/firefox"
TBDIR="${HOME}/.thunderbird"

# Prüfung, ob Firefox oder Thunderbird noch ausgeführt werden
echo "Prüfe, ob Firefox oder Thunderbird noch ausgeführt werden"
FFRUNNING=$(find "$FFDIR" -name lock)
TBRUNNING=$(find "$TBDIR" -name lock)

# Funktion, um zu prüfen, ob das Programm noch ausgeführt wird
function check_running {
  if [ -n "$1" ]
  then
    echo -e "\n${2} wird noch ausgeführt!\nBitte beenden Sie ${2}, bevor Sie die"
    echo -e "Datenbanken komprimieren!\n";
    exit $3;
  fi
}
 
# Funktion zum Komprimieren der Datenbanken
function shrink_dbs {
  echo -e "\nKomprimiere ${1}-Datenbanken"
  FILES=$(find "${2}" -name *sqlite);

  for db in $FILES;
  do 
	echo -e "komprimiere $db"
	echo "VACUUM;" | sqlite3 $db ;
  done;
  echo -e "${1}-Datenbanken komprimiert\n"
}

# prüfen, ob FF und TB noch laufen
check_running "$FFRUNNING" "Firefox" -110
check_running "$TBRUNNING" "Thunderbird" -210

# Datenbanken komprimieren
shrink_dbs "Firefox" "$FFDIR"
shrink_dbs "Thunderbird" "$TBDIR"

zenity --info --text="Kompression abgeschlossen"

IFS=$OLDIFS

