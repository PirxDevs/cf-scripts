#!/bin/bash

# Copyright (C) 2026 Pirx Developers - https://pirx.dev/
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

usage() {
  cat <<EOF
Usage: $(basename "$0") -a ACTION -z DNS_ZONE -n NAME [-v VALUE] [-t TYPE] [-l TTL] [-p VALUE]

Options:
  -a <action> - action to perform, valid ones are set, update or remove
  -z <zone> - name of DNS zone to edit
  -n <record> - name of DNS record to set/update/remove
  -v <value> - value of DNS record to set
  -t <type> - type of DNS record to set
  -l <ttl> - ttl value for DNS record, default: 1 (Auto)
  -p <value> - true or false to set record proxied or not
  -r <value> - priority for MX records
  -h - show this help
EOF
  exit 0
}

script_dir="$(realpath "${0}")"
script_dir="$(dirname "${script_dir}")"

if test -f "${script_dir}/shared"; then
  . "${script_dir}/shared"
else
  echo "Shared code file not found or not readable"
  exit 1
fi

while getopts ":a:z:n:v:t:l:p:r:h" option; do
  case "${option}" in
    a) action="${OPTARG}" ;;
    z) zone="${OPTARG}" ;;
    n) name="${OPTARG}" ;;
    v) value="${OPTARG}" ;;
    t) type=$(echo "${OPTARG}" | tr '[:lower:]' '[:upper:]') ;;
    l) ttl="${OPTARG}" ;;
    p) proxied="${OPTARG}" ;;
    r) priortiy="${OPTARG}" ;;
    h) usage ;;
    :)
      echo "Error: option -${OPTARG} requires an argument"
      exit 1
      ;;
    \?)
      echo "Error: invalid option -${OPTARG}"
      exit 1
      ;;
  esac
done

if [ -z "${action}" ] || ([ "${action}" != "set" ] && [ "${action}" != "update" ] && [ "${action}" != "remove" ]); then
  echo "Error: missing or invalid action"
  exit 1
fi

if [ -z "${zone}" ]; then
  echo "Error: DNS zone is required"
  exit 1
fi

if [ -z "${name}" ]; then
  echo "Error: DNS record name is required"
  exit 1
fi

if [ "${action}" = "set" ]; then
  if [ -z "${type}" ]; then
    echo "Error: DNS record type is required"
    exit 1
  elif [ -z "${value}" ]; then
    echo "Error: DNS record value is required"
    exit 1
  elif [ -z "${proxied}" ]; then
    echo "Error: proxied is required"
    exit 1
  fi
fi

if [ "${type}" = "MX" ] && [ -z "${priority}" ]; then
  echo "Error: priority is required for MX records"
  exit 1
fi

if [ -n "${proxied}" ] && [ "${proxied}" != "true" ] && [ "${proxied}" != "false" ]; then
  echo "Error: proxied value must be true or false"
  exit 1
fi

if [ -z "${ttl}" ]; then
  ttl=1
else
  if ! [[ "${ttl}" =~ ^[0-9]+$ ]]; then
    echo "Error: TTL must be a number"
    exit 1
  fi
  if [ "${ttl}" -ne 1 ] && ([ "${ttl}" -lt 60 ] || [ "${ttl}" -gt 86400 ]); then
    echo "Error: TTL must be 1 (Auto) or between 60 and 86400"
    exit 1
  fi
fi

if [ -n "${priority}" ]; then
  if ! [[ "${priority}" =~ ^[0-9]+$ ]]; then
    echo "Error: MX priority must be a number"
    exit 1
  fi
  if [ "${priority}" -lt 0 ] || [ "${priority}" -gt 65535 ]; then
    echo "Error: MX priority must be between 0 and 65535"
    exit 1
  fi
fi

if [ -n "${type}" ]; then
  if ! [[ "${type}" =~ ^(A|AAAA|CNAME|TXT|MX|NS|PTR)$ ]]; then
    echo "Error: invalid or unsupported record type '${type}'"
    exit 1
  fi
fi

api_data=$(cf_api GET "zones?name=${zone}") || bail_out "${api_data}"
if [ $(echo "${api_data}" | jq -r '.result_info["count"]') -eq 0 ]; then
  echo "DNS zone ${zone} not found"
  exit 1
fi

zone_id=$(echo "${api_data}" | jq -r '.result[0].id')
if [ -z "${zone_id}" ]; then
  echo "Error getting DNS zone id"
  exit 1
fi

if [ "${name}" = "${zone}" ]; then
  record_name="${name}"
else
  record_name="${name}.${zone}"
fi

api_data=$(cf_api GET "zones/${zone_id}/dns_records?name=${record_name}") || bail_out "${api_data}"
if [ $(echo "${api_data}" | jq -r '.result_info["count"]') -ne 0 ]; then
  record_id=$(echo "${api_data}" | jq -r '.result[0].id')
  if [ -z "${record_id}" ]; then
    echo "Error getting DNS record id"
    exit 1
  fi
fi

if [ "${action}" = "set" ]; then
  data=$(jq -n \
    --arg name "${name}" \
    --arg type "${type}" \
    --arg content "${value}" \
    --argjson ttl ${ttl} \
    --argjson proxied ${proxied} \
      '{type: $type, name: $name, content: $content, ttl: $ttl, proxied: $proxied}')
  if [ "${type}" = "MX" ]; then
    data=$(echo "${data}" | jq --argjson priority "${priority}" '.priority=$priority')
  fi
  if [ -z "${record_id}" ]; then
    api_data=$(cf_api POST "zones/${zone_id}/dns_records" "${data}") || bail_out "${api_data}"
  else
    api_data=$(cf_api PUT "zones/${zone_id}/dns_records/${record_id}" "${data}") || bail_out "${api_data}"
  fi
  echo "Record ${record_name} set"
elif [ "${action}" = "update" ]; then
  if [ -z "${record_id}" ]; then
    echo "Record ${record_name} not found"
    exit 1
  fi
  data='{}'
  if [ -n "${value}" ]; then
    data=$(echo "${data}" | jq --arg v "${value}" '.content=$v')
  fi
  if [ -n "${type}" ]; then
    data=$(echo "${data}" | jq --arg v "${type}" '.type=$v')
  fi
  if [ -n "${ttl}" ]; then
    data=$(echo "${data}" | jq --argjson v "${ttl}" '.ttl=$v')
  fi
  if [ -n "${proxied}" ]; then
    data=$(echo "${data}" | jq --argjson v "${proxied}" '.proxied=$v')
  fi
  if [ "${type}" = "MX" ] && [ -n "${priority}" ]; then
    data=$(echo "${data}" | jq --argjson v "${priority}" '.priority=$v')
  fi
  if [ "${data}" = "{}" ]; then
    echo "Nothing to update"
    exit 1
  fi
  api_data=$(cf_api PATCH "zones/${zone_id}/dns_records/${record_id}" "${data}") || bail_out "${api_data}"
  echo "Record ${record_name} updated"
elif [ "${action}" = "remove" ]; then
  api_data=$(cf_api DELETE "zones/${zone_id}/dns_records/${record_id}") || bail_out "${api_data}"
  echo "Record ${record_name} removed"
fi

exit 0
