#!/bin/bash
set -ue -o pipefail
export LC_ALL=C

###
# dns-challenge/dns-challenge-cloudflare
#
# https://github.com/furplag/dns-challenge
# Copyright 2021 furplag
# Licensed under Apache 2.0 (https://github.com/furplag/dns-challenge/blob/master/LICENSE)

### variables
# constants
if ! declare -p name >/dev/null 2>&1; then declare -r name=`basename ${0:-}`; fi
if ! declare -p basedir >/dev/null 2>&1; then declare -r basedir=$(cd $(dirname $0); pwd); fi
if ! declare -p dns_type >/dev/null 2>&1; then declare -r dns_type=$(echo "${name:-}" | sed -e 's/\..*$//' -e 's/^.*\-//'); fi
if [[ -z "${dns_type}" ]]; then cat <<_EOT_

no DNS type selected .
see https://github.com/furplag/dns-challenge

_EOT_
exit 1; fi
if ! declare -p configuration_file >/dev/null 2>&1; then declare -r configuration_file=${basedir}/.credencials/${dns_type}; fi

### pre-processing
if ! source "${basedir}/${dns_type}/configurator.sh" 2>/dev/null; then exit 1; fi
### processing
if ! source "${basedir}/${dns_type}/${config[execute]}.sh" 2>/dev/null; then _log FATAL "process \"${dns_type}/${config[execute]}\" not implemented"; exit 1; fi

_log "$(if [[ $(("${result:-1}")) -ne 0 ]]; then echo ERROR; else echo INFO; fi)" "process: ${config[execute]} $(if [[ $(("${result:-1}")) -ne 0 ]]; then echo failed; else echo successed; fi)"

exit $((${result:-1}))
