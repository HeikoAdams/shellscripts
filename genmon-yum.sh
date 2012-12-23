#!/bin/bash

# Reference: 
# http://lists.fedoraproject.org/pipermail/xfce/2011-November/000841.html

# From "man yum"
#    check-update
#        Implemented  so  you  could know if your machine had any updates
#        that needed to be  applied  without  running  it  interactively.
#        Returns exit value of 100 if there are packages available for an
#        update. Also returns a list of the packages  to  be  updated  in
#        list  format. Returns 0 if no packages are available for update.
#        Returns 1 if an error occurred.

# Dependencies:  Oxygen icons
#                gpk-update-viewer  (yum install gnome-packagekit)

updates=$( yum check-update -q )
status=$?

if [ $status = 100 ]
    then
       echo -e "<img>/usr/share/icons/gnome/22x22/status/software-update-available.png</img>"
       echo -e "<tool>Updates verfügbar</tool>"
       echo -e "<click>yumex --update-only</click>"

elif [ $status = 1 ]
    then
       echo -e "<img>/usr/share/icons/gnome/22x22/status/error.png</img>"
       echo -e "<tool>Fehler bei der Update-Prüfung</tool>"
       echo -e "<click>yumex --update-only</click>"

elif [ $status = 0 ]
    then
       echo -e "<img>/usr/share/icons/gnome/22x22/status/dialog-information.png</img>"
       echo -e "<tool>Alle Updates installiert</tool>"
       echo -e "<click>yumex --update-only</click>"

else
       echo -e "<img>/usr/share/icons/gnome/22x22/status/stock_dialog-warning.png</img>"
       echo -e "<tool>Unbekannter Status</tool>"
       echo -e "<click>yumex --update-only</click>"
fi
