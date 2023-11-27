#!/bin/bash
set -ue -o pipefail
export LC_ALL=C

###
# dns-challenge/cloudflare/teardown
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
  _response=$(cat <<_EOT_|bash
curl -s -X GET "${config[base_url]}/${config[zone_id]}/dns_records?type=TXT&name=${config[record]}&page=1&per_page=100" \
$(_request_header)
_EOT_
  )
  local -ar _records=($(echo "${_response:-}" \
    | $_python -c "import sys;import json;data=json.load(sys.stdin);[print(result['id']) for result in data['result']] if data['success'] and data['result_info']['count'] > 0 else False;"
  ))
  for _record in "${_records[@]}"; do
    if [[ -n "${_record:-}" ]]; then
      _terminate=$(cat <<_EOT_|bash
curl -s -X DELETE "${config[base_url]}/${config[zone_id]}/dns_records/${_record}" \
$(_request_header)
_EOT_
      )
      _terminated=$(echo "${_terminate}" \
        | python -c "import sys;import json;data=json.load(sys.stdin);print(data['result']['id']) if data['success'] else False;"
      )
      if [[ $(("${result:-1}")) -ne 0 ]]; then :;
      elif [[ $(("${config[teardown_lazily]:-0}")) -eq 0 ]]; then :;
      elif [[ -z "${_terminated:-}" ]]; then _log ERROR "could not remove record\\n  id: ${_record}\\n  ${_terminate}"; _result=1; fi
    fi
  done
fi
