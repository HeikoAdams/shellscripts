#!/bin/bash

# Variablen für die Backup- und Protokoll-Dateien
TBFILENAME="backup_thunderbird_"$(date +"%Y%m%d").tar.gz
TBLOGFILE="backup_thunderbird_"$(date +"%Y%m%d").log
FFFILENAME="backup_firefox_"$(date +"%Y%m%d").tar.gz
FFLOGFILE="backup_firefox_"$(date +"%Y%m%d").log

# Variable für das Zielverzeichnis
BACKUPDIR=${HOME}"/Dokumente"

# Variablen für die Profil-Verzeichnisse
TBDIR="${HOME}/.thunderbird"
FFDIR="${HOME}/.mozilla/firefox"

# Variablen für die Crash-Report-Verzeichnisse
TBCRASHDIR=$(find "$TBDIR" -name "Crash Reports")
FFCRASHDIR=$(find "$FFDIR" -name "Crash Reports")

# Variablen für die Cache-Verzeichnisse
TBCACHDIR=$(find "$TBDIR" -name "Cache")
FFCACHDIR=$(find "$FFDIR" -name "Cache")

# Prüfung, ob Firefox oder Thunderbird noch ausgeführt werden
FFRUNNING=$(find "$FFDIR" -name lock)
TBRUNNING=$(find "$TBDIR" -name lock)

# Funktion, um die möglichen Parameter anzuzeigen
function help_params {
  echo -e "\nmögliche Parameter:\nALL: komplettes Backup\nTB: Nur Thunderbird sichern\nFF: nur Firefox sichern\n";
  exit 1;
}

# Funktion, um zu prüfen, ob das übergebene Verzeichnis existiert
function check_dir {
  if [ ! -d "$1" ]
  then
    echo -e "\n ${1} ist ungültig! \n";
    exit "$2";
  fi
}

# Funktion, um das Verzeichnis mit Crash-Reports zu löschen
function check_del_dir {
  if [ -d "$1" ]
  then
    rm -rf "$1";
  fi  
}

# Funktion, um das übergebene Verzeichnis zu leeren
function clear_directory {
  if [ -d "$1" ]
  then
    rm -rf "${1:?}/*";
  fi  
}

# Funktion, um zu prüfen, ob das Programm noch ausgeführt wird
function check_running {
  if [ -n "$1" ]
  then
    echo -e "\n${2} wird noch ausgeführt!\nBitte beenden Sie ${2}, bevor Sie das Backup starten!\n";
    exit "$3";
  fi
}

# Funktion, zum Erstellen des Backups
function create_backup {
  echo "erstelle ${1}-Backup"
  
  if $ENC
  then
    tar czp "${3}" | gpg -z 0 -c > "$BACKUPDIR/${2}.gpg"
  else
    if $DEBUG
    then
      tar zcvf "$BACKUPDIR/${2}" "${3}" > "$BACKUPDIR/${4}"
    else
      tar zcf "$BACKUPDIR/${2} ${3}"
    fi
  fi
  
  echo "${1}-Backup erstellt"
}

# Funktion für das Firefox-Backup
function backup_firefox {
  # prüfen, ob das Zielverzeichnis existiert
  check_dir "$BACKUPDIR" -120

  # prüfen, ob Firefox noch ausgeführt wird
  check_running "$FFRUNNING" "Firefox" -110

  # prüfen, ob das angegebene Profil-Verzeichnis existiert
  check_dir "$FFDIR" -100
  
  # prüfen, ob das Crash Reports-Verzeichnis vorhanden ist
  clear_directory "$FFCRASHDIR"
  
  # Cache-Verzeichnis vor dem Backup leeren
  clear_directory "$FFCACHDIR"

  # Backup erstellen
  create_backup "Firefox" "$FFFILENAME" "$FFDIR" "$FFLOGFILE"
}

# Funktion für das Thunderbird-Backup
function backup_thunderbird {
  # prüfen, ob das Zielverzeichnis existiert
  check_dir "$BACKUPDIR" -220
  
  # prüfen, ob Thunderbird noch ausgeführt wird
  check_running "$TBRUNNING" "Thunderbird" -210

  # prüfen, ob das angegebene Profil-Verzeichnis existiert
  check_dir "$TBDIR" -200

  # prüfen, ob das Crash Reports-Verzeichnis vorhanden ist
  clear_directory "$TBCRASHDIR" 
   
  # Cache-Verzeichnis vor dem Backup leeren
  clear_directory "$TBCACHDIR"

  # Backup erstellen
  create_backup "Thunderbird" "$TBFILENAME" "$TBDIR" "$TBLOGFILE"
}

# wenn kein Parameter übergeben wurde, die möglichen Parameter anzeigen
if [ -z "$1" ]
then
  help_params
fi

# Prüfen, ob die Backups verschlüsselt werden sollen
if [[ -n "$2" && "$2" == "ENC" ]]
then
  ENC=true
else
  ENC=false
fi

# Prüfen, ob der Debug-Modus aktiviert werden soll
if [[ -n "$2" && "$2" == "DEBUG" ]]
then
  DEBUG=true
else
  DEBUG=false
fi

# Festlegen, was gesichert werden soll
case "$1" in
  ALL)
    FFBACKUP=true
    TBBACKUP=true
    ;;
  FF)
    FFBACKUP=true
    TBBACKUP=false
    ;;
  TB)
    FFBACKUP=false
    TBBACKUP=true
    ;;
  *)
    echo -e "\nungültiger Parameter: ${1}";
    help_params
    ;;
esac

# Backup Firefox-Profil(e)
if $FFBACKUP
then
  backup_firefox;
fi

# Backup Thunderbird-Profil(e)
if $TBBACKUP
then
  backup_thunderbird
fi
