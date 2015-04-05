#! /bin/bash

if [ -z "$1" ]
then
	echo "Geben Sie ein zu verarbeitendes Specfile an"
	exit
fi

WDIR=$(pwd)

if [ "$WDIR" != "$HOME/rpmbuild" ]; then
	cd $HOME/rpmbuild
fi

# benötigte Variable befüllen
ARCH=$(cat SPECS/$1.spec | grep BuildArch | awk '{print $2}');
SOURCE=$(cat SPECS/$1.spec | grep Source | awk '{print $2}');
NAME=$(cat SPECS/$1.spec | grep Name | head -1 | awk '{print $2}');
PRJNAME=$(cat SPECS/$1.spec | grep prjname | head -1 | awk '{print $3}');
VERSION=$(cat SPECS/$1.spec | grep Version | head -1 | awk '{print $2}');
COMMIT=$(cat SPECS/$1.spec | grep commit | head -1 | awk '{print $3}');

# Wenn die Quellen aus Git kommen, auch noch den Git-Hash berechnen
if [ -n "$COMMIT" ]; then
	HASH=${COMMIT:0:7};
fi

# URL für den Download der Sourcen zusammenbauen
MATCH="%{name}"
SOURCE=${SOURCE//$MATCH/$NAME}
MATCH="%{version}"
SOURCE=${SOURCE//$MATCH/$VERSION}
if [ -n "$PRJNAME" ]; then
	MATCH="%{prjname}"
	SOURCE=${SOURCE//$MATCH/$PRJNAME}
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

echo
read -p "Sourcen herunterladen? (j/n) " download
if [ "$download" == "j" ]; then
	echo
	echo "Lade Sourcen runter"
	WGET=$(whereis wget | awk '{print $2}')
	rm -f SOURCES/$DEST
	$WGET -q $SOURCE -O SOURCES/$DEST

	if [ $? != 0 ]; then
		echo
		echo "Download fehlgeschlagen!"
		exit
	fi
fi

# Wenn im SPEC keine BuildArch angegeben ist, für x86_64 bauen
if [ -z "$ARCH" ]; then
	BARCH="x86_64"
fi

echo
echo "Räume Build-Verzeichnisse auf"
rm -rf BUILD/*
rm -rf BUILDDIR/*
rm -rf BUILDROOT/*
for DIR in $(ls /var/lib/mock/)
do
	RESDIR="/var/lib/mock/$DIR/result"
	rm -rf $RESDIR/*
done

echo
echo "lösche vorhandene RPMs"
rm -rf RPMS/i686/*$1*.rpm
rm -rf RPMS/noarch/*$1*.rpm
rm -rf RPMS/x86_64/*$1*.rpm
rm -rf SRPMS/*$1*.rpm

echo
echo -e "Erstelle ${1} Source-Paket"

# SRPM erstellen
RPMBUILD=$(whereis rpmbuild | awk '{print $2}')
$RPMBUILD -bs SPECS/$1.spec
if [ $? != 0 ]; then
	echo
	echo "SRPM-Build fehlgeschlagen!"
	exit
fi

# Dateinamen des SRPM extrahieren
cd SRPMS
SRPM=$(find -name $1* -type f)
SRPM=$(basename $SRPM)

echo
read -p "Binärpakete erstellen? (j/n/q) " binary
if [ "$binary" == "j" ]; then
	echo
	echo "Erstelle Binärpaket"
	MOCK=$(whereis mock | awk '{print $2}')
	$MOCK rebuild $SRPM --target=$BARCH --dnf

	if [ $? != 0 ]; then
		echo
		echo "Build fehlgeschlagen!"
		exit
	fi
elif [ "$binary" == "q" ]; then
	exit
fi

echo
read -p "Upload des Source-Paketes? (j/n/q) " upload
if [ "$upload" == "j" ]; then
	# FTP-Zugangsdaten auslesen und Variablen bestücken
	FTPUSER=$(cat $HOME/rpmbuild/ftp.conf | grep FTPUSER)
	FTPPWD=$(cat $HOME/rpmbuild/ftp.conf | grep FTPPWD)
	FTPHOST=$(cat $HOME/rpmbuild/ftp.conf | grep FTPHOST)
	FTPPATH=$(cat $HOME/rpmbuild/ftp.conf | grep FTPPATH)
	FTPUSER=${FTPUSER#*=}
	FTPPWD=${FTPPWD#*=}
	FTPHOST=${FTPHOST#*=}
	FTPPATH=${FTPPATH#*=}

	echo
	echo "lade $SRPM auf FTP-Server hoch"
	CURL=$(whereis curl | awk '{print $2}')
	$CURL -T $HOME/rpmbuild/SRPMS/$SRPM -u "$FTPUSER:$FTPPWD" ftp://$FTPHOST/$FTPPATH
elif [ "$upload" == "q" ]; then
	exit
fi

# Binärpakete mit COPR bauen
if [ $? == 0 ]; then
	echo
	read -p "Pakete im COPR bauen? (j/n/) " build
	if [ "$build" == "n" ]; then
		exit
	fi

	for coprs in $(copr-cli list | grep Name | awk '{print $2}' | grep $1)
	do
		echo
		read -p "COPR $coprs verwenden? (j/n/q) " use
		if [ "$use" == "j" ]; then
			copr=$coprs
			break
		elif [ "$use" == "q" ]; then
			exit
		fi
	done

	if [ -z "$copr" ]; then
		if [ -e "$HOME/rpmbuild/coprs.conf" ]; then
			coprs=$(cat $HOME/rpmbuild/coprs.conf | grep $1)
			if [ -n "$coprs" ]; then
				echo
				read -p "COPR $coprs verwenden? (j/n/q) " use
				if [ "$use" == "j" ]; then
					copr=$coprs
				elif [ "$binary" == "q" ]; then
					exit
				fi
			fi
		fi

		if [ -z "$copr" ]; then
			echo
			read -p "Name des zu verwendenden COPRs: " copr
		fi
	fi

	if [ -n "$copr" ]; then
		CLI=$(whereis copr-cli | awk '{print $2}')
		if [ -n "$CLI" ]; then
			# URL des SRPM auslesen und Variablen bestücken
			HTTPHOST=$(cat $HOME/rpmbuild/ftp.conf | grep HTTPHOST)
			HTTPPATH=$(cat $HOME/rpmbuild/ftp.conf | grep HTTPPATH)
			HTTPHOST=${HTTPHOST#*=}
			HTTPPATH=${HTTPPATH#*=}

			$CLI build "$copr" http://$HTTPHOST/$HTTPPATH/$SRPM
		fi
	fi
else
	echo
	echo "Upload fehlgeschlagen!"
fi

cd ..
