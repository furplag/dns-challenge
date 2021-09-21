#!/bin/bash
set -ue -o pipefail
export LC_ALL=C

###
# dns-challenge/certbot-authenticator
#
# https://github.com/furplag/dns-challenge
# Copyright 2021 furplag
# Licensed under Apache 2.0 (https://github.com/furplag/dns-challenge/blob/master/LICENSE)

### variables
# constants
if ! declare -p name >/dev/null 2>&1; then declare -r name=`basename ${0:-}`; fi
if ! declare -p basedir >/dev/null 2>&1; then declare -r basedir=$(cd $(dirname $0); pwd); fi
if ! declare -p dns_type >/dev/null 2>&1; then declare -r dns_type=$(echo "${name:-}" | sed -e 's/\..*$//' -e 's/^.*\-//'); fi
if [[ -z "${dns_type}" ]]; then exit 1; fi
if ! declare -p configuration_file >/dev/null 2>&1; then declare -r configuration_file=${basedir}/.credencials/${dns_type}; fi

if ! declare -p CERTBOT_DOMAIN >/dev/null 2>&1; then declare -r CERTBOT_DOMAIN=hey.furplag.jp; fi

cat <<_EOT_|bash -s -- teardown "${CERTBOT_DOMAIN}"
declare -r name=${name}
declare -r basedir=${basedir}
declare -r dns_type=${dns_type}
declare -r configuration_file=${configuration_file}

source ${basedir}/dns-challenge.sh
_EOT_

exit $?
