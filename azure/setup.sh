#!/bin/bash
set -ue -o pipefail
export LC_ALL=C

###
# dns-challenge/azure/setup
#
# https://github.com/furplag/dns-challenge
# Copyright 2021 furplag
# Licensed under Apache 2.0 (https://github.com/furplag/dns-challenge/blob/master/LICENSE)

### variable
# statics
if ! declare -p _python >/dev/null 2>&1; then declare -r _python=$(if which python >/dev/null 2>&1; then which python; else which python3; fi); fi
if ! declare -p result >/dev/null 2>&1; then declare -i result=0; fi
if ! declare -p config >/dev/null 2>&1; then result=1; fi

if [[ $(("${result:-1}")) -ne 0 ]]; then _log ERROR "imcomplete configuration";
elif [[ ! " ${!config[@]} " =~ ' initialized ' ]]; then _log ERROR "imcomplete configuration"; result=1;
else
  _request="${config[base_url]}/TXT/${config[record]}?api-version=${config[api_version]}"
  _response=$(cat <<_EOT_|bash
curl -s -X GET "${_request}" \
$(_request_header)
_EOT_
  )
  declare -a _values=($(echo "${_response:-}" | $_python -c "import sys;import json;data=json.load(sys.stdin);[[print(value) for value in records['value']] for records in data['properties']['TXTRecords']] if 'properties' in data else False;"))
  _response=$(cat <<_EOT_|bash
curl -s -X PUT "${_request}" \
$(_request_header) \
--data "{\"properties\":{\"TTL\":${config[ttl]},\"TXTRecords\":[{\"value\":[$([[ -z "${_values[@]:-}" ]] || echo "\\\"${_values[@]}\\\"," | sed -e 's/ /\\\",\\\"/g')\"${config[token]}\"]}],}}"
_EOT_
  )
  _record=$(echo "${_response:-}" | $_python -c "import sys;import json;data=json.load(sys.stdin);print(data['name']) if 'properties' in data and data['properties']['provisioningState'] == 'Succeeded' else False;")
  if [[ -z "${_record:-}" ]]; then _log ERROR "could not add DNS record\\n  ${_response}"; result=1;
  else sleep ${config[propagation_seconds]}; fi
fi
