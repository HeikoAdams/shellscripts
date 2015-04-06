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
ARCH=$(cat SPECS/$1.spec | grep BuildArch: | awk '{print $2}');
SOURCE=$(cat SPECS/$1.spec | grep Source: | awk '{print $2}');
NAME=$(cat SPECS/$1.spec | grep Name: | head -1 | awk '{print $2}');
PRJNAME=$(cat SPECS/$1.spec | grep prjname | head -1 | awk '{print $3}');
VERSION=$(cat SPECS/$1.spec | grep Version: | head -1 | awk '{print $2}');
COMMIT=$(cat SPECS/$1.spec | grep commit | head -1 | awk '{print $3}');

# Wenn die Quellen aus Git kommen, auch noch den Git-Hash berechnen
if [ -n "$COMMIT" ]; then
	HASH=${COMMIT:0:7};
fi

# Wenn im SPEC keine BuildArch angegeben ist, für x86_64 bauen
if [ -z "$ARCH" ]; then
	BARCH="x86_64"
fi

echo
read -p "Sourcen herunterladen? (j/n) " download
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
	echo "Lade Sourcen runter"
	rm -f SOURCES/$DEST
	WGET=$(whereis wget | awk '{print $2}')
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
echo "Räume Build-Verzeichnisse auf"
rm -rf BUILD/*
rm -rf BUILDDIR/*
rm -rf BUILDROOT/*

echo
echo "lösche vorhandene RPMs"
rm -rf RPMS/i686/*$1*.rpm
rm -rf RPMS/noarch/*$1*.rpm
rm -rf RPMS/x86_64/*$1*.rpm
rm -rf SRPMS/*$1*.rpm

for DIR in $(ls /var/lib/mock/)
do
	RESDIR="/var/lib/mock/$DIR/result"
	rm -rf $RESDIR/*$1*.rpm
done

echo
echo -e "Erstelle ${1} Source-Paket"

# SRPM erstellen
RPMBUILD=$(whereis rpmbuild | awk '{print $2}')
if [ -n "$RPMBUILD" ]; then
	$RPMBUILD -bs SPECS/$1.spec
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
	if [ -n "$CURL" ]; then
		$CURL -T $HOME/rpmbuild/SRPMS/$SRPM -u "$FTPUSER:$FTPPWD" ftp://$FTPHOST/$FTPPATH

		if [ $? != 0 ]; then
			echo
			echo "Upload fehlgeschlagen!"
		fi
	else
		echo
		echo "curl ist nicht installiert!"
		exit
	fi
elif [ "$upload" == "q" ]; then
	exit
fi

# Binärpakete mit COPR bauen
echo
read -p "Pakete im COPR bauen? (j/n/) " build
if [ "$build" == "n" ]; then
	exit
fi
# Das zu verwendende COPR versuchen, zu ermitteln
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

# Kein passendes COPR gefunden -> in coprs.conf nachschauen
if [ -z "$copr" ]; then
	if [ -e "$HOME/rpmbuild/coprs.conf" ]; then
		coprs=$(cat $HOME/rpmbuild/coprs.conf | grep $1)
		coprs=${coprs#*=}
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
fi

# Noch immer kein passendes COPR gefunden -> User fragen
if [ -z "$copr" ]; then
	echo
	read -p "Name des zu verwendenden COPRs: " copr
fi

# COPR-Build veranlassen
if [ -n "$copr" ]; then
	CLI=$(whereis copr-cli | awk '{print $2}')
	if [ -n "$CLI" ]; then
		# URL des SRPM auslesen und Variablen bestücken
		HTTPHOST=$(cat $HOME/rpmbuild/ftp.conf | grep HTTPHOST)
		HTTPPATH=$(cat $HOME/rpmbuild/ftp.conf | grep HTTPPATH)
		HTTPHOST=${HTTPHOST#*=}
		HTTPPATH=${HTTPPATH#*=}

		if [ -n "$CURL" ]; then
			$CLI build "$copr" http://$HTTPHOST/$HTTPPATH/$SRPM
		else
			echo
			echo "copr-cli ist nicht installiert!"
			exit
		fi
	fi
fi

cd ..
