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
Usage: $(basename "$0") -o IP -n IP

Options:
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

while getopts ":o:n:h" option; do
  case "${option}" in
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

if [ -z "${old_ip}" ] || [ -z "${new_ip}" ]; then
  usage
fi

page=1
while :; do
  api_data=$(cf_api GET "zones?page=${page}&per_page=100") || bail_out "${api_data}"
  count=$(echo "${api_data}" | jq -r '.result | length')
  if [ "${count}" -eq 0 ]; then
    break
  fi
  while read -r zone_name; do
    echo "Processing domain: ${zone_name}"
    "${script_dir}/cf-change-ip.sh" \
      -z "${zone_name}" \
      -o "${old_ip}" \
      -n "${new_ip}"
    if [ $? -ne 0 ]; then
      echo "Failed processing domain ${zone_name}"
    fi
  done < <(echo "${api_data}" | jq -r '.result[].name')
  page=$((page + 1))
done

exit 0
