#!/usr/bin/env bash
set -o errexit -o nounset -o pipefail

cd "$(dirname "$0")"

echo " + Updating lets-nfsn.sh..."
git pull

echo " + Updating dehydrated..."
git submodule update --remote
cd dehydrated

if [ ! -d certs ]
then
	echo "No certs directory. Have you run nfsn-setup.sh?"
	exit 1
fi

echo " + Checking certificate expiration date..."
if find certs -name cert.pem -type l \
	-exec openssl x509 -checkend 2592000 -in {} \; |
		grep -qF "Certificate will expire"; then
	echo " + Certificte will expire in 30 days or less! SSH into this site and"
	echo "   run the following commands to renew your certificates:"
	echo "	cd ~/lets-nfsn.sh/dehydrated/"
	echo "	./dehydrated --cron"
	echo " + This error message will repeat daily."
	exit 1
else
	echo " + More than 30 days until any certificate expires. Exiting."
	exit 0
fi

echo " + Running dehydrated..."
./dehydrated --cron

echo " + Cleaning up old certificates..."
./dehydrated --cleanup
