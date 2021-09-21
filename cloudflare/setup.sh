#!/bin/bash
set -ue -o pipefail
export LC_ALL=C

###
# dns-challenge/cloudflare/setup
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
else _response=$(cat <<_EOT_|bash
curl -s -X POST "${config[base_url]}/${config[zone_id]}/dns_records" \
$(_request_header) \
--data "{\"type\":\"TXT\",\"name\":\"${config[record_prefix]}.${config[domain]}\",\"content\":\"${config[token]}\",\"ttl\":\"${config[ttl]}\"}"
_EOT_
  )
  _record=$(echo "${_response:-}" | python -c "import sys;import json;data=json.load(sys.stdin);print(data['result']['id']) if data['success'] else False;")
  if [[ -z "${_record:-}" ]]; then _log ERROR "could not add DNS record\\n  ${_response}"; result=1;
  else sleep ${config[propagation_seconds]}; fi
fi
