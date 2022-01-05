#!/bin/bash
set -ue -o pipefail
export LC_ALL=C

###
# dns-challenge/azure/configurator
#
# https://github.com/furplag/dns-challenge/azure
# Copyright 2021 furplag
# Licensed under Apache 2.0 (https://github.com/furplag/dns-challenge/blob/master/LICENSE)

### variable
# statics
if ! declare -p name >/dev/null 2>&1; then declare -r name=azure; fi
if ! declare -p basedir >/dev/null 2>&1; then declare -r basedir=/var/lib/httpd/dns-challenge; fi
if ! declare -p dns_type >/dev/null 2>&1; then declare -r dns_type=$(echo "${name:-}" | sed -e 's/\..*$//' -e 's/^.*\-//'); fi
if ! declare -p configuration_file >/dev/null 2>&1; then declare -r configuration_file=${basedir}/.credencials/azure; fi
if ! declare -p log_dir >/dev/null 2>&1; then declare -r log_dir=${basedir}/logs; fi
if ! declare -p log >/dev/null 2>&1; then declare -r log=${log_dir}/${name}.`date +"%Y%m"`.log; fi
if ! declare -p config >/dev/null 2>&1; then declare -A config=(
  [name]="${name:-}"
  [basedir]="${basedir:-}"
  [dns_type]="${dns_type:-}"
  [configuration_file]="${configuration_file:-}"

  [logging]=1
  [log_dir]="${log_dir:-}"
  [log]="${log:-}"
  [log_console]=1
  [debug]=1

  [token_endpoint]=https://login.microsoftonline.com/@_tenant_id_@/oauth2/token
  [resource_endpoint]=https://management.core.windows.net/
  [grant_type]=client_credentials
  [tenant_id]=
  [client_id]=
  [client_secret]=
  [subscription_id]=
  [resource_group]=
  [api_version]=2018-05-01
  [private_zone]=1

  [access_token]=
  [base_url]=https://management.azure.com/subscriptions/@_subscription_id_@/resourceGroups/@_resource_group_@/providers/Microsoft.Network/dnsZones/@_zone_@
  [zone]=
  [record_prefix]=_acme-challenge
  [ttl]=120
  [propagation_seconds]=10
  [teardown_lazily]=0

  [execute]=
  [domain]=
  [record]=
  [token]=
); fi
if ! declare -p result >/dev/null 2>&1; then declare -i result=0; fi
# arguments
if [[ -z "${config[execute]:-}" ]]; then config[execute]=$(_execute="${1:-}"; echo "${_execute,,}" | sed -e 's/ \+//g'); fi
if [[ -z "${config[domain]:-}" ]]; then config[domain]=$(echo "${2:-}" | sed -e 's/^\*\.//' -e 's/ \+//g'); fi
if [[ -z "${config[zone]:-}" ]]; then config[zone]=$(_zone=$(expr match "${config[domain]:-}" '.*\.\(.*\..*\)'); [ -z "${_zone:-}" ] && _zone=${config[domain]}; echo "${_zone}"); fi
if [[ -z "${config[token]:-}" ]]; then config[token]=$(echo "${3:-}" | sed -e 's/^ \+//g' -e 's/ \+$//g'); fi

### function

###
# _log: simply logging
# usase: _log [level] [message]
# Note: no output any "debug" calls under mod_md processing, even if debug=0 .
function _log(){
  local -ar _logLevels=(DEBUG INFO WARN ERROR FATAL)
  local -r _logLevel=$(_1="${1:-debug}"; echo "${_1^^}" | sed -e 's/ \+//g')
  if [[ $(("${config[logging]}")) -ne 0 ]]; then :;
  elif [[ ! " ${_logLevels[@]} " =~ " ${_logLevel} " ]]; then :;
  elif [[ $(("${config[debug]}")) -ne 0 ]] && [[ "${_logLevel}" = "DEBUG" ]]; then :;
  else
    [ -n "${config[log_dir]}" ] && [ ! -d "${config[log_dir]}" ] && mkdir -p ${config[log_dir]}
    if [[ $(("${config[log_console]}")) -eq 0 ]] && [[ ! "${config[name]}" =~ certbot ]]; then
      bash -c "echo -e \"`date +"%Y-%m-%d %H:%M:%S"` - [${1}] ${2}\" $([ -n "${config[log]}" ] && [ -d "${config[log_dir]}" ] && echo "| tee -a ${config[log]}" )"
    elif [[ -n "${config[log]}" ]] && [[ -d "${config[log_dir]}" ]]; then
      bash -c "echo -e \"`date +"%Y-%m-%d %H:%M:%S"` - [${1}] ${2}\" >>${config[log]:-${log}}"
    fi
  fi

  return 0
}

###
# _request_header: add request header to API request with curl
function _request_header(){
  local -r _content_type=application/json
  if [[ -n "${config[access_token]:-}" ]]; then cat <<_EOT_
-H "Content-Type: ${_content_type}" \
-H "Authorization: Bearer ${config[access_token]}"
_EOT_
  else echo ''; fi
}

### processing
# read configuration
if [[ " ${config[@]} " =~ ' initialized ' ]]; then :;
elif ! curl --version >/dev/null 2>&1; then _log FATAL "enable to command \"curl\" first"; result=1;
elif ! python --version >/dev/null 2>&1; then _log FATAL "enable to command \"python\" first"; result=1;
elif [[ ! -f "${config[configuration_file]}" ]]; then _log FATAL "configuration_file \"${config[configuration_file]}\" not found"; result=1;
elif [[ ! " setup teardown " =~ " ${config[execute]:-} " ]]; then _log ERROR "required argument (1): \"setup\" or \"teardown\""; result=1;
elif [[ -z "${config[domain]:-}" ]]; then _log ERROR "required argument (2): \"domain\""; result=1;
elif [[ -z "${config[zone]:-}" ]]; then _log ERROR "could not resolv DNS zone name from domain \"${config[domain]:-}\""; result=1;
elif [[ "${config[execute]:-}" = 'setup' ]] && [[ -z "${config[token]:-}" ]]; then _log ERROR "required argument (3): \"validation token\""; result=1;
else
  for readline in $(cat ${config[configuration_file]} | grep -v ^# | grep -vE "^\s*\[.+\]" | grep -E ^.+=.+$ | sed -e 's/^ \+//g' -e 's/ \+$//g' | sort -r); do
    _key="$(echo ${readline} | sed -e 's/=.*$//')"
    _value="$(echo ${readline} | sed -e 's/^.*=//')"
    if [[ "${config[name]}" =~ certbot ]] && [[ ' log_console ' =~ " ${_key:-} " ]]; then :;
    else config[$(echo ${_key})]="$([ "${_key}" = "log" ] && echo ${config[log_dir]} | sed -e 's/[^\/]$/\0\//')${_value}"; fi
  done

  config[token_endpoint]=$(echo "${config[token_endpoint]:-@_undefined_@}" | sed -e "s/@_tenant_id_@/${config[tenant_id]}/g")
  config[base_url]=$(echo "${config[base_url]:-@_undefined_@}" | sed -e "s/@_subscription_id_@/${config[subscription_id]:-@_undefined_@}/g" -e "s/@_resource_group_@/${config[resource_group]:-@_undefined_@}/g" -e "s/@_zone_@/${config[zone]:-@_undefined_@}/g")
  if [[ $(("${config[private_zone]:-1}")) -eq 0 ]]; then config[base_url]=$(echo "${config[base_url]:-}" | sed -e 's/\/dnsZones\//\/privateDnsZones\//g'); fi

  if [[ "${config[base_url]:-@_undefined_@}" =~ '@_undefined_@' ]]; then _log ERROR "misconfiguration: invalid \"API endpoint URL\""; result=1;
  elif [[ "${config[token_endpoint]:-@_undefined_@}" =~ '@_undefined_@' ]]; then _log ERROR "misconfiguration: invalid \"API token endpoint URL\""; result=1;
  elif [[ ! "${config[domain]:-}" =~ "${config[zone]:-@_undefined_@}" ]]; then _log ERROR "misconfiguration: \"DNS zone\" unmatched for the domain\\n  ( domain: \"${config[domain]}\", zone: \"${config[zone]}\" )"; result=1;
  elif [[ -z "${config[api_version]:-}" ]]; then _log ERROR "misconfiguration: \"API version\" unspecified"; result=1; fi
fi

if [[ $(("${result:-1}")) -eq 0 ]]; then
  # get an access token
  _response=$(cat <<_EOT_|bash
curl -s -X POST "${config[token_endpoint]}" \
 -d "grant_type=${config[grant_type]}" \
 -d "resource=${config[resource_endpoint]}" \
 -d "client_id=${config[client_id]}" \
 -d "client_secret=${config[client_secret]}"
_EOT_
  )
  config[access_token]=$(echo ${_response} | python -c "import sys;import json;data=json.load(sys.stdin);print(data['access_token']) if 'access_token' in data else False;")
  if [[ -z "${config[access_token]:-}" ]]; then _log ERROR "could not retrieve API access Token\\n  ${_response}"; result=1; fi
fi

if [[ $(("${result:-1}")) -ne 0 ]]; then :;
elif [[ -z "$(_request_header)" ]]; then result=1;
else
  # DNS zone validation
  _response=$(cat <<_EOT_|bash
curl -s -X GET "${config[base_url]}?api-version=${config[api_version]}" \
$(_request_header)
_EOT_
  )
  config[zone]=$(echo ${_response} | python -c "import sys;import json;data=json.load(sys.stdin);print(data['name']) if 'name' in data else False;")
  if [[ -z "${config[zone]:-}" ]]; then _log ERROR "could not resolv DNS zone ID from domain \"${config[domain]:-}\"\\n  ${_response}"; result=1; fi
fi

if [[ $(("${result:-1}")) -eq 0 ]]; then
  config[record]="${config[record_prefix]}$([[ -z "${config[record_prefix]:-}" ]] || echo '.')$(echo "${config[domain]}" | sed -e "s/\.${config[zone]}$//")"
fi

_log DEBUG "config\\n$(for k in ${!config[@]}; do echo "  $k=${config[$k]}"; done)"

if [[ $(("${result:-1}")) -ne 0 ]]; then exit $((${result:-1}));
else config[initialized]="${0:-${name}}"; fi
