#!/bin/sh

Help=no
Reinstall=no
Verbose=no

while [ ${#} -gt 0 ]
do
	Arg=${1}
	shift 1
	case ${Arg} in
	"-h"|"--help")
		Help=yes
		;;
	"-r"|"--reinstall")
		Reinstall=yes
		;;
	"-v"|"--verbose")
		Verbose=yes
		;;
	*)
		echo "Bad argument: ${Arg}"
		return 20
	esac
done

if [ "${Help}" = "yes" ]
then
	echo
	echo "YourPrompt> ${0} [-r|--reinstall] [-v|--verbose]"
	echo "YourPrompt> ${0} <-h|--help>"
	echo
	echo "Options:"
	echo "  -h, --help      = Display this output."
	echo "  -r, --reinstall = Reinstall existing certificates."
	echo "  -v, --verbose   = Don't suppress boring output."
	echo
	return 0
fi

. /usr/local/etc/dehydrated/config
if [ ! -d "${BASEDIR}" ]
then
	echo "Creating base directory for Dehydrated."
	mkdir "${BASEDIR}"
fi

if [ ! -d "${BASEDIR}/accounts" ]
then
	echo
	echo "To use Let's Encrypt you must agree to their Subscriber Agreement,"
	echo "which is linked from:"
	echo
	echo "    https://letsencrypt.org/repository/"
	echo
	printf "Do you accept the Let's Encrypt Subscriber Agreement (y/n)? "
	read -r yes
	case $yes in
		y|Y|yes|YES|Yes|yup)
			;;
		*)
			echo "OK, tls-setup.sh will be aborted."
			return 30
	esac
	/usr/local/bin/dehydrated --register --accept-terms
fi

if [ ! -d "${WELLKNOWN}" ]
then
	echo "Creating well-known directory for Let's Encrypt challenges."
	mkdir -p "${WELLKNOWN}"
fi

/usr/local/bin/nfsn list-aliases >"${BASEDIR}/domains.txt"

if [ ! -s "${BASEDIR}/domains.txt" ]
then
	echo "There are no aliases for this site."
	return 10
fi

while IFS='' read -r Alias
do
	if [ -d "/home/public/${Alias}" ]
	then
		if [ ! -d "/home/public/${Alias}/.well-known" ]
		then
			echo "Creating well-known directory for ${Alias}."
			mkdir -p "/home/public/${Alias}/.well-known"
		fi
		if [ ! -d "/home/public/${Alias}/.well-known/acme-challenge" ]
		then
			echo "Linking acme-challenge for ${Alias}."
			ln -s "${WELLKNOWN}" "/home/public/${Alias}/.well-known/acme-challenge"
		fi
	fi
	if [ "${Reinstall}" = "yes" ]
	then
		cat \
			"${BASEDIR}/certs/${Alias}/cert.pem" \
			"${BASEDIR}/certs/${Alias}/chain.pem" \
			"${BASEDIR}/certs/${Alias}/privkey.pem" \
		| /usr/local/bin/nfsn -i set-tls
	fi
done <"${BASEDIR}/domains.txt"

if [ "${Reinstall}" = "yes" ]
then
	return 0
fi

/usr/local/bin/dehydrated --cron >"${BASEDIR}/dehydrated.out"

if grep -F -v INFO: "${BASEDIR}/dehydrated.out" | grep -F -v unchanged | grep -F -v 'Skipping renew' | grep -F -v 'Checking expire date' | grep -E -q -v '^Processing' || [ "${Verbose}" = "yes" ]
then
	cat "${BASEDIR}/dehydrated.out"
fi

if ! /usr/local/bin/nfsn test-cron tlssetup | grep -F -q 'exists=true'
then
	echo Adding scheduled task to renew certificates.
	/usr/local/bin/nfsn add-cron tlssetup /usr/local/bin/tls-setup.sh me ssh '?' '*' '*'
fi
