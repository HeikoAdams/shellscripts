#!/usr/bin/env bash

OLDIFS=$IFS
IFS=$'\n'

# Prüfen, ob find und pgrep installiert sind
if [ "$(which find)" == "" ]; then
  echo "find ist nicht installier!"
  exit 1
fi

if [ "$(which pgrep)" == "" ]; then
  echo "find ist nicht installier!"
  exit 1
fi

# Variablen für die Profil-Verzeichnisse
FFDIR="${HOME}/.mozilla/firefox"
TBDIR="${HOME}/.thunderbird"

# Prüfung, ob Firefox oder Thunderbird noch ausgeführt werden
echo "Prüfe, ob Firefox oder Thunderbird noch ausgeführt werden"
FFRUNNING=$(find "$FFDIR" -name lock)
TBRUNNING=$(find "$TBDIR" -name lock)
FFCOUNT=$(pgrep firefox | wc -l)
TBCOUNT=$(pgrep thunderbird | wc -l)

# Funktion, um zu prüfen, ob das Programm noch ausgeführt wird
function check_running() {
  if [ -n "$1" ]; then
    if [ "$4" -eq 0 ]; then
      rm -f "$1"
    else
      echo -e "\n${2} wird noch ausgeführt!\nBitte beenden Sie ${2}, bevor Sie die"
      echo -e "Datenbanken komprimieren!\n"
      exit "$3"
    fi
  elif [ "$4" -gt 1 ]; then
    echo -e "\n${2} wird noch ausgeführt!\nBitte beenden Sie ${2}, bevor Sie die"
    echo -e "Datenbanken komprimieren!\n"
    exit "$3"
  fi
}

# Funktion zum Komprimieren der Datenbanken
function shrink_dbs() {
  echo -e "\nKomprimiere ${1}-Datenbanken"
  FILES=$(find "${2}" -name "*sqlite" -o -name "*.db")

  for db in $FILES; do
    echo -e "komprimiere $db"
    echo "VACUUM;" | sqlite3 "$db"
  done
  echo -e "${1}-Datenbanken komprimiert\n"
}

# prüfen, ob FF und TB noch laufen
check_running "$FFRUNNING" "Firefox" -110 "$FFCOUNT"
check_running "$TBRUNNING" "Thunderbird" -210 "$TBCOUNT"

# Datenbanken komprimieren
shrink_dbs "Firefox" "$FFDIR"
shrink_dbs "Thunderbird" "$TBDIR"

zenity=$(which zenity)
if [ "$zenity" == "" ]; then
  $zenity --info --text="Komprimierung abgeschlossen"
else
  echo "Komprimierung abgeschlossen"
fi

IFS=$OLDIFS
