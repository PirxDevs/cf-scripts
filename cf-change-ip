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
Usage: $(basename "$0") -z DNS_ZONE -o IP -n IP

Options:
  -z <zone> - name of DNZ zone to edit
  -o <ip> - old IP address
  -n <ip> - new IP address
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

while getopts ":z:o:n:h" option; do
  case "${option}" in
    z) zone="${OPTARG}" ;;
    o) old_ip="${OPTARG}" ;;
    n) new_ip="${OPTARG}" ;;
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

if [ -z "${zone}" ] || [ -z "${old_ip}" ] || [ -z "${new_ip}" ]; then
  usage
fi

api_data=$(cf_api GET "zones?name=${zone}") || bail_out "${api_data}"
if [ $(echo "${api_data}" | jq -r '.result_info["count"]') -eq 0 ]; then
  echo "DNS zone ${zone} not found"
  exit 1
fi

zone_id=$(echo "${api_data}" | jq -r '.result[0].id')
if [ -z "${zone_id}" ]; then
  log "Error getting DNS zone id"
  exit 1
fi

api_data=$(cf_api GET "zones/${zone_id}/dns_records?type=A") || bail_out "${api_data}"
records=$(echo "${api_data}" | jq -c '.result[]')

if [ -z "${records}" ]; then
  exit 0
fi

while read -r record; do
  record_name=$(echo "${record}" | jq -r '.name')
  record_ip=$(echo "${record}" | jq -r '.content')
  if [ "${record_ip}" = "${old_ip}" ]; then
    echo "Updating ${record_name}: ${old_ip} -> ${new_ip}"
    "${script_dir}/cf-dns.sh" \
      -a update \
      -z "${zone}" \
      -n "${record_name%.${zone}}"
    if [ $? -ne 0 ]; then
      echo "Failed updating ${record_name}"
      exit 1
    fi
  fi
done <<< "${records}"

exit 0
