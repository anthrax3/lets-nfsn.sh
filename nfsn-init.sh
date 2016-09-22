#!/usr/bin/env bash
set -o errexit -o nounset -o pipefail

readonly well_known='.well-known/acme-challenge/'
declare single_cert='true'

echo " + Cloning dehydrated git repository..."
git submodule init
git submodule update --remote

echo " + Generating configuration..."
for site_root in $(nfsn list-aliases); do
   if [[ -d "${DOCUMENT_ROOT}${site_root}/" ]]; then
      WELLKNOWN="${DOCUMENT_ROOT}${site_root}/${well_known}"
      CONFIGDIR="dehydrated/certs/${site_root}/"
      mkdir -p "${WELLKNOWN}" "${CONFIGDIR}"
      echo "WELLKNOWN='${WELLKNOWN}'" > "${CONFIGDIR}/config"
      echo " + Installing hook script..."
      echo "HOOK='$(realpath nfsn-hook.sh)'" >> "${CONFIGDIR}/config"
      unset single_cert
   fi
done

if [[ "${single_cert:+true}" ]]; then
   echo " + Generating fallback configuration..."
   mkdir -p "${DOCUMENT_ROOT}${well_known}"
   echo "WELLKNOWN='${DOCUMENT_ROOT}${well_known}'" > dehydrated/config
   echo " + Installing hook script..."
   echo "HOOK='$(realpath nfsn-hook.sh)'" >> dehydrated/config
fi

echo " + Generating domains.txt..."
nfsn ${single_cert:+-s} list-aliases > dehydrated/domains.txt

