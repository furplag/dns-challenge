#!/bin/bash
set -ue -o pipefail
export LC_ALL=C

###
# dns-challenge/azure/teardown
#
# https://github.com/furplag/dns-challenge
# Copyright 2021 furplag
# Licensed under Apache 2.0 (https://github.com/furplag/dns-challenge/blob/master/LICENSE)

### variable
# statics
if ! declare -p result >/dev/null 2>&1; then declare -i result=0; fi
if ! declare -p config >/dev/null 2>&1; then result=1; fi

if [[ $(("${result:-1}")) -ne 0 ]]; then _log ERROR "imcomplete configuration";
elif [[ ! " ${!config[@]} " =~ ' initialized ' ]]; then _log ERROR "imcomplete configuration"; result=1;
else
  _request="${config[base_url]}/TXT/${config[record]}?api-version=${config[api_version]}"
  _response=$(cat <<_EOT_|bash
curl -s -X DELETE "${_request}" \
$(_request_header)
_EOT_
  )
  if [[ $(("${config[teardown_lazily]:-0}")) -ne 0 ]]; then
    _response=$(cat <<_EOT_|bash
curl -s -X GET "${_request}" \
$(_request_header)
_EOT_
    )
    _record=$(echo "${_response:-}" | python -c "import sys;import json;data=json.load(sys.stdin);print(data['name']) if 'properties' in data and data['properties']['provisioningState'] == 'Succeeded' else False;")
    if [[ -n "${_record:-}" ]]; then _log ERROR "could not remove DNS record\\n  ${_response}"; result=1; fi
  fi
fi
