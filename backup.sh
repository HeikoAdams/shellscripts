#!/bin/bash

for u in $(who | awk '{print $1}' | sort | uniq)
do
	if [ "$u" != "heiko" ]; then
		exit 0
	fi
done

test -x $(which duplicity) || exit 0
test -d //media/fritzbox/Intenso-UltraLine-01/Heiko || exit 0

echo "start: " `date +%D-%T` >> $HOME/backup.log

export PASSPHRASE=21November2008

$(which duplicity) \
	--name home-backup \
	--log-file $HOME/backup.log \
	--full-if-older-than 15D \
	--include $HOME/Bilder \
	--include $HOME/bin \
	--include $HOME/Dokumente/ \
	--include $HOME/Musik \
	--include $HOME/rpmbuild \
	--include $HOME/Vorlagen \
	--include $HOME/Templates \
	--exclude $HOME/Dokumente/Kalender \
	--exclude $HOME/rpmbuild/SRPMS \
	--exclude $HOME/rpmbuild/RPMS \
	--exclude $HOME/Dokumente/Backup \
	$HOME \
	file:///media/fritzbox/Intenso-UltraLine-01/Heiko/

$(which duplicity) \
	remove-all-but-n-full 3 \
	--force \
	file:///media/fritzbox/Intenso-UltraLine-01/Heiko/

echo "end: " `date +%D-%T` >> $HOME/backup.log

$(which duplicity) \
	cleanup \
	--force \
	file:///media/fritzbox/Intenso-UltraLine-01/Heiko/

$(which duplicity) \
	collection-status \
	file:///media/fritzbox/Intenso-UltraLine-01/Heiko/ > \
	$HOME/status.log

unset PASSPHRASE