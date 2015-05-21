#! /bin/bash

function initVars {
	WDIR=$(pwd)
	# benötigte Variable befüllen
	RPMBUILD=$(whereis rpmbuild | awk '{print $2}')
	WGET=$(whereis wget | awk '{print $2}')
	MOCK=$(whereis mock | awk '{print $2}')
	CURL=$(whereis curl | awk '{print $2}')
	CLI=$(whereis copr-cli | awk '{print $2}')

	ARCH=$(cat SPECS/$PRJ.spec | grep BuildArch: | awk '{print $2}');
	# Wenn im SPEC keine BuildArch angegeben ist, für die eigene Prozessor-
	# Architektur bauen
	if [ -z "$ARCH" ]; then
		BARCH=$(uname -m)
	fi

	SOURCE=$(cat SPECS/$PRJ.spec | grep Source: | awk '{print $2}');
	if [ -z "$SOURCE" ]; then
		SOURCE=$(cat SPECS/$PRJ.spec | grep Source0: | awk '{print $2}');
	fi
	NAME=$(cat SPECS/$PRJ.spec | grep Name: | head -1 | awk '{print $2}');
	PRJNAME=$(cat SPECS/$PRJ.spec | grep prjname | head -1 | awk '{print $3}');
	PKGNAME=$(cat SPECS/$PRJ.spec | grep pkgname | head -1 | awk '{print $3}');
	VERSION=$(cat SPECS/$PRJ.spec | grep Version: | head -1 | awk '{print $2}');
	COMMIT=$(cat SPECS/$PRJ.spec | grep commit | head -1 | awk '{print $3}');
	# Wenn die Quellen aus Git kommen, auch noch den Git-Hash berechnen
	if [ -n "$COMMIT" ]; then
		HASH=${COMMIT:0:7};
	fi
}

if [ -z "$1" ]
then
	echo "Geben Sie ein zu verarbeitendes Specfile an"
	exit
fi

PRJ=$1
AUTO=true

if [ -n "$2" ]; then
	if [ "$2" == "noauto" ]; then
		AUTO=false
	fi
fi

initVars

if [ "$WDIR" != "$HOME/rpmbuild" ]; then
	cd $HOME/rpmbuild
fi

# FTP-Zugangsdaten auslesen sowie URL des SRPM auslesen
if [ -e "$HOME/rpmbuild/ftp.conf" ]; then
	source $HOME/rpmbuild/ftp.conf
else
	echo
	echo "$HOME/rpmbuild/ftp.conf existiert nicht!"
	exit
fi

if [ $AUTO == true ]; then
	download="j"
else
	echo
	read -p "Sourcen herunterladen? (j/n) " download
fi
if [ "$download" == "j" ]; then
	# URL für den Download der Sourcen zusammenbauen
	MATCH="%{name}"
	SOURCE=${SOURCE//$MATCH/$NAME}
	MATCH="%{version}"
	SOURCE=${SOURCE//$MATCH/$VERSION}
	if [ -n "$PRJNAME" ]; then
		MATCH="%{prjname}"
		SOURCE=${SOURCE//$MATCH/$PRJNAME}
	fi
	if [ -n "$PKGNAME" ]; then
		MATCH="%{pkgname}"
		SOURCE=${SOURCE//$MATCH/$PKGNAME}
	fi
	if [ -n "$COMMIT" ]; then
		MATCH="%{commit}"
		SOURCE=${SOURCE//$MATCH/$COMMIT}
	fi
	if [ -n "$HASH" ]; then
		MATCH="%{githash}"
		SOURCE=${SOURCE//$MATCH/$HASH}
	fi

	# Dateinamen des lokalen Sourcen-Archivs generieren
	DEST=$(echo $SOURCE | awk -F\/ '{print $NF}')

	echo "lösche alte Sourcen ..."
	rm -f SOURCES/*$PRJ*.gz
	rm -f SOURCES/*$PRJ*.xz
	rm -f SOURCES/*$PRJ*.bz2
	echo "Lade Source-Archiv $SOURCE herunter ..."
	if [ -n "$WGET" ]; then
		$WGET $SOURCE -q -O SOURCES/$DEST

		if [ $? != 0 ]; then
			echo
			echo "Download fehlgeschlagen!"
			exit
		fi
	else
		echo
		echo "wget ist nicht installiert!"
		exit
	fi
fi

echo
echo "Räume Build-Verzeichnisse auf ..."
rm -rf BUILD/*
rm -rf BUILDDIR/*
rm -rf BUILDROOT/*

echo "lösche vorhandene RPMs ..."
rm -rf RPMS/i686/*$PRJ*.rpm
rm -rf RPMS/noarch/*$PRJ*.rpm
rm -rf RPMS/x86_64/*$PRJ*.rpm
rm -rf SRPMS/*$PRJ*.rpm

for DIR in $(ls /var/lib/mock/)
do
	RESDIR="/var/lib/mock/$DIR/result"
	rm -rf $RESDIR/*$PRJ*.rpm
done

echo
echo -e "Erstelle ${1} Source-Paket"

# SRPM erstellen
if [ -n "$RPMBUILD" ]; then
	$RPMBUILD -bs SPECS/$PRJ.spec
	if [ $? != 0 ]; then
		echo
		echo "SRPM-Build fehlgeschlagen!"
		exit
	fi
else
	echo
	echo "rpmbuild ist nicht installiert!"
	exit
fi

# Pfad zum SRPM generieren
SRPM=$(find -samefile SRPMS/$PRJ* -type f)
SRPM=$(readlink -f $SRPM)
SRCRPM=$(basename $SRPM)

if [ -z "$SRPM" ]; then
	echo
	echo "konnte das SRPM nicht finden!"
	exit
fi

if [ $AUTO == true ]; then
	binary="n"
else
	echo
	read -p "Binärpakete erstellen? (j/n/q) " binary
fi
if [ "$binary" == "j" ]; then
	echo "Erstelle Binärpaket ..."
	if [ -n "$MOCK" ]; then
		$MOCK rebuild $SRPM --target=$BARCH --dnf

		if [ $? != 0 ]; then
			echo
			echo "Build fehlgeschlagen!"
			exit
		fi
	else
		echo
		echo "mock ist nicht installiert"
		exit
	fi
fi
if [ "$binary" == "q" ]; then
	exit
fi

if [ $AUTO == true ]; then
	upload="j"
else
	echo
	read -p "Upload des Source-Paketes? (j/n/q) " upload
fi

if [ "$upload" == "j" ]; then
	if [ -n "$FTPHOST" ]; then
		echo "lade $SRPM auf FTP-Server hoch ..."
		if [ -n "$CURL" ]; then
			$CURL -T $SRPM -u "$FTPUSER:$FTPPWD" ftp://$FTPHOST/$FTPPATH

			if [ $? != 0 ]; then
				echo
				echo "Upload fehlgeschlagen!"
			fi
		else
			echo
			echo "curl ist nicht installiert!"
			exit
		fi
	else
		echo
		echo "FTP-Zugangsdaten sind nicht konfiguriert"
		exit
	fi
fi
if [ "$upload" == "q" ]; then
	exit
fi

# Binärpakete mit COPR bauen
if [ $AUTO == true ]; then
	build="j"
else
	echo
	read -p "Paket(e) im COPR bauen? (j/n/) " build
fi
if [ "$build" == "n" ]; then
	exit
fi

if [ -n "$CLI" ]; then
	# Das zu verwendende COPR versuchen, zu ermitteln
	echo "Suche nach passendem COPR ..."
	for coprs in $($CLI list | grep Name | awk '{print $2}' | grep $PRJ)
	do
		if [ $AUTO == true ]; then
			use="j"
		else
			read -p "COPR $coprs verwenden? (j/n/q) " use
		fi
		if [ "$use" == "j" ]; then
			copr=$coprs
			break
		elif [ "$use" == "q" ]; then
			exit
		fi
	done

	# Kein passendes COPR gefunden -> in coprs.conf nachschauen
	if [ -z "$copr" ]; then
		if [ -e "$HOME/rpmbuild/coprs.conf" ]; then
			echo "Suche in coprs.conf nach passendem COPR ..."
			coprs=$(cat $HOME/rpmbuild/coprs.conf | grep $PRJ)
			coprs=${coprs#*=}
			if [ -n "$coprs" ]; then
				if [ $AUTO == true ]; then
					use="j"
				else
					read -p "COPR $coprs verwenden? (j/n/q) " use
				fi
				if [ "$use" == "j" ]; then
					copr=$coprs
				elif [ "$use" == "q" ]; then
					exit
				fi
			fi
		fi
	fi

	# Noch immer kein passendes COPR gefunden -> User fragen
	if [ -z "$copr" ]; then
		read -p "Name des zu verwendenden COPRs: " copr
	fi

	# COPR-Build veranlassen
	if [ -n "$copr" ]; then
		if [ -n "$HTTPHOST" ]; then
			# Nachschauen, ob ein Projekt nur für bestimmte
			# chroots gebaut werden soll
			if [ -e "$HOME/rpmbuild/chroots.conf" ]; then
				CHROOTS=$(cat $HOME/rpmbuild/chroots.conf | grep $copr)
				CHROOTS=${CHROOTS#*=}
			fi

			if [ -z "$CHROOTS" ]; then
				echo
				$CLI build "$copr" http://$HTTPHOST/$HTTPPATH/$SRCRPM
			else
				echo
				OLDIFS=$IFS
				IFS=","
				for CHROOT in $CHROOTS;	do
					CMDLINE="$CMDLINE -r $CHROOT"
				done
				IFS=$OLDIFS
				$CLI build "$copr" $CMDLINE http://$HTTPHOST/$HTTPPATH/$SRCRPM
				exit
			fi
		else
			echo
			echo "$HOME/rpmbuild/ftp.conf ist fehlerhaft!"
			exit
		fi
	fi
else
	echo
	echo "copr-cli ist nicht installiert!"
	exit
fi

cd ..
